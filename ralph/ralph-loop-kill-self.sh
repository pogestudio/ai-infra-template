#!/usr/bin/env bash
#
# ralph-loop-kill-self.sh — shared helper, meant to be SOURCED (not executed).
#
# Defines ralph_kill_iteration: end the current Ralph iteration *now* by SIGKILLing the claude
# process that owns it. Sourced by ralph-loop-done.sh (issue done) and ralph-loop-plan-done.sh
# (plan written) so the one kill mechanism lives in a single place — change it here, both inherit.

# End the iteration now instead of idling until the iteration timeout's SIGKILL. We can't use
# pkill/pgrep (procps isn't installed in the container) and mustn't background claude (it'd lose
# the interactive TTY + --verbose view, so its PID isn't capturable up front). So walk up our OWN
# ancestry to the claude process — the nearest ancestor whose cmdline carries the loop's launch
# flag — and SIGKILL it by PID. Precise: kills only the claude that owns THIS iteration, never an
# unrelated claude session in the same container.
ralph_kill_iteration() {
  local pid=$$ ppid cmd
  while [[ "${pid:-0}" -gt 1 ]]; do
    ppid=$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null) || break
    [[ -z "${ppid:-}" || "$ppid" == "0" ]] && break
    cmd=$(tr '\0' ' ' < "/proc/$ppid/cmdline" 2>/dev/null)
    case " $cmd " in
      *"--dangerously-skip-permissions"*) kill -KILL "$ppid" 2>/dev/null || true; break ;;
    esac
    pid=$ppid
  done
}
