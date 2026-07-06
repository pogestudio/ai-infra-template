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
    else
      jq -s '.[0] * {hooks: (.[0].hooks // {} | to_entries + (.[1].hooks // {} | to_entries) | group_by(.key) | map({key: .[0].key, value: [.[] | .value[]] | unique}) | from_entries)}' \
        "${CLAUDE_LOCAL}/settings.json" "${PEON_BACKUP}/settings.json" > "${CLAUDE_LOCAL}/settings.json.tmp" \
        && mv "${CLAUDE_LOCAL}/settings.json.tmp" "${CLAUDE_LOCAL}/settings.json" \
        || cp "${PEON_BACKUP}/settings.json" "${CLAUDE_LOCAL}/settings.json"
    fi
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
