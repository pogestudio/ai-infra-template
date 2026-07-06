# <!-- CUSTOMIZE: Project Name -->

<!-- CUSTOMIZE: one line — what this app is. -->

## Goal

<!-- CUSTOMIZE: the current overriding goal, one line. -->

## Tech Stack

- **Backend**: <!-- CUSTOMIZE -->
- **Frontend**: <!-- CUSTOMIZE -->
- **Deployment**: <!-- CUSTOMIZE -->

## Project Structure

```
backend/       # CUSTOMIZE
frontend/      # CUSTOMIZE
```

## Running Tests

**Always run tests before committing changes.**

```bash
./scripts/run-tests.sh    # the single green-gate — every suite, exit 0 only on all-green
```
<!-- CUSTOMIZE: add the per-suite commands for tight red-green cycles, e.g.
backend/venv/bin/python -m pytest backend/tests
cd frontend && npx vitest run
See AI-Info/skills/how-to-TDD.md for patterns. -->

**Git:** always merge, never rebase (`pull.rebase false`); never force-push.

## Development

**To start (or restart) the dev environment, run `./scripts/dev-up.sh`** — it stops any stack
already running and starts backend + frontend fresh on the current code (so it's also how you
pick up backend edits before an e2e). `./scripts/dev-up.sh stop` tears down. It returns on its
own once the stack is healthy; if you script it, give it a short timeout as insurance.

<!-- CUSTOMIZE: dev URLs + the seeded dev login, e.g.
- Frontend: http://localhost:5173
- Backend: http://localhost:8000 (API docs at /docs)
Seeded dev login: admin@example.test / password — use for manual and Playwright-MCP e2e login. -->

## Local Agents

- **Tech Ranger**: For focused implementation tasks, use `/tech-ranger` — see `AI-Info/local-agents/local-tech-ranger.md`
- **Meta-Agent**: For working on the agent system itself (Ralph loop, agents, skills, instruction files), use `/meta-agent` — see `AI-Info/local-agents/local-meta-agent.md`
