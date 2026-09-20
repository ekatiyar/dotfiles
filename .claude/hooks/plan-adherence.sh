#!/usr/bin/env bash
# Points the model at the plan-adherence skill at plan-execution boundaries.
# $1 = hook event name (PostToolUse | SessionStart), set by the hook config.
event="${1:-PostToolUse}"

context='Load the `plan-adherence` skill before executing an approved plan. If you are not
currently executing a plan, ignore this.'

jq -nc --arg event "$event" --arg c "$context" '{
  hookSpecificOutput: {
    hookEventName: $event,
    additionalContext: $c
  }
}'
