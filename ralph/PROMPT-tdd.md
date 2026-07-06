# Ralph Loop — build one story from its plan

The picker has already CLAIMED an issue for this loop (label `claimed-ralph-@@LOOP_ID@@`) and a
plan for it is on disk. Build it.

**Current issue: #@@ISSUE@@**

1. **Read the contract.** Run `./ralph/ralph-fetch-issue.sh @@ISSUE@@` **once** — it prints the full
   issue (header + body + every comment) in one reliable call, so don't re-run it. Read the acceptance
   criteria, the e2e journey, and the Decision Log before you build.
2. **Build it.** Run `/ralph-tdd @@ISSUE@@`. It resumes from the on-disk plan and does
   red-green-refactor + the issue's Playwright e2e. (If the plan is tagged for a *different* issue,
   `/ralph-tdd` hands off to `./ralph/ralph-issue-drift.sh` for a clean restart.)
3. **Commit + push to `ralph-loop`.** Your commit message MUST reference `#@@ISSUE@@` (e.g.
   `Closes #@@ISSUE@@`) — the done-gate greps `origin/ralph-loop` for it as proof-of-work. On a
   **non-fast-forward** push (another loop pushed first):
   - `git fetch origin ralph-loop`
   - `git pull --no-rebase origin ralph-loop`  (explicit `--no-rebase`; **never** rebase or force-push)
   - resolve any conflicts **in-tree** (never `git merge --abort`, never force)
   - re-run `./scripts/run-tests.sh` until green
   - retry the push (up to ~5 times). If it still won't land, comment on the issue and stop.
4. **Hand back to the loop.** Run `./ralph/ralph-loop-done.sh --issueDone @@ISSUE@@`. It verifies the
   `#@@ISSUE@@` proof-of-work commit is on `origin/ralph-loop` **and** that tests are green, then
   closes the issue, removes this loop's `claimed-ralph-@@LOOP_ID@@` label, and clears the plan.
5. **Already done?** If the work is already pushed and the issue is satisfied (a prior iteration
   just forgot to advance the queue), skip straight to step 4.
