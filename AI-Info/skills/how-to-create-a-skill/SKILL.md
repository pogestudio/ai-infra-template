---
user-invocable: false
name: how-to-create-a-skill
description: Instructions for creating and improving reusable skills. Use when extracting a methodology into a skill, creating a new skill from scratch, or improving an existing skill's structure, description, or writing quality. Also use when the user says "turn this into a skill" or asks about skill best practices.
---

# How to Create a Skill

## What is a Skill?

A skill is a **self-contained piece of reusable knowledge or methodology** that can be used by multiple agents. It is NOT agent-specific instructions — those belong in the project's instruction files (`CLAUDE.md`, `AI-Info/`).

Examples:
- "Test-driven development: the red-green-refactor loop"
- "Breaking a PRD into vertical-slice issues"
- "Interviewing to stress-test a design"

## When to Extract a Skill

- Research contains **>500 words** on a single methodology
- A framework/template could be **used by multiple agents**
- The knowledge is **reusable** beyond one specific task or agent

If it's only relevant to one agent, it's an **instruction**, not a skill.

## Skill Anatomy

```
skill-name/
├── SKILL.md          (required, <500 lines)
├── references/       (docs loaded conditionally, for overflow)
├── scripts/          (executable utilities, invoked as black boxes)
├── examples/         (patterns and reference implementations)
└── assets/           (files used in output — templates, fonts, etc.)
```

Only `SKILL.md` is required. Add subdirectories when the skill needs them — most don't.

## Skill Format

```markdown
---
user-invocable: false
name: skill-name
description: [See "Writing the Description" below]
---

# Skill Title

[The actual methodology, framework, or knowledge]
```

- **YAML frontmatter** is required: `user-invocable` + `name` + `description`
- **Body** should be under **500 lines**. If approaching that, move detail to `references/` with clear pointers about when to read them
- Skill names use **kebab-case**
- **Naming convention:** Only core skills (e.g. `tdd`, `grill-me`) should be root-level commands. Non-core or seldom-used skills should be prefixed with `skill-` (e.g. `skill-heroku-deploy`, `skill-email-templates`) to avoid cluttering the command list

## Writing the Description

The description is the **primary triggering mechanism** — it determines whether Claude uses the skill. Undertriggering (not using a skill when it's relevant) is the most common problem. Write descriptions that are assertive.

**Formula:**
```
[SCOPE: "Use this skill when/any time..."]
[TRIGGERS: specific phrases, file types, keywords — formal AND casual]
[EDGE CASES: "Also use when...", "even if..."]
[NEGATIVES: "Do NOT use for..." to prevent false triggering on adjacent skills]
```

**Before (weak):**
> "Instructions for creating skills."

**After (strong):**
> "Instructions for creating and improving reusable skills. Use when extracting a methodology into a skill, creating a new skill from scratch, or improving an existing skill's structure, description, or writing quality. Also use when the user says 'turn this into a skill' or asks about skill best practices."

Include casual language users might actually say, not just formal terminology.

## Writing Style

**Explain the why, not just the what.** LLMs are smart — they follow reasoning better than rigid commands. If you find yourself writing ALWAYS or NEVER in all caps, ask: is this a hard technical constraint that will break things? If yes, keep it. If it's guidance, reframe with reasoning.

**Hard constraint (ALWAYS/NEVER is appropriate):**
> NEVER commit while a test is failing (RED) — it poisons `git bisect` for everyone after you.

**Guidance (explain the why instead):**
> Read the existing routers and services before adding an endpoint — they show the established FastAPI + SQLAlchemy patterns for auth, validation, and DB sessions, so you don't reinvent them.

**Other patterns:**
- Use examples that escalate in complexity (simple case first, then edge cases)
- Show negative examples when the wrong approach is tempting (Bad/Good comparisons)
- Match tone to the skill's domain: technical reference for APIs, collaborative for workflows

## Referencing Bundled Files

Use **conditional loading** so the AI reads files only when relevant, not upfront:

- **Task-conditional:** "If you need to fill a form, read `references/forms.md`"
- **Complexity-conditional:** "For advanced usage, see `references/advanced.md`"
- **Phase-conditional:** "During Phase 2, load `references/implementation.md`"

For scripts, treat them as black boxes: "Run `scripts/validate.py --help` for usage." Don't explain source code in the SKILL.md.

## Skill Location

```
AI-Info/skills/{skill-name}/SKILL.md
```

## Symlink for Auto-Discovery

After creating a skill, symlink it to `.claude/skills/` so Claude Code discovers it at session start:

```bash
ln -s "../../AI-Info/skills/{skill-name}" ".claude/skills/{skill-name}"
```

Source of truth remains `AI-Info/skills/`. The symlink gives Claude Code auto-discovery via YAML frontmatter.

## Update the Skills Index

After creating a skill, add it to the skills index at `AI-Info/skills/README.md` (create it if absent) under the appropriate category. Use the exact `description` from the SKILL.md frontmatter.

## Quality Criteria

- **Standalone**: makes sense without reading other files
- **Reusable**: useful to more than one agent or context
- **Actionable**: contains steps, templates, or frameworks — not just theory
- **Explains the why**: reasoning behind instructions, not just commands
- **Concise**: says what's needed, nothing more — but not at the cost of clarity
