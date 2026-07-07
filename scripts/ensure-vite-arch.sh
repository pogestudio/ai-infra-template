#!/usr/bin/env bash
# Ensure vite's native build binaries (rollup + esbuild) in node_modules can run on
# the current OS/arch, reinstalling them when they can't. Handles host/container
# drift in the bind-mounted node_modules tree: the macOS host and the Linux dev
# container share frontend/node_modules, but rollup/esbuild ship per-OS native
# binaries, so only one platform's are usable at a time.
#
# Probe via the Node API (require + transformSync), NOT the */.bin CLIs: vite uses
# rollup/esbuild as libraries, and .bin/esbuild can point at the wrong-OS binary even
# when vite works, so a CLI `--version` probe gives false positives.
#
# CUSTOMIZE: assumes a vite frontend in frontend/. Point the cd below at your
# frontend dir if it lives elsewhere; if your repo has no vite frontend, replace
# the body with a bare `exit 0` (the loop runs this at startup and exits hard on
# failure).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../frontend"

# Probe the host-platform native binaries the way vite loads them. Covers both the
# missing-node_modules case (require throws) and host/container drift.
if node -e "require('rollup'); require('esbuild').transformSync('const x = 1')" >/dev/null 2>&1; then
  exit 0
fi

echo "[ensure-vite-arch] rollup/esbuild not runnable on $(uname -s) $(uname -m), reinstalling..."
rm -rf node_modules/@rollup node_modules/@esbuild node_modules/esbuild
npm install
