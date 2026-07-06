---
name: workflow-retro
description: Run a full AI workflow retrospective to identify patterns and improve dev-guide, workflow, and skills. Use when the user says "/workflow-retro", "let's do a retrospective", "what went wrong", "how can we improve the workflow", or after completing a feature or issue. Also use at end of day or when the user wants to review accumulated quick-workflow-retro notes. Do NOT use for quick mid-session captures — use quick-workflow-retro for that.
---

# Workflow Retrospective

Review AI workflow effectiveness and propose improvements to dev-guide, workflow, and skills. The goal is making the AI more useful in future sessions.

## Phase 1: Gather Context

Before interviewing, silently gather:

1. Read `AI-Info/workflow-retrospectives/retro-log.jsonl` for accumulated quick-retro notes
2. Read `AI-Info/workflow-retrospectives/retro-index.json` for known patterns and previous fixes
3. Skim the current conversation for evidence of friction (repeated tool calls, corrections from user, abandoned approaches)
4. Read `CLAUDE.md` and the docs under `AI-Info/` (e.g. `software-architecture.md`, `skills/how-to-TDD.md`) so you know what's already documented

**Filter already-processed entries.** Retro-log entries that have a `"processed_in"` field are already handled — exclude them from clustering in Phase 3. Only unprocessed entries feed into the interview.

## Phase 2: Review Past Improvements

**This phase is mandatory. Do NOT skip it.**

Read ALL files in `AI-Info/improvements/*.md`. This serves two purposes:

### 2a. Detect already-handled work

If there are recent `[pending]` entries from a previous workflow-retro session, cross-reference their **Symptom** fields with unprocessed retro-log entries. Retro-log entries whose symptoms are already covered by a pending improvement are effectively handled — skip them in the interview. Tell the user: "Last session addressed {N} clusters ({list}). {M} clusters remain."

### 2b. Evaluate past improvements (3+ days old only)

