#!/usr/bin/env bash
# Tests for sleep-wait-policy.sh: pipe sample tool_input JSON, assert on the
# resulting decision (deny | nudge | silent).
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/sleep-wait-policy.sh"
. "$(dirname "$0")/../test-lib.sh"

# Run the hook for a command; classify its output as deny/nudge/allow-nocontext/silent.
run() {
  local out dec ctx
  out=$(jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$HOOK")
  [[ -z "$out" ]] && { echo silent; return; }
  dec=$(jq -r '.hookSpecificOutput.permissionDecision // ""' <<<"$out")
  ctx=$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$out")
  case "$dec" in
    deny)  echo deny ;;
    allow) [[ -n "$ctx" ]] && echo nudge || echo allow-nocontext ;;
    *)     echo "unknown:$out" ;;
  esac
}

check() { # expected command
  local got; got=$(run "$2")
  if [[ "$got" == "$1" ]]; then
    printf 'PASS  %-34s -> %s\n' "$2" "$got"; pass=$((pass+1))
  else
    printf 'FAIL  %-34s -> got=%s want=%s\n' "$2" "$got" "$1"; fail=$((fail+1))
  fi
}

check deny   'sleep 30 && echo done'
check deny   'sleep 5 && echo ready'
check nudge  'sleep 30 && cat out.txt'
check nudge  'sleep 30'
check nudge  'sleep 30; cat out.txt'
check nudge  'while true; do sleep 10; done'
check nudge  'sleep 0.5'
check silent 'git status'

summary
