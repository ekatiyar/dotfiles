# .bashrc

# Source global definitions
if [ -n "$BASH" ] && [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Homebrew (Linuxbrew) — put its bin (and the tools installed there) on PATH.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# User specific environment
# Helper function to add directory to PATH if not already present
add_to_path() {
    case ":$PATH:" in
        *":$1:"*) ;;            # already on PATH as a full entry
        *) PATH="$1:$PATH" ;;
    esac
}

# Add directories to PATH if not already present
add_to_path "$HOME/.local/bin"
add_to_path "$HOME/bin"

export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -f ~/.bash_aliases ]; then
        . ~/.bash_aliases
fi
if [ -f ~/.bash_functions ]; then
        . ~/.bash_functions
fi

# Fzf Config (only needed in bash shell; zsh loads w/ plugin)
if [ -n "$BASH" ] && [ -f ~/.fzf.bash ]; then
    source ~/.fzf.bash
fi
# Use ripgrep instead of grep/git whilst still using default filters
export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git/' --ignore-vcs"

# GitHub token for Claude Code MCP server
export GITHUB_TOKEN="$(gh auth token)"

# Machine-local secrets (untracked; see ~/.secrets)
if [ -f "$HOME/.secrets" ]; then
    . "$HOME/.secrets"
fi
