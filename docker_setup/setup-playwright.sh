#!/usr/bin/env bash
# Point Playwright at a writable, persistent browser cache.
#
# The browsers live inside the bind-mounted workspace (alongside node_modules)
# rather than /opt: the app user can't write /opt at runtime, and anything
# outside the workspace is lost when the container is rebuilt. Keeping them in
# the workspace means `npx playwright install chromium` only runs once and the
# binaries survive container restarts. The .mcp.json playwright server points at
# this same path. Install with:
#   PLAYWRIGHT_BROWSERS_PATH="${WORKSPACE}/.cache/ms-playwright" \
#     ./node_modules/.bin/playwright install chromium chromium-headless-shell
set -euo pipefail

export PLAYWRIGHT_BROWSERS_PATH="${WORKSPACE:-/workspace}/.cache/ms-playwright"
