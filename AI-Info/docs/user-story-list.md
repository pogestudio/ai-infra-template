# User-story backlog — index

The prioritised, traceable backlog `/ralph-prio` stocks and `/ralph-create-issues` consumes.
Stories live in per-track files under `user-story-list/` (one file per track, `track-NN-slug.md`);
this index only links them.

## Row format (inside track files)

```
- [ ] **P4.7** — As a <actor>, I want <goal>, so that <benefit>. · <value note> · → #—
  - ***Why:*** <one-line build/dependency rationale — never crammed into the story line>
```

- **ID** (`P4.7` = area/phase P4, story 7) is permanent and travels into the GitHub issue title.
- `→ #—` becomes `→ #<issue>` and `[ ]` becomes `[x]` when `/ralph-create-issues` creates the
  issue. The checkbox mirrors "issue created", **not** build/merge status.

## Tracks

| Track | File | Theme | Status |
|---|---|---|---|
| <!-- CUSTOMIZE: /ralph-prio appends one row per track it creates --> | | | |
