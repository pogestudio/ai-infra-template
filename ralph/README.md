# Ralph loop

An autonomous GitHub issue runner. Each iteration claims one open issue, launches a fresh capped
`claude` session to either plan it or build it, then exits so the next iteration starts with a clean
context. Plan and build are deliberately split across two iterations so the build always starts from
a fresh context instead of one already filled by the planning fan out.

This folder is the harness only. The operations manual (mental model, invariants, running, stopping,
monitoring, concurrency, failure modes) lives in the top level `README.md`, section 4, and the setup
steps live in its section 2. This file covers only what is not documented there: the role of each
script, and the helper scripts the loop calls but does not ship.

## Scripts

| File | Role |
|------|------|
| `ralph-loop.sh` | The long running driver. Runs the picker, renders the matching prompt, launches and time caps `claude`, handles self reload when its own source changes mid run. |
| `ralph-loop-pick-gh-user-story.sh` | Picks AND claims the next issue. Resumes an existing claim first, otherwise takes the lowest open `agent-ready` issue whose blockers are all closed. Emits `STATUS` / `ISSUE` / `BRANCH` / `MODE` on stdout. Decides plan vs build from whether an on disk plan is tagged for the issue. |
| `PROMPT-plan.md` | First turn prompt for a plan iteration. Tells the agent to read the issue, run `/ralph-tdd-plan`, write the plan, and end the iteration. No implementation code this turn. |
| `PROMPT-tdd.md` | First turn prompt for a build iteration. Tells the agent to read the issue, run `/ralph-tdd` from the on disk plan, commit and push to `ralph-loop` referencing the issue, then call the done gate. |
| `ralph-fetch-issue.sh` | Prints one issue's full contract (header, body, every comment) in a single non TTY call. The canonical "read the contract" command, written because `gh issue view --comments` emits nothing when stdout is not a TTY. |
| `ralph-find-claimed-issue.sh` | Helper for the in session agent: finds the issue this loop currently holds and prints the verdict command to run. Expands `RALPH_LOOP_ID` in the shell so the agent never queries the wrong loop's label. |
| `ralph-loop-plan-done.sh` | Ends a plan iteration. Clears the scratch research dir, then SIGKILLs this iteration's `claude` so the next iteration re picks the same issue, finds the plan, and builds with a clean context. The loop keeps running. |
| `ralph-loop-done.sh` | Ends a build iteration. `--issueDone <N>` closes the issue only after both gates pass (a proof of work commit referencing `#N` is on `origin/ralph-loop`, and tests are green), then releases the claim label and clears the plan. With no argument it marks the whole loop DONE so the driver exits. |
| `ralph-issue-drift.sh` | Recovers from a claim vs plan mismatch (the held issue is not the one the on disk plan is tagged for). Logs the drift to `.drift-log`, drops the claim, deletes the stale plan, and SIGKILLs the iteration if running under one. A clean restart. |
| `ralph-loop-kill-self.sh` | Shared helper, meant to be sourced. Defines `ralph_kill_iteration`, which walks `/proc` up its own ancestry to find and SIGKILL the `claude` that owns the current iteration (no `pkill` in the container). Used by both done scripts and the drift handler. |

## Helper scripts the loop calls but does not ship

The setup checklist in the top level README covers `scripts/run-tests.sh` and `scripts/dev-up.sh`.
The loop additionally calls two scripts that are not part of the template, and it exits hard when
they are missing:

- `scripts/ensure-vite-arch.sh`: run once at loop startup to heal host vs container native binary
  drift. Replace with a stub that exits 0 for repos where that cannot happen.
- `scripts/clear-research-dir.sh`: wipes the planning scratch dir. Called before a plan iteration
  starts and again by `ralph-loop-plan-done.sh` when the plan is written.

## Runtime files

- `.ralph-status`: the DONE marker the driver checks at the top of each iteration (already
  gitignored by the template).
- `.drift-log`: an append only audit trail written by the drift handler. Add it to your project's
  `.gitignore`.
