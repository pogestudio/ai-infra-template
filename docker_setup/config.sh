#!/usr/bin/env bash
# Shared configuration for all docker setup scripts.
# Source this file, do not execute it directly.

# Paths (container)
CLAUDE_LOCAL="/home/app/.claude"
CLAUDE_PERSIST="/home/app/.claude-persist"
PEON_BACKUP="/opt/peon-ping-backup"
WORKSPACE="${PWD:-/workspace}"

# Docker
IMAGE_NAME="ai-starter-image"   # CUSTOMIZE: your project's docker image name
CLAUDE_CREDS_VOLUME="claude-credentials"

# Peon-ping relay
PEON_RELAY_HOST="host.docker.internal"
PEON_RELAY_PORT="19998"

# Credential sync interval (seconds)
SYNC_INTERVAL=30

# macOS Keychain
KEYCHAIN_SERVICE="Claude Code-credentials"

# Git defaults
DEFAULT_GIT_USERNAME="x-access-token"
