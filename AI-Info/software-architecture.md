# Software architecture — current map

<!-- CUSTOMIZE: this file is load-bearing for the whole Ralph pipeline. /ralph-tdd-plan's research
agents read it to find seams; /ralph-create-issues links issues to its sections; /ralph-tdd builds
against it instead of inventing new patterns. Keep it a MAP of what exists (modules, seams,
extension playbooks), not aspirational design.

Suggested sections (mirror what worked on Klara):

## Module map
One paragraph + diagram per top-level module: what it owns, what it must never do.

## Key seams (extend these, don't reinvent)
For each seam — persistence/repository layer, auth, notifications/external transports, API client
layer, shared UI models — one subsection: where it lives (file paths), how to extend it, one
example extension.

## Adding a feature — the playbook
The ordered steps a new feature follows through your layers (model → repository → service →
route → API client → component), each with a "copy this existing example" pointer.

## Locked decisions
Numbered decisions that are settled. Issues reference these by number so the loop never
re-litigates them.
-->
