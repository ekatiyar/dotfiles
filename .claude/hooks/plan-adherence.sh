#!/usr/bin/env bash
# Injects a plan-adherence reminder at plan-execution boundaries.
# $1 = hook event name (PostToolUse | SessionStart), set by the hook config.
event="${1:-PostToolUse}"
context="When executing an approved plan, follow it closely. Do not expand scope, switch approach, or touch files or systems the plan did not cover on your own initiative. Trivial in-scope adjustments are fine: make them and note them. If a non-trivial issue would take you off-plan (the approach does not work, a step reveals a different root cause, or a decision the plan did not specify is required), STOP: explain the issue and the options, and ask how to proceed before making changes. If you are not currently executing a plan, ignore this."
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$context"
