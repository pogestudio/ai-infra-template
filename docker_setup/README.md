# docker_setup/ Module Reference

Each script handles one concern. They are sourced by `docker-entrypoint.sh` in order.

## Scripts

| Script | Runs as | Purpose |
|--------|---------|---------|
| `config.sh` | sourced first | All shared config values (paths, volume names, ports, intervals) |
| `setup-docker-socket.sh` | root | Fix Docker socket group ownership and permissions |
| `setup-git-credentials.sh` | root | Configure git URL rewriting with token, export GH_TOKEN |
| `setup-python-dev.sh` | root | `pip install -e .` if pyproject.toml exists in workspace |
| `setup-credentials.sh` | root | Restore .claude.json, compare OAuth freshness, start background sync |
| `setup-peon-ping.sh` | root | Copy peon-ping from /opt backup into mounted ~/.claude, merge hooks |
| `setup-gdrive.sh` | root | Export GDRIVE_CREDENTIALS_DIR if credentials/ folder exists |
| `setup-playwright.sh` | root | Export PLAYWRIGHT_BROWSERS_PATH |
| `install-statusline.sh` | app | Install Claude Code statusline (runs after entrypoint via CMD) |
| `sync-claude-token-from-keychain.sh` | host (macOS) | Three-way Keychain/volume/local freshness comparison |

## Adding a new module

1. Create `setup-yourfeature.sh` in this directory
2. Start with `#!/usr/bin/env bash` and `set -euo pipefail`
3. Use variables from `config.sh` (they are already in scope when sourced)
4. Add a `source "${SETUP_DIR}/setup-yourfeature.sh"` line to `docker-entrypoint.sh`
5. If it needs new config values, add them to `config.sh`

## Config values (config.sh)

| Variable | Value | Used by |
|----------|-------|---------|
| `CLAUDE_LOCAL` | `/home/app/.claude` | credentials, peon-ping |
| `CLAUDE_PERSIST` | `/home/app/.claude-persist` | credentials |
| `PEON_BACKUP` | `/opt/peon-ping-backup` | peon-ping |
| `WORKSPACE` | `${PWD:-/workspace}` | python-dev, gdrive |
| `IMAGE_NAME` | `codex-expo-claude` | run-claude.sh |
| `CLAUDE_CREDS_VOLUME` | `claude-credentials` | run-claude.sh |
| `PEON_RELAY_HOST` | `host.docker.internal` | run-claude.sh |
| `PEON_RELAY_PORT` | `19998` | run-claude.sh |
| `SYNC_INTERVAL` | `30` | credentials background sync |
| `KEYCHAIN_SERVICE` | `Claude Code-credentials` | keychain sync |
| `DEFAULT_GIT_USERNAME` | `x-access-token` | git-credentials |
