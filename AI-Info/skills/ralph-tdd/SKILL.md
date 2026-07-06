---
name: ralph-tdd
user-invocable: true
description: >
  Autonomous, single-user-story TDD for the Ralph loop. Invoked per issue by ralph/PROMPT-tdd.md as
  `/ralph-tdd <ISSUE>`. Implements one agent-ready story issue end-to-end — prior-work check,
  red-green-refactor, and Playwright e2e — with no human present. Do NOT use for authoring
  (that's /ralph-prio and /ralph-create-issues).
---

# ralph-tdd — build one user story, headless

Builds exactly one user-story issue inside the Ralph loop on the single `ralph-loop` branch.
The issue is the contract: it carries the acceptance criteria, the e2e journey, the verbatim
decision log, and links to the locked architecture. Read it, build it, prove it, advance.

**Plan before you build; commit every green slice.** The loop SIGKILLs each iteration and the next
starts with zero carryover, so **git history on `ralph-loop` is the durable record of how far you
got** — each green slice is its own committed checkpoint, and a restart reads `git log` to resume.
The checkbox plan on disk (`AI-Info/implementation-plans/current/current-plan.md`) is the *route* —
the decided steps and verified seams — and a human-readable mirror of progress; it's gitignored, so
it is never the source of truth for what landed. The first step of a new issue is to plan it well.

**You are an orchestrator — delegate, don't do.** You run on Opus with a 1M-token context so you can
hold the whole plan and coordinate many small, cheap Sonnet workers. Spawn **one subagent per
area/task** — a single plan step, or one tightly-coupled test+implementation pair — and **never hand
one subagent a span of steps** (that blows a worker's context and strands the build if it SIGKILLs
mid-way). Each worker reports back terse — what changed, test status, `file:line` — so *your* context
stays lean; you verify, tick the plan, and dispatch the next. Independent work (prior-work scan,
research, unrelated components) fans out in parallel; a sequential test→impl chain goes one step at a
time. The e2e journey is delegated to a subagent too, but always a *single* one — the browser is a
shared instance, so never parallel drivers (see step 4).

## Autonomy contract (no human is present)

- The **issue is the spec.** Decide and proceed — never wait for confirmation, never ask the
  user a question, and **never present an interactive prompt, menu, or multiple-choice question**:
  no human is watching the loop, so it just hangs the iteration until SIGKILL. Never invent a
  pattern the architecture doesn't already sanction.
- If you are **genuinely blocked** (issue underspecified, a dependency isn't built, a decision
  truly can't be inferred), write a comment on the issue explaining the block and stop — do
  **not** guess your way forward or mark the work done.
- The TDD knowledge files in this skill's directory apply unchanged: `tests.md`, `deep-modules.md`,
  `interface-design.md`, `mocking.md`, `refactoring.md`, and
  `AI-Info/skills/how-to-TDD.md` for concrete test patterns.
- Run the whole suite with `./scripts/run-tests.sh` (the project's single green-gate — it must exit 0 only when every suite passes) — the gate `ralph/ralph-loop-done.sh` enforces; for tight red-green cycles run the single target test directly per `how-to-TDD.md`.

## Process

1. **Read the contract.** `./ralph/ralph-fetch-issue.sh <ISSUE>` (full body + all comments in one non-TTY-safe call). Read its **References** — two docs, two jobs:
   **`AI-Info/architecture-spec.md`** is the *locked design authority* — its module map (§3) and
   locked decisions (§7) dictate **how this feature decomposes** (build to it so you don't grow
   god-objects). **`AI-Info/software-architecture.md`** maps the existing base-app seams you
   extend, not reinvent.
   Inherit decisions from the **Decision Log** — do not re-derive them.

2. **Plan first.** Check for `AI-Info/implementation-plans/current/current-plan.md`.
   - **No plan:** invoke **`/ralph-tdd-plan <ISSUE>`**. It writes the plan and **ends this
     iteration** (via `ralph/ralph-loop-plan-done.sh`) — you do *not* build in the same turn you plan.
     The next iteration re-picks this issue, lands in the "Plan exists" branch below, and builds.
   - **Plan exists** (the normal build entry — planning just handed off, or you're resuming a
     SIGKILL'd build): **trust the plan's already-verified `file:line` anchors — don't re-open the
     cited files to re-verify them or re-run the research fan-out; a wrong anchor surfaces as a fast
     red test.** Find where to resume from **`git log` on `ralph-loop`, not the checkboxes**: each
     `#<ISSUE> step N` commit is a slice that truly landed (the plan's ticks are only a mirror and
     may lag a SIGKILL). Resume from the first step with no such commit, and read a cited file only
     when you're about to edit it. **If the tree is dirty, it's the half-done slice the last
     iteration was SIGKILLed mid-way through** — inspect it, then either finish + commit it or
     `git checkout -- .` to discard it and re-run that one step; never build on top of an
     uncommitted slice you don't recognise. If the plan's `Issue: #N` ≠ <ISSUE>,
     it's a claim↔plan drift (the plan on disk belongs to another issue): don't inline-delete — hand
     off to `./ralph/ralph-issue-drift.sh <ISSUE> <plan-issue>`, which logs the drift, unclaims this
     loop's label, clears the plan, and ends the iteration so a clean restart re-plans <ISSUE>.

3. **Tracer bullet, then the incremental loop — one subagent per step.** Work the plan's steps in
   order, dispatching **a separate subagent for each step** (or one tightly-coupled test+impl pair):
   the failing tracer e2e first, then inward — one test → one minimal implementation → repeat. Do
   **not** give one subagent a run of steps. Between handoffs *you* run the targeted test to confirm
   green, then **commit that slice atomically — `#<ISSUE> step N: <desc>` — and tick its checkbox,
   before dispatching the next** (the commit is the durable checkpoint a restart resumes from; the
   tick just mirrors it). Never refactor while red; never commit while red. Build supporting "tech"
   (models, repositories, jobs, endpoints,
   components) as needed to enable the story, always behind the existing seams. For a UI surface,
   build from the plan's **Design reference** section — copy the sanctioned styling verbatim and
   recreate the referenced prototype's behaviour, don't improvise it. The prototypes live in
   `AI-Info/reference-projects/design-reference/` (see its README — the validated design is the
   UX spec).

4. **E2E the user journey — dispatch ONE subagent to drive it; don't drive Playwright yourself.**
   **Skip this whole step for `comm-test` issues** (the loop appends a note flagging them) — a
   backend-only behaviour-test issue has no browser journey; it's proven by the test harness named
   in the issue, not Playwright. (Optional mechanism — only fires if you use the `comm-test` label.)
   Delegating keeps the token-heavy DOM snapshots and console logs out of *your* context, and the
   browser is a single shared instance, so exactly **one** e2e subagent runs at a time (never fan out
   parallel browser drivers — they'd fight over the one browser). Hand that subagent a self-contained
   brief; it holds the mechanics, you don't:
   - **Journey:** the issue's **E2E Test Plan** — the steps to exercise and the acceptance criterion
     each one proves.
   - **Stack:** `./scripts/dev-up.sh` is up; log in with the seeded dev credentials
     <!-- CUSTOMIZE: your seeded dev login, e.g. admin@example.test / password --> ; navigate to
     `http://localhost:$FRONTEND_PORT` where `FRONTEND_PORT = <base port> + ${RALPH_LOOP_ID:-0}`
     <!-- CUSTOMIZE: your frontend base port, e.g. 5173 --> — this loop's own port, so compute it
     and never hardcode the base (concurrent loops would collide).
   - **How to assert:** prefer machine-checkable `browser_snapshot` DOM assertions over screenshot
     eyeballing; capture screenshots to the configured output dir for the visual gate; mock
     external boundaries (payments/LLM/calendar/notifications) per the issue.
   <!-- CUSTOMIZE: if your app writes structured logs at its external seams (LLM calls, webhooks),
   add a bullet telling the subagent where to look when an assertion fails and the DOM doesn't
   say why. -->
   - **Report back terse:** per-criterion PASS/FAIL, the snapshot assertions checked, the screenshot
     paths, and any console errors — raw outcomes only (if a capture fails, say so; never describe an
     imagined render). The subagent does **not** decide the story is done.
   *You* read the report, judge it against the acceptance criteria, and tick them (step 5). Re-drive
   Playwright yourself **only** as a fallback — if the subagent reports it can't reach the Playwright
   MCP tools.

5. **Track progress on the issue.** Tick each acceptance criterion `- [ ]` → `- [x]` via
   `gh issue edit` as it's satisfied.

6. **Push, hand back to the loop.** Your green slices are already committed (step 3) — each
   conventional-commit, atomic, and green, with `#<ISSUE>` in the message — so those commits on
   `origin/ralph-loop` are the done-gate's proof-of-work (digit-bounded, so #17 ≠ #170); commit any
   last changes (e.g. the acceptance-criteria ticks) the same way. There is **no PR**. Push to
   `ralph-loop`; on a non-fast-forward (a concurrent loop pushed first) don't force or `--abort` —
   `git fetch`, `git pull --no-rebase origin ralph-loop`, resolve conflicts in-tree, re-green with
   `./scripts/run-tests.sh`, and retry the push (≤5 attempts); if it still won't land, comment on
   the issue and stop. Then `ralph/PROMPT-tdd.md` runs `./ralph/ralph-loop-done.sh --issueDone
   <ISSUE>`, which **gates on the proof-of-work commit on `origin/ralph-loop` plus a green suite**
   before closing the issue, releasing this loop's `claimed-ralph-<id>` label, and clearing
   `current-plan.md`.

## Hard rules

- **Never commit while RED** (poisons `git bisect`); each commit passes the touched tests.
- **Never rewrite what already exists** — the fresh-work subagents exist to prevent this
  (illustrative example from a real project):
  - Bad — write a fresh SMS-sending helper inside the new feature's module.
  - Good — extend the existing `Notifier` / `TwilioTransport` seam in `backend/notifications/`;
    it already routes `Channel.SMS`.
- **Never mark done on red or unverified work** — `ralph/ralph-loop-done.sh` re-runs the suite (and
  requires the proof-of-work commit on `origin/ralph-loop`), but don't lean on it; a half-done slice
  that advances corrupts the queue.
- **Stay on `ralph-loop`** — one branch for the whole run; never switch branches.
