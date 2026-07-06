# Ralph Loop — plan one story (no code this iteration)

The picker has already CLAIMED an issue for this loop (label `claimed-ralph-@@LOOP_ID@@`).
This iteration PLANS it; the build runs next iteration.

**Current issue: #@@ISSUE@@**

1. **Read the contract.** Run `./ralph/ralph-fetch-issue.sh @@ISSUE@@` **once** — it prints the full
   issue (header + body + every comment) in one reliable call, so don't re-run it.
2. **Plan it.** Run `/ralph-tdd-plan @@ISSUE@@`. It researches the issue + codebase, writes the
   durable checkbox plan to `AI-Info/implementation-plans/current/current-plan.md` tagged
   `Issue: #@@ISSUE@@`, then ENDS this iteration via `./ralph/ralph-loop-plan-done.sh`. You do **not**
   write implementation code this iteration.
3. **If genuinely blocked** (issue underspecified, a dependency isn't built): comment on the issue
   explaining the block and stop — do **not** call plan-done, and do **not** guess your way forward.

The next iteration re-claims this same issue, finds the plan, and builds it.
