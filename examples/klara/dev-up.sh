#!/usr/bin/env bash
#
# scripts/dev-up.sh — bring up the full local dev stack on SQLite (no external services).
#
#   ./scripts/dev-up.sh          rebuild the dev SQLite DB from scratch, seed the dev
#                                user + demo applications, start backend (:8000) +
#                                frontend (:5173) detached, wait until both are healthy,
#                                then print status.
#   ./scripts/dev-up.sh stop     stop the backend + frontend.
#
# Login: admin@klara.test / klara1234 (override with DEV_USER_EMAIL / DEV_USER_PASSWORD).
#
# Works both inside the Linux dev container and on a macOS host that shares this tree:
# the first run bootstraps a per-OS Python venv (backend/venv on Linux, backend/venv-macos
# on macOS — so the two never clobber each other's binaries) and installs backend +
# frontend deps. Override the interpreter used to build the venv with PYTHON=/path/to/python3.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Per-loop isolation: one Ralph loop runs per clone, keyed by RALPH_LOOP_ID (default 0 ⇒
# today's exact ports/DB/logs). Each loop offsets its ports + names its own SQLite file so
# multiple stacks coexist on Docker --network host. An explicitly-set BACKEND_PORT/
# FRONTEND_PORT/DATABASE_URL still wins (prod sets DATABASE_URL).
RALPH_LOOP_ID="${RALPH_LOOP_ID:-0}"
BACKEND_PORT="${BACKEND_PORT:-$((8000 + RALPH_LOOP_ID))}"
FRONTEND_PORT="${FRONTEND_PORT:-$((5173 + RALPH_LOOP_ID))}"
# id 0 → sqlite:///klara_dev.db (unchanged); id N → klara_dev_N.db. backend/database.py
# anchors a relative sqlite path to backend/, so this resolves to backend/klara_dev[_N].db.
export DATABASE_URL="${DATABASE_URL:-sqlite:///klara_dev$( [ "$RALPH_LOOP_ID" = 0 ] || printf '_%s' "$RALPH_LOOP_ID" ).db}"

# Host (macOS) and the Linux dev container share this working tree but each need their own
# native binaries, so the venv is keyed on the OS. Both names match `backend/venv*` in
# .gitignore.
case "$(uname -s)" in
  Darwin) VENV_DIR="backend/venv-macos" ;;
  *)      VENV_DIR="backend/venv" ;;
esac
PY="$VENV_DIR/bin/python"
if [ "$RALPH_LOOP_ID" = 0 ]; then LOG_DIR="/tmp/klara-dev"; else LOG_DIR="/tmp/klara-dev-$RALPH_LOOP_ID"; fi
mkdir -p "$LOG_DIR"

# Interpreter that builds the venv on first run. An explicit PYTHON=/path/to/python3 always
# wins; otherwise prefer one matching the pinned .python-version (so local == prod), trying
# the most prod-like first and falling back through whatever is installed.
PINNED_PY="$(tr -d '[:space:]' < .python-version 2>/dev/null || true)"   # e.g. 3.11
if [ -n "${PYTHON:-}" ]; then
  PY_BOOTSTRAP="$PYTHON"
else
  PY_BOOTSTRAP="python3"
  for cand in "python${PINNED_PY:-3.11}" python3.14 python3.13 python3.12 python3.11 python3; do
    if command -v "$cand" >/dev/null 2>&1; then PY_BOOTSTRAP="$cand"; break; fi
  done
fi

ver_key() {  # "3.14" -> 3014, so MAJOR.MINOR versions compare numerically
  local v="${1:-0.0}" maj min
  maj="${v%%.*}"; min="${v#"$maj".}"; min="${min%%.*}"
  printf '%d' "$(( ${maj:-0} * 1000 + ${min:-0} ))"
}

warn_interpreter_drift() {  # local-vs-prod guard, emitted only when we are about to build
  [ -n "$PINNED_PY" ] || return 0
  local ver tested="3.11"
  ver="$("$PY_BOOTSTRAP" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)" || return 0
  if [ "$(ver_key "$ver")" -lt "$(ver_key "$PINNED_PY")" ]; then
    echo "WARNING: building venv with $PY_BOOTSTRAP (Python $ver) — older than pinned .python-version" >&2
    echo "         ($PINNED_PY); local will not match prod. Install python$PINNED_PY or set PYTHON=…."   >&2
  elif [ "$(ver_key "$ver")" -gt "$(ver_key "$tested")" ]; then
    echo "WARNING: building venv with $PY_BOOTSTRAP (Python $ver) — newer than the newest tested"        >&2
    echo "         ($tested); dependency wheels may be unverified on this version."                      >&2
  fi
}

