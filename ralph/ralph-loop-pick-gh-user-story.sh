#!/usr/bin/env bash
#
# ralph/ralph-loop-pick-gh-user-story.sh — pick AND CLAIM the next user-story issue.
#
# CONCURRENCY MODEL (multiple loops share the single origin/ralph-loop branch)
#   Up to 4 Ralph loops run at once, one per clone, each with a stable RALPH_LOOP_ID (0..3,
#   default 0). A loop CLAIMS an issue by adding the per-loop label `claimed-ralph-<id>`. That
#   label is the SINGLE source of truth for BOTH:
#     * cross-loop dedup — every loop excludes any issue carrying ANY `claimed-ralph-*` label, so
#                          two loops never work the same issue;
#     * self-resume      — a SIGKILL'd loop re-finds its work by querying open issues labelled
#                          `claimed-ralph-<my-id>` (no local marker file).
#
# WHAT THIS DOES each iteration (ralph-loop.sh runs it BEFORE it spawns claude):
#   1. RESUME first (the claim is idempotent across restarts): if I already hold an issue, re-hand
#      it — UNLESS the on-disk plan is tagged for a DIFFERENT issue (drift), in which case the drift
#      handler unclaims + clears the plan and we fall through to a fresh pick.
#   2. FRESH PICK + claim-verify: lowest open `agent-ready` issue, blockers all closed, NOT already
#      claimed by anyone. Add my label, re-read, and if another loop also claimed it the LOWEST id
#      wins (the loser drops its label and takes the next issue) — a deterministic tie-break that
#      makes the rare simultaneous-claim race safe.
#
# Output (stdout, key=value):
#   STATUS=found|done|unknown
#   ISSUE=<n>  BRANCH=ralph-loop  MODE=plan|tdd     (found — MODE drives the runner's prompt+timer)
#   KIND=feature|comm-test                          (found — comm-test ⇒ runner skips FE research+e2e)
#   MESSAGE=<text>                                  (unknown)
# KIND is ALWAYS emitted on found (feature is the default) so the runner's bare `grep '^KIND='`
# can't fail under its `set -euo pipefail`; never make a found-path key optional again.
# MODE=plan → no plan yet for this issue → planning iteration (/ralph-tdd-plan, 1.5× budget).
# MODE=tdd  → an on-disk plan tagged this issue exists → build iteration (/ralph-tdd, 1× budget).
#
# Progress logs go to stderr; stdout is parseable for the caller.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."   # repo root: the PLAN path, ./scripts, and git all resolve from here

BRANCH="ralph-loop"
ID="${RALPH_LOOP_ID:-0}"
MY="claimed-ralph-$ID"
PLAN="AI-Info/implementation-plans/current/current-plan.md"

emit_found()   { echo "STATUS=found"; echo "ISSUE=$1"; echo "BRANCH=$BRANCH"; echo "MODE=$2"; if is_comm_test "$1"; then echo "KIND=comm-test"; else echo "KIND=feature"; fi; exit 0; }
emit_done()    { echo "STATUS=done"; exit 0; }
emit_unknown() { echo "STATUS=unknown"; echo "MESSAGE=$1"; exit 0; }
log() { echo "ralph-loop-pick[$ID]: $*" >&2; }

# Preflight
command -v gh >/dev/null 2>&1 || emit_unknown "gh CLI not installed."
command -v jq >/dev/null 2>&1 || emit_unknown "jq not installed."
gh auth status >/dev/null 2>&1 || emit_unknown "gh CLI not authenticated. Run 'gh auth login' or set GH_TOKEN."

# Tree may be dirty after a SIGKILL'd iteration. We stay on ralph-loop, so a dirty tree is
# tolerable while resuming; only block if we'd need to leave a dirty branch to switch.
require_clean_to_switch() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    emit_unknown "Dirty tree on $(git branch --show-current) but need to switch to $BRANCH. Commit or revert the in-flight work."
  fi
}

