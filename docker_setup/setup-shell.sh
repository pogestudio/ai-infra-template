#!/usr/bin/env bash
# Shell customizations for the app user (aliases, prompt tweaks, etc.)

# cdv = the everyday interactive Claude. Run its subagents on Sonnet (not Opus) for cost —
# mirrors ralph/ralph-loop.sh's CLAUDE_CODE_SUBAGENT_MODEL=sonnet export. The inline prefix
# scopes it to cdv (a bare `claude` is unaffected); subagents inherit it from the env.
echo "alias cdv='CLAUDE_CODE_SUBAGENT_MODEL=sonnet claude --dangerously-skip-permissions --verbose'" >> /home/app/.bashrc
echo "[shell] Claude Code: effort=xhigh, adaptive_thinking=off"
