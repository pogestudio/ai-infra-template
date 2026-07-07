#!/usr/bin/env bash
set +e
# PreToolUse BLOCK — fires when editing .md files in AI-Info/
# 5-minute cooldown, reset on SessionStart
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
MARKER="/tmp/claude-hook-ai-context-${SESSION_ID}"
COOLDOWN=300

# Only match .md files inside AI-Info/
[[ "$FILE" == *.md ]] && [[ "$FILE" == */AI-Info/* ]] || exit 0

# Check cooldown
if [[ -n "$SESSION_ID" ]] && [[ -f "$MARKER" ]]; then
  LAST=$(cat "$MARKER" 2>/dev/null)
  NOW=$(date +%s)
  if (( NOW - LAST < COOLDOWN )); then
    exit 0
  fi
fi

# Set timer
if [[ -n "$SESSION_ID" ]]; then
  date +%s > "$MARKER"
fi

echo '{"decision":"block","reason":"Read AI-Info/skills/how-to-write-ai-instructions/SKILL.md before editing this file. It contains principles for writing effective AI instruction files."}'
