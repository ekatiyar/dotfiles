alias cd="z"
alias cdi="zi"

#Navigation
alias ll="ls -lah"

# Claude Code
alias claude='claude --mcp-config "$HOME/.claude/.mcp.json"'
alias fable='CLAUDE_CODE_EFFORT_LEVEL=medium claude --model fable'
alias sonnet='claude --model sonnet'
alias rclaude='claude --settings '"'"'{"env": {"DISABLE_TELEMETRY": ""}}'"'"''

# Codex
alias codex='GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" BASH_ENV="$HOME/.codex/bash_env" codex'
alias luna='codex --model gpt-5.6-luna'
