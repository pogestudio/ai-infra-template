#!/bin/bash
# Claude Code statusline installer
# Run from outside the VM:
#   docker cp statusline/install.sh <container>:/tmp/ && docker exec <container> bash /tmp/install.sh
# Or inside any VM:
#   bash install.sh

set -e

CLAUDE_DIR="${HOME}/.claude"
SCRIPT_PATH="${CLAUDE_DIR}/statusline-command.sh"
SETTINGS_PATH="${CLAUDE_DIR}/settings.json"

# Silent installation

# Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# Write the statusline script
cat > "$SCRIPT_PATH" << 'STATUSLINE'
#!/bin/bash
input=$(cat)

# Guard against empty/bad input (prevents terminal corruption)
if [ -z "$input" ] || ! echo "$input" | jq empty 2>/dev/null; then
  echo "..."
  exit 0
fi

# Detect terminal width — output plain text if too narrow for ANSI
COLS=$(tput cols 2>/dev/null || echo 80)
if [ "$COLS" -lt 40 ] 2>/dev/null; then
  model_id=$(echo "$input" | jq -r '.model.id')
  clean_id="${model_id%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]}"
  if [[ "$clean_id" =~ ^claude-([a-z]+)-(.+)$ ]]; then
    m=$(echo "${BASH_REMATCH[1]:0:1}" | tr 'a-z' 'A-Z'):$(echo "${BASH_REMATCH[2]}" | tr '-' '.')
  else
    m="?"
  fi
  d=$(echo "$input" | jq -r '.workspace.current_dir' | xargs basename)
  echo "[$m] $d"
  exit 0
fi

# 5 pastel rainbow colors (256-color mode)
# #ffb3ba=217  #ffdfba=223  #ffffba=229  #baffc9=158  #bae1ff=153
PALETTE=(217 223 229 158 153)
SHIFT=$(( $(date +%-H) % 5 ))

RST='\033[0m'
MINT='\033[38;5;158m'
SKY='\033[38;5;153m'

# Helper: get color escape for index (auto-rotated by hour)
c() {
  local idx=$(( ($1 + SHIFT) % 5 ))
  echo "\033[38;5;${PALETTE[$idx]}m"
}

# 1. Model shorthand - programmatic parsing
# Format: claude-{model}-{version}-{date} -> {M}:{version}
model_id=$(echo "$input" | jq -r '.model.id')
clean_id="${model_id%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]}"
if [[ "$clean_id" =~ ^claude-([a-z]+)-(.+)$ ]]; then
  model_name="${BASH_REMATCH[1]}"
  version_part="${BASH_REMATCH[2]}"
  first_letter=$(echo "${model_name:0:1}" | tr 'a-z' 'A-Z')
  version=$(echo "$version_part" | tr '-' '.')
  MODEL="${first_letter}:${version}"
else
  MODEL="?"
fi

# 2. Folder or active GSD task
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
FOLDER=$(basename "$DIR")

# Check for active GSD task (in_progress todo with activeForm)
DISPLAY="$FOLDER"
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
TODOS_DIR="${HOME}/.claude/todos"
if [ -n "$SESSION_ID" ] && [ -d "$TODOS_DIR" ]; then
  LATEST=$(ls -t "$TODOS_DIR"/${SESSION_ID}-agent-*.json 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    TASK=$(jq -r '[.[] | select(.status == "in_progress") | .activeForm // empty] | first // empty' "$LATEST" 2>/dev/null)
    [ -n "$TASK" ] && DISPLAY="$TASK"
  fi
fi

# 3. Rainbow the merged "[MODEL] DISPLAY" string across 5 pastel colors
LABEL="[${MODEL}] ${DISPLAY}"
LEN=${#LABEL}
RAINBOW=""
pos=0
for ((seg=0; seg<5; seg++)); do
  remaining=$((LEN - pos))
  segs_left=$((5 - seg))
  seg_len=$((remaining / segs_left))
  chunk="${LABEL:$pos:$seg_len}"
  RAINBOW="${RAINBOW}$(c $seg)${chunk}"
  pos=$((pos + seg_len))
done
RAINBOW="${RAINBOW}${RST}"

# 4. Git branch
BRANCH=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
  B=$(git -C "$DIR" --no-optional-locks branch --show-current 2>/dev/null)
  [ -n "$B" ] && BRANCH=" | ${MINT}${B}${RST}"
fi

# 5. Context bar (green -> yellow -> red gradient)
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
PCT=${PCT:-0}
BAR_LEN=15
FILLED=$((PCT * BAR_LEN / 100))
BAR=""
for ((i=0; i<BAR_LEN; i++)); do
  t=$((i * 100 / (BAR_LEN - 1)))
  if [ $t -le 50 ]; then
    r=$((t * 255 / 50)); g=255
  else
    r=255; g=$(((100 - t) * 255 / 50))
  fi
  if [ $i -lt $FILLED ]; then
    BAR="${BAR}\033[38;2;${r};${g};0m█"
  else
    BAR="${BAR}\033[38;2;${r};${g};0m\033[2m░\033[22m"
  fi
done

# Pct text color matches fill level
if [ "$PCT" -le 50 ]; then
  pr=$((PCT * 255 / 50)); pg=255
else
  pr=255; pg=$(((100 - PCT) * 255 / 50))
fi

# 6. Session time (time since transcript file created)
SESSION=""
TPATH=$(echo "$input" | jq -r '.transcript_path')
if [ -f "$TPATH" ]; then
  if START=$(stat -f "%B" "$TPATH" 2>/dev/null); then :
  else
    START=$(stat -c "%W" "$TPATH" 2>/dev/null)
    [ "$START" = "0" ] && START=$(stat -c "%Y" "$TPATH" 2>/dev/null)
  fi
  if [ -n "$START" ] && [ "$START" -gt 0 ] 2>/dev/null; then
    ELAPSED=$(( $(date +%s) - START ))
    if [ $ELAPSED -lt 60 ]; then SESSION="${ELAPSED}s"
    elif [ $ELAPSED -lt 3600 ]; then SESSION="$((ELAPSED/60))m"
    else SESSION="$((ELAPSED/3600))h$((ELAPSED%3600/60))m"
    fi
  fi
fi

# 7. GSD update available?
GSD_UPDATE=""
GSD_CACHE="${HOME}/.claude/cache/gsd-update-check.json"
if [ -f "$GSD_CACHE" ]; then
  UPDATE_AVAIL=$(jq -r '.update_available // false' "$GSD_CACHE" 2>/dev/null)
  [ "$UPDATE_AVAIL" = "true" ] && GSD_UPDATE="\033[33m⬆ /gsd:update\033[0m | "
fi

echo -e "${GSD_UPDATE}${RAINBOW}${BRANCH} ${BAR}${RST} \033[38;2;${pr};${pg};0m${PCT}%${RST} | ${SKY}${SESSION}${RST}"
STATUSLINE

chmod +x "$SCRIPT_PATH"

# Patch settings.json (merge statusLine key, preserve everything else)
STATUSLINE_JSON='{"type":"command","command":"'"$SCRIPT_PATH"'"}'

if [ -f "$SETTINGS_PATH" ]; then
  # Merge into existing settings
  TMP=$(mktemp)
  jq --argjson sl "$STATUSLINE_JSON" '.statusLine = $sl' "$SETTINGS_PATH" > "$TMP" && mv "$TMP" "$SETTINGS_PATH"
else
  # Create fresh settings
  echo "{\"statusLine\":$STATUSLINE_JSON}" | jq . > "$SETTINGS_PATH"
fi

echo "[Claude statusline installation success]"
