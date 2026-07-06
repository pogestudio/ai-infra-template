#!/usr/bin/env bash
set -euo pipefail

# Resolve setup dir relative to this script (works both baked-in and bind-mounted)
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/docker_setup"

# Fallback to baked-in location if relative path doesn't exist
if [ ! -d "${SETUP_DIR}" ]; then
  SETUP_DIR="/usr/local/bin/docker_setup"
fi

# Source shared config (sets CLAUDE_LOCAL, CLAUDE_PERSIST, WORKSPACE, etc.)
source "${SETUP_DIR}/config.sh"

# Run each setup module (sourced so env var exports persist)
source "${SETUP_DIR}/setup-docker-socket.sh"
source "${SETUP_DIR}/setup-git-credentials.sh"
source "${SETUP_DIR}/setup-python-dev.sh"
source "${SETUP_DIR}/setup-credentials.sh"
source "${SETUP_DIR}/setup-peon-ping.sh"
source "${SETUP_DIR}/setup-gdrive.sh"
source "${SETUP_DIR}/setup-playwright.sh"
source "${SETUP_DIR}/setup-shell.sh"

# Switch to workspace and drop to app user
cd "${WORKSPACE}"
exec gosu app "$@"
