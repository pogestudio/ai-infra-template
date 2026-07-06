---
name: ralph-prio
user-invocable: true
description: >
  Discover, map, and prioritise KF user stories into AI-Info/docs/user-story-list.md like
  a product manager — fanning out one subagent per lifecycle phase to research the specs while
  the main thread ranks and picks the track with you. Use to load up the backlog with the next
  buildable set of stories — whenever you say "prioritise", "what should we build next",
  "ralph-prio", or the loop has run dry. Do NOT use to write GitHub issues (that's
  /ralph-create-issues) or to implement (that's /ralph-tdd).
---

# ralph-prio — product-manager pass over the KF backlog

This skill keeps `AI-Info/docs/user-story-list.md` stocked with prioritised, traceable
user stories. It is **always additive**: each run loads up *more* unplanned stories,
whether the backlog is empty or not.

It produces user stories only — never GitHub issues, never code. The next stage
(`/ralph-create-issues`) grills each story and emits the issue; the loop (`/ralph-tdd`)
builds it.

## Why this exists

The KF automation feature is large and its architecture is already **locked**. The risk is
not "what should we build" being unknown — it's the backlog drifting from the source specs,
or being sequenced badly so the loop builds things out of dependency order. This pass pins
the next coherent slice of value to its source and orders it for the loop.

## Process

1. **Map the current backlog — delegate the read.** Dispatch one subagent to read the index
   `AI-Info/docs/user-story-list.md` and the per-track files under
   `AI-Info/docs/user-story-list/`, and report back the already-tracked story **IDs** and which
   phases / UX-flows are covered. Keep that map; don't pull 23 track files into your own context —
   your budget is for ranking and the conversation with me. You dedup against those IDs (never
   duplicate one) — the ID check is the authoritative no-duplicate guard, so even a GAP row a prior
   run promoted but didn't flip to 📋 can't be re-offered. Add new tracks as new files; existing rows
   are left alone.

2. **Source candidate stories — fan out by phase; the subagents read, you decide.** Decide which
   lifecycle phases are in scope (from my ask plus the gaps the step-1 map revealed), then dispatch
   **one subagent per in-scope phase**, in a single parallel batch — reading sources in your own
   context is what crowds out the PM judgment.

   Each phase agent's job is to **harvest its section's ⬜ GAP rows** — the spec-supported-but-untracked
   stories `AI-Info/docs/user-stories-atomized/<phase>.md` already lists, which the atomized index calls
   the live "what to build next" menu. Those GAP rows are the candidate pool; promoting a cohesive track
   of them into the backlog is the whole point of this pass. The agent opens its **paired workflow spec**
   (same phase tag — e.g. `04-p4-booking.md` ↔ `4.spec-schedule-viewing.md`) only to confirm and phrase
   each GAP (`As a <actor>, I want <goal>, so that <benefit>.`) and to carry the locked-spec precedence —
   not to re-derive what the inventory already captured. It returns candidates with cross-ref ID, a
   one-line dependency signal (what must ship first), a value signal, and a source `file:line`; it never
   edits the backlog.

   Re-mine a phase's specs in full **only** when the atomized inventory is stale against them or doesn't
   cover my ask — then fold the newly-found stories back into that atomized section so the GAP menu stays
   the source of truth (step 7). Either way the reading happens in the subagent.

   The docs a phase agent reads:
   - `AI-Info/docs/user-stories-atomized.md` + the section files under
     `AI-Info/docs/user-stories-atomized/` — **the ⬜ GAP rows are the candidate menu** (the index
     explains the ✅/📋/⬜ legend).
   - `workflows-and-prototype-projects/workflow-documents/` — the workflow specs (`4.spec-*.md` =
     P1–P7 + S1), `11.flow_overview.md` (§8 build order), `7.requirements_inventory.md`,
     `13.raw-user-walkthrough.md`.
   - `workflows-and-prototype-projects/workflow-state-architecture/0.architecture-spec.md` — the
     **locked** spec; §7 (locked decisions) and §8 (first-build order) win over any older draft, and
     the superseded `drafts/` folder must not be mined — tell each agent so.
   - `workflows-and-prototype-projects/prototypes/` — what's already proven.

3. **Confirm each cross-ref ID.** The phase agents propose these; you confirm each is unique against
   the step-1 map and ties to its workflow phase, e.g. `P4.7` = the 7th story of phase P4
   (schedule-viewing). The ID is permanent and travels into the GitHub issue, so a story is always
   traceable back to its spec.

4. **Reconcile, then rank like a PM.** First consolidate the agents' returned candidates: drop any
   that dupe the step-1 ID map, and spot-check each **load-bearing dependency claim** (does the
   named blocker actually ship or sit queued?) — each agent reported from one read, and a wrong
   "unblocked" sequences a track too early. Then judge **where the most value is** and which
   are **suitable to build in track** now — readiness (are its dependencies already shipped
   or queued?), value to the actors (Malin/Lena/prospects/HG), and risk. Honour the §8
   tracer-bullet order (spine/detection → SMS dance → P7 close-out → overlays); the first
   delivered build is **Track 1** in the backlog (vacancy → one-click search → warm-up send),
   **not** a bare termination → board slice.

5. **Pick the next track — a cohesive set of 3–4.** Prefer stories that **share a UX flow**
   (e.g. the board-projection stories, or the start-search stories) so the loop builds a
   coherent journey, not scattered fragments. A track is the unit you hand to
   `/ralph-create-issues` next.

6. **Help me choose, then write the rows.** Present the proposed track with one-line value
   rationale and dependency notes; let me confirm or redirect. Then write the chosen rows as
   a **new track file** under `AI-Info/docs/user-story-list/` (one file per track —
   `track-NN-slug.md`, mirroring the existing names), in the row format the index documents —
   the **user-story line first** (`- [ ] **ID** — As <actor>, I want <goal>, so that <benefit>. · value · → #—`),
   then a concise indented ***Why:*** note beneath it carrying the build/dependency detail (never
   crammed into the story line) — and add one linking row to the index's **Tracks**
   table. A new track is a new file — never append to an existing track file or to a shared list.

7. **Save and commit — always.** Promoting a story is a **move**, so keep the inventory honest: when
   you write a backlog row for a GAP story, flip that story's atomized row **⬜ GAP → 📋** and change its
   parent citation from `GAP` to the story's cross-ref ID + `→ #—` — it now maps to a backlog row, so by
   the inventory's own legend it is no longer a gap (match the row format already in
   `user-stories-atomized/<phase>.md`). A story a re-mine turned up that the inventory lacked gets a new
   row there too — 📋 if you promoted it, ⬜ GAP if you left it for later — so the inventory stays the
   complete map. These edits stay inside the one phase section, so they rarely collide. Then **save and
   commit every change** — the new track file, its Tracks-table row, the touched atomized section(s), and
   any other source-doc reconciliation the pass required (e.g. a spec section that now contradicts the
   chosen track) — with a clear message. Never leave the backlog or edited docs as uncommitted changes.

## Output

A **new committed** track file under `AI-Info/docs/user-story-list/` (plus its row in the
index's Tracks table) — new prioritised rows, no GitHub issues, no code; plus any source-doc
reconciliation the pass required. Report which IDs you added, the track they form, and the commit.

## Hard rules

- **Never invent a story the specs don't support.** Ambiguity → ask me, don't guess. Every
  story traces to a workflow doc.
- **Never duplicate** a story already in the backlog (check IDs first).
- The **locked spec wins.** Where `0.architecture-spec.md` §7 contradicts an older draft or
  slice doc (e.g. the D8 data-model decision), follow §7 — read it there directly rather than
  trusting the `drafts/` or your memory.
- **Always commit your edits when done.**
