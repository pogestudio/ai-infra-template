# Skills Index

Skills live in `AI-Info/skills/<name>/SKILL.md` (the source of truth) and are symlinked into
`.claude/skills/` so Claude Code discovers them at session start. Externally-vendored skills live
in `.agents/skills/` (tracked in `skills-lock.json`) and are symlinked the same way. Invoke a
user-invocable skill as `/<name>`.

## Ralph user-story loop — build the product one story at a time

The autonomous build pipeline. **Authoring is human-present; implementation is headless.** You
run the two authoring skills; then `ralph/ralph-loop.sh` chugs through the resulting GitHub
issues unattended.

| Skill | Phase | What it does |
|---|---|---|
| `/ralph-prio` | author (you) | Discover + prioritise user stories into `AI-Info/docs/user-story-list.md`. Additive, PM-style, in cohesive tracks of 3–4 sharing a UX flow. |
| `/ralph-create-issues` | author (you) | Grill on a prioritised track, then create one loop-ready GitHub issue per story — verbatim decision log + heavy Playwright e2e plan + references to the locked architecture. |
| `/ralph-tdd` | build (loop) | Autonomous single-story TDD inside the loop — plans first (`/ralph-tdd-plan`), then fires subagents for red-green-refactor and e2e. Invoked per iteration by `ralph/PROMPT-tdd.md` (build) / `ralph/PROMPT-plan.md` (plan). Its directory also carries the TDD knowledge files (`tests.md`, `deep-modules.md`, `interface-design.md`, `mocking.md`, `refactoring.md`). |
| `/ralph-tdd-plan` | build (loop) | First step of a NEW story: fans out 3 subagents per fact-area to research, reconciles and verifies findings against the source, then writes the durable checkbox plan to `AI-Info/implementation-plans/current/current-plan.md`. Invoked by `/ralph-tdd`. |

**Loop infra (`ralph/`):** `ralph-loop.sh` (runner — MODE-driven prompt + timer) ·
`ralph-loop-pick-gh-user-story.sh` (pick AND CLAIM — resume my per-loop `claimed-ralph-<id>`
label else claim the lowest open unclaimed `agent-ready` story with blockers closed) ·
`ralph-loop-done.sh` (proof-of-work + green-gated close, releases the claim) ·
`ralph-issue-drift.sh` (claim↔plan drift handler) · `PROMPT-plan.md` / `PROMPT-tdd.md` (the two
per-iteration prompts). Loops run concurrently from up to 4 clones keyed by `RALPH_LOOP_ID`. The
backlog `AI-Info/docs/user-story-list.md` is the roadmap *above* the GitHub-issue queue.

## Working practice

| Skill | What it does |
|---|---|
| `/grill-me` | Interview the user relentlessly to stress-test a plan until shared understanding. |
| `/systematic-debugging` | Disciplined debugging before proposing fixes (vendored). |
| `/security-review` | AI security scan of the codebase (vendored). |
| `/improve-codebase-architecture` | Find architecture improvements; deepen shallow modules (vendored). |
| `/workflow-retro` | Full AI-workflow retrospective; folds in accumulated quick notes. |
| `/quick-workflow-retro` | One-line mid-session capture of AI-workflow friction/success. |
| `/how-to-create-a-skill` | Create/improve skills. |
| `/how-to-write-ai-instructions` | Write instruction files Claude actually follows. |

## Reference docs (not slash-skills)

`how-to-TDD.md` (concrete test patterns — CUSTOMIZE for your stack) ·
`how-to-write-claude-md.md` · `how-to-write-modular-code.md`
