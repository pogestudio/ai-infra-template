#!/usr/bin/env bash
#
# ralph/ralph-fetch-issue.sh — print one issue's full contract (header + body + EVERY comment) in
# a single, non-TTY-safe call. The canonical "read the contract" command for the Ralph loop.
#
# WHY THIS EXISTS
#   `gh issue view <N> --comments` emits ZERO bytes when stdout is not a TTY — which is exactly how
#   the loop runs claude — so the in-loop agent burned 2-3 calls every iteration rediscovering a
#   working invocation (--comments → empty → GH_PAGER=cat → still empty → --json | python). The
#   `--json … --template` form below is TTY-independent and prints the body AND comment bodies on
#   the first try. (Plain `gh issue view <N>` is also non-TTY-safe but hides comment bodies — it
#   only shows a `comments: N` count — so this wrapper always renders the comments too.)
#
# USAGE
#   ./ralph/ralph-fetch-issue.sh <ISSUE_NUMBER>      # e.g. ./ralph/ralph-fetch-issue.sh 127
#
# Issues here run ~75 lines; no `head` cap is needed (and capping could hide a Decision Log).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."   # repo root: gh resolves the repo from the cwd's git remote

raw="${1:?usage: ralph-fetch-issue.sh <ISSUE_NUMBER>}"
issue="${raw#\#}"     # tolerate a leading '#': accept both 127 and #127

gh issue view "$issue" \
  --json number,title,state,labels,body,comments \
  --template '#{{.number}}  {{.title}}  [{{.state}}]
labels: {{range .labels}}{{.name}} {{end}}

{{.body}}

---------------- comments ({{len .comments}}) ----------------
{{range .comments}}
@{{.author.login}}  {{.createdAt}}:
{{.body}}
{{end}}'
