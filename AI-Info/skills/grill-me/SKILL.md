---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

If a question can be answered by exploring the codebase, explore the codebase instead.

## Before / during the interview

Search for existing patterns that solve the technical challenges in this design:

1. **In-repo patterns**: Search the codebase for prior art — `backend/` (FastAPI routes, SQLAlchemy models, services), `frontend/src/` (Vue components), and the current-architecture map in `AI-Info/software-architecture.md`. Grep for keywords related to the feature's core mechanics.
2. **Online references**: If no in-repo pattern covers a key technical challenge, web search the FastAPI / SQLAlchemy / Vue docs or GitHub repos that demonstrate the pattern.
3. **Document findings**: For each relevant pattern found, note: where it lives, which files, what pattern it demonstrates, and how it applies to the current design.

These findings feed directly into the PRD — they prevent the implementation phase from reinventing solutions that already exist in the codebase.

Skip this for quick one-offs or obvious implementations where the approach is clear.
