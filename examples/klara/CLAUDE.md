# Klara Ansökningssystem

Application management system with FastAPI backend and Vue 3 frontend.

> **Input may be voice-transcribed** (occasionally garbled) — if words seem contradictory or out of place, ask for clarification rather than assume, unless the intent is clear.

## Goal

Get this application working on Heroku.

## Tech Stack

- **Backend**: Python 3 / FastAPI / SQLAlchemy (SQLite for local/dev, MySQL in production)
- **Frontend**: Vue 3 / Vite
- **Deployment**: Heroku

## Project Structure

```
backend/       # FastAPI API server
frontend/      # Vue 3 SPA
```

## Running Tests

**Always run tests before committing changes.** Both suites run on SQLite — no MySQL or other services needed.

### Backend (pytest) — from the repo root
```bash
backend/venv/bin/python -m pytest backend/tests
```
Tests use an in-memory SQLite DB (see `backend/tests/conftest.py`).

### Frontend (vitest)
```bash
cd frontend && npx vitest run
```
Tests are in `frontend/tests/*.test.js`. See `AI-Info/skills/how-to-TDD.md` for patterns.

**Git:** always merge, never rebase (`pull.rebase false`); never force-push.

## Development

The app defaults to a local SQLite DB (`backend/klara_dev.db`) with zero external
services. **To start (or restart) the dev environment, just run `./scripts/dev-up.sh`** — it stops any stack already running, reinstalls deps if needed, and starts backend + frontend fresh on the current code (so it's also how you pick up backend edits before an e2e — no need to stop or kill anything first; `./scripts/dev-up.sh stop` tears down).

> **It returns on its own once the stack is healthy (~2s).** If you script it, a short timeout (e.g. the Bash tool's `timeout: 10000`) is cheap insurance — mostly for a first run that still has to install deps.

Or run the pieces from the repo root, in separate terminals:

### Backend (http://localhost:8000)
```bash
backend/venv/bin/python -m uvicorn backend.main:app --reload --port 8000
```

### Frontend (http://localhost:5173)
```bash
cd frontend && npm run dev
```
The dev frontend calls the backend at `http://localhost:8000`, so port 8000 must be free.

### Seed a dev user (needed to log in)
Login requires a real account; the dev DB starts empty. Seed an idempotent user from the repo root:
```bash
backend/venv/bin/python -m backend.seed_dev   # creates admin@klara.test / klara1234
```
Use those credentials for manual and Playwright-MCP e2e login.

## Heroku Deployment

The app uses a `Procfile` for Heroku:
- Release phase runs `build.sh`, then `python -m backend.migrate`, then `alembic upgrade head`
- Web process runs uvicorn from `/backend`
- Frontend is built during `heroku-postbuild` and served as static files

## Database migrations (Alembic)

`create_all()` builds the schema on fresh dev/test DBs but can only *add* tables — it never
alters an existing one. So **any change to an existing table (add/alter/drop a column) needs an
Alembic migration**, or it silently never reaches production. How to write, test (SQLite *and*
MySQL), and ship one is in **`MIGRATIONS.md`**.

## Local Agents

- **Tech Ranger**: For focused implementation tasks, use `/tech-ranger` — see `AI-Info/local-agents/local-tech-ranger.md`
- **Meta-Agent**: For working on the agent system itself (Ralph loop, agents, skills, instruction files), use `/meta-agent` — see `AI-Info/local-agents/local-meta-agent.md`
