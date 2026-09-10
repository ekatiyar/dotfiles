#!/usr/bin/env bash
# PreToolUse(Agent): enforce subagent model policy.
# When no model is specified, known agent types are auto-assigned; unknown
# types are denied so the caller must pick a model explicitly. A deliberate
# choice (opus/sonnet/haiku/fable or a full model ID) is left untouched.
input=$(cat)

tool_input=$(jq -c '.tool_input // {}' <<<"$input")
model=$(jq -r '.tool_input.model // ""' <<<"$input")
agent=$(jq -r '.tool_input.subagent_type // ""' <<<"$input")

# Respect a deliberate model choice; only act on unset/inherit.
case "$model" in
  ""|inherit) ;;
  *) exit 0 ;;
esac

# Auto-assign known agent types; require an explicit model for anything else.
case "$agent" in
  Explore|claude-code-guide|statusline-setup) picked=sonnet ;;
  Plan)                                       picked=opus ;;
  *)
    reason="subagent-model-policy: agent '${agent:-unknown}' has no default model. Re-issue the Agent call with an explicit model param (opus, sonnet, or haiku)."
    jq -nc --arg r "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $r
      }
    }'
    exit 0
    ;;
esac

reason="subagent-model-policy: model '${model:-inherit}' -> '$picked' for '$agent'"
updated=$(jq -c --arg m "$picked" '.model=$m' <<<"$tool_input")

jq -nc --argjson ui "$updated" --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: $r,
    updatedInput: $ui
  }
}'
