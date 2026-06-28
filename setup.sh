#!/usr/bin/env bash
#
# setup.sh — idempotent bootstrap for this dotfiles repo.
#
# Installs CLI tooling via Homebrew (Linuxbrew), then lets GNU Stow do ALL the
# symlinking in a single pass. 100% sudo-free: it never touches apt and never
# builds anything from source. Re-runnable: every step is guarded, so a second
# run reports skips/no-ops.
#
# Homebrew is a hard requirement and must be pre-installed (see https://brew.sh).
#
# Usage:
#   ./dotfiles/setup.sh           # full bootstrap
#   ./dotfiles/setup.sh --help    # this message
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Constants & helpers
# ----------------------------------------------------------------------------

# Repo dir = the directory this script lives in
readonly DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly LOCAL_BIN="$HOME/.local/bin"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
setup.sh — idempotent bootstrap for this dotfiles repo.

Installs CLI tooling via Homebrew (Linuxbrew), then lets GNU Stow do ALL the
symlinking in a single pass. 100% sudo-free. Re-runnable.

Homebrew must be pre-installed (see https://brew.sh).

Usage:
  ./dotfiles/setup.sh           full bootstrap
  ./dotfiles/setup.sh --help    this message
EOF
  exit 0
}

# ----------------------------------------------------------------------------
# Steps
# ----------------------------------------------------------------------------

# 1. preflight — require brew + git on PATH (never install, never sudo) and
#    pre-create the dirs that let stow descend (unfold) rather than fold whole
#    directories.
preflight() {
  log "Preflight: checking required tools"

  # If brew isn't on PATH yet, try to source it from the standard locations
  # before giving up (a fresh install often isn't wired into the rc files yet).
  if ! command -v brew >/dev/null 2>&1; then
    local candidate
    for candidate in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
      if [ -x "$candidate" ]; then
        eval "$("$candidate" shellenv)"
        break
      fi
    done
  fi

  command -v brew >/dev/null 2>&1 \
    || die "Homebrew is required but not found on PATH. Install it first: https://brew.sh"
  command -v git >/dev/null 2>&1 \
    || die "git is required but not found on PATH."

  mkdir -p "$LOCAL_BIN"
  export PATH="$LOCAL_BIN:$PATH"

  # Pre-create the runtime dir as a REAL dir so the single stow pass descends
  # into it and links the leaf files, instead of folding the whole dir.
  mkdir -p "$HOME/.claude"
}

# 2. submodules — vim bundles + zsh plugins must exist before stow links them.
update_submodules() {
  log "Updating git submodules (vim bundles, zsh plugins)"
  git -C "$DOTFILES_DIR" submodule update --init --recursive
}

# 3. install_tools — brew install the full CLI set. tealdeer provides `tldr`;
#    jq is needed by merge_mcp; zsh is the login shell (.tmux.conf and next_steps
#    both expect it on PATH). fzf's install script generates ~/.fzf.{bash,zsh}
#    without editing the soon-to-be-symlinked rc files.
install_tools() {
  log "Installing CLI tools via Homebrew"
  brew_install stow zoxide fzf ripgrep gh tealdeer jq zsh

  if [ ! -f "$HOME/.fzf.bash" ] || [ ! -f "$HOME/.fzf.zsh" ]; then
    log "Generating fzf key-bindings and completion (~/.fzf.{bash,zsh})"
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
  else
    log "fzf shell integration already present; skipping"
  fi
}

# brew_install <formula...> — install only formulae not already present.
brew_install() {
  local pkg
  for pkg in "$@"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      log "$pkg already installed; skipping"
    else
      log "Installing $pkg"
      brew install "$pkg"
    fi
  done
}

