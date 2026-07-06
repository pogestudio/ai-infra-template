# Reference projects

Validated prototypes and reference implementations live here. On Klara this directory turned out
to be **crucial for UI work and extremely helpful for architecture questions** — treat it as a
first-class part of the setup, not an optional extra.

## Why it matters

- **UI: the design reference IS the UX spec.** A fresh-context loop iteration builds whatever UX
  you didn't pin down. A validated prototype pins down every screen, state, and label — so
  `/ralph-create-issues` walks it screen-by-screen with you, issues link to the exact prototype
  file + README section, `/ralph-tdd-plan` copies its `file:line` + styling into the plan
  verbatim, and `/ralph-tdd` recreates it instead of improvising. A UI story with no
  design-reference pointer is an invitation for the loop to invent screens.
- **Architecture: prototypes answer "how should this work?"** When a seam or flow is ambiguous,
  a working prototype is the fastest authority — behaviour you can read beats prose you can
  misread. The planning fan-out's design-reference pass exists for exactly this.

## Layout convention (proven on Klara)

```
reference-projects/
  design-reference/
    README.md      # screen map: every screen → prototype file, broken into per-state
                   # sub-sections (success / empty / loading / error) with exact copy
    CLAUDE.md      # how an agent should consume the bundle
    <Prototype>.html + <name>/*.jsx + styles.css   # the runnable high-fidelity prototype
```

The prototypes are **design references, not production code**: recreate them in the target
codebase's framework and conventions; copy the styling tokens verbatim; never ship the prototype
wiring itself.

<!-- CUSTOMIZE: drop your validated prototypes here in that shape. The screen-map README is the
load-bearing piece — without it, agents can't navigate the bundle. If you have no prototypes yet,
building one (even quickly, validated with real users) pays for itself many times over once the
loop starts building UI. -->
