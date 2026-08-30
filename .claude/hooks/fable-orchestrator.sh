#!/usr/bin/env bash
# SessionStart: when fable is the selected model, load the orchestrator skill.
input=$(cat)
model=$(jq -r '.model // ""' <<<"$input")

case "$model" in
  *[Ff]able*) ;;
  *) exit 0 ;;
esac

prompt='Load the `orchestrator` skill before planning or dispatching work'

jq -nc --arg c "$prompt" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $c
  }
}'
