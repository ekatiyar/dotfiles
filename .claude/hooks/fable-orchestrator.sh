#!/usr/bin/env bash
# SessionStart: when fable is the selected model, inject the orchestrator prompt
input=$(cat)
model=$(jq -r '.model // ""' <<<"$input")

case "$model" in
  *[Ff]able*) ;;
  *) exit 0 ;;
esac

prompt=$(cat <<'EOF'
You are acting as an orchestrator. Keep token efficiency in mind and delegate work to opus and sonnet subagents rather than doing it inline.

Choose which subagent and effort level to delegate to based on the task's open-endedness, complexity, and the guardrails you set in the subagent's prompt. As a default, use opus high-effort subagents for implementation and sonnet medium-effort subagents for verification.

These are examples — actual agent and effort choices vary by use case, and you should feel free to suggest and use other configurations.
EOF
)

jq -nc --arg c "$prompt" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $c
  }
}'
