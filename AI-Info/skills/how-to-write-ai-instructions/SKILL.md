---
user-invocable: false
name: how-to-write-ai-instructions
description: How to write effective instruction files that Claude actually follows — CLAUDE.md, the AI-Info docs, skills, memory, or any markdown injected into LLM context. TRIGGER when writing, editing, or reviewing any .md file whose purpose is to guide AI behavior. Also trigger BEFORE adding lessons learned, gotchas, or rules to any context file. Do NOT trigger for user-facing documentation like READMEs or changelogs.
---

# How to Write AI Instructions

Applies to any file injected into Claude's context: CLAUDE.md, the AI-Info docs, skill SKILL.md files, memory files, agent definitions, and custom instructions.

## Core Insight: Explain the Why

LLMs are strong reasoners. They follow reasoning better than rigid commands. When Claude understands *why* a rule exists, it can apply judgment in edge cases instead of blindly following or ignoring the rule.

**Rigid (fragile):**
> ALWAYS use an absolute path for the SQLite database. NEVER use a relative one.

**With reasoning (robust):**
> Anchor the SQLite file path to `backend/` rather than the current working directory — uvicorn, pytest, and the seed script each launch from a different CWD, so a relative path silently opens a different database file for each. This applies to any path resolved at import time.

Reserve ALWAYS/NEVER for hard technical constraints where violating them *breaks things* (data loss, crashes, desync). For guidance and best practices, explain the reasoning so Claude can adapt when context shifts.

This principle comes directly from Anthropic's own skill-writing guidance: "If you find yourself writing ALWAYS or NEVER in all caps, that's a yellow flag — reframe with reasoning."

## Instruction Budget

Claude follows roughly 150-200 instructions reliably per context window. More instructions = uniform degradation across ALL of them — not just the new ones. Claude Code's system prompt already uses ~50 of that budget.

Implications:
- Every line in a shared file (CLAUDE.md) costs every session, even irrelevant ones
- Only include content applicable to EVERY session using that file
- Task-specific instructions belong in separate files, loaded conditionally
- When adding a rule, ask: "Does removing this cause concrete harm?" If not, cut it

## What Goes Where

Different files serve different purposes. Putting content in the wrong file wastes instruction budget or hides critical information.

| File | Purpose | Scope | Example |
|------|---------|-------|---------|
| **CLAUDE.md** | Hard project constraints, tech stack, file layout | Every session | "Backend runs on SQLite locally, MySQL in production" |
| **dev-guide.md** | Workflow practices, patterns, gotchas | Development sessions | "Anchor SQLite paths to backend/ so CWD doesn't change which DB you open" |
| **testing-strategy.md** | Test commands, patterns, infrastructure | Testing sessions | "Run pytest before committing; both suites use SQLite" |
| **Skill SKILL.md** | Reusable methodology for a specific domain | When skill triggers | "How to break a PRD into vertical-slice issues" |
| **Memory** | User preferences, project state, external references | When relevant | "User prefers bundled PRs for refactors" |
| **CLAUDE.md (root)** | Pointers to the above files | Every session | "Read AI-Info/skills/how-to-TDD.md before writing tests" |

**Decision test:** Will this help in *every* session that loads this file? If yes, add it there. If only sometimes, put it in a more specific file and point to it.

## Structure and Formatting

### Use Progressive Disclosure

Don't inline everything. Point to separate files with brief descriptions — Claude reads them when relevant.

```markdown
# Good: pointer with context
Read `AI-Info/skills/how-to-TDD.md` before writing or running tests.

# Bad: duplicating content
Here are all 47 test commands and their flags...
```

Prefer pointers to copies. Duplicated content goes stale when the source changes.

### Choose Structure to Match Content

**Markdown headers** work well for most instruction files — dev-guides, testing strategies, skills. They're scannable and nest naturally.

**XML tags** work well for CLAUDE.md and agent definitions where you need hard semantic boundaries between sections. LLMs treat XML tags as reliable delimiters, and they survive context compression better than headers.

```xml
<!-- CLAUDE.md — XML tags for clear boundaries -->
<purpose>What this project does</purpose>
<rules>Hard constraints that apply every session</rules>
<files>Key paths and what they contain</files>
```

```markdown
<!-- dev-guide.md — Markdown headers for scannable reference -->
## Local Setup
Run `./scripts/dev-up.sh` to seed the dev user and start backend (:8000) + frontend (:5173)...

## Before Committing
Run the backend suite: `backend/venv/bin/python -m pytest backend/tests`...
```

This isn't a universal rule — use whatever makes the content clearest. The point is that structure should serve scannability, not dogma.

### Tables for Decision Frameworks

When Claude needs to choose between options, a table or decision tree is faster to parse than prose:

```markdown
| Situation | Use |
|-----------|-----|
| New reusable methodology | Skill |
| Project-wide constraint | CLAUDE.md |
| Session-specific gotcha | dev-guide.md |
```

## Writing Principles

### Be Concrete, Not Abstract

**Abstract (hard to follow):**
> Ensure proper error handling in network code.

**Concrete (actionable):**
> Wrap the SMTP send in try/except — `smtplib` raises on an auth failure or a refused recipient, and an uncaught exception turns one failed email into a 500 for the whole bulk-send.

### Show Negative Examples When the Wrong Path is Tempting

```markdown
# Bad: == leaks timing info, letting an attacker guess the key byte-by-byte
if x_api_key == EXTERNAL_API_KEY:

# Good: constant-time comparison
if secrets.compare_digest(x_api_key, EXTERNAL_API_KEY):
```

Bad/Good comparisons are high-leverage because they preempt the exact mistake Claude would make.

### Keep It Short

If you can say it in one sentence, don't use three. Avoid:
- Restating what the heading already says
- Explaining obvious things ("This is important because...")
- Summary sections that repeat the content above

Every line should teach something new or constrain behavior in a way that prevents real mistakes.

### Don't Auto-Generate Context Files

Every line affects every session. Bad context cascades: bad rule leads to bad research leads to bad implementation. Hand-craft these files. Review additions critically — a wrong rule is worse than no rule.

### Don't Use Instructions as Linters

Style rules (naming conventions, formatting, import order) bloat context and degrade instruction-following. LLMs learn style from your codebase examples. Use deterministic tools (linters, formatters, pre-commit hooks) for style enforcement — they're more reliable and don't cost instruction budget.

## When Writing a Skill

If the instruction file you're writing is a skill (SKILL.md), also read `how-to-create-a-skill` for the required format, frontmatter, description-writing formula, file structure, and symlink setup. This file covers *writing quality*; that skill covers *skill-specific structure*.

## Quality Checklist

Before committing changes to any instruction file:

- [ ] Every rule has a *why* (or is a hard technical constraint)
- [ ] No duplicated content — pointers instead of copies
- [ ] Nothing task-specific in a shared file
- [ ] Concrete examples where the wrong approach is tempting
- [ ] No style rules that a linter could enforce
- [ ] Removing any line would cause concrete harm