stop() {
  for port in "$BACKEND_PORT" "$FRONTEND_PORT"; do
    pids="$(lsof -ti:"$port" 2>/dev/null || true)"
    if [ -n "$pids" ]; then
      echo "stopping :$port ($pids)"
      kill $pids 2>/dev/null || true
      sleep 1
      pids="$(lsof -ti:"$port" 2>/dev/null || true)"
      [ -n "$pids" ] && kill -9 $pids 2>/dev/null || true
    fi
  done
  # cloudflared (prodCom mode) has no listening port — pid file is the handle.
  if [ -f "$LOG_DIR/cloudflared.pid" ]; then
    tpid="$(cat "$LOG_DIR/cloudflared.pid" 2>/dev/null || true)"
    if [ -n "$tpid" ] && kill -0 "$tpid" 2>/dev/null; then
      echo "stopping cloudflared ($tpid)"
      kill "$tpid" 2>/dev/null || true
      sleep 1
      kill -0 "$tpid" 2>/dev/null && kill -9 "$tpid" 2>/dev/null || true
    fi
    rm -f "$LOG_DIR/cloudflared.pid"
  fi
}

start_tunnel() {  # prodCom only — bring up a Cloudflare quick-tunnel pointing at
                  # localhost:$BACKEND_PORT, write the public URL to TUNNEL_URL, and
                  # PATCH the Twilio Console + backend/.env via configure_twilio_webhook.py.
                  # Sequenced BEFORE the backend so TWILIO_WEBHOOK_BASE_URL is in scope
                  # when uvicorn boots (TwilioTransport reads it for status_callback).
  command -v cloudflared >/dev/null 2>&1 || {
    echo "ERROR: 'cloudflared' not found on PATH — prodCom mode needs the tunnel."  >&2
    echo "       Linux/container: rebuild the image (./run-claude.sh --build)."     >&2
    echo "       macOS host:      brew install cloudflared"                          >&2
    exit 1
  }
  for v in TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_FROM_NUMBER; do
    if [ -z "$(grep -E "^$v=" backend/.env 2>/dev/null | tail -n1 | cut -d= -f2-)" ]; then
      echo "ERROR: backend/.env missing $v — prodCom mode needs the three Twilio creds." >&2
      exit 1
    fi
  done

  : > "$LOG_DIR/cloudflared.log"
  echo "      starting cloudflared tunnel → http://localhost:$BACKEND_PORT"
  detach cloudflared tunnel --url "http://localhost:$BACKEND_PORT" \
    > "$LOG_DIR/cloudflared.log" 2>&1 < /dev/null &
  echo $! > "$LOG_DIR/cloudflared.pid"

  echo "      waiting for tunnel URL (up to 60s)…"
  TUNNEL_URL=""
  for _ in $(seq 1 60); do
    TUNNEL_URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/cloudflared.log" | head -n1 || true)"
    [ -n "$TUNNEL_URL" ] && break
    sleep 1
  done
  if [ -z "$TUNNEL_URL" ]; then
    echo "ERROR: cloudflared never reported a tunnel URL. Last 20 log lines:" >&2
    tail -n 20 "$LOG_DIR/cloudflared.log" >&2 || true
    exit 1
  fi
  echo "      tunnel up: $TUNNEL_URL"

  echo "      updating Twilio Console + backend/.env…"
  if ! "$PY" scripts/configure_twilio_webhook.py "$TUNNEL_URL"; then
    echo "ERROR: configure_twilio_webhook.py failed — see output above." >&2
    exit 1
  fi
  export TWILIO_WEBHOOK_BASE_URL="$TUNNEL_URL"
}

wait_up() {  # $1=url
  for _ in $(seq 1 60); do
    curl -sf "$1" -o /dev/null 2>/dev/null && return 0
    sleep 0.5
  done
  return 1
}

