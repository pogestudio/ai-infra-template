# peon-ping in Docker VM (with Relay to Mac Host)

Sounds play on your Mac even though Claude Code runs inside a Linux Docker container.

## Architecture

```
Mac (Ghostty)                    Docker VM (Linux)
┌──────────────┐    port 19998   ┌──────────────────┐
│ peon relay   │◄────────────────│ peon-ping hooks   │
│ (plays sound)│                 │ (Claude Code)     │
└──────────────┘                 └──────────────────┘
```

## Mac Host Setup (one-time)

```bash
brew install PeonPing/tap/peon-ping
peon-ping-setup
peon relay --daemon
```

Relay listens on `127.0.0.1:19998`. Verify with `lsof -i :19998`.

**Important:** After install, replace the packs symlink with real files (prevents relay 403 errors):

```bash
cd ~/.claude/hooks/peon-ping && rm packs && cp -r ~/.openpeon/packs .
peon relay --stop && peon relay --daemon
```

Add to `~/.zshrc` to auto-restart relay fresh on every terminal (avoids stale PID issues):

```bash
peon relay --stop >/dev/null 2>&1; peon relay --daemon
```

## Docker VM Integration

### 1. Add to Dockerfile

After the Claude Code install, add:

```dockerfile
# Install audio player for peon-ping (aplay from alsa-utils)
USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends alsa-utils \
  && rm -rf /var/lib/apt/lists/*

# Install peon-ping for terminal notifications (relay mode)
USER app
RUN mkdir -p /home/app/.claude \
  && curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --packs=peon \
  || true
# Backup peon-ping installation (volume mount will overwrite ~/.claude at runtime)
USER root
RUN cp -a /home/app/.claude /opt/peon-ping-backup 2>/dev/null || true
```

> **Note:** The `alsa-utils` package is required because the peon-ping installer checks for a supported audio player (`aplay`, `paplay`, `ffplay`, `mpv`, or `pw-play`). Slim base images like `debian:bullseye-slim` don't include any of these. If your base image already has one (e.g. `node:20-bullseye-slim` with `libasound2` from Playwright deps), you may still need `alsa-utils` since `libasound2` is just the library, `aplay` is the CLI binary peon-ping looks for.

### 2. Add restore logic to docker-entrypoint.sh

The `~/.claude` volume mount overwrites the build-time install. Add this before `exec gosu app "$@"`:

```bash
# Restore peon-ping into mounted .claude dir (build installs to image, but volume mount overwrites)
PEON_BACKUP="/opt/peon-ping-backup"
if [ -d "${PEON_BACKUP}/hooks/peon-ping" ] && [ ! -d "${CLAUDE_LOCAL}/hooks/peon-ping" ]; then
  echo "[entrypoint] Restoring peon-ping installation..."
  cp -a "${PEON_BACKUP}/hooks" "${CLAUDE_LOCAL}/"
  if [ -f "${PEON_BACKUP}/settings.json" ]; then
    if [ ! -f "${CLAUDE_LOCAL}/settings.json" ] || [ ! -s "${CLAUDE_LOCAL}/settings.json" ]; then
      cp "${PEON_BACKUP}/settings.json" "${CLAUDE_LOCAL}/settings.json"
    else
      jq -s '.[0] * {hooks: (.[0].hooks // {} | to_entries + (.[1].hooks // {} | to_entries) | group_by(.key) | map({key: .[0].key, value: [.[] | .value[]] | unique}) | from_entries)}' \
        "${CLAUDE_LOCAL}/settings.json" "${PEON_BACKUP}/settings.json" > "${CLAUDE_LOCAL}/settings.json.tmp" \
        && mv "${CLAUDE_LOCAL}/settings.json.tmp" "${CLAUDE_LOCAL}/settings.json" \
        || cp "${PEON_BACKUP}/settings.json" "${CLAUDE_LOCAL}/settings.json"
    fi
  fi
  chown -R app:app "${CLAUDE_LOCAL}"
  echo "[entrypoint] peon-ping restored"
fi
```

### 3. Add environment variables to run-claude.sh

Pass the relay env vars so peon-ping routes audio back to the Mac:

```bash
# Peon-ping relay: route audio from container to Mac host via HTTP relay on port 19998
docker run --rm -it \
  ...
  -e PLATFORM=devcontainer \
  -e PEON_RELAY_HOST=host.docker.internal \
  -e PEON_RELAY_PORT=19998 \
  ...
```

All three env vars are needed. `PLATFORM=devcontainer` tells peon.sh to use relay mode instead of trying local audio playback.

## Verifying It Works

From inside the container:

```bash
# Check relay is reachable
curl -s http://host.docker.internal:19998/health

# Test a sound
peon preview
```

From the Mac host:

```bash
lsof -i :19998           # relay actually listening? (more reliable than --status)
peon preview              # should play locally
```

## Useful Commands

| Command | Where | What |
|---|---|---|
| `peon relay --daemon` | Mac host | Start relay in background |
| `peon relay --stop` | Mac host | Stop relay |
| `lsof -i :19998` | Mac host | Check relay is actually listening |
| `peon toggle` | Either | Mute/unmute sounds |
| `peon status` | Either | Current config status |
| `peon packs list` | Either | Show installed packs |
| `peon packs use <name>` | Either | Switch active pack |
| `peon preview` | Either | Test sounds |

## Config

Config lives at `~/.claude/hooks/peon-ping/config.json` (inside the container for per-VM config, or on the Mac host for the relay).

Key settings:

```json
{
  "volume": 0.5,
  "desktop_notifications": true,
  "silent_window_seconds": 0
}
```

## Ghostty

Your Ghostty config already has `desktop-notifications = true` and `bell-features = attention, title`, which enables peon-ping's tab title updates and desktop popups.

## Troubleshooting

See `PEON_PING_SETUP_DEBUG.md` for detailed debugging of all known failure modes.

Quick checklist:

- **No sound, no notifications**: Relay not running. Check `lsof -i :19998`. Restart with `peon relay --stop; peon relay --daemon`.
- **Notifications arrive but no sound (403 in relay log)**: Packs symlink issue. Replace with real files: `cd ~/.claude/hooks/peon-ping && rm packs && cp -r ~/.openpeon/packs .` then restart relay.
- **Relay "already running" but nothing on port 19998**: Stale PID file. `peon relay --stop; peon relay --daemon`.
- **No sound from container, no errors**: Missing `PLATFORM=devcontainer` env var in run-claude.sh. Peon.sh defaults to local Linux playback (silent in headless container).
- **`host.docker.internal` not resolving**: Add `--add-host=host.docker.internal:host-gateway` to `docker run` (needed on some Linux Docker hosts, not needed on Docker Desktop for Mac).
- **"Async hook Stop completed" message**: The `Stop` hook in `settings.json` has `"async": true`. Remove the `"async": true` field from the Stop hook entry.