For each `[pending]` entry that is **3+ days old** (regardless of which tracker file it's in):

1. Check `retro-log.jsonl` for recurrences of the symptom since the change date
2. Briefly ask the user: "Last time we added {change} to fix {symptom} — has that been working?"
3. Don't belabor this — one question per pending item, move on

Skip entries newer than 3 days — not enough data yet. Update evaluated entries in Phase 7.

## Phase 3: Interview

Focus on **AI effectiveness and quality delivery**. Only present clusters from unprocessed, unhandled retro-log entries — if Phase 2a identified already-handled clusters, do not re-present them.

### Auto-start on highest impact

1. Rank clusters by severity: `blocked` > `slowed-down` > `minor`. Within a tier, prefer clusters with more entries or recurring patterns.
2. **Start immediately on the highest-impact cluster** — do not list all clusters and ask which to start with. The user wants to get through clusters efficiently, not review a menu.
3. **Work through ONE cluster at a time** — do not present multiple clusters in one message. After finishing one cluster (interview → propose → apply → commit), move to the next highest-impact cluster automatically.

### For each cluster

Present the **evidence** — which retro-log entries, what happened, what you observed in the conversation. Then ask genuine questions to understand the user's experience:

- How often does this happen? Every session or specific situations?
- What does the user end up doing as a workaround?
- Is there context you're missing about why this is hard?

**Do NOT propose fixes in this phase.** No "my read," no "the root cause is," no "the fix would be." That belongs in Phase 6. The interview is for understanding, not solving. If you catch yourself writing a solution, stop and turn it into a question instead.

Cover these areas, adapting based on what the retro notes and conversation show:

- **Where did the AI get stuck?** Wrong approach, missing context, misunderstood the codebase, fought with the FastAPI/SQLAlchemy or Vue APIs
- **What did you have to repeat or correct?** Instructions not followed, patterns it kept getting wrong
- **What took too many iterations?** Things that should have been straightforward
- **What context was missing?** Information that if present in CLAUDE.md or a skill would have saved time
- **Where did quality suffer?** AI delivered something that needed rework, missed edge cases, used wrong patterns
- **What went well?** Patterns worth reinforcing in the workflow docs

## Phase 4: Write the Retrospective

After the interview, create a retrospective file at:
```
AI-Info/workflow-retrospectives/YYYY-MM-DD-{feature-name}.md
```

Structure:
```markdown
# Retrospective: {Feature Name}
Date: {date}
Issue: #{issue number if applicable}

## What Went Well
- {pattern worth reinforcing, with specifics}

## What Struggled
- **{problem}**: {description}
  - Root cause: {missing context / wrong pattern / tooling gap / codebase unfamiliarity}
  - Severity: {blocked / slowed-down / minor}
  - Suggested fix: {specific change to a specific file}

## Patterns Detected
- {pattern seen 2+ times across retros — reference which retros}
- {new pattern from this session — note as "first occurrence"}

## Proposed Changes
- [ ] {file}: {specific change} — Evidence: {which observations drove this}
```

## Phase 5: Pattern Detection

Read ALL previous retrospective files in `AI-Info/workflow-retrospectives/`. Look for:

- **Recurring root causes** (seen 2+ times): These deserve a workflow/dev-guide change. Propose one.
- **One-offs**: Note them but don't act. They might be feature-specific.
- **Regressions**: A problem that was "fixed" in a previous retro but showed up again. The previous fix didn't work — propose a different approach.
- **Reinforcements**: Things that went well 2+ times. Make sure the pattern is documented so it persists.

## Phase 6: Propose and Apply Changes (Incremental)

Based on the interview and pattern detection, propose specific edits to:
- `CLAUDE.md` — new project-wide rules, gotchas, constraints
- `AI-Info/` docs (e.g. `software-architecture.md`, `skills/how-to-TDD.md`) — patterns, workflow, test approaches
- `AI-Info/skills/*` — improvements to skills

For each proposed change:
- Show the exact edit (not vague suggestions)
- Reference which retro observations drove it
- Wait for user approval before applying

**Process incrementally, per cluster.** After the user approves changes for each cluster:

1. Apply the changes and commit
2. Mark the retro-log.jsonl entries addressed by this cluster with `"processed_in": "YYYY-MM-DD-{retro-name}"`
3. Append an improvement entry to `AI-Info/improvements/workflow-retro.md`:
```markdown
## YYYY-MM-DD: {Short description} [pending]
- **Symptom**: {What problem this addresses}
- **Change**: {What was changed}
- **Files**: {Files modified}
```
4. Commit the retro-log and improvements tracker updates

This way, if the session ends mid-retro, completed clusters are persisted and the next session picks up only the remaining work.

## Phase 7: Update the Index

After all clusters are processed (or when ending the session), update `AI-Info/workflow-retrospectives/retro-index.json`:

```json
{
  "last_retro": "2026-03-25",
  "retro_count": 1,
  "patterns": [
    {
      "id": "pattern-001",
      "description": "AI reads config via os.getenv instead of the typed Settings object",
      "occurrences": ["2026-03-25-config-settings"],
      "status": "first-occurrence",
      "fix_applied": null
    }
  ],
  "changes_applied": [
    {
      "date": "2026-03-25",
      "file": "CLAUDE.md",
      "change": "Documented config single-source-of-truth",
      "driven_by": ["2026-03-25-config-settings"],
      "pattern_id": "pattern-001"
    }
  ]
}
```

When evaluating a past `[pending]` improvement entry (from Phase 2b), change `[pending]` to `[evaluated]` and add:
- **Evaluated**: {date}
- **Outcome**: {working | unused | ineffective | removed} — {brief explanation}

Keep the comment counter at the top of each improvements file updated: `<!-- pending: N  evaluated: M -->`

Immediately commit the retro-index.json and all modified improvements/*.md files after updating them (no user confirmation needed for retro file commits).

## Bootstrapping

If `retro-index.json` doesn't exist yet, create it with empty patterns and changes arrays. If `retro-log.jsonl` doesn't exist or is empty, that's fine — run the retrospective from conversation context alone.
