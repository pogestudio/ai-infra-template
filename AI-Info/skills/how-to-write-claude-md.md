# How to Write a Good CLAUDE.md

Reference: [Kyle Mistele's blog post](https://blog.humanlayer.dev/writing-a-good-claude-md/) (November 25, 2025)

Also applicable to AGENTS.md for other harnesses (OpenCode, Zed, Cursor, Codex).

## Core Principle: LLMs Are Stateless

LLMs know nothing about your codebase at session start. CLAUDE.md is the only file that goes into every conversation by default. This means:

1. Agents start each session with zero codebase knowledge
2. Important info must be provided each time
3. CLAUDE.md is your onboarding mechanism

## What CLAUDE.md Should Cover

| Aspect | Purpose |
|--------|---------|
| **WHAT** | Tech stack, project structure, codebase map. Critical for monorepos. |
| **WHY** | Project purpose, what different parts do |
| **HOW** | How to work on the project (e.g., use bun vs node), verify changes, run tests |

## Why Claude Ignores CLAUDE.md

Claude Code injects this system reminder with your CLAUDE.md:

```
<system-reminder>
IMPORTANT: this context may or may not be relevant to your tasks.
You should not respond to this context unless it is highly relevant to your task.
</system-reminder>
```

Claude will ignore content it deems irrelevant. The more non-universal content you add, the more likely it ignores everything.

## Best Practices

### 1. Less Instructions = Better Results

Research findings:
- Frontier thinking LLMs follow ~150-200 instructions reliably
- Smaller models degrade exponentially; larger models degrade linearly
- LLMs bias toward prompt peripheries (beginning and end)
- **More instructions = uniform degradation across ALL instructions**

Claude Code's system prompt already contains ~50 instructions. That's potentially 1/3 of your instruction budget before you add anything.

**Target: As few instructions as possible, only universally applicable ones.**

### 2. Keep It Short and Universal

- General consensus: **<300 lines**, shorter is better
- Only include content applicable to EVERY session
- Avoid task-specific instructions (e.g., "how to structure database schemas")

Example: HumanLayer's root CLAUDE.md is <60 lines.

### 3. Use Progressive Disclosure

Instead of inlining everything, point to separate files:

```
agent_docs/
  |- building_the_project.md
  |- running_tests.md
  |- code_conventions.md
  |- service_architecture.md
```

In CLAUDE.md, list these files with brief descriptions. Claude reads them when relevant.

**Prefer pointers to copies.** Don't include code snippets—they become stale. Use `file:line` references instead.

### 4. Don't Use Claude as a Linter

- Linters are fast and deterministic; LLMs are slow and expensive
- Style guidelines bloat context and degrade instruction-following
- LLMs are in-context learners—they'll follow patterns from your codebase

Better approaches:
- Use auto-fixing linters (e.g., Biome)
- Set up Claude Code hooks to run formatters
- Create slash commands for style checking (separate from implementation)

### 5. Don't Auto-Generate CLAUDE.md

CLAUDE.md is the highest-leverage file in your system:

```
Bad CLAUDE.md line
  → Bad research
    → Bad plan
      → Bad implementation (many bad lines)
```

Every line affects every session. Craft it carefully—don't use `/init` or auto-generation.

## Summary

| Principle | Action |
|-----------|--------|
| Onboard Claude | Define WHAT, WHY, HOW |
| Less is more | Minimize instruction count |
| Universal only | No task-specific content |
| Progressive disclosure | Point to docs, don't inline |
| Not a linter | Use deterministic tools |
| High leverage | Hand-craft, don't auto-generate |
