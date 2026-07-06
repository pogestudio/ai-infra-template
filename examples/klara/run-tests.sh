#!/usr/bin/env bash
#
# scripts/run-tests.sh — run the full unit/integration suite (backend pytest + frontend
# vitest). The single source of truth for "run all tests": used by the ralph loop's green
# gate (ralph/ralph-loop-done.sh) and by /ralph-tdd.
#
# It self-heals the frontend's per-OS native binaries first (scripts/ensure-vite-arch.sh), so
# a host/container node_modules drift reads as what it is — an env issue the script fixes —
# not as a phantom test failure. Runs every suite it can and aggregates: exits 0 only if all
# suites that ran passed.
set -uo pipefail   # deliberately NOT -e: run BOTH suites and aggregate, don't bail on the first

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# venv is keyed on OS (matches scripts/dev-up.sh): Linux dev container vs macOS host share the
# tree but need their own binaries.
case "$(uname -s)" in
  Darwin) PY="backend/venv-macos/bin/python" ;;
  *)      PY="backend/venv/bin/python" ;;
esac

rc=0

echo "== backend pytest =="
if [ -x "$PY" ]; then
  "$PY" -m pytest backend/tests -q || rc=1
else
  echo "ERROR: $PY missing — run scripts/dev-up.sh once to build the venv." >&2
  rc=1
fi

echo "== frontend vitest =="
if [ -f frontend/package.json ]; then
  if ./scripts/ensure-vite-arch.sh; then            # heal per-OS rollup/esbuild (no-op when healthy)
    ( cd frontend && node_modules/.bin/vitest run ) || rc=1
  else
    echo "ERROR: could not ready frontend native deps (ensure-vite-arch failed)." >&2
    rc=1
  fi
else
  echo "(no frontend/package.json — skipping)"
fi

if [ "$rc" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "TESTS FAILED (rc=$rc)" >&2; fi
exit $rc
