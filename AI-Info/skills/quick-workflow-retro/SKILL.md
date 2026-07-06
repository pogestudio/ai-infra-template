---
name: quick-workflow-retro
description: Capture a quick note about AI workflow friction or success mid-session. Use when the user says "/quick-workflow-retro", "retro note", "remember this for later", "that was painful", "that worked well", or wants to log something about AI effectiveness without doing a full retrospective. Also use when the user notices the AI going in circles, using the wrong approach, or missing context. Do NOT use for full retrospectives — use the workflow-retro skill for that.
---

# Quick Workflow Retro Note

Capture a brief observation about AI workflow effectiveness mid-session. This should take 30 seconds, not 10 minutes.

## Process

1. Read the user's note
2. If the note is clear enough, skip to step 4. If it's ambiguous, ask ONE clarifying question — no more
3. Based on the note and current conversation context, suggest a root cause (the user can correct you)
4. Tag the note with a category and phase
5. Append to `AI-Info/workflow-retrospectives/retro-log.jsonl`
6. Immediately commit the retro-log.jsonl change (no user confirmation needed)
7. Confirm with a one-line summary

## Categories

Tag each note with the most relevant category:

- **stuck**: AI couldn't make progress, went in circles
- **slow**: AI got there but took way too many iterations
- **wrong-approach**: AI used the wrong pattern, API, or architecture
- **missing-context**: Information that should have been in CLAUDE.md, a skill, or the AI-Info docs but wasn't
- **tooling-gap**: MCP tool limitation, dev-stack issue, test infrastructure gap
- **quality-issue**: AI delivered something that needed significant rework
- **worked-well**: Something went smoothly — capture so we can reinforce it

## Phases

Tag with phase if obvious (leave blank if not applicable):

`grill-me`, `prd`, `issues`, `tdd`, `implementation`, `refactor`, `architecture`, `debugging`, `testing`, `ui`, `deploy`

## Generalizing from specifics

When the user describes a specific incident, always extract the **general lesson** — the broader pattern that applies beyond this one case. Write the `note` field as the general principle first, then include the specific example as illustration. Do NOT narrow the lesson to only the specific case.

Ask yourself: "If this happened in a completely different feature area, what's the underlying mistake?" That's the general lesson.

Example:
- User says: "The bulk-delete button stayed enabled after the list was emptied"
- BAD note: "Bulk-delete button left enabled on an empty applications list"
- GOOD note: "Claude builds features in isolation without considering the complete end-to-end product flow — it doesn't think about what comes before and after. Example: the bulk-delete button stayed enabled after all applications were removed because Claude didn't consider the empty-list state."

## Log Format

Append one JSON object per line to `retro-log.jsonl`:

```json
{"date": "2026-03-25", "category": "wrong-approach", "phase": "implementation", "note": "General lesson first, then specific example. Claude read config via os.getenv in new code instead of the typed Settings object", "root_cause": "Config single-source-of-truth not documented in CLAUDE.md", "severity": "slowed-down"}
```

Severity levels: `blocked` (couldn't proceed), `slowed-down` (got there eventually), `minor` (small friction)

## NEVER act on the note

This skill is **log-only**. NEVER fix the problem, update CLAUDE.md, modify skills, read additional files, spawn agents, or start implementation based on the retro note. The only mutations allowed are appending to `retro-log.jsonl` and committing. Acting on notes happens later during a full `/workflow-retro` — not mid-session.

## Tone

Be brief. Don't turn this into a conversation. Capture the note, confirm, move on. The user is in the middle of work.
