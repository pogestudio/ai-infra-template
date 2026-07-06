#!/usr/bin/env bash
#
# ralph/ralph-loop.sh — autonomous issue runner (concurrency-safe; one loop per clone).
#
# WHAT IT DOES
#   Each iteration: run the pick-AND-claim picker (it CLAIMS an issue with this loop's
#   `claimed-ralph-<id>` label and reports MODE=plan|tdd), then launch a fresh, capped `claude`
#   session preseeded with the matching prompt as its first user turn:
#     MODE=plan → ralph/PROMPT-plan.md, 1.5× budget (the heavy /ralph-tdd-plan fan-out → reconcile)
#     MODE=tdd  → ralph/PROMPT-tdd.md,  1× budget (build from the on-disk plan)
#   The session is capped then SIGKILLed; the next iteration starts fresh (no context carryover)
#   and the claim label lets it resume the SAME issue. Stops when:
#     - the picker reports STATUS=done at the top of an iteration (queue empty / all claimed / blocked);
#     - ./ralph/.ralph-status contains `status=DONE` (set by ralph/ralph-loop-done.sh);
#     - You Ctrl-C.
#
#   Multiple loops (RALPH_LOOP_ID 0..3, one per clone) run this concurrently against the single
#   origin/ralph-loop branch; the per-loop claim label keeps them off each other's issues.
#
# HOW TO RUN
#   1. Label issues `agent-ready`. Create the claim labels once: `gh label create claimed-ralph-0` …
#   2. Set RALPH_LOOP_ID per clone in .env.claude (unset ⇒ 0). `gh auth status` must succeed.
#   3. Inside the dev container shell (`./run-claude.sh`):  ./ralph/ralph-loop.sh
#
# HOW TO STOP
#   - Ctrl-C in the terminal at any time.
#   - From inside a claude session:
#       ./ralph/ralph-loop-done.sh --issueDone <N>   # end current iteration only
#       ./ralph/ralph-loop-done.sh                    # whole loop done; bash exits next iter
#
# FILES (all in ralph/)
#   PROMPT-plan.md / PROMPT-tdd.md     the two per-iteration prompts (plan vs build)
#   ralph-loop-pick-gh-user-story.sh   pick AND CLAIM next issue; emits STATUS / ISSUE / MODE
#   ralph-loop-done.sh                 issue done: proof-of-work + green gate, close, unclaim
#   ralph-loop-plan-done.sh            plan written: end iteration so the build starts fresh next
#   ralph-issue-drift.sh               claim↔plan mismatch handler (unclaim + clear plan + restart)
#   ralph-loop-kill-self.sh            shared helper: SIGKILL this iteration's claude
#   .ralph-status                      runtime done-marker (gitignored)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."   # repo root: ./ralph/… and ./scripts/… resolve regardless of caller cwd

PICKER="./ralph/ralph-loop-pick-gh-user-story.sh"
PROMPT_PLAN="./ralph/PROMPT-plan.md"
PROMPT_TDD="./ralph/PROMPT-tdd.md"
STATUS_FILE="./ralph/.ralph-status"
ITERATION_TIMEOUT=1400   # per-iteration build budget in seconds (plan iterations get 1.5×, below)

# Model strategy (Anthropic's Opus-lead / Sonnet-worker pattern beat solo Opus):
#   ORCHESTRATOR — both plan and tdd iterations — runs on Opus 4.7 with a 1M context window so a long
#   autonomous iteration never compacts mid-build. (Effort is xhigh, pinned container-wide in the
#   Dockerfile via CLAUDE_CODE_EFFORT_LEVEL — it overrides any per-launch --effort flag.) We pin 1M
#   via the alias env var below rather than
#   `--model opus[1m]`: as of CLI v2.1.114 `--model` silently strips the `[1m]` suffix
#   (anthropics/claude-code#50803), whereas ANTHROPIC_DEFAULT_OPUS_MODEL applies it reliably AND pins
#   the version. 1M carries no per-token premium beyond 200K.
#   SUBAGENTS — the bulk of per-iteration tokens (the /ralph-tdd-plan research+reconcile waves and the
#   build workers) — stay on Sonnet (200K; no 1M usage-credits) to keep cost down.
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-7[1m]'   # `opus` alias ⇒ Opus 4.7, 1M context
export CLAUDE_CODE_SUBAGENT_MODEL=sonnet

