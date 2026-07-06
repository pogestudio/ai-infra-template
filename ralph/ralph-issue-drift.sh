#!/usr/bin/env bash
#
# ralph/ralph-issue-drift.sh — handle a claim↔plan mismatch ("drift").
#
# Drift = the issue this loop HOLDS (its claimed-ralph-<id> label) is NOT the issue the on-disk
# plan (AI-Info/implementation-plans/current/current-plan.md, tagged `Issue: #N`) is for. That can
# happen if a claim/close raced a SIGKILL. The only safe move is a clean restart, so this:
#   1. logs the drift to ralph/.drift-log (auditable — drift should be rare),
#   2. drops MY claim label (unclaim — so the held issue returns to the queue for any loop),
#   3. deletes the stale plan,
#   4. SIGKILLs the current iteration's claude IF we're running under one.
#
# Dual-use:
#   * the picker calls it PRE-LAUNCH (no claude ancestor → step 4 is a no-op; the picker then falls
#     through to a fresh pick);
#   * /ralph-tdd calls it MID-BUILD when it notices a stale plan → step 4 ends the iteration so the
#     next one restarts clean.
#
# Usage: ralph/ralph-issue-drift.sh <held-issue> <plan-issue>
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ralph-loop-kill-self.sh
source "$SCRIPT_DIR/ralph-loop-kill-self.sh"
cd "$SCRIPT_DIR/.."   # repo root: the PLAN path + .drift-log resolve from here

ID="${RALPH_LOOP_ID:-0}"
MY="claimed-ralph-$ID"
PLAN="AI-Info/implementation-plans/current/current-plan.md"
DRIFT_LOG="ralph/.drift-log"

held="${1:-}"
plan_issue="${2:-}"

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\tloop=%s\thost=%s\theld=#%s\tplan=#%s\n' \
  "$ts" "$ID" "$(hostname 2>/dev/null || echo '?')" "$held" "$plan_issue" >> "$DRIFT_LOG"
echo "ralph-loop: DRIFT — hold #$held but plan is for #$plan_issue; unclaiming + clearing plan (logged to $DRIFT_LOG)" >&2

if [[ -n "$held" ]]; then
  gh issue edit "$held" --remove-label "$MY" >/dev/null 2>&1 || true
fi
rm -f "$PLAN"

# No-op pre-launch (the picker has no claude ancestor with the launch flag); ends the iteration
# when invoked under claude (/ralph-tdd) so the next one restarts clean.
ralph_kill_iteration
