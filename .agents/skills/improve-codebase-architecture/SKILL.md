---
name: improve-codebase-architecture
description: Explore a codebase to find opportunities for architectural improvement, focusing on making the codebase more testable by deepening shallow modules. Use when user wants to improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make a codebase more AI-navigable.
---

# Improve Codebase Architecture

Explore a codebase like an AI would, surface architectural friction, discover opportunities for improving testability, and propose module-deepening refactors as GitHub issue RFCs.

A **deep module** (John Ousterhout, "A Philosophy of Software Design") has a small interface hiding a large implementation. Deep modules are more testable, more AI-navigable, and let you test at the boundary instead of inside.

## Process

### 1. Find where the risk concentrates (evidence-first)

Subjective "this feels shallow" friction *overstates* impact — it is exactly what the verify step (Step 2) keeps deflating. So lead with objective, **measured** signals and use friction only to *interpret* them. The deep-module lens (Ousterhout) tells you what a good fix looks like; the metrics tell you where a fix is actually worth doing.

Gather these signals first — see [REFERENCE.md](REFERENCE.md#refactor-target-signals) for the exact commands and the one-time, idempotent provisioning step (run it first if any tool is missing). **Every candidate you carry forward must cite a measured number, not an impression:**

- **Hotspots — churn × complexity (the single best signal).** Cross `git log` change-frequency with per-file/function complexity (`radon`). High-churn × high-complexity = a real target. **A complex but rarely-changed module is *not* a target** — and a well-covered, stable split is a deliberate design choice working as intended; ranking it low is the point, not a miss.
- **Coupling & cycles.** Build the static import graph (`grimp`) and flag import cycles (including function-local back-edges) and high fan-in/out. Cycles are objective smells and tend to be the cleanest deep-module wins.
- **Duplication — measured, not eyeballed** (`jscpd`). Report how many files *truly* share a shape and what % of each is unique — never "N identical files" from a glance.
- **Dead / inert code** (`vulture` + grep). Unreferenced exports, zero-call-site functions, and keys read but never written (always-`None`). Cheap, high-certainty wins.
- **Coverage truth-check.** Before claiming "no test covers X," grep the test dir and count — do not assume.

Use the Agent tool with subagent_type=Explore to run these sweeps and read the hotspots they surface, recording the friction you feel navigating each one — that prose is what turns a metric into a candidate description. The numbers justify the candidate; the friction explains it.

### 2. Verify each candidate's claims with a subagent (adversarial)

Before presenting anything, fan out **one subagent per candidate** to fact-check its claims against the real code. Do this *before* the user sees the list: the user picks which candidate to pursue based on impact, so the impact has to be calibrated before the choice — not after.

The subagent did not produce the claim, so it isn't anchored to your estimate — its job is to **refute, not confirm**. Default position: the impact is smaller than claimed unless the code proves otherwise. (This step exists because the explore pass tends to *overstate* what a refactor buys — inflated coupling, overcounted "tests this would replace", speculative integration risk.)

Give each subagent the candidate's cluster plus every concrete claim, and have it open the cited files and return a per-claim verdict — `confirmed | overstated | refuted` — with `file:line` evidence:

- **Coupling**: real structural coupling, or incidental/superficial?
- **Test impact**: actually open and count the tests that would be replaced — does the claimed number hold?
- **Friction**: does understanding the concept really require bouncing between the named files, or is that overstated?
- **Integration risk**: evidence of real defects/risk in the seams, or speculation?

Drop candidates whose core claim is refuted; downgrade the rest to the verified impact.

### 3. Present candidates

Present a numbered list of the surviving deepening opportunities. For each candidate, show:

- **Cluster**: Which modules/concepts are involved
- **Why they're coupled**: Shared types, call patterns, co-ownership of a concept
- **Dependency category**: See [REFERENCE.md](REFERENCE.md) for the four categories
- **Test impact (verified)**: What existing tests would be replaced by boundary tests, per the Step 2 count

Where Step 2 downgraded or refuted a claim, say so inline (e.g. "original estimate ~12 tests, verified 3") so the user sees the correction rather than the inflated number.

Do NOT propose interfaces yet. Ask the user: "Which of these would you like to explore?"

### 4. User picks a candidate

### 5. Frame the problem space

Before spawning sub-agents, write a user-facing explanation of the problem space for the chosen candidate:

- The constraints any new interface would need to satisfy
- The dependencies it would need to rely on
- A rough illustrative code sketch to make the constraints concrete — this is not a proposal, just a way to ground the constraints

Show this to the user, then immediately proceed to Step 6. The user reads and thinks about the problem while the sub-agents work in parallel.

### 6. Design multiple interfaces

Spawn 3+ sub-agents in parallel using the Agent tool. Each must produce a **radically different** interface for the deepened module.

Prompt each sub-agent with a separate technical brief (file paths, coupling details, dependency category, what's being hidden). This brief is independent of the user-facing explanation in Step 5. Give each agent a different design constraint:

- Agent 1: "Minimize the interface — aim for 1-3 entry points max"
- Agent 2: "Maximize flexibility — support many use cases and extension"
- Agent 3: "Optimize for the most common caller — make the default case trivial"
- Agent 4 (if applicable): "Design around the ports & adapters pattern for cross-boundary dependencies"

Each sub-agent outputs:

1. Interface signature (types, methods, params)
2. Usage example showing how callers use it
3. What complexity it hides internally
4. Dependency strategy (how deps are handled — see [REFERENCE.md](REFERENCE.md))
5. Trade-offs

Present designs sequentially, then compare them in prose.

After comparing, give your own recommendation: which design you think is strongest and why. If elements from different designs would combine well, propose a hybrid. Be opinionated — the user wants a strong read, not just a menu.

### 7. User picks an interface (or accepts recommendation)

### 8. Create GitHub issue

Create a refactor RFC as a GitHub issue using `gh issue create`. Use the template in [REFERENCE.md](REFERENCE.md). Do NOT ask the user to review before creating — just create it and share the URL.
