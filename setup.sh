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
#    jq is needed by sync_mcp; zsh is the login shell (.tmux.conf and next_steps
#    both expect it on PATH). fzf's install script generates ~/.fzf.{bash,zsh}
#    without editing the soon-to-be-symlinked rc files.
install_tools() {
  log "Installing CLI tools via Homebrew"
  brew_install stow zoxide fzf ripgrep gh tealdeer jq zsh github-mcp-server tmux

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
  local installer
  installer="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    || die "Failed to fetch Oh My Zsh installer"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$installer"
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
  local entry name target link _shopt_save
  _shopt_save=$(shopt -p dotglob nullglob) || true
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
  eval "$_shopt_save"
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

# Helper for sync_mcp: assemble a git-conflict-style JSON text buffer.
# Argument: JSON array of classified entries (output of the classification jq call).
_sync_mcp_build_buffer() {
  local cls="$1"
  local total i comma key key_type val block repo_val home_val repo_body home_body entry

  total="$(printf '%s\n' "$cls" | jq 'length')"
  i=0

  printf '{\n'
  while IFS= read -r entry; do
    i=$((i + 1))
    comma=","
    [ "$i" -eq "$total" ] && comma=""

    key="$(printf '%s\n' "$entry" | jq -r '.key')"
    key_type="$(printf '%s\n' "$entry" | jq -r '.type')"

    if [ "$key_type" = "auto" ]; then
      val="$(printf '%s\n' "$entry" | jq '.val')"
      # Strip outer { } lines → "  \"key\": ..." at 2-space indent.
      block="$(jq -n --arg k "$key" --argjson v "$val" '{($k): $v}' | sed '1d;$d')"
      printf '%s%s\n' "$block" "$comma"
    else
      repo_val="$(printf '%s\n' "$entry" | jq '.repo')"
      home_val="$(printf '%s\n' "$entry" | jq '.home')"
      # Body = inner lines of pretty-printed object, re-indented +2 to 4-space depth.
      repo_body="$(printf '%s\n' "$repo_val" | jq . | sed '1d;$d' | sed 's/^/  /')"
      home_body="$(printf '%s\n' "$home_val" | jq . | sed '1d;$d' | sed 's/^/  /')"
      printf '  "%s": {\n' "$key"
      printf '<<<<<<< .claude/.mcp.json (repo)\n'
      printf '%s\n' "$repo_body"
      printf '=======\n'
      printf '%s\n' "$home_body"
      printf '>>>>>>> ~/.claude.json (home)\n'
      printf '  }%s\n' "$comma"
    fi
  done < <(printf '%s\n' "$cls" | jq -c '.[]')
  printf '}\n'
}

# 9. sync_mcp — interactive deep-merge of repo .mcp.json ↔ ~/.claude.json.
#    Identical/single-source servers are auto-included; conflicting values open
#    an editor with git-style conflict markers. Writes back to BOTH files atomically.
#    Skips (idempotent) when the merged result already matches both sources.
sync_mcp() {
  log "Syncing MCP server definitions (interactive)"
  local home_json="$HOME/.claude.json"
  local repo_json="$DOTFILES_DIR/.claude/.mcp.json"
  local tmpbase="${TMPDIR:-/tmp}"
  local tmpfile editor

  [ -f "$home_json" ] || printf '{}\n' > "$home_json"

  local home_servers repo_servers
  home_servers="$(jq '.mcpServers // {}' "$home_json")"
  repo_servers="$(jq '.mcpServers // {}' "$repo_json")"

  # Classify each key: auto (identical or single-source) vs conflict (differing values).
  local classification
  classification="$(jq -n \
    --argjson home "$home_servers" \
    --argjson repo "$repo_servers" '
    (($home | keys) + ($repo | keys)) | unique | sort | map(
      . as $k |
      if ($home | has($k)) and ($repo | has($k)) then
        if $home[$k] == $repo[$k] then
          { key: $k, type: "auto", val: $home[$k] }
        else
          { key: $k, type: "conflict", repo: $repo[$k], home: $home[$k] }
        end
      elif $home | has($k) then
        { key: $k, type: "auto", val: $home[$k] }
      else
        { key: $k, type: "auto", val: $repo[$k] }
      end
    )
  ')"

  local conflict_count
  conflict_count="$(printf '%s\n' "$classification" | jq '[.[] | select(.type == "conflict")] | length')"

  # Idempotent: skip when no conflicts and merged result already matches both files.
  if [ "$conflict_count" -eq 0 ]; then
    local merged
    merged="$(printf '%s\n' "$classification" | jq 'map({key: .key, value: .val}) | from_entries')"
    local home_ok repo_ok
    home_ok="$(jq -n --argjson m "$merged" --argjson h "$home_servers" '$m == $h')"
    repo_ok="$(jq -n --argjson m "$merged" --argjson r "$repo_servers" '$m == $r')"
    if [ "$home_ok" = "true" ] && [ "$repo_ok" = "true" ]; then
      log "MCP servers already in sync; skipping"
      return
    fi
  fi

  if [ "$conflict_count" -gt 0 ]; then
    warn "$conflict_count MCP server conflict(s) require manual resolution:"
    printf '%s\n' "$classification" | \
      jq -r '.[] | select(.type == "conflict") | "  conflict: \(.key)"' >&2
  fi

  tmpfile="$(mktemp "${tmpbase%/}/dotfiles-mcp.XXXXXX.json")"
  {
    printf '// MCP merge. Resolve each <<<<<<< / ======= / >>>>>>> conflict by keeping one\n'
    printf '// side and deleting the markers and the other side. Lines starting with // are\n'
    printf '// ignored. Save and exit when done.\n'
    _sync_mcp_build_buffer "$classification"
  } > "$tmpfile"

  editor="${VISUAL:-${EDITOR:-vi}}"
  local content attempt error_banner jq_err
  for attempt in 1 2 3 4 5; do
    "$editor" "$tmpfile"

    # Strip JSONC // comment/banner lines before validation.
    content="$(sed '/^[[:space:]]*\/\//d' "$tmpfile")"
    error_banner=""

    if printf '%s\n' "$content" | grep -Eq '^(<<<<<<<|=======|>>>>>>>)'; then
      error_banner='// ERROR: Unresolved conflict markers remain — keep one side and delete the
// <<<<<<< ======= >>>>>>> lines, then save again.'
    else
      jq_err=""
      if ! jq_err="$(jq -e . <<<"$content" 2>&1 >/dev/null)"; then
        error_banner="// ERROR (invalid JSON): ${jq_err}
// Note: line numbers are relative to the JSON below this banner."
      fi
    fi

    if [ -n "$error_banner" ]; then
      if [ "$attempt" -eq 5 ]; then
        rm -f "$tmpfile"
        die "Too many invalid saves; both files left untouched."
      fi
      { printf '%s\n' "$error_banner"; printf '%s\n' "$content"; } > "$tmpfile"
      continue
    fi

    break
  done

  local resolved
  resolved="$(jq '.' <<<"$content")"
  rm -f "$tmpfile"

  # Write to ~/.claude.json atomically, preserving all other keys.
  local home_tmp
  home_tmp="$(mktemp "${tmpbase%/}/dotfiles-claude.XXXXXX.json")"
  jq --argjson s "$resolved" '.mcpServers = $s' "$home_json" > "$home_tmp" \
    || { rm -f "$home_tmp"; die "Failed to write updated ~/.claude.json"; }
  jq -e . "$home_tmp" >/dev/null \
    || { rm -f "$home_tmp"; die "Updated ~/.claude.json failed validation; leaving untouched."; }
  mv "$home_tmp" "$home_json"
  log "Updated ~/.claude.json"

  # Write to .claude/.mcp.json only if content actually changed.
  local new_repo
  new_repo="$(jq -n --argjson s "$resolved" '{"mcpServers": $s}')"
  if [ "$(jq -c . "$repo_json")" != "$(printf '%s\n' "$new_repo" | jq -c .)" ]; then
    local repo_tmp
    repo_tmp="$(mktemp "${tmpbase%/}/dotfiles-mcp-repo.XXXXXX.json")"
    printf '%s\n' "$new_repo" | jq . > "$repo_tmp" \
      || { rm -f "$repo_tmp"; die "Failed to write updated .claude/.mcp.json"; }
    mv "$repo_tmp" "$repo_json"
    log "Updated .claude/.mcp.json"
    warn "Review and commit the updated .claude/.mcp.json:"
    warn "  git -C \"$DOTFILES_DIR\" diff .claude/.mcp.json"
    warn "  git -C \"$DOTFILES_DIR\" add .claude/.mcp.json && git -C \"$DOTFILES_DIR\" commit"
  fi
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

  [ -t 0 ] && [ -t 1 ] || die "setup.sh must be run in an interactive terminal."

  preflight
  update_submodules
  install_tools
  install_omz
  install_claude
  clean_legacy_links
  run_stow
  review_adopt
  sync_mcp
  next_steps
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
