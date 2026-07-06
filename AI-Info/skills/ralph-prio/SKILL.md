---
name: ralph-prio
user-invocable: true
description: >
  Discover, map, and prioritise user stories into AI-Info/docs/user-story-list.md like
  a product manager — fanning out one subagent per product area to research the specs while
  the main thread ranks and picks the track with you. Use to load up the backlog with the next
  buildable set of stories — whenever you say "prioritise", "what should we build next",
  "ralph-prio", or the loop has run dry. Do NOT use to write GitHub issues (that's
  /ralph-create-issues) or to implement (that's /ralph-tdd).
---

# ralph-prio — product-manager pass over the backlog

This skill keeps `AI-Info/docs/user-story-list.md` stocked with prioritised, traceable
user stories. It is **always additive**: each run loads up *more* unplanned stories,
whether the backlog is empty or not.

It produces user stories only — never GitHub issues, never code. The next stage
(`/ralph-create-issues`) grills each story and emits the issue; the loop (`/ralph-tdd`)
builds it.

## Why this exists

When a feature area is large and its architecture is already decided, the risk is not
"what should we build" being unknown — it's the backlog drifting from the source specs,
or being sequenced badly so the loop builds things out of dependency order. This pass pins
the next coherent slice of value to its source and orders it for the loop.

<!-- CUSTOMIZE: list your project's source-of-truth spec documents here — the docs stories must
trace back to. Examples: workflow specs, a locked architecture spec, requirements inventories,
user walkthroughs, validated prototypes. Every phase agent in step 2 reads from this list. -->

## Process

1. **Map the current backlog — delegate the read.** Dispatch one subagent to read the index
   `AI-Info/docs/user-story-list.md` and the per-track files under
   `AI-Info/docs/user-story-list/`, and report back the already-tracked story **IDs** and which
   product areas / UX-flows are covered. Keep that map; don't pull all the track files into your
   own context — your budget is for ranking and the conversation with me. You dedup against those
   IDs (never duplicate one) — the ID check is the authoritative no-duplicate guard. Add new
   tracks as new files; existing rows are left alone.

2. **Source candidate stories — fan out by product area; the subagents read, you decide.** Decide
   which areas are in scope (from my ask plus the gaps the step-1 map revealed), then dispatch
   **one subagent per in-scope area**, in a single parallel batch — reading sources in your own
   context is what crowds out the PM judgment.

   Each area agent's job is to harvest **spec-supported-but-untracked candidate stories** from the
   source documents (see the CUSTOMIZE list above). It phrases each candidate as
   `As a <actor>, I want <goal>, so that <benefit>.` and returns it with a cross-ref ID proposal,
   a one-line dependency signal (what must ship first), a value signal, and a source `file:line`;
   it never edits the backlog.

   <!-- CUSTOMIZE (optional pattern): if you maintain an *atomized story inventory* — a
   spec-derived, per-area list of every possible story with a status legend (✅ built / 📋 queued /
   ⬜ GAP) — make the GAP rows the candidate menu and have agents re-mine the raw specs only when
   the inventory is stale. It keeps repeat runs cheap and dedup trivial. See the Klara originals
   in examples/klara/ for a worked version. -->

3. **Confirm each cross-ref ID.** The area agents propose these; you confirm each is unique against
   the step-1 map and ties to its source area, e.g. `P4.7` = the 7th story of area/phase P4. The ID
   is permanent and travels into the GitHub issue, so a story is always traceable back to its spec.

4. **Reconcile, then rank like a PM.** First consolidate the agents' returned candidates: drop any
   that dupe the step-1 ID map, and spot-check each **load-bearing dependency claim** (does the
   named blocker actually ship or sit queued?) — each agent reported from one read, and a wrong
   "unblocked" sequences a track too early. Then judge **where the most value is** and which are
   **suitable to build in track** now — readiness (are its dependencies already shipped or
   queued?), value to the actors, and risk. Honour your spec's build order if it defines one; the
   first delivered track should be a tracer bullet through the spine of the feature, not a
   peripheral slice.

5. **Pick the next track — a cohesive set of 3–4.** Prefer stories that **share a UX flow**
   so the loop builds a coherent journey, not scattered fragments. A track is the unit you hand to
   `/ralph-create-issues` next.

6. **Help me choose, then write the rows.** Present the proposed track with one-line value
   rationale and dependency notes; let me confirm or redirect. Then write the chosen rows as
   a **new track file** under `AI-Info/docs/user-story-list/` (one file per track —
   `track-NN-slug.md`, mirroring the existing names), in the row format the index documents —
   the **user-story line first** (`- [ ] **ID** — As <actor>, I want <goal>, so that <benefit>. · value · → #—`),
   then a concise indented ***Why:*** note beneath it carrying the build/dependency detail (never
   crammed into the story line) — and add one linking row to the index's **Tracks**
   table. A new track is a new file — never append to an existing track file or to a shared list.

7. **Save and commit — always.** Commit every change — the new track file, its Tracks-table row,
   and any source-doc reconciliation the pass required (e.g. an inventory row promoted, or a spec
   section that now contradicts the chosen track) — with a clear message. Never leave the backlog
   or edited docs as uncommitted changes.

## Output

A **new committed** track file under `AI-Info/docs/user-story-list/` (plus its row in the
index's Tracks table) — new prioritised rows, no GitHub issues, no code; plus any source-doc
reconciliation the pass required. Report which IDs you added, the track they form, and the commit.

## Hard rules

- **Never invent a story the specs don't support.** Ambiguity → ask me, don't guess. Every
  story traces to a source document.
- **Never duplicate** a story already in the backlog (check IDs first).
- The **locked spec wins.** Where the locked architecture/feature spec contradicts an older draft,
  follow the locked spec — read it there directly rather than trusting drafts or your memory.
- **Always commit your edits when done.**
