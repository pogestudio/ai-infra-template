#!/usr/bin/env bash
# Restore peon-ping from backup into mounted .claude directory.
#
# The Dockerfile installs peon-ping at build time, but the ~/.claude volume
# mount overwrites it at runtime. This script copies the backup back in and
# merges the hook entries into settings.json.
set -euo pipefail

if [ -d "${PEON_BACKUP}/hooks/peon-ping" ] && [ ! -d "${CLAUDE_LOCAL}/hooks/peon-ping" ]; then
  echo "[peon-ping] Restoring installation from backup..."
  cp -a "${PEON_BACKUP}/hooks" "${CLAUDE_LOCAL}/"

  # Merge peon-ping hooks into settings.json (or copy if none exists)
  if [ -f "${PEON_BACKUP}/settings.json" ]; then
    if [ ! -f "${CLAUDE_LOCAL}/settings.json" ] || [ ! -s "${CLAUDE_LOCAL}/settings.json" ]; then
      cp "${PEON_BACKUP}/settings.json" "${CLAUDE_LOCAL}/settings.json"
    elif ! grep -q "peon-ping" "${CLAUDE_LOCAL}/settings.json"; then
      # Local settings lacks peon hooks: merge them in. On failure, KEEP local
      # (never clobber the curated settings.json — that would drop statusLine / showThinkingSummaries).
      jq -s '.[0] * {hooks: (.[0].hooks // {} | to_entries + (.[1].hooks // {} | to_entries) | group_by(.key) | map({key: .[0].key, value: [.[] | .value[]] | unique}) | from_entries)}' \
        "${CLAUDE_LOCAL}/settings.json" "${PEON_BACKUP}/settings.json" > "${CLAUDE_LOCAL}/settings.json.tmp" \
        && mv "${CLAUDE_LOCAL}/settings.json.tmp" "${CLAUDE_LOCAL}/settings.json" \
        || { rm -f "${CLAUDE_LOCAL}/settings.json.tmp"; echo "[peon-ping] merge failed; keeping existing settings.json"; }
    else
      echo "[peon-ping] settings.json already has peon hooks; leaving as-is"
    fi
  fi

  # Strip any "async" property the peon-ping installer baked into hook entries.
  # The async Stop hook emits a noisy "Async hook ... completed" line; user-requested removal.
  if [ -f "${CLAUDE_LOCAL}/settings.json" ] && command -v jq >/dev/null 2>&1; then
    jq 'if has("hooks") then .hooks |= walk(if type=="object" then del(.async) else . end) else . end' \
      "${CLAUDE_LOCAL}/settings.json" > "${CLAUDE_LOCAL}/settings.json.tmp" \
      && mv "${CLAUDE_LOCAL}/settings.json.tmp" "${CLAUDE_LOCAL}/settings.json" \
      && echo "[peon-ping] Stripped async from hook entries" \
      || rm -f "${CLAUDE_LOCAL}/settings.json.tmp"
  fi

  chown -R app:app "${CLAUDE_LOCAL}"
  echo "[peon-ping] Restored successfully"
else
  if [ -d "${CLAUDE_LOCAL}/hooks/peon-ping" ]; then
    echo "[peon-ping] Already present in mounted volume"
  else
    echo "[peon-ping] No backup found at ${PEON_BACKUP} (skipping)"
  fi
fi
