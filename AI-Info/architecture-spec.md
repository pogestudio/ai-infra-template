# 0. <!-- CUSTOMIZE: feature/product name --> — unified architecture spec

<!-- CUSTOMIZE: this is the LOCKED design authority the whole Ralph pipeline builds against.
/ralph-create-issues references its sections in every issue; /ralph-tdd-plan plans to its module
map so the build doesn't grow god-objects; /ralph-tdd inherits its decisions instead of
re-deriving them. Fill the headings below (structure proven on the Klara project — keep the
section numbers stable, issues cite them as "§7", "§3.2" etc.). Sections you don't need yet can
stay as one-line stubs, but §3 (module map), §7 (locked decisions) and §8 (build order) are the
three the loop leans on hardest — fill those first. When a decision changes, edit it HERE (with
a date), never in a copy. -->

## Why this layer exists / what it unifies

<!-- One paragraph: which partial specs/drafts/prototypes this document reconciles, and the rule
that THIS document wins over all of them. -->

## How to read this

<!-- Reading order + precedence. E.g.: §7 locked decisions override everything; §1 is the
coherent picture; drafts/ and older docs must not be mined once this exists. -->

## 1. The unified design (one coherent picture)

### 1.1 The spine — the core state model

<!-- The central entity/entities and their state machine: states, legal transitions, who/what
triggers each. This is the backbone every story hangs off. -->

### 1.2 How it runs — events + jobs

<!-- What happens on a schedule vs. on an event; idempotency rules; where jobs live. -->

### 1.3 Integration boundaries — the ports

<!-- Every external system (payments, SMS, LLM, calendar, email …) as a named port: interface,
real adapter, dev/test fake. New code talks to the port, never the vendor SDK directly. -->

### 1.4 Conversation / interaction behaviour

<!-- If the feature has an agent/bot/notification surface: the roles, prompts, and rules of
engagement. Delete if not applicable. -->

### 1.5 Control surface + app fit

<!-- How the feature surfaces in the existing app: projections, commands, navigation. -->

## 2. Cross-cutting reconciliations (explicit)

<!-- Where two partial designs disagreed and what was decided. One numbered entry each. -->

## 3. Consolidated module map (where every piece lives)

<!-- Table or tree: module → directory → what it owns → what it must never do. The planning
fan-out verifies seams against this map. -->

## 4. Port-from-prototype plan

<!-- What gets recreated from the reference prototypes (see AI-Info/reference-projects/) vs.
built fresh, and in which target framework/patterns. -->

## 5. Consolidated test strategy

<!-- What each layer proves and with which harness: unit, integration, e2e (Playwright),
behaviour tests. Name the commands. -->

## 6. Confidence & gaps

<!-- What's still uncertain; what a build should flag rather than guess. -->

## 7. Locked decisions

<!-- The section issues cite most. Numbered, dated, verbatim decisions:
D1 (YYYY-MM-DD): <question> → <decision> — <why>.
These are settled: the loop must never re-litigate them. -->

## 8. First-build order

<!-- The tracer-bullet sequence: which vertical slice ships first and why, then the order the
tracks stack. /ralph-prio honours this when ranking. -->