# Ensure we're on the single ralph-loop branch: local → remote (fetch+switch) → create from main.
ensure_branch() {
  local cur; cur=$(git branch --show-current)
  [[ "$cur" == "$BRANCH" ]] && return 0
  require_clean_to_switch
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    log "switching to local $BRANCH"
    git switch "$BRANCH" >&2
  elif git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    log "fetching + switching to origin/$BRANCH"
    git fetch origin "$BRANCH" >&2
    git switch "$BRANCH" >&2
  else
    log "creating $BRANCH from origin/main"
    git fetch origin main >&2
    git switch main >&2
    git merge --ff-only origin/main >&2 2>/dev/null || true
    git switch -c "$BRANCH" >&2
  fi
}

# Extract #N blocker refs from a 'Blocked by' section. Uses portable POSIX-ERE quantifiers
# (#* / #+, not #{0,6}) because the system awk is mawk, which has no interval-expression
# support — #{0,6} silently never matches, so the header was invisible and every blocker was
# missed. Skips the blank line(s) right after the header (standard Markdown), then collects
# refs until the blank line AFTER the refs / the next header / a horizontal rule.
extract_blockers() {
  local section
  section=$(awk '
    BEGIN { in_section = 0; seen = 0 }
    /^[[:space:]]*#*[[:space:]]*[Bb]locked by/ { in_section = 1; next }
    in_section && /^[[:space:]]*$/ { if (seen) exit; else next }
    in_section && /^[[:space:]]*#+[[:space:]]/ { exit }
    in_section && /^---/ { exit }
    in_section { print; seen = 1 }
  ' <<<"$1")
  # Explicit "no blockers" sentinel. If the section opens with None / N/A (optionally
  # italicised — "_None._", "None — can start immediately"), there are ZERO blockers, even
  # when explanatory prose on that same line name-drops other #refs. Without this, a helpful
  # "_None._ … #52 and #53 extend this" sentence makes the picker treat #52/#53 as blockers
  # and the issue is wrongly skipped (see #51, P4.6).
  if grep -qiE '^[[:space:]]*[_*]*n(one|/a)([^[:alpha:]]|$)' <<<"$section"; then
    return 0
  fi
  grep -oE '#[0-9]+' <<<"$section" | tr -d '#' | sort -un
}

is_closed() { [[ "$(gh issue view "$1" --json state -q '.state' 2>/dev/null)" == "CLOSED" ]]; }

# Does this issue carry the `comm-test` label? A backend-only behaviour test has no frontend and no
# browser e2e, so the runner forwards KIND=comm-test into the prompt and the planning fan-out skips
# the frontend research while the build skips Playwright (ralph-loop.sh + the ralph-tdd* skills carry
# the matching guards). Emitted by emit_found, so it costs one extra read only on the launched issue.
is_comm_test() { [[ "$(gh issue view "$1" --json labels --jq 'any(.labels[].name; . == "comm-test")' 2>/dev/null)" == "true" ]]; }

# The issue number tagged in the on-disk plan (the planner writes "**Issue:** #N"); empty if no
# plan. The drift check and MODE both key off this — it's how a restart tells "build the planned
# issue" from "this plan is for a different/older issue".
plan_issue() {
  [[ -f "$PLAN" ]] || return 0
  grep -m1 -iE '^[*_[:space:]]*issue:' "$PLAN" | grep -oE '#[0-9]+' | head -n1 | tr -d '#'
}

# MODE for an issue we hold: build (tdd) only if the on-disk plan is tagged for THIS issue;
# otherwise plan. Matches the old "no plan on disk → planning iteration (1.5×)" signal.
mode_for() {
  local pi; pi=$(plan_issue)
  if [[ -n "$pi" && "$pi" == "$1" ]]; then echo tdd; else echo plan; fi
}

# Make sure THIS loop's claim label exists before we use it. A fresh clone or a new
# RALPH_LOOP_ID may not have had it created yet — and `gh issue edit --add-label "$MY"` FAILS
# on a missing label, so a brand-new loop id could never claim. Idempotent: create only when
# absent, so adding a loop needs no manual `gh label create`.
ensure_label() {
  gh label list -L 200 --json name --jq '.[].name' 2>/dev/null | grep -qxF "$MY" && return 0
  log "claim label '$MY' not found — creating it"
  gh label create "$MY" --color 5319E7 \
    --description "Ralph loop $ID claim (added on claim, removed on close)" >/dev/null 2>&1 \
    || log "note: could not create '$MY' (another loop may have just created it)"
}
ensure_label

# ---- 1. RESUME: do I already hold an issue? (claim is idempotent across restarts) ----------------
mine=$(gh issue list --state open --label "$MY" --json number --jq 'map(.number) | min // empty' 2>/dev/null || true)
if [[ -n "$mine" ]]; then
  pi=$(plan_issue)
  if [[ -z "$pi" || "$pi" == "$mine" ]]; then
    log "resuming my claim #$mine (mode $(mode_for "$mine"))"
    ensure_branch
    emit_found "$mine" "$(mode_for "$mine")"
  fi
  # Drift: I hold #$mine but the plan on disk is for #$pi. Hand off to the drift handler — it logs,
  # drops my label, deletes the stale plan (and SIGKILLs if under claude, a no-op here pre-launch).
  # Then fall through to a fresh pick with a clean slate.
  log "drift: hold #$mine but plan is tagged #$pi — running drift handler"
  "$SCRIPT_DIR/ralph-issue-drift.sh" "$mine" "$pi" || true
fi

# ---- 2. No active claim ⇒ any on-disk plan is orphaned (its issue closed, or drift cleared a
#         mismatched one). Sweep it so a fresh claim starts in plan mode, not a stale build. -------
if [[ -f "$PLAN" ]]; then
  log "no active claim but a plan is on disk — clearing orphaned $PLAN"
  rm -f "$PLAN"
fi

# ---- 3. FRESH PICK + claim-verify ----------------------------------------------------------------
# Optional small jitter decorrelates two loops that wake in lockstep. The lowest-id tie-break below
# already makes a simultaneous claim safe; this just makes one less likely.
sleep "$(( RANDOM % 3 ))"

# Candidates: open `agent-ready`, ascending, EXCLUDING any issue already claimed by ANY loop.
cands=$(gh issue list --state open --label agent-ready -L 200 --json number,labels \
  --jq 'map(select(any(.labels[].name; startswith("claimed-ralph-")) | not)) | sort_by(.number) | .[].number')

if [[ -z "$cands" ]]; then
  log "no open, unclaimed agent-ready issues"
  emit_done
fi

for num in $cands; do
  # Blockers must all be closed (bodies are multi-line → fetch each separately).
  body=$(gh issue view "$num" --json body -q '.body' 2>/dev/null || echo "")
  blocked=false
  for b in $(extract_blockers "$body"); do
    is_closed "$b" || { blocked=true; break; }
  done
  if $blocked; then
    log "issue #$num blocked by an open issue — skipping"
    continue
  fi

  # Claim, then VERIFY: add my label, let GitHub settle, re-read ALL claimers. The lowest id among
  # them wins; if that's not me I lost the race — drop my label and take the next issue.
  log "claiming #$num with $MY"
  gh issue edit "$num" --add-label "$MY" >/dev/null 2>&1 || { log "couldn't add $MY to #$num — skipping"; continue; }
  sleep 2
  winner=$(gh issue view "$num" --json labels \
    --jq '[.labels[].name | select(startswith("claimed-ralph-")) | ltrimstr("claimed-ralph-") | tonumber] | min // empty' 2>/dev/null || true)
  if [[ "$winner" == "$ID" ]]; then
    log "won #$num (lowest claimer id = $winner = me)"
    ensure_branch
    emit_found "$num" "$(mode_for "$num")"
  fi
  log "lost #$num (lowest claimer id = ${winner:-none}, not me) — dropping $MY, trying next"
  gh issue edit "$num" --remove-label "$MY" >/dev/null 2>&1 || true
done

log "all open unclaimed agent-ready issues are blocked or lost to other loops"
emit_done
