#!/usr/bin/env bash
# Claude credential management: restore .claude.json, compare freshness, background sync.
#
# Handles three things:
#   1. Restore .claude.json (onboarding, theme, account) from backup
#   2. Pick the freshest OAuth credentials (local vs shared volume)
#   3. Start a background sync loop to keep credentials in sync
set -euo pipefail

mkdir -p "${CLAUDE_LOCAL}"
chown -R app:app "${CLAUDE_LOCAL}"

# --- Restore .claude.json ---
# This file lives at ~/.claude.json (outside the bind mount at ~/.claude/)
# so it gets destroyed on every --rm container exit. We back it up inside the bind mount.

# Remove stale symlinks from previous entrypoint versions
[ -L /home/app/.claude.json ] && rm -f /home/app/.claude.json

CLAUDE_JSON_BACKUP="${CLAUDE_LOCAL}/.claude.json.bak"
CLAUDE_JSON_SHARED="${CLAUDE_PERSIST}/.claude.json.bak"

# Find newest Claude Code native backup (no pipes, safe with pipefail)
CLAUDE_NATIVE_BACKUP=""
for _f in "${CLAUDE_LOCAL}"/backups/.claude.json.backup.* ; do
  [ -f "$_f" ] && CLAUDE_NATIVE_BACKUP="$_f"
done

if [ ! -f /home/app/.claude.json ]; then
  if [ -f "${CLAUDE_JSON_BACKUP}" ]; then
    cp "${CLAUDE_JSON_BACKUP}" /home/app/.claude.json
    chown app:app /home/app/.claude.json
    echo "[credentials] Restored .claude.json from previous session"
  elif [ -n "${CLAUDE_NATIVE_BACKUP}" ]; then
    cp "${CLAUDE_NATIVE_BACKUP}" /home/app/.claude.json
    chown app:app /home/app/.claude.json
    echo "[credentials] Restored .claude.json from Claude Code backup"
  elif [ -d "${CLAUDE_PERSIST}" ] && [ -f "${CLAUDE_JSON_SHARED}" ]; then
    cp "${CLAUDE_JSON_SHARED}" /home/app/.claude.json
    chown app:app /home/app/.claude.json
    echo "[credentials] Restored .claude.json from shared volume"
  else
    echo "[credentials] No .claude.json backup found (first run)"
  fi
fi

# Remove stale symlinks for credentials
[ -L "${CLAUDE_LOCAL}/.credentials.json" ] && rm -f "${CLAUDE_LOCAL}/.credentials.json"
[ -L "${CLAUDE_LOCAL}/.claude" ] && rm -f "${CLAUDE_LOCAL}/.claude"

# --- Compare credential freshness ---
LOCAL_CREDS="${CLAUDE_LOCAL}/.credentials.json"
SHARED_CREDS="${CLAUDE_PERSIST}/.credentials.json"
LOCAL_EXPIRES=0
SHARED_EXPIRES=0

if [ -f "$LOCAL_CREDS" ]; then
  LOCAL_EXPIRES=$(jq -r '.claudeAiOauth.expiresAt // 0' "$LOCAL_CREDS" 2>/dev/null) || LOCAL_EXPIRES=0
fi
if [ -d "${CLAUDE_PERSIST}" ] && [ -f "$SHARED_CREDS" ]; then
  SHARED_EXPIRES=$(jq -r '.claudeAiOauth.expiresAt // 0' "$SHARED_CREDS" 2>/dev/null) || SHARED_EXPIRES=0
fi

echo "[credentials] Freshness: local=${LOCAL_EXPIRES} shared=${SHARED_EXPIRES}"

if [ -f "$LOCAL_CREDS" ] && [ -d "${CLAUDE_PERSIST}" ] && [ -f "$SHARED_CREDS" ] && [ "${SHARED_EXPIRES:-0}" -gt "${LOCAL_EXPIRES:-0}" ] 2>/dev/null; then
  cp "$SHARED_CREDS" "$LOCAL_CREDS"
  chown app:app "$LOCAL_CREDS"
  echo "[credentials] Shared volume credentials are fresher, copied to local"
elif [ -f "$LOCAL_CREDS" ]; then
  echo "[credentials] Using local credentials (synced from Keychain or already fresh)"
elif [ -d "${CLAUDE_PERSIST}" ] && [ -f "$SHARED_CREDS" ]; then
  cp "$SHARED_CREDS" "$LOCAL_CREDS"
  chown app:app "$LOCAL_CREDS"
  echo "[credentials] Copied credentials from shared volume (no local found)"
else
  echo "[credentials] No credentials found. Run /login or check sync-claude-token-from-keychain.sh"
fi

# --- Background sync ---
# Bidirectional credential sync every SYNC_INTERVAL seconds.
# Ensures containers started later always get the freshest token.
if [ -d "${CLAUDE_PERSIST}" ]; then
  chown -R app:app "${CLAUDE_PERSIST}"
  (
    while sleep "${SYNC_INTERVAL}"; do
      _LOCAL_EXP=0; _SHARED_EXP=0
      if [ -f "${CLAUDE_LOCAL}/.credentials.json" ] && [ ! -L "${CLAUDE_LOCAL}/.credentials.json" ]; then
        _LOCAL_EXP=$(jq -r '.claudeAiOauth.expiresAt // 0' "${CLAUDE_LOCAL}/.credentials.json" 2>/dev/null) || _LOCAL_EXP=0
      fi
      if [ -f "${CLAUDE_PERSIST}/.credentials.json" ]; then
        _SHARED_EXP=$(jq -r '.claudeAiOauth.expiresAt // 0' "${CLAUDE_PERSIST}/.credentials.json" 2>/dev/null) || _SHARED_EXP=0
      fi
      if [ "${_SHARED_EXP:-0}" -gt "${_LOCAL_EXP:-0}" ] 2>/dev/null; then
        cp "${CLAUDE_PERSIST}/.credentials.json" "${CLAUDE_LOCAL}/.credentials.json" 2>/dev/null || true
      elif [ "${_LOCAL_EXP:-0}" -gt "${_SHARED_EXP:-0}" ] 2>/dev/null; then
        cp "${CLAUDE_LOCAL}/.credentials.json" "${CLAUDE_PERSIST}/.credentials.json" 2>/dev/null || true
      fi
      # Backup .claude.json into bind mount and shared volume so it survives --rm
      if [ -f /home/app/.claude.json ] && [ ! -L /home/app/.claude.json ]; then
        cp /home/app/.claude.json "${CLAUDE_LOCAL}/.claude.json.bak" 2>/dev/null || true
        cp /home/app/.claude.json "${CLAUDE_PERSIST}/.claude.json.bak" 2>/dev/null || true
      fi
    done
  ) &
  echo "[credentials] Background sync started (every ${SYNC_INTERVAL}s)"
fi