detach() {  # Run "$@" detached from the caller's terminal so dev-up.sh can return the
            # moment the stack is healthy. setsid (util-linux) gives it a brand-new
            # session on Linux/in-container; macOS ships no setsid(1), so fall back to
            # nohup, which makes the server SIGHUP-immune instead. Either way the call
            # site's `> log 2>&1 < /dev/null` is what frees the caller's fds (see the
            # launch sites); this just keeps the server alive once the terminal closes.
  if command -v setsid >/dev/null 2>&1; then
    setsid "$@"
  else
    nohup "$@"
  fi
}

ensure_venv() {  # (re)build the venv only when its core deps don't import (first run / other
                 # OS / half-built install); then ALWAYS install requirements.txt (minus the
                 # prod-only mysqlclient, see below) so anything listed but missing gets
                 # installed. Durable + simple: pip is
                 # the source of truth — it installs the missing reqs and skips what's already
                 # satisfied, every start. (Fixes the bug where a dep ADDED to requirements.txt
                 # after the venv was built — e.g. twilio — was silently never installed,
                 # because the import-probe below passes on the stale venv.)
  if ! "$PY" -c 'import fastapi, pydantic, uvicorn' >/dev/null 2>&1; then
    command -v "$PY_BOOTSTRAP" >/dev/null 2>&1 || {
      echo "ERROR: '$PY_BOOTSTRAP' not found. Install Python 3 (macOS: 'brew install python')," >&2
      echo "       or point PYTHON at one:  PYTHON=/path/to/python3 $0"                          >&2
      exit 1
    }
    warn_interpreter_drift
    if [ -e "$VENV_DIR" ]; then
      echo "venv at $VENV_DIR is unusable or incomplete on $(uname -s) — rebuilding it…"
      rm -rf "$VENV_DIR"
    else
      echo "creating Python venv at $VENV_DIR (first run on $(uname -s))…"
    fi
    "$PY_BOOTSTRAP" -m venv "$VENV_DIR"
    "$PY" -m pip install --quiet --upgrade pip
  fi
  # Install everything in requirements.txt that isn't already satisfied (pip skips the rest),
  # MINUS the prod-only MySQL C-driver `mysqlclient`: it needs a native build that may be
  # unavailable here, and dev runs on SQLite (PyMySQL — pure-python — covers any MySQL need),
  # so it's both unbuildable and unnecessary in dev. Letting it through would abort the whole
  # install under `set -e`. Durable + simple: runs every start, no stamp/marker to drift.
  echo "      ensuring backend deps (pip install -r requirements.txt, minus prod-only mysqlclient)…"
  grep -ivE '^mysqlclient[=<> ]' requirements.txt | "$PY" -m pip install --quiet -r /dev/stdin
}

ensure_frontend_deps() {  # node_modules is shared host/container via the bind mount, but
                          # rollup/esbuild ship per-OS native binaries. Probe + heal only when the
                          # current OS/arch can't run them (fast no-op otherwise; also covers a
                          # missing node_modules). See scripts/ensure-vite-arch.sh.
  if ! ./scripts/ensure-vite-arch.sh > "$LOG_DIR/ensure-vite-arch.log" 2>&1; then
    echo "ERROR: frontend deps not ready (see $LOG_DIR/ensure-vite-arch.log)" >&2
    exit 1
  fi
}

reset_db() {  # Rebuild the dev DB from scratch on every start: delete the SQLite file (and
              # its WAL/journal sidecars) so the next seed starts truly empty. seed_dev's
              # Base.metadata.create_all() then recreates the schema, and because the DB is
              # empty all three (idempotent) seeders run anew instead of no-op'ing on
              # existing rows. We resolve the path from the backend's own config so it honors
              # the backend/ anchoring and any DATABASE_URL override — and only ever remove a
              # local SQLite *file*, so pointing DATABASE_URL at a real MySQL/Postgres (or an
              # in-memory DB) is left untouched. A backend import failure here aborts the
              # start, which is what we want (the server wouldn't run either).
  "$PY" - <<'PY'
import os
from backend.database import DATABASE_URL

prefix = "sqlite:///"
if not DATABASE_URL.startswith(prefix):
    print(f"      DATABASE_URL is not local SQLite ({DATABASE_URL!r}) — skipping DB reset.")
    raise SystemExit(0)
path = DATABASE_URL[len(prefix):]
if not path or path == ":memory:":
    print("      in-memory SQLite — nothing to reset.")
    raise SystemExit(0)
removed = [
    os.path.basename(p)
    for p in (path, path + "-wal", path + "-shm", path + "-journal")
    if os.path.exists(p) and (os.remove(p) or True)
]
print(f"      removed {', '.join(removed)}" if removed else "      no existing DB file (already empty).")
PY
}

