#!/usr/bin/env bash
#
# scripts/run-tests.sh — the project's single green-gate. NOT YET IMPLEMENTED for this project.
#
# CONTRACT (what the Ralph loop and the done-gate depend on):
#   - Runs EVERY test suite the project has (backend, frontend, linters if you gate on them).
#   - Exits 0 only when everything passes; non-zero otherwise.
#   - Runs from the repo root with no arguments and no interactive prompts.
#   - Self-heals cheap environment drift where possible (e.g. reinstall native binaries that
#     break after a container/arch switch) rather than failing on it — the loop runs headless
#     and can't fix your environment for you.
#   - Keep it fast; it runs at least twice per loop iteration (during the build and again in
#     ralph/ralph-loop-done.sh's gate).
#
# WHO CALLS IT:
#   - ralph/ralph-loop-done.sh   (the close-issue gate — a red suite blocks the queue advance)
#   - /ralph-tdd                 (full-suite check between slices)
#   - you, before any commit
#
# See examples/klara/run-tests.sh for a real implementation (Python venv pytest + npm vitest,
# with a native-binary self-heal step).
#
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "ERROR: scripts/run-tests.sh is not implemented for this project yet." >&2
echo "       Replace the lines below the CUSTOMIZE marker with your real test commands" >&2
echo "       (see the contract in this file's header + examples/klara/run-tests.sh)." >&2
exit 1

# CUSTOMIZE: delete the three lines above and implement, e.g.:
#
# echo "== backend =="
# backend/venv/bin/python -m pytest backend/tests
#
# echo "== frontend =="
# ( cd frontend && npx vitest run )
#
# echo "ALL GREEN"
