---
name: ralph-create-issues
user-invocable: true
description: >
  Grill the user on prioritised user stories, then create one loop-ready GitHub issue per
  story. Use after /ralph-prio has stocked AI-Info/docs/user-story-list.md, when you say
  "create issues", "grill me on the next track", or "ralph-create-issues". Do NOT use to
  discover/prioritise stories (that's /ralph-prio) or to implement them (that's /ralph-tdd).
---

# ralph-create-issues — grill → loop-ready GitHub issues

Takes a prioritised **track** of user stories from the backlog and turns each into a single
self-contained GitHub issue the headless loop can build with no further human input. There is
**no PRD**: the grill output is recorded **verbatim** in the issue so nothing is lost between
deciding and building.

## Why this exists

The original failure mode: a great grill, then a PRD that *summarised* the decisions and
dropped detail, so the TDD loop re-invented them. The fix is to (a) keep stories tiny, (b)
capture every grilled decision verbatim in the issue, and (c) **reference** the locked
architecture instead of paraphrasing it — because a fresh-context loop iteration only reads
the issue + the docs it points to.

A second, UX-specific failure mode: the mock already specifies every screen, but a quick
"covered the UX" grill skims it and the loop invents the states the design spelled out — so
step 3 walks the mock with the user, screen by screen, before the grill.

## Process

1. **Pick the next track.** Read the backlog index `AI-Info/docs/user-story-list.md` and the
   per-track files under `AI-Info/docs/user-story-list/`; take the next prioritised, un-issued
   stories (`→ #—`) — a track is one file. Confirm the set with me.

2. **Gather everything a ralph agent will need — fan out subagents.** In parallel:
   - **Scan the source specs** for each story's ID (its cross-ref points at the spec section),
     plus `AI-Info/architecture-spec.md` §7 (locked decisions) / §8 (build order).
     <!-- CUSTOMIZE: add your other spec docs — the same source-of-truth list as /ralph-prio. -->
   - Fire **multiple subagents to scan the codebase** for prior art — existing seams the
     story should reuse. <!-- CUSTOMIZE: name your key seams (persistence layer, notification
     service, auth, API client layer, shared UI models) so agents know what to look for. -->
   - Fetch related GitHub issues (`gh issue list`, `gh issue view`) so blockers can be linked.
   - **Find AND read the design for every UI story — it already exists and it's the spec.** In
     `AI-Info/reference-projects/design-reference/`, the `README.md` (+ `CLAUDE.md`) maps each
     screen to a prototype file and breaks it into per-state sub-sections with copy.
     Read the prototype file(s) + matching README section(s) **into context** — not just locate
     them — and list the screens/states this story touches, ready to walk through. Backend-only
     stories skip this.
     **If a UI story has no suitable design reference AND no existing in-app pattern to extend —
     FLAG IT, don't paper over it.** Tell me explicitly: which screens/states are un-designed,
     what the loop would have to invent, and that **UI design work needs to happen before the
     Ralph loop can successfully execute this story**. Do NOT create the issue for that story by
     default — park its backlog row and move on to the stories that are covered. (Only if I
     explicitly accept the risk after the flag do we pin the UX down from scratch in step 3 and
     proceed.)

3. **Walk the UI with me — one screen at a time (UI stories only).** The mock is the spec, but a
   fresh-context loop builds whatever UX you *didn't* pin down — so don't summarise the design to
   yourself, walk me through it. For each screen/state in the journey, **in order**, present
   straight from the prototype:
   - **what the user sees** — the layout and elements;
   - **the copy that matters** — exact labels/messages, in the product's language where the mock is;
   - **the success / empty / loading / error states** — the design doc's per-screen sub-sections
     are your state checklist; don't skip the unhappy paths.
   Then **stop and let me confirm or correct that screen before you move to the next** — I'm the
   one who catches what the mock leaves implicit. Each confirmed-or-corrected screen becomes a
   **verbatim Decision-Log entry**, and the set of screens you walk becomes the issue's exact
   **References** (both in step 5). Backend-only stories skip this and go straight to the grill.