PROD_COM=0
case "${1:-start}" in
  stop) stop; echo "dev stack stopped."; exit 0 ;;
  prodCom) PROD_COM=1 ;;
  start) ;;
  *) echo "usage: $0 [start|stop|prodCom]" >&2; exit 2 ;;
esac

ensure_venv

if [ "$PROD_COM" = 1 ]; then
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!  prodCom mode — REAL EMAIL + REAL TWILIO SMS WILL BE SENT        !"
  echo "!  SMS_TRANSPORT=twilio  EMAIL_TRANSPORT=smtp                       !"
  echo "!  ENVIRONMENT stays development (SQLite safe)                      !"
  echo "!  cloudflared tunnel exposes :$BACKEND_PORT for inbound SMS         !"
  echo "!  KF_DEMO_SINGLE=1 — seeds ONE applicant carrying the demo phone   !"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  # Single-demo seed: prodCom = a real-SMS demo, so seed exactly one maximally-matching
  # applicant carrying the demo phone (backend.seed_dev honours this) instead of the full
  # ~32-applicant set — the live intresseckoll/slot-pick SMS then reaches only that number.
  # Override the recipient with KF_DEMO_PHONE=… if a different tester should get the SMS.
  export KF_DEMO_SINGLE=1
  # Warn if SMTP creds are absent (Twilio creds are checked by start_tunnel below — fatal).
  if [ -z "${SMTP_HOST:-}" ]; then
    echo "WARNING: SMTP_HOST not set — real email will NOT send." >&2
  fi
fi

# Self-healing start: stop any stack already holding the ports (a leftover from a
# prior run — these dev containers share Docker --network host) so `dev-up.sh` always
# (re)starts cleanly on the current code. No-op when nothing is running; ensure_venv +
# ensure_frontend_deps reinstall deps when needed. So one command = a fresh, current
# stack, with no manual stop/kill first. `stop` stays available as a subcommand.
stop

# Tunnel comes up BEFORE the backend so TWILIO_WEBHOOK_BASE_URL is exported by the
# time uvicorn boots — TwilioTransport.from_settings reads it for status_callback,
# and configure_twilio_webhook.py also writes it to backend/.env (so a manual
# uvicorn restart, without dev-up.sh, would still pick it up).
if [ "$PROD_COM" = 1 ]; then
  start_tunnel
fi

echo "[1/4] resetting dev DB — rebuilding from scratch on every start…"
reset_db

echo "[2/4] seeding dev user (admin@klara.test / klara1234) + demo applications…"
"$PY" -m backend.seed_dev

echo "[3/4] backend  -> http://localhost:$BACKEND_PORT"
# detach + </dev/null + log redirect: launch fully detached (see detach() above), stdin
# from /dev/null and stdout/err to the log, so dev-up.sh returns the moment the stack is
# healthy instead of blocking its caller (e.g. an agent's shell) on the long-lived server.
# `env` carries the polling var into the interpreter because a bash `VAR=val` prefix on
# the detach FUNCTION isn't exported to the setsid/nohup child it spawns.
# WATCHFILES_FORCE_POLLING + --reload-dir backend: poll mtime (FS events may not cross
# the Docker bind-mount), scoped to backend/ to stay off node_modules.
# --proxy-headers + --forwarded-allow-ips="*": trust X-Forwarded-Proto/Host so the Twilio
# signature validator rebuilds the public URL (D11) — matches the Heroku Procfile.
# Comms transport is decided HERE and forced into the uvicorn process env — never left to
# backend/.env. prodCom mode => real Twilio SMS + SMTP email; every other mode (default
# `start`, the prompt-testing harness via run-prompts.sh) => console transports. Because
# pydantic-settings ranks the process environment ABOVE the .env file, this hard-overrides
# any leftover `SMS_TRANSPORT=twilio` + live creds a past `prodCom` run wrote to backend/.env.
# Without this, a stale backend/.env silently sends REAL SMS from an ordinary dev/harness run
# — which on 2026-06-03 drained the Twilio account across unattended Ralph-loop harness runs
# (account suspended). The guarantee is now: no prodCom on the command line => no live comms,
# regardless of what any VM's backend/.env holds.
#
# Defense-in-depth (2026-06-04): the chatbot's OWN SMS path (backend/integrations/sms,
# get_channel) historically picked the live TwilioSmsChannel purely on the PRESENCE of
# TWILIO_ACCOUNT_SID — it did NOT read SMS_TRANSPORT — so the console force above did not
# cover it and a normal dev-tui run sent real SMS. The code now honors sms_transport, but we
# also blank the Twilio creds for non-prodCom so the channel falls back to LogChannel even if
# that code path ever regresses. (prodCom keeps the creds; that's the only live mode.)
if [ "$PROD_COM" = 1 ]; then
  COMMS_ENV="SMS_TRANSPORT=twilio EMAIL_TRANSPORT=smtp"
