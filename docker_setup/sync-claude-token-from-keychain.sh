#!/bin/bash
# -----------------------------------------------------------------
# Sync Claude OAuth Token: three-way freshness comparison
# -----------------------------------------------------------------
# Runs on the HOST (macOS) before starting a Docker container.
# Compares credential freshness (expiresAt) across three sources:
#   1. macOS Keychain
#   2. Shared Docker volume (claude-credentials)
#   3. Existing local file in output dir
# Picks the freshest and writes to the output dir.
# If Keychain was stale, reverse-syncs fresh credentials back to Keychain.
#
# Prerequisites:
#   - macOS with Keychain containing "Claude Code-credentials"
#   - jq installed (brew install jq)
#   - Docker running (for shared volume read)
#
# Usage:
#   ./sync-claude-token-from-keychain.sh <output-dir>
#   e.g. ./sync-claude-token-from-keychain.sh .claude-container-config
# -----------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

OUTPUT_DIR="${1:-.claude-container-config}"

# --- Read credentials from macOS Keychain ---
# Keychain may store plain JSON or hex-encoded JSON depending on Claude Code version
RAW=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null) || {
  echo "[sync-token] No Claude credentials in Keychain. Run 'claude login' first."
  exit 1
}
if echo "$RAW" | jq empty 2>/dev/null; then
  KEYCHAIN_JSON="$RAW"
else
  KEYCHAIN_JSON=$(echo "$RAW" | xxd -r -p 2>/dev/null) || {
    echo "[sync-token] Could not decode Keychain credentials."
    exit 1
  }
fi

# Validate we have the expected structure
ACCESS_TOKEN=$(echo "$KEYCHAIN_JSON" | jq -r '.claudeAiOauth.accessToken // empty')
REFRESH_TOKEN=$(echo "$KEYCHAIN_JSON" | jq -r '.claudeAiOauth.refreshToken // empty')

if [[ -z "$ACCESS_TOKEN" || -z "$REFRESH_TOKEN" ]]; then
  echo "[sync-token] Incomplete credentials in Keychain. Run 'claude login' first."
  exit 1
fi

# --- Three-way freshness comparison ---
KEYCHAIN_EXPIRES=$(echo "$KEYCHAIN_JSON" | jq -r '.claudeAiOauth.expiresAt // 0')

# Read from shared Docker volume (if available)
VOLUME_JSON=""
VOLUME_EXPIRES=0
VOLUME_RAW=$(docker run --rm -v claude-credentials:/data:ro alpine cat /data/.credentials.json 2>/dev/null) || true
if [ -n "${VOLUME_RAW}" ] && echo "$VOLUME_RAW" | jq empty 2>/dev/null; then
  VOLUME_EXPIRES=$(echo "$VOLUME_RAW" | jq -r '.claudeAiOauth.expiresAt // 0')
  VOLUME_JSON="$VOLUME_RAW"
fi

# Read from existing local file (if present)
LOCAL_JSON=""
LOCAL_EXPIRES=0
LOCAL_FILE="${OUTPUT_DIR}/.credentials.json"
if [ -f "$LOCAL_FILE" ]; then
  LOCAL_RAW=$(cat "$LOCAL_FILE")
  if echo "$LOCAL_RAW" | jq empty 2>/dev/null; then
    LOCAL_EXPIRES=$(echo "$LOCAL_RAW" | jq -r '.claudeAiOauth.expiresAt // 0')
    LOCAL_JSON="$LOCAL_RAW"
  fi
fi

# Pick the freshest source
WINNER="keychain"
WINNER_JSON="$KEYCHAIN_JSON"
WINNER_EXPIRES="$KEYCHAIN_EXPIRES"

if [ "${VOLUME_EXPIRES:-0}" -gt "${WINNER_EXPIRES:-0}" ] 2>/dev/null; then
  WINNER="shared-volume"
  WINNER_JSON="$VOLUME_JSON"
  WINNER_EXPIRES="$VOLUME_EXPIRES"
fi

if [ "${LOCAL_EXPIRES:-0}" -gt "${WINNER_EXPIRES:-0}" ] 2>/dev/null; then
  WINNER="local-file"
  WINNER_JSON="$LOCAL_JSON"
  WINNER_EXPIRES="$LOCAL_EXPIRES"
fi

echo "[sync-token] Freshness: keychain=${KEYCHAIN_EXPIRES} volume=${VOLUME_EXPIRES} local=${LOCAL_EXPIRES} => winner=${WINNER}"

# Write winner to output dir
mkdir -p "$OUTPUT_DIR"
echo "$WINNER_JSON" | jq '{claudeAiOauth}' > "${OUTPUT_DIR}/.credentials.json"
chmod 600 "${OUTPUT_DIR}/.credentials.json"

NOW_MS=$(( $(date +%s) * 1000 ))
if [ "${WINNER_EXPIRES:-0}" -gt "$NOW_MS" ] 2>/dev/null; then
  REMAINING_H=$(( (WINNER_EXPIRES - NOW_MS) / 3600000 ))
  echo "[sync-token] Wrote ${WINNER} token (~${REMAINING_H}h remaining) to ${OUTPUT_DIR}/.credentials.json"
else
  echo "[sync-token] Wrote ${WINNER} token (may need refresh) to ${OUTPUT_DIR}/.credentials.json"
fi

# Reverse-sync to Keychain if it was stale
if [ "$WINNER" != "keychain" ]; then
  echo "[sync-token] Keychain is stale. Reverse-syncing from ${WINNER}..."
  HEX=$(echo "$WINNER_JSON" | jq -c '{claudeAiOauth}' | xxd -p | tr -d '\n')
  security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 || true
  if security add-generic-password -s "$KEYCHAIN_SERVICE" -a "Claude Code" -w "$HEX" >/dev/null 2>&1; then
    echo "[sync-token] Keychain updated with fresher credentials from ${WINNER}"
  else
    echo "[sync-token] WARNING: Could not update Keychain (non-fatal, container still gets correct tokens)"
  fi
fi