4. **Grill me relentlessly across two dimensions — scoped to this track.** (UX is already pinned
   down in step 3's walkthrough.) Walk every branch of the decision tree; for each question give
   your recommended answer (this is `/grill-me` behaviour — invoke it or do the same inline). A
   fresh-context loop iteration builds *exactly* what you pin down and invents the rest — so
   resolve every decision it would otherwise guess, in **both**:
   - **User story** — who the user is, the job they're doing, and the "so that" payoff. Is it
     scoped to one journey? What does "done" mean *from their side*? Challenge the "As a… I
     want… so that…" itself; don't just accept the backlog wording.
   - **Tech** — data shapes, the seam to reuse, edge cases, and the mocks for external systems.
   Stop only when no branch in *either* is unresolved.

5. **Create one GitHub issue per user story.** `gh issue create --label agent-ready --title
   "<title>" --body-file <tmp>`. Title carries a recognisable token + the ID, e.g.
   `[Story P4.7] prospect self-books a viewing slot`. Each issue body, in this order:

   - **What to build** — one paragraph.
   - **Acceptance criteria** — a `- [ ]` checklist (the loop ticks these as it goes).
   - **E2E Test Plan** — lean heavily here. Numbered `mcp__playwright__browser_*` steps that
     ARE the user journey, a Setup line (`./scripts/dev-up.sh`, seeded login), a Visual gate (for
     UI stories, against the design reference), and a **"What Claude CANNOT verify"** section
     (real external services → mocked).
   - **Decision Log** — every grilled decision **verbatim**: `Q → chosen answer → why`. Not
     summarised. This is the anti-information-loss core of the skill.
   - **References** (links, not copies): the relevant `AI-Info/software-architecture.md`
     section(s), the locked spec (`AI-Info/architecture-spec.md` §…), and — for UI stories — the
     exact design-reference file + README section under
     `AI-Info/reference-projects/design-reference/` the build must recreate. The loop reads these
     for shared contracts.
   - **Mocks / fakes** the slice must use for any external boundary.
   - **Blocked by** — a paragraph of **only** the `#N` refs that must close first (dependency
     order, so the picker sequences correctly). The picker harvests *every* `#N` in this
     paragraph — keep other issue mentions out of it; write `_None._` when there are none.
   - **User story** — the **verbatim** "As a… I want… so that…", as the closing section.

6. **Write back the issue numbers + tick the row.** Update each row **in its track file** under
   `user-story-list/`: `→ #—` → `→ #N`, **and** flip its checkbox `- [ ]` → `- [x]`. Edit **only
   that one track file** — keeping each run inside one file is what stops concurrent runs from
   colliding. An `[x]` means "issue created on GitHub" (the at-a-glance mirror of `→ #N`) — this
   file does **not** track build/merge status, so tick at creation, not at ship.

7. **Commit and push.** Commit the backlog track-file edits (and any other changes from this run)
   and push to the remote, so the new issue and the updated backlog are durably shared.

## Output

One `agent-ready` GitHub issue per story (in dependency order so `Blocked by` can reference
real numbers), and the backlog rows updated with their issue numbers **and ticked `[x]`**.

## Hard rules

- **Capture decisions verbatim, never summarised** — the loop builds from the issue alone,
  and summarising is the exact bug this skill exists to kill (examples from a real project):
  - Bad — *"Decided to reuse the existing persistence layer for the new entity."*
  - Good (tech) — *"Q: where does Objekt persistence live? → A: a new `ObjektRepository(Repository[Objekt, ObjektCreate])` in `backend/kf/repositories.py`, writing via `uow.atomic()`. Why: the persistence fitness test forbids raw ORM outside `persistence/`."*
  - Good (UX) — *"Q: what does the prospect see right after booking a slot? → A: the slot list is replaced in place by a confirmation card showing the booked date/time plus a 'we'll text you a reminder' line; the booked slot then disappears for other prospects. Why: confirms success without a page nav and closes the door on double-booking."* — UX decisions from the step-3 walkthrough and user-story decisions get logged verbatim too, not just tech ones.
- **Reference the architecture, never copy it** — keep `software-architecture.md` the single
  source of truth; the issue links to it, the loop reads it. Copies go stale; links don't.
- **The design reference is the UX source of truth — every UI story's issue must point at it.**
  All designed UI lives in `AI-Info/reference-projects/design-reference/`; don't invent a screen
  the prototype already defines. Reference the exact file + README section (a link, not a copy —
  the build's `/ralph-tdd-plan` copies the `file:line` + styling verbatim), and make the E2E
  **Visual gate** compare against it. A UI story whose issue names no design-reference file
  isn't finished — and if no suitable reference or existing pattern exists at all, the story
  must be **flagged as needing UI design work first** (step 2), never quietly issued for the
  loop to improvise.
- The title token + `agent-ready` label + `Blocked by` paragraph are **parsed by
  `ralph/ralph-loop-pick-gh-user-story.sh`** — keep the format exact or the picker can't see the issue.
- **One issue = one user story.** If a story is too big for one loop iteration (~20 min build
  budget), split it into two stories with a `Blocked by` link.
- **Always commit your edits when done.**
