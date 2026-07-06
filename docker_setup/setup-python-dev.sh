#!/usr/bin/env bash
# Install Python package in development mode if pyproject.toml exists.
set -euo pipefail

if [ -f "${WORKSPACE}/pyproject.toml" ]; then
  echo "[python-dev] Installing package in development mode..."
  # /opt/venv is built root-owned in the image; the install below runs as
  # 'app', so hand it ownership first or the editable .pth write hits EACCES.
  if [ -d /opt/venv ]; then
    chown -R app:app /opt/venv
  fi
  su - app -c "cd ${WORKSPACE} && pip install -e . --quiet" || true
fi
