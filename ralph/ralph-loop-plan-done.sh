#!/usr/bin/env bash
#
# ralph-loop-plan-done.sh — signal end-of-iteration after PLANNING (no code written yet).
#
# /ralph-tdd-plan calls this once it has written the durable implementation plan to
# AI-Info/implementation-plans/current/current-plan.md. Unlike ralph-loop-done.sh there is
# nothing to close, push, or test — the plan is an on-disk scratchpad, not a deliverable. We
# end the iteration immediately so the NEXT iteration re-picks the same issue, finds the plan,
# and builds with a fresh, uncluttered context. The loop keeps running (no DONE marker written);
# ralph/ralph-loop.sh keys the budget off the picker's MODE — build (tdd) gets the standard
# budget, planning (plan) gets 1.5×.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ralph-loop-kill-self.sh
source "$SCRIPT_DIR/ralph-loop-kill-self.sh"
cd "$SCRIPT_DIR/.."   # repo root, for parity with the other ralph/ scripts

# Wipe the scratch research dir here (not from the skill) so the model never issues the
# delete itself: a model-issued `rm -rf` trips Claude Code's dangerous-command prompt even
# under --dangerously-skip-permissions and stalls the unattended loop. Must run BEFORE
# ralph_kill_iteration (which SIGKILLs our claude ancestor — once it's gone this script may
# not finish). Fail loudly: a broken cleanup must not silently end the iteration.
echo "ralph-loop: plan written — clearing the scratch research dir"
if ! "$SCRIPT_DIR/../scripts/clear-research-dir.sh"; then
  echo "ralph-loop: ERROR — research-dir cleanup failed" >&2
  exit 1
fi

echo "ralph-loop: plan written — ending this iteration so the build starts fresh"
ralph_kill_iteration