else
  COMMS_ENV="SMS_TRANSPORT=console EMAIL_TRANSPORT=console TWILIO_ACCOUNT_SID= TWILIO_AUTH_TOKEN="
fi
# shellcheck disable=SC2086
detach env WATCHFILES_FORCE_POLLING=true $COMMS_ENV "$PY" -m uvicorn backend.main:app --reload --reload-dir backend --port "$BACKEND_PORT" --proxy-headers --forwarded-allow-ips="*" > "$LOG_DIR/backend.log" 2>&1 < /dev/null &

ensure_frontend_deps
echo "[4/4] frontend -> http://localhost:$FRONTEND_PORT"
# Redirect + background the WHOLE subshell, not just npm. With the earlier
# `( cd frontend && setsid npm … >log 2>&1 < /dev/null & )`, the redirect bound only to
# npm: the subshell running the `cd && …` list then waited on npm with ITS OWN stdout/
# stderr still pointing at dev-up.sh's caller pipe (we're invoked as `dev-up.sh 2>&1 | …`).
# So the caller (agent shell / `… | tail`) never saw EOF and hung until timeout even
# though the stack was already up. Whether bash exec-replaces that trailing list command
# or forks-and-waits is bash-build-dependent — hence "fine on one VM, hangs on another".
# Redirecting the group points the waiting shell's fds at the log instead, so nothing
# holds the caller pipe. detach() detaches the session (setsid on Linux, nohup on macOS);
# `env` carries the polling var past the detach function; CHOKIDAR_USEPOLLING polls for
# the same Docker bind-mount reason as the backend.
( cd frontend && detach env CHOKIDAR_USEPOLLING=true VITE_API_BASE_URL="http://localhost:$BACKEND_PORT" npm run dev -- --port "$FRONTEND_PORT" --strictPort ) > "$LOG_DIR/frontend.log" 2>&1 < /dev/null &

wait_up "http://localhost:$BACKEND_PORT/docs" || { echo "backend failed to start — see $LOG_DIR/backend.log" >&2; exit 1; }
wait_up "http://localhost:$FRONTEND_PORT/"    || { echo "frontend failed to start — see $LOG_DIR/frontend.log" >&2; exit 1; }

DB_DISPLAY="backend/klara_dev$( [ "$RALPH_LOOP_ID" = 0 ] || printf '_%s' "$RALPH_LOOP_ID" ).db"
cat <<EOF

dev stack up (SQLite at $DB_DISPLAY):
  backend   http://localhost:$BACKEND_PORT     logs: $LOG_DIR/backend.log
  frontend  http://localhost:$FRONTEND_PORT     logs: $LOG_DIR/frontend.log
$([ "$PROD_COM" = 1 ] && echo "  tunnel    ${TUNNEL_URL:-<unset>}   logs: $LOG_DIR/cloudflared.log")
  loop      RALPH_LOOP_ID=$RALPH_LOOP_ID  (ports/DB/logs offset by this)
  venv      $VENV_DIR
  login     admin@klara.test / klara1234
  data      DB rebuilt fresh each start; demo applications seeded (a few already emailed)
  email     $([ "$PROD_COM" = 1 ] && echo "prodCom: REAL email (SMTP) + REAL SMS (Twilio) active" || echo 'dev mode logs "SENDING EMAIL: …" to backend.log — no real mail is sent')
  stop      $0 stop
EOF
