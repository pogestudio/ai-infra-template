#!/usr/bin/env bash
#
# ralph/ralph-loop-done.sh — signal end-of-iteration to the Ralph loop.
#
# Modes:
#   ./ralph/ralph-loop-done.sh --issueDone <N>
#     Close issue #N so the queue advances, but only after BOTH gates pass:
#       * proof-of-work — a commit referencing #N exists on origin/ralph-loop (so an empty claim
#         can't advance the queue). This replaces the old PR `Closes #N` + strict-local-HEAD checks,
#         which don't fit the no-PR, many-loops-one-branch model (HEAD races other loops' pushes).
#       * green tests — backend pytest + frontend vitest (scripts/run-tests.sh).
#     On success: close #N, REMOVE this loop's claimed-ralph-<id> label (release the claim), and
#     clear the on-disk plan.
#
#   ./ralph/ralph-loop-done.sh
#     Mark the whole loop done. The bash runner exits after this iteration.
#
# On success, both modes SIGKILL this script's own claude ancestor (walked via /proc, since pkill
# isn't installed here) to short-circuit the iteration timeout, so the runner picks up the next
# issue immediately. See the kill block at the bottom.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ralph-loop-kill-self.sh
source "$SCRIPT_DIR/ralph-loop-kill-self.sh"
cd "$SCRIPT_DIR/.."   # repo root: ./scripts/run-tests.sh + the PLAN path resolve from here

ID="${RALPH_LOOP_ID:-0}"
MY="claimed-ralph-$ID"
BRANCH="ralph-loop"
PLAN="AI-Info/implementation-plans/current/current-plan.md"

# Green-test gate: never advance the queue on red. Delegates to the single test entrypoint
# (self-heals frontend native-binary drift, then backend pytest + frontend vitest) so this gate
# and /ralph-tdd can't drift apart.
run_test_gate() { ./scripts/run-tests.sh; }

# Clear the per-issue implementation plan so the next issue starts with no plan — which makes the
# picker report MODE=plan and /ralph-tdd-plan re-plan from the template. The plan is gitignored.
reset_plan() {
  [[ -f "$PLAN" ]] || return 0
  rm -f "$PLAN"
  echo "ralph-loop: cleared implementation plan ($PLAN)" >&2
}

case "${1:-}" in
  --issueDone)
    issue="${2:-}"
    if [[ -z "$issue" ]]; then
      echo "usage: ralph-loop-done.sh --issueDone <issue-number>" >&2
      exit 1
    fi

    # Proof-of-work gate: a commit referencing #<issue> must be on origin/ralph-loop. This is what
    # forces real, PUSHED work before the queue advances (there is no PR in this model). The digit
    # boundary — #N followed by a non-digit or end-of-line — stops #17 from matching #170. Cheap, so
    # it runs before the test gate.
    if ! git fetch origin "$BRANCH" >&2; then
      echo "ERROR: couldn't fetch origin/$BRANCH to verify proof-of-work." >&2
      exit 1
    fi
    pow=$(git log "origin/$BRANCH" -E --grep="#${issue}([^0-9]|\$)" -n1 --format='%h' || true)
    if [[ -z "$pow" ]]; then
      echo "ERROR: no commit referencing #$issue on origin/$BRANCH — push the work (with #$issue in the commit message) before signaling done." >&2
      exit 1
    fi

    # Green-test gate: refuse to advance the queue unless the suite passes.
    if ! run_test_gate; then
      echo "ERROR: test gate failed — refusing to close #$issue. Get to green, then retry." >&2
      exit 1
    fi

    echo "ralph-loop: closing #$issue (proof-of-work $pow on origin/$BRANCH)"
    # gh issue close tolerates an already-closed issue with `|| true`.
    gh issue close "$issue" --comment "Implemented on $BRANCH ($pow)." || true
    # Release my claim so the picker won't resume a closed issue, and the per-loop label stays bounded.
    gh issue edit "$issue" --remove-label "$MY" >/dev/null 2>&1 || true
    reset_plan
    ;;
  "")
    echo "status=DONE" > ./ralph/.ralph-status
    echo "ralph-loop: whole loop done — ending this iteration"
    ;;
  *)
    echo "ralph-loop-done.sh: unknown arg '$1'" >&2
    exit 1
    ;;
esac

# End the iteration now (SIGKILL our own claude ancestor) instead of idling until the iteration
# timeout, so the runner picks up the next issue immediately. Shared with ralph-loop-plan-done.sh;
# the how + why lives in ralph-loop-kill-self.sh.
ralph_kill_iteration
