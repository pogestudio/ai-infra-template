# Reference

## Refactor-target signals

Used in Step 1 to find candidates by **evidence, not impression**. Run sweeps over the relevant tree (`backend` for Python, `frontend/src` for Vue/JS). If a tool is ever missing, fall back to git + grep + reading — never block on it.

### Provisioning (idempotent — run once at the start if a tool is missing)

The Python tools are pinned in `requirements-dev.txt` (deliberately out of the prod `requirements.txt`). Install them **into the project venv** and ensure the npm one:

```
backend/venv/bin/python -m pip install -q -r requirements-dev.txt   # radon, vulture, grimp
command -v jscpd >/dev/null || npm install -g jscpd                 # duplication (JS/Vue + Python)
```

Re-running is a no-op once installed. Always invoke the Python tools as `backend/venv/bin/python -m <tool>` (not `backend/venv/bin/<tool>`) — the venv's console-script shebangs are stale, which is the same reason CLAUDE.md runs `… python -m pytest`.

### Churn × complexity (hotspots — the primary signal)

- **Churn** (change frequency, last ~12 months): `git log --since="12 months ago" --name-only --format= -- backend | sort | uniq -c | sort -rn | head -40`
- **Complexity**: `backend/venv/bin/python -m radon cc -s -n C backend -i "*venv*"` (cyclomatic, grade C and worse) and `backend/venv/bin/python -m radon mi -s backend -i "*venv*"` (maintainability index; flag MI < 65). The `-i "*venv*"` excludes the vendored `backend/venv*` dirs.
- A file high on **both** lists is a hotspot. A complex file with near-zero churn is stable on purpose — leave it. Cite the actual change-count and CC/MI grade per candidate.

### Coupling & import cycles

- Static graph, no code execution: `PYTHONPATH=. backend/venv/bin/python -c "import grimp; g = grimp.build_graph('backend'); ..."` — walk it for cycles and count fan-in/fan-out per module. (Put the concrete cycle-finder snippet in the candidate's brief.)
- Function-local imports (`def f(): import x`) are how cycles get hidden — grep for indented `import`/`from` lines in `backend` and treat them as suspected back-edges.

### Duplication (measured, not eyeballed)

- `jscpd --min-tokens 50 --reporters console backend` (and again for `frontend/src`). Read the clone % and the actual file pairs. Report "N files share the shape, each X% unique" — never a bare "identical."

### Dead / inert code

- `backend/venv/bin/python -m vulture backend --min-confidence 70 --exclude "*venv*"` for unused functions/vars/imports.
- "Read but never written" keys (always-`None`): grep the read sites for the key, then the write sites; a key with reads and no writes is a dead trace/field.

### Coverage truth-check

- Don't claim "no test for X" — count first: `grep -rl "X" backend/tests` (and `frontend/tests`).
- Real coverage number (optional, if the plugin is present): `backend/venv/bin/python -m pytest backend/tests --cov=backend --cov-report=term-missing`; frontend `cd frontend && npx vitest run --coverage`.

## Dependency Categories

When assessing a candidate for deepening, classify its dependencies:

### 1. In-process

Pure computation, in-memory state, no I/O. Always deepenable — just merge the modules and test directly.

### 2. Local-substitutable

Dependencies that have local test stand-ins (e.g., PGLite for Postgres, in-memory filesystem). Deepenable if the test substitute exists. The deepened module is tested with the local stand-in running in the test suite.

### 3. Remote but owned (Ports & Adapters)

Your own services across a network boundary (microservices, internal APIs). Define a port (interface) at the module boundary. The deep module owns the logic; the transport is injected. Tests use an in-memory adapter. Production uses the real HTTP/gRPC/queue adapter.

Recommendation shape: "Define a shared interface (port), implement an HTTP adapter for production and an in-memory adapter for testing, so the logic can be tested as one deep module even though it's deployed across a network boundary."

### 4. True external (Mock)

Third-party services (Stripe, Twilio, etc.) you don't control. Mock at the boundary. The deepened module takes the external dependency as an injected port, and tests provide a mock implementation.

## Testing Strategy

The core principle: **replace, don't layer.**

- Old unit tests on shallow modules are waste once boundary tests exist — delete them
- Write new tests at the deepened module's interface boundary
- Tests assert on observable outcomes through the public interface, not internal state
- Tests should survive internal refactors — they describe behavior, not implementation

## Issue Template

<issue-template>

## Problem

Describe the architectural friction:

- Which modules are shallow and tightly coupled
- What integration risk exists in the seams between them
- Why this makes the codebase harder to navigate and maintain

## Proposed Interface

The chosen interface design:

- Interface signature (types, methods, params)
- Usage example showing how callers use it
- What complexity it hides internally

## Dependency Strategy

Which category applies and how dependencies are handled:

- **In-process**: merged directly
- **Local-substitutable**: tested with [specific stand-in]
- **Ports & adapters**: port definition, production adapter, test adapter
- **Mock**: mock boundary for external services

## Testing Strategy

- **New boundary tests to write**: describe the behaviors to verify at the interface
- **Old tests to delete**: list the shallow module tests that become redundant
- **Test environment needs**: any local stand-ins or adapters required

## Implementation Recommendations

Durable architectural guidance that is NOT coupled to current file paths:

- What the module should own (responsibilities)
- What it should hide (implementation details)
- What it should expose (the interface contract)
- How callers should migrate to the new interface

</issue-template>