# --- Self-reload guard ---------------------------------------------------------------------------
# This loop's own source lives on the ralph-loop branch it builds on, so an iteration's
# non-fast-forward `git pull` can swap ralph-loop.sh / the PROMPT-*.md templates UNDER this
# long-running process. Bash parses the `while` body ONCE and runs it from memory — it does NOT
# re-read the script per iteration — so a stale parent keeps feeding the NEW @@ISSUE@@ templates
# through its OLD launcher WITHOUT the substitution step, handing Claude literal @@ISSUE@@ (the
# P3.26a/b incident: line 161 still ran `claude ... "$(cat "$prompt_file")"` after the file on disk
# had moved to the substituted `"$prompt_text"`). Fix: fingerprint our source each iteration and
# `exec` a fresh copy when it changes, so the next iteration always runs current on-disk code. The
# runtime dotfiles (.ralph-status, .drift-log) carry no .sh/.md extension, so the globs skip them —
# no spurious reloads. `|| true` keeps a missing cksum from tripping `set -e` (fail-safe: equal
# fingerprints ⇒ no reload).
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
ralph_infra_fingerprint() { cat "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.md 2>/dev/null | cksum 2>/dev/null || true; }

rm -f "$STATUS_FILE"

# Heal the frontend's per-OS native binaries up front (host↔container node_modules drift).
# FATAL on failure: if this can't be readied, the test gate can never run, so the loop has
# nothing to validate against — fail loud now rather than thrash through ungated iterations.
if ! ./scripts/ensure-vite-arch.sh; then
  echo "ralph-loop: ERROR — ensure-vite-arch failed; frontend tests can't run. Fix the env (e.g. npm install) and retry." >&2
  exit 1
fi

iteration=0
ralph_src_fingerprint="$(ralph_infra_fingerprint)"
while true; do
  iteration=$((iteration + 1))
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Self-reload if our own source changed since we started (see the guard note above) — e.g. the
  # previous iteration pulled new loop infra on a non-ff push. exec a fresh copy so this process
  # runs current on-disk code (incl. the @@ISSUE@@/@@LOOP_ID@@ substitution) instead of its stale,
  # already-parsed in-memory body. exec replaces the process, so iteration numbering restarts — the
  # picker just re-resumes the active claim, which is the loop's normal resume path.
  if [[ "$(ralph_infra_fingerprint)" != "$ralph_src_fingerprint" ]]; then
    echo "ralph-loop: ralph/ source changed under the running process — re-exec'ing to load current code." >&2
    exec "$SELF"
  fi

  if [[ -f "$STATUS_FILE" ]] && grep -q '^status=DONE$' "$STATUS_FILE"; then
    echo
    echo "ralph-loop: DONE after $((iteration - 1)) iteration(s)."
    exit 0
  fi

  # Pick AND claim at the top of every iteration. This call has side effects (it adds the claim
  # label), unlike the old read-only peek — but it keeps that peek's safety role too: a claude that
  # crashes or hallucinates without writing the DONE marker can't spin the loop forever, because the
  # picker reports STATUS=done once the queue is empty. Read STATUS/MODE/ISSUE from key=value stdout.
  set +e
  picker_out=$("$PICKER")
  # Parse under `set +e` too: an OPTIONAL key (KIND, emitted only for comm-test issues) means its
  # `grep` finds nothing and exits 1, which `pipefail` propagates to the bare assignment — under
  # `set -e` that SILENTLY kills the whole loop right here, before the banner (the regression that
  # made every non-comm-test issue exit at once). Keeping `set -e` off through the parse also makes
  # the `*)` "no usable STATUS → retry" branch below reachable on garbled/partial picker output,
  # instead of crashing at the STATUS grep first.
  picker_status=$(grep -E '^STATUS=' <<<"$picker_out" | head -n1 | cut -d= -f2-)
  mode=$(grep -E '^MODE=' <<<"$picker_out" | head -n1 | cut -d= -f2-)
  issue=$(grep -E '^ISSUE=' <<<"$picker_out" | head -n1 | cut -d= -f2-)
  kind=$(grep -E '^KIND=' <<<"$picker_out" | head -n1 | cut -d= -f2-)   # comm-test ⇒ skip FE research + e2e
  set -e

  case "$picker_status" in
    done)
      echo
      echo "ralph-loop: queue empty (picker STATUS=done) — exiting after $((iteration - 1)) iteration(s)."
      echo "status=DONE" > "$STATUS_FILE"
      exit 0
      ;;
    unknown)
      msg=$(grep -E '^MESSAGE=' <<<"$picker_out" | head -n1 | cut -d= -f2-)
      echo "ralph-loop: picker STATUS=unknown — ${msg:-no message}; retrying in 30s." >&2
      sleep 30
      continue
      ;;
    found) : ;;
    *)
      echo "ralph-loop: picker gave no usable STATUS (transient gh/network error?) — retrying in 30s." >&2
      sleep 30
      continue
      ;;
  esac

  # MODE from the picker drives the prompt and the budget — the picker is the single source of truth
  # for plan-vs-build (it decides from whether an on-disk plan is tagged for this issue):
  #   plan → /ralph-tdd-plan fan-out → reconcile; needs 1.5×.
  #   tdd  → build from the plan; standard 1× budget.
  # Both run the orchestrator on Opus 1M (see ANTHROPIC_DEFAULT_OPUS_MODEL above) — the build is now
  # an Opus orchestrator fanning out Sonnet workers, not a solo Sonnet; only the prompt and the
  # timeout differ. The else-branch (plan, or any unexpected MODE) fails safe to the bigger budget.
  if [[ "$mode" == "tdd" ]]; then
    prompt_file="$PROMPT_TDD"; iter_timeout=$ITERATION_TIMEOUT
  else
    prompt_file="$PROMPT_PLAN"; iter_timeout=$(( ITERATION_TIMEOUT * 3 / 2 ))   # 1.5× → 1400*1.5 = 2100s
    # Clear the planning scratch dir before launching /ralph-tdd-plan — deterministically here, not
    # via a skill instruction (a model-issued `rm -rf` trips Claude Code's dangerous-command prompt
    # and stalls the unattended loop). A prior plan iteration SIGKILLed mid-research may have left
    # stale files for this re-pick. FATAL on failure, like ensure-vite-arch above.
    if ! ./scripts/clear-research-dir.sh; then
      echo "ralph-loop: ERROR — research-dir cleanup failed before planning" >&2
      exit 1
    fi
  fi
  iter_model="opus"   # both modes; resolves to Opus 4.7 [1m] via ANTHROPIC_DEFAULT_OPUS_MODEL above

  echo
  echo "============================================================"
  echo "ralph-loop: iteration $iteration  (loop ${RALPH_LOOP_ID:-0})"
  echo "  issue:    #${issue:-?}   mode: ${mode:-plan}   kind: ${kind:-feature}"
  echo "  model:    Opus 4.7 [1m] @ xhigh  (subagents: $CLAUDE_CODE_SUBAGENT_MODEL)"
  echo "  started:  $ts"
  echo "  timeout:  ${iter_timeout}s (then SIGKILL)"
  echo "  prompt:   $prompt_file"
  echo "  Ctrl-C to bail."
  echo "============================================================"

  # Resolve the prompt TEMPLATE into the actual first-turn text. The picker already told us the
  # claimed issue (#$issue) and this loop's id, so inject them as literals — the in-loop agent gets
  # a ready-to-run prompt: no `${RALPH_LOOP_ID:-0}` to hand-expand (the old drift), no issue to
  # rediscover. Read → substitute → stdout with sed (NEVER `sed -i`): PROMPT-*.md stay pristine
  # @@ISSUE@@/@@LOOP_ID@@ templates, so the tree never goes dirty and the next iteration re-renders
  # from the same source. Tokens are digits-only, safe for the `/` sed delimiter.
  prompt_text=$(sed -e "s/@@ISSUE@@/${issue}/g" -e "s/@@LOOP_ID@@/${RALPH_LOOP_ID:-0}/g" "$prompt_file")

  # comm-test issues have no frontend and no browser e2e — append a directive so the planning
  # fan-out skips frontend research and the build skips Playwright. The ralph-tdd* skills carry the
  # matching guards; this per-issue note is the signal that triggers them. Appended to the rendered
  # text, NOT the .md, so the PROMPT-*.md templates stay pristine @@token@@ sources.
  # CUSTOMIZE: optional mechanism — only fires on issues you label `comm-test` (backend-only
  # behaviour tests proven by a non-browser harness). Point the directive at your harness, or
  # ignore it: without the label this block never runs.
  if [[ "$kind" == "comm-test" ]]; then
    prompt_text="${prompt_text}

