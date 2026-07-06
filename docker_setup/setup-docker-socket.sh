#!/usr/bin/env bash
# Fix Docker socket permissions for macOS Docker Desktop.
# Allows the app user (in the docker group) to access the mounted socket.
set -euo pipefail

if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(getent group docker | cut -d: -f3)
  if [ -n "${DOCKER_GID}" ]; then
    chgrp "${DOCKER_GID}" /var/run/docker.sock 2>/dev/null || true
    chmod 660 /var/run/docker.sock 2>/dev/null || true
    echo "[docker-socket] Fixed permissions for group ${DOCKER_GID}"
  fi
fi
