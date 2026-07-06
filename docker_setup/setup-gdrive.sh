#!/usr/bin/env bash
# Setup Google Drive OAuth credentials directory.
set -euo pipefail

GDRIVE_CREDS_DIR="${WORKSPACE}/credentials"

if [ -d "${GDRIVE_CREDS_DIR}" ]; then
  export GDRIVE_CREDENTIALS_DIR="${GDRIVE_CREDS_DIR}"
  if [ -f "${GDRIVE_CREDS_DIR}/client_secrets.json" ]; then
    echo "[gdrive] OAuth client secrets found"
    if [ -f "${GDRIVE_CREDS_DIR}/token.json" ]; then
      echo "[gdrive] OAuth token cached (already authenticated)"
    else
      echo "[gdrive] Not yet authenticated — sign in with your Google account / Drive credentials to create token.json"
    fi
  else
    echo "[gdrive] No client_secrets.json at ${GDRIVE_CREDS_DIR}"
  fi
fi
