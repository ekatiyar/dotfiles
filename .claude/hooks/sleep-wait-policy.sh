#!/usr/bin/env bash
# PreToolUse(Bash): steer away from sleep-based waiting on background tasks.
# Background Bash/Agent tasks re-invoke the model with a <task-notification> on
# completion, so blocking with sleep is wasteful. Hard-deny the canonical
# "sleep N && echo ..." wait shape; soft-nudge any other command using sleep.
input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

# Deliberately narrow: only the leading "sleep N && echo ..." poll shape. Grow
# this as the nudge below flags shapes that should always be blocked.
DENY_RE='^[[:space:]]*sleep[[:space:]]+[0-9]+(\.[0-9]+)?[smhd]?[[:space:]]*&&[[:space:]]*echo([[:space:]]|$)'
SLEEP_RE='(^|[^[:alnum:]_])sleep[[:space:]]'

[[ $cmd =~ $SLEEP_RE ]] || exit 0

if [[ $cmd =~ $DENY_RE ]]; then
  reason="sleep-wait-policy: don't sleep to wait for background work. Background Bash/Agent tasks re-invoke you with a <task-notification> when they finish — end your turn and Read the output file then. If you genuinely need a foreground wait (e.g. a booting server), run the sleep as its own standalone Bash call rather than chaining '&& echo'."
  jq -nc --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
fi

ctx="sleep-wait-policy: this command uses sleep. If it is polling/waiting for a background Bash or Agent task, don't — those tasks push a <task-notification> on completion, so end your turn instead. If this sleep shape should always be blocked outright, tell the user to add it to DENY_RE in ~/.claude/hooks/sleep-wait-policy.sh."
jq -nc --arg c "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "sleep-wait-policy: allowed with guidance",
    additionalContext: $c
  }
}'
