#!/usr/bin/env bash
# Configure git credentials and GitHub CLI authentication.
# Reads GIT_TOKEN (or GITHUB_TOKEN) and GIT_USERNAME from the environment.
set -euo pipefail

GIT_TOKEN="${GIT_TOKEN:-${GITHUB_TOKEN:-}}"
GIT_USERNAME="${GIT_USERNAME:-${DEFAULT_GIT_USERNAME}}"

if [ -n "${GIT_TOKEN}" ]; then
  export GH_TOKEN="${GIT_TOKEN}"
  su - app -c "git config --global url.\"https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/\".insteadOf \"https://github.com/\""
  echo "[git-credentials] Configured git + GitHub CLI authentication"
fi
