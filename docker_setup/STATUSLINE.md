# Claude Code Statusline

A colorful, compact statusline for Claude Code sessions.

```
[O:4.6] 23.RedditMarketingExtension | main █████░░░░░░░░░░ 27% | 4m
 ╰───────── rainbow pastel ────────╯              ╰green→red╯       ╰session
```

## What it shows

| Element | Color | Description |
|---------|-------|-------------|
| `[O:4.6] FolderName` | 5 pastel rainbow colors | Model shorthand + working directory, split evenly across a rotating palette |
| `main` | Mint | Current git branch (hidden if not a git repo) |
| `█████░░░░░` | Green → Yellow → Red gradient | Context window usage bar (15 chars wide) |
| `27%` | Matches bar fill level | Context percentage (green when low, red when high) |
| `4m` | Sky blue | Time since session/context started |

## Palette

The label text cycles through 5 pastel colors, rotating by `hour % 5`:

| Color | Hex | 256-color |
|-------|-----|-----------|
| Pink | `#ffb3ba` | 217 |
| Peach | `#ffdfba` | 223 |
| Yellow | `#ffffba` | 229 |
| Mint | `#baffc9` | 158 |
| Sky | `#bae1ff` | 153 |

## Requirements

- `jq` (JSON parsing)
- `git` (optional, for branch display)
- A terminal with 256-color support

## Install

### From the host into a Docker container

```bash
docker cp statusline/install.sh <container>:/tmp/install.sh
docker exec <container> bash /tmp/install.sh
```

### Via SSH to a remote VM

```bash
scp statusline/install.sh user@host:/tmp/install.sh
ssh user@host bash /tmp/install.sh
```

### Locally

```bash
bash statusline/install.sh
```

## Uninstall

Remove the script and the settings key:

```bash
rm ~/.claude/statusline-command.sh
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

## Known issues

- **Narrow terminal at session start**: When the terminal hasn't settled its width yet (e.g. fresh session with empty input box), ANSI escape bytes can confuse the width calculation. The script detects narrow terminals (`< 40 cols`) and falls back to plain uncolored text.
- **RGB vs 256-color**: RGB true color (`38;2;R;G;B`) works for block characters (the bar) but not regular text in some environments (Docker/devcontainers). The label text uses 256-color mode for compatibility.
- **Cross-platform stat**: Session time uses macOS `stat -f "%B"` with Linux `stat -c "%W"/"%Y"` fallback.
