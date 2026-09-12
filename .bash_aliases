alias cd="z"
alias cdi="zi"

#Navigation
alias ll="ls -lah"

# Codex
alias codex='GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" BASH_ENV="$HOME/.codex/bash_env" codex'

# Claude Code: Fable at medium effort.
alias fable='CLAUDE_CODE_EFFORT_LEVEL=medium claude --model fable'

# Claude Code: Sonnet
alias sonnet='claude --model sonnet'

# Claude Code: enable remote control
alias rclaude='claude --settings '"'"'{"env": {"DISABLE_TELEMETRY": ""}}'"'"''