## This is a comm-test issue — adjust the workflow
The \`comm-test\` label marks a backend-only behaviour test: **no frontend, no browser e2e.** The
deliverable is a scenario in the project's behaviour-test harness, proven by running that
harness per the issue's Run / verify + Definition of done.
- Planning (/ralph-tdd-plan): SKIP the frontend + architecture research fan-out and the
  design-reference pass — research the backend seams and the test harness only.
- Build (/ralph-tdd): SKIP the Playwright e2e step — there is no browser journey. Prove the
  scenario with the harness and paste the transcript instead."
  fi

  iter_start=$SECONDS
  set +e
  timeout --foreground --signal=KILL "$iter_timeout" \
    claude --model "$iter_model" --dangerously-skip-permissions --verbose "$prompt_text"
  exit_code=$?
  set -e
  elapsed=$(( SECONDS - iter_start ))

  echo
  # elapsed vs ${iter_timeout}s cap: a planning iteration near its cap is the signal to retune the
  # 1.5× multiplier above. exit=137 (128+SIGKILL) means timeout fired — the work didn't fit the cap.
  echo "ralph-loop: iteration $iteration ended (exit=$exit_code, elapsed=${elapsed}s, cap=${iter_timeout}s)"

  [[ $exit_code -eq 130 ]] && { echo "ralph-loop: interrupted."; exit 130; }

  # Pause between iterations so git has time to update state — the just-finished iteration's
  # push/close and origin/ralph-loop refresh land before the next picker reads them, so it
  # claims against fresh state rather than a stale snapshot.
  sleep 10
done