# 4. install_omz — creates a real ~/.oh-my-zsh/custom so stow can later descend
#    and link plugins. KEEP_ZSHRC=yes leaves rc files alone.
install_omz() {
  if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    log "Oh My Zsh already installed; skipping"
    return
  fi
  log "Installing Oh My Zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

# 5. install_claude — native installer drops the binary into ~/.local/bin.
install_claude() {
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code already installed; skipping"
    return
  fi
  log "Installing Claude Code (native installer)"
  curl -fsSL https://claude.ai/install.sh | bash
}

# 6. clean_legacy_links — stow only manages RELATIVE symlinks; it ignores
#    absolute ones (and neither --override nor --adopt reclaims them). The old
#    manual setup created absolute links, so delete any home symlink whose
#    target is absolute and points into THIS repo, letting the stow pass
#    recreate it as a relative, stow-owned link. Nothing else is touched.
clean_legacy_links() {
  log "Removing legacy absolute symlinks that point into the repo"
  local entry name target link
  shopt -s dotglob nullglob          # include dotfiles; empty globs disappear
  for entry in "$DOTFILES_DIR"/*; do
    name="${entry##*/}"
    [ "$name" = ".git" ] && continue
    target="$HOME/$name"
    if [ -L "$target" ]; then        # file link or folded dir link (e.g. ~/.vim)
      case "$(readlink "$target")" in
        "$DOTFILES_DIR"/*) warn "  unlink $target"; rm -f "$target" ;;
      esac
    elif [ -d "$entry" ] && [ ! -L "$entry" ] && [ -d "$target" ] && [ ! -L "$target" ]; then
      while IFS= read -r link; do    # descended real dir (~/.claude, ~/.oh-my-zsh, ...)
        case "$(readlink "$link")" in
          "$DOTFILES_DIR"/*) warn "  unlink $link"; rm -f "$link" ;;
        esac
      done < <(find "$target" -type l 2>/dev/null)
    fi
  done
}

# 7. run_stow — the single symlink pass. Stow dir = the repo, target = $HOME
#    (distinct paths); package = ".". Tools above created their real dirs and
#    preflight pre-created runtime dirs, so stow descends and links leaf files.
#    --adopt imports any pre-existing real home files (reviewed via git, never
#    deleted); --restow re-links cleanly on re-runs.
run_stow() {
  log "Running stow (single pass, --adopt --restow)"
  stow --dir="$DOTFILES_DIR" --target="$HOME" \
       --adopt --restow --verbose=1 .
}

# 8. review_adopt — surface anything --adopt pulled into the repo.
review_adopt() {
  local changes
  changes="$(git -C "$DOTFILES_DIR" status --short)"
  if [ -n "$changes" ]; then
    warn "stow --adopt imported pre-existing home files into the repo."
    warn "Review and restore intended versions:"
    warn "  git -C \"$DOTFILES_DIR\" status"
    warn "  git -C \"$DOTFILES_DIR\" diff"
    warn "  git -C \"$DOTFILES_DIR\" checkout -- <path>   # to discard an adoption"
    printf '%s\n' "$changes" >&2
  else
    log "No files adopted; working tree clean"
  fi
}

# 9. merge_mcp — deep-merge tracked MCP servers into ~/.claude.json
#    (atomic + validated; .mcp.json itself is stow-ignored, never symlinked).
merge_mcp() {
  log "Merging MCP server definitions into ~/.claude.json"
  local tmpbase tmpfile
  tmpbase="${TMPDIR:-/tmp}"
  tmpfile="$(mktemp "${tmpbase%/}/dotfiles-claude.XXXXXX.json")"
  [ -f "$HOME/.claude.json" ] || printf '{}\n' > "$HOME/.claude.json"
  jq -s '.[0].mcpServers = ((.[0].mcpServers // {}) * .[1].mcpServers) | .[0]' \
     "$HOME/.claude.json" "$DOTFILES_DIR/.claude/.mcp.json" > "$tmpfile"
  jq -e . "$tmpfile" >/dev/null \
    || { rm -f "$tmpfile"; die "Merged ~/.claude.json failed jq validation; leaving original untouched"; }
  mv "$tmpfile" "$HOME/.claude.json"
}

# 10. next_steps — manual, auth-bound follow-ups.
next_steps() {
  cat <<'EOF'

==> Bootstrap complete. Remaining manual steps:

  1. Authenticate the GitHub CLI:
       gh auth login

  2. Start a fresh shell to load Oh My Zsh, plugins, and aliases:
       exec zsh

EOF
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

main() {
  case "${1:-}" in
    -h|--help) usage ;;
  esac

  preflight
  update_submodules
  install_tools
  install_omz
  install_claude
  clean_legacy_links
  run_stow
  review_adopt
  merge_mcp
  next_steps
}

main "$@"
