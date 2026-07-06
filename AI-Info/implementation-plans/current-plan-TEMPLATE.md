# Implementation Plan — <issue title>

<!--
Per-issue route + progress mirror for the Ralph loop:
  • /ralph-tdd-plan writes this file (fresh issue, no plan yet).
  • /ralph-tdd commits each green step to `ralph-loop` and ticks it here as it builds.
  • ralph/ralph-loop-done.sh deletes it when the issue closes, so the next issue re-plans.
It is gitignored — a human-readable mirror, never the source of truth. The durable record of how
far the build got is git history (`#<N> step k` commits on ralph-loop); a restart resumes from
git log, not these ticks. Keep steps small so a restart mid-build loses at most one (committed) step.
-->

**Issue:** #<N> — <one-line title>
**Branch:** ralph-loop

## Findings — reconciled & verified; reuse, don't rebuild

Each seam carries a `file:line` anchor the reconciler confirmed by opening the file — a restart
resumes this route faithfully, so an unverified seam misroutes the whole build. No anchor = not a
finding.

- **Backend seam(s) to extend:** <seam — `file:line`; e.g. Notifier→Channel.SMS — backend/notifications/notifier.py:42>
- **Frontend seam(s) to extend:** <seam — `file:line`; e.g. api.kf client group — frontend/src/api/kf.js:18>
- **Architecture section:** <software-architecture.md §…>
- **Already implements part of this story:** <path:line, so you don't rewrite it>
- **Confirmed absent (don't assume these exist):** <symbols/files the reconciler searched for and didn't find — negative knowledge that stops the build hunting for, or inventing, a seam that isn't there>
- **Inherited decisions (from the issue's Decision Log):** <the ones that shape the build>

## Design reference — verbatim (UI stories; omit for backend-only)

<!-- /ralph-tdd-plan pastes research/design-reference.md here verbatim; the build recreates the UI from it. -->

## Steps

Tracer first, then inward (one test → one minimal impl → repeat). The moment a step is green,
commit it (`#<N> step k: …`) and tick `- [x]` here, before starting the next — the commit is the
checkpoint a restart resumes from; this tick only mirrors it.

- [ ] 1. Failing tracer e2e/journey test for <the user-visible outcome>
- [ ] 2. <test → minimal implementation>
- [ ] 3. <test → minimal implementation>
- [ ] 4. …
- [ ] 5. Run the issue's E2E Test Plan via Playwright MCP (DOM snapshots + screenshots)
- [ ] 6. Tick the issue's acceptance criteria; commit green with `#<N>` in the message; push to `ralph-loop` (on non-fast-forward: `git fetch` + `git pull --no-rebase` + resolve + re-green + retry); then `./ralph/ralph-loop-done.sh --issueDone <N>` (proof-of-work + green gate)

## Follow-up knowledge — for the next step / iteration

- <what the next step needs to know; open questions; exactly where you stopped>
