alias cd="z"
alias cdi="zi"

#Navigation
alias ll="ls -lah"

# Claude Code
alias claude='claude --mcp-config "$HOME/.claude/.mcp.json"'
alias fable='claude --model fable --settings "{\"outputStyle\":\"default\"}"'
alias sonnet='claude --model sonnet'
alias rclaude='claude --settings '"'"'{"env": {"DISABLE_TELEMETRY": ""}}'"'"''

# Codex
alias codex='GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" BASH_ENV="$HOME/.codex/bash_env" codex'
alias luna='codex --model gpt-5.6-luna'

# Local LLMs
alias lclclaude='CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" CLAUDE_CODE_ATTRIBUTION_HEADER="0" ANTHROPIC_BASE_URL="http://127.0.0.1:8080" ANTHROPIC_API_KEY="local_token" ANTHROPIC_MODEL="opus" ANTHROPIC_DEFAULT_FABLE_MODEL="qwen3.8-27b" ANTHROPIC_DEFAULT_OPUS_MODEL="qwen3.8-27b" ANTHROPIC_DEFAULT_SONNET_MODEL="qwen3.8-27b" ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen3.5-4b" CLAUDE_CODE_DISABLE_1M_CONTEXT="1" claude --mcp-config "$HOME/.claude/lclclaude.mcp.json" --exclude-dynamic-system-prompt-sections --effort high --settings '"'"'{"permissions":{"disableAutoMode":"disable"}}'"'"''
alias lclcodex='codex --profile local'