#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/docker_setup/config.sh"

ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.claude}"

# Parse arguments
BUILD=false
for arg in "$@"; do
  case $arg in
    --build)
      BUILD=true
      shift
      ;;
    --help|-h)
      echo "Usage: ./run-claude.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --build    Rebuild the Docker image (no cache) before running"
      echo "             This will stop any existing containers using the image"
      echo "  --help     Show this help message"
      echo ""
      echo "Shared Credentials:"
      echo "  Claude OAuth credentials are stored in Docker volume '${CLAUDE_CREDS_VOLUME}'."
      echo "  This means you only need to log in once and all projects share the auth."
      echo "  Token is also auto-refreshed from macOS Keychain on each run."
      echo ""
      echo "Examples:"
      echo "  ./run-claude.sh          # Run normally"
      echo "  ./run-claude.sh --build  # Rebuild image and run"
      exit 0
      ;;
  esac
done

if [ ! -f "${ENV_FILE}" ]; then
  echo "Env file not found: ${ENV_FILE}"
  echo "Create it from the template:  cp .env.claude.example .env.claude"
  echo "Then fill GIT_TOKEN/GIT_USERNAME; leave ANTHROPIC_API_KEY empty for Claude Code web login."
  exit 1
fi

PROJECT_DIR="$(pwd)"

# Persistent Claude config directory (stores theme, settings, etc.)
CLAUDE_CONFIG_DIR="${SCRIPT_DIR}/.claude-container-config"
mkdir -p "${CLAUDE_CONFIG_DIR}"

# Handle --build flag
if [ "$BUILD" = true ]; then
  echo "[build] Rebuilding image with --no-cache..."

  # Stop and remove any containers using this image
  RUNNING_CONTAINERS=$(docker ps -q --filter ancestor="${IMAGE_NAME}" 2>/dev/null || true)
  if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "[build] Stopping running containers..."
    docker stop $RUNNING_CONTAINERS
  fi

  ALL_CONTAINERS=$(docker ps -aq --filter ancestor="${IMAGE_NAME}" 2>/dev/null || true)
  if [ -n "$ALL_CONTAINERS" ]; then
    echo "[build] Removing containers..."
    docker rm $ALL_CONTAINERS 2>/dev/null || true
  fi

  # Rebuild with no cache
  echo "[build] Building image (this may take a few minutes)..."
  docker build --no-cache -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

  # Verify critical tools are present
  echo "[build] Verifying image..."
  if docker run --rm --entrypoint "" "${IMAGE_NAME}" which lsof > /dev/null 2>&1; then
    echo "[build] lsof present"
  else
    echo "[build] WARNING: lsof not found in image!"
  fi

  echo "[build] Image rebuilt successfully"
  echo ""
fi

# Get folder name and git info for terminal title
FOLDER_NAME=$(basename "${PROJECT_DIR}")
GIT_BRANCH=""
GIT_STATUS_COLOR=""
if git -C "${PROJECT_DIR}" rev-parse --git-dir > /dev/null 2>&1; then
  GIT_BRANCH=$(git -C "${PROJECT_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  # Check git status for coloring
  if [ -n "$(git -C "${PROJECT_DIR}" status --porcelain 2>/dev/null)" ]; then
    # Unstaged/uncommitted changes = RED
    GIT_STATUS_COLOR="red"
  elif [ -n "$(git -C "${PROJECT_DIR}" log @{u}.. 2>/dev/null)" ]; then
    # Committed but not pushed = YELLOW
    GIT_STATUS_COLOR="yellow"
  else
    # Clean and pushed = GREEN
    GIT_STATUS_COLOR="green"
  fi
fi

# Set terminal title
TITLE="${FOLDER_NAME}"
[ -n "${GIT_BRANCH}" ] && TITLE="${FOLDER_NAME} -- ${GIT_BRANCH}"
printf '\033]0;%s\007' "${TITLE}"

# Print colorful status line
if [ -n "${GIT_BRANCH}" ]; then
  case "${GIT_STATUS_COLOR}" in
    red)    COLOR='\033[1;31m' ;;
    yellow) COLOR='\033[1;33m' ;;
    green)  COLOR='\033[1;32m' ;;
    *)      COLOR='\033[0m' ;;
  esac
  RESET='\033[0m'
  echo ""
  echo -e "  ${FOLDER_NAME} -- ${COLOR}${GIT_BRANCH}${RESET}"
  echo ""
fi

echo "[run] Using workspace: ${PROJECT_DIR}"
echo "[run] Using env file: ${ENV_FILE}"
echo "[run] Using config dir: ${CLAUDE_CONFIG_DIR}"

# Refresh Claude OAuth token from macOS Keychain before starting container
if [[ "$(uname)" == "Darwin" ]]; then
  SYNC_SCRIPT="${SCRIPT_DIR}/docker_setup/sync-claude-token-from-keychain.sh"
  if [ -x "${SYNC_SCRIPT}" ]; then
    "${SYNC_SCRIPT}" "${CLAUDE_CONFIG_DIR}" || echo "[run] Warning: Token sync failed. You may need to /login inside the container."
  fi
fi

# Ensure shared credentials volume exists
if ! docker volume inspect "${CLAUDE_CREDS_VOLUME}" >/dev/null 2>&1; then
  echo "[run] Creating shared credentials volume '${CLAUDE_CREDS_VOLUME}'..."
  docker volume create "${CLAUDE_CREDS_VOLUME}"
fi

# Detect host OS for Docker socket handling
DOCKER_OPTS=""
if [[ "$(uname)" == "Darwin" ]]; then
  DOCKER_OPTS="-e DOCKER_HOST=unix:///var/run/docker.sock"
fi

# Mount at the same path as host so Docker volume mounts from within
# the container use paths that exist on the host
docker run --rm -it \
  --network host \
  --entrypoint "${SCRIPT_DIR}/docker-entrypoint.sh" \
  --env-file "${ENV_FILE}" \
  -v "${PROJECT_DIR}:${PROJECT_DIR}" \
  -w "${PROJECT_DIR}" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${CLAUDE_CONFIG_DIR}:/home/app/.claude" \
  -v "${CLAUDE_CREDS_VOLUME}:/home/app/.claude-persist" \
  -e PLATFORM=devcontainer \
  -e PEON_RELAY_HOST="${PEON_RELAY_HOST}" \
  -e PEON_RELAY_PORT="${PEON_RELAY_PORT}" \
  ${DOCKER_OPTS} \
  "${IMAGE_NAME}" \
  bash -c "${SCRIPT_DIR}/docker_setup/install-statusline.sh && exec /bin/bash"
