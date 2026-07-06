#!/usr/bin/env bash
#
# ralph/ralph-find-claimed-issue.sh — do PROMPT step 1 for the in-iteration agent: find the issue
# this loop holds and say what to do with it. Exists because the agent kept hand-expanding
# "${RALPH_LOOP_ID:-0}" in the old inline command and querying claimed-ralph-0 even on loop 1; here
# the shell expands it against the real env, so it can't drift.
#
# Mirrors each prompt's step 1:
#   tdd  → verdict: run /ralph-tdd <N>
#   plan → verdict: run /ralph-tdd-plan <N>
#
# Prints ISSUE=<n> (capture it as <ISSUE>) and a VERDICT line the agent acts on.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."   # repo root: git status reflects the worktree the agent builds in

ID="${RALPH_LOOP_ID:-0}"
MY="claimed-ralph-$ID"
MODE="${1:-tdd}"
echo "ralph-find-claimed[$ID]: querying open issues labelled $MY" >&2

issue=$(gh issue list --state open --label "$MY" --json number --jq 'map(.number) | min // empty')
echo "ISSUE=$issue"

if [[ "$MODE" == plan ]]; then
  echo "VERDICT: run /ralph-tdd-plan $issue"
else
  echo "VERDICT: run /ralph-tdd $issue"
fi
