---
name: ralph-tdd-plan
user-invocable: true
description: >
  Plan one Ralph-loop user story into a durable, checkbox implementation plan that survives
  SIGKILL restarts. Invoked by /ralph-tdd as the first step of a NEW issue (when no plan exists
  yet): fans out 3 subagents per fact-area to research the issue + codebase, reconciles and
  verifies their findings against the source, then writes
  AI-Info/implementation-plans/current/current-plan.md from the template. Do NOT use to build
  (that's /ralph-tdd) or to author issues (/ralph-prio, /ralph-create-issues).
---

# ralph-tdd-plan — plan one story so the plan survives restarts

The first step of a new issue is to carefully plan it so the plan survives restarts. The Ralph
loop SIGKILLs each iteration at its timeout and the next one starts with **zero carryover** — so
the checkbox plan on disk at `AI-Info/implementation-plans/current/current-plan.md` is the memory
of *what you decided to do* (the route + verified seams). *How far the build got* lives in git
history (each green slice is a `#<N> step k` commit on `ralph-loop`); the plan's ticks only mirror
it. Plan well once, and a restart resumes instead of re-deriving from a blank slate.

**Why you're here:** `/ralph-tdd` invoked you because no `current/current-plan.md` exists — a
fresh issue. Produce that plan, then end the iteration (step 5) — the *next* iteration builds from
it. **You plan; you do not write implementation code.**

## Process

1. **Read the contract.** `./ralph/ralph-fetch-issue.sh <ISSUE>` (full body + all comments in one non-TTY-safe call). Read its **References** — two docs, two jobs:
   **`AI-Info/architecture-spec.md`** is the *locked design authority* — its module map (§3) and
   locked decisions (§7) dictate **how this feature decomposes** (plan to it so the build doesn't
   grow god-objects). **`AI-Info/software-architecture.md`** maps the existing base-app seams you
   extend, not reinvent.
   Inherit the **Decision Log** verbatim: the plan is the *route*, not a re-litigation of decided questions.

2. **Fan out the research — one parallel batch.** A plan built from a single skim sends a
   faithful-but-wrong build down the wrong road; independent passes that *converge* are what let
   you trust a seam. Launch all of the following at once — they're independent:

   **Two triangulated fact-areas — 3 agents each.** These areas are *factual* (what the code
   already provides), so triangulation pays. Give the three agents the same objective and output
   schema but a **different entry point each**, and tell each to follow the thread through the
   *whole* area — the differing entry point is what decorrelates their mistakes; the whole-area
   sweep is what guarantees coverage (no agent stops at its entry point).
   - **Backend seams** — entry points (A) models/persistence, (B) routes/services, (C) existing
     tests + jobs/notifications. Each sweeps the backend for what already implements part of this
     story. <!-- CUSTOMIZE: name your backend's key dirs so agents know where to sweep. -->
   - **Frontend + architecture seams** — entry points (A) the API client layer,
     (B) the relevant component dirs + navigation model, (C) the relevant
     `software-architecture.md` section. Each sweeps the whole frontend + architecture surface
     from its entry point. <!-- CUSTOMIZE: name your frontend's key dirs/modules. -->
     **Skip this entire fact-area for `comm-test` issues** (the loop appends a note flagging them) —
     a backend-only behaviour-test issue has no frontend, so 3 agents here would burn budget for
     nothing; research the backend seams + the test harness the issue names instead.
     (Optional mechanism — only fires if you use the `comm-test` label.)

   Each research agent writes `…/current/research/<area>.agent<N>.md` — to a file, not back
   through your context, which avoids the game-of-telephone summarisation loss — in this schema:
   ```
   ## Candidate seams (reuse, don't rebuild)
   - <claim> · `file:line` · confidence high|med|low
   ## Already implements part of this story
   - <path> · <what>
   ## Gaps / couldn't confirm
   - <what I looked for and didn't find>
   ```

   **One light resume-state check** (a single agent, *not* triangulated — `git status` is
   deterministic, there's nothing to corroborate): report uncommitted changes, recent `ralph-loop`
   commits, and the issue's ticked acceptance criteria, in case a prior attempt left work behind.

   **One design-reference pass — UI stories only, skip backend-only** (single agent, like the resume
   check: `AI-Info/reference-projects/design-reference/` is authoritative, nothing to corroborate).
   Per its `README.md`, write `…/research/design-reference.md`: the prototype `file:line` to
   recreate and the styling to copy verbatim. (If the project has no design reference yet, report
   that gap into the research notes instead of inventing a design — see
   `AI-Info/reference-projects/README.md` for why one should exist.)

3. **Reconcile each fact-area — verify, don't vote.** One reconciler agent per area reads its 3
   reports and writes `…/research/<area>.reconciled.md`. Agreement across entry points is a strong
   *prior*, not proof — three agents on one codebase can share a hallucination. So for every
   **load-bearing** claim (a seam the plan will build on) the reconciler opens the file / greps the
   symbol and confirms it, carrying the `file:line` forward.
   - Bad — keep the seam two of three agents agreed on. (A majority vote propagates a shared
     hallucination, and a restart faithfully resumes the wrong route.)
   - Good — open the file at the cited line; keep the seam only if the symbol is really there.

   Output three buckets, so dropped hallucinations stay visible rather than silent: **Verified**
   (with `file:line`), **Single-source but verified anyway**, **Dropped (couldn't confirm)**.

4. **Synthesize the plan** to `AI-Info/implementation-plans/current/current-plan.md`, in the
   structure of `AI-Info/implementation-plans/current-plan-TEMPLATE.md`. This is main-thread work:
   the build *sequence* is interdependent design judgment, not a fact to triangulate.
   - Tag it `Issue: #<N>` so a later run can tell this issue's plan from a stale leftover — the
     picker also parses this tag to decide build-vs-plan and to detect claim↔plan drift, so keep the
     `Issue: #<N>` format exact.
   - Record the reconcilers' **Verified** seams *with their `file:line` anchors* and the inherited
     decisions, so the build doesn't re-discover them. Plan new tech only where no verified seam
     covers it — structure new modules per `AI-Info/architecture-spec.md` §3 (the module map),
     and for base-app extensions follow the "Adding a Feature" playbook in
     `software-architecture.md`.
   - Carry the reconcilers' **Dropped / couldn't-confirm** items into the plan's **Confirmed absent**
     line — negative knowledge ("we looked for X; it isn't there") that stops the build hunting for,
     or inventing, a seam that doesn't exist. This is the one useful thing the deleted research dir
     would otherwise take with it.
   - For UI stories, copy `…/research/design-reference.md` **verbatim** into the plan's **Design
     reference** section — the research dir doesn't survive the iteration, so the plan must carry it
     for the build.
   - Turn the acceptance criteria + E2E Test Plan into an **ordered checkbox step-list** — failing
     tracer e2e first, then inward (one test → one minimal implementation → repeat), then the
     issue's E2E Test Plan, then commit/push/PR. Keep steps small: a SIGKILL between two steps
     should cost one step, not the whole issue.

5. **End the iteration; the build comes next.** With the plan written, run
   `./ralph/ralph-loop-plan-done.sh` — it ends this iteration so the **next** one builds from a fresh
   context: the picker re-hands this same issue, `/ralph-tdd` finds the plan and executes it.
   Isolating planning (many subagents, lots of context) from the build gives each its own full
   budget; `ralph/ralph-loop.sh` grants plan-less iterations 1.5× the timeout (it keys off the picker's
   `MODE=plan`, emitted when no on-disk plan is tagged for the claimed issue) so the fan-out →
   reconcile waves have room. Do **not** call this if you're blocked (see Notes) — comment on the
   issue and stop instead.

## Notes

- The plan is gitignored — an on-disk scratchpad, not a deliverable. It survives a SIGKILL (the
  file stays on disk for the next iteration); `ralph/ralph-loop-done.sh` deletes it when the issue
  closes so the next issue re-plans from scratch.
- The **issue stays the spec.** If research shows the issue is underspecified or a dependency
  isn't built, don't plan around a guess — per `/ralph-tdd`'s autonomy contract, comment on the
  issue explaining the block and stop.
- **Never present an interactive prompt, menu, or choice** — no human is watching the loop, so a
  question hangs the iteration until SIGKILL. If something looks wrong (even "the data looks
  corrupted/spoofed"), re-check it with one command before believing it; if genuinely blocked,
  comment on the issue and stop.
