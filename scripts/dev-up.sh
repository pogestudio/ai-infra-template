#!/usr/bin/env bash
#
# scripts/dev-up.sh — start (or restart) the whole dev stack. NOT YET IMPLEMENTED for this project.
#
# CONTRACT (what the Ralph loop, the e2e subagents, and the local agents depend on):
#   - `./scripts/dev-up.sh`       stops any stack already running, then starts everything fresh
#                                 on the current code: rebuild/reseed the dev DB, seed an
#                                 idempotent dev login, start backend + frontend.
#   - `./scripts/dev-up.sh stop`  tears everything down (kill by port/pid, remove pid files).
#   - RETURNS ONLY WHEN HEALTHY:  poll each server's health/root endpoint and exit 0 once all
#                                 respond — callers script it with a short timeout and treat a
#                                 prompt return as "stack is ready". Exit non-zero if a piece
#                                 fails to come up, with the log path in the error message.
#   - IDEMPOTENT + NON-INTERACTIVE: safe to run repeatedly, headless (the loop restarts it to
#                                 pick up backend edits before an e2e — no human present).
#   - MULTI-LOOP PORT OFFSETS:    if you run concurrent Ralph loops from several clones, offset
#                                 ports by RALPH_LOOP_ID (e.g. frontend 5173+ID, backend 8000+ID)
#                                 so clones don't collide.
#   - SEEDED LOGIN:               login must work on a fresh DB; seed a fixed dev account and
#                                 document it in CLAUDE.md (e2e subagents log in with it).
#
# WHO CALLS IT:
#   - /ralph-tdd's e2e step (Playwright drives the stack this script started)
#   - the local agents (tech-ranger) and you, for manual testing
#
# See examples/klara/dev-up.sh for a real 350-line implementation (SQLite reseed, venv
# bootstrap, uvicorn + vite with per-loop ports, health-wait, log files, optional tunnel mode).
#
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "ERROR: scripts/dev-up.sh is not implemented for this project yet." >&2
echo "       Implement the contract in this file's header (start/stop/health-wait/seed);" >&2
echo "       examples/klara/dev-up.sh is a full reference implementation." >&2
exit 1

# CUSTOMIZE: delete the four lines above and implement. Skeleton shape:
#
# LOOP_ID="${RALPH_LOOP_ID:-0}"
# BACKEND_PORT=$((8000 + LOOP_ID))
# FRONTEND_PORT=$((5173 + LOOP_ID))
# LOG_DIR=".devlogs"; mkdir -p "$LOG_DIR"
#
# stop() { <kill whatever listens on $BACKEND_PORT/$FRONTEND_PORT, rm pid files> ; }
# [ "${1:-}" = "stop" ] && { stop; exit 0; }
#
# stop                       # always restart fresh on current code
# <bootstrap deps if missing (venv / npm install)>
# <rebuild + seed dev DB, idempotent dev login>
# <start backend  → $LOG_DIR/backend.log,  save pid>
# <start frontend → $LOG_DIR/frontend.log, save pid>
# <poll http://localhost:$BACKEND_PORT/health and the frontend root until both answer, then exit 0>
