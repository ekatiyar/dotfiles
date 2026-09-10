# Dotfiles

My personal terminal configuration dotfiles. The repo mirrors `$HOME`: every
tracked file sits at the path it should occupy in your home directory, and
[GNU Stow](https://www.gnu.org/software/stow/) symlinks it into place.

## What's Included

- [Vim](https://github.com/vim/vim) configuration with [pathogen](https://github.com/tpope/vim-pathogen), [onedark](https://github.com/joshdick/onedark.vim), and [lightline](https://github.com/itchyny/lightline.vim)
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) configured with the plugins: `git`, [fzf](https://github.com/junegunn/fzf), [zoxide](https://github.com/ajeetdsouza/zoxide), [you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), and [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [Ripgrep](https://github.com/BurntSushi/ripgrep) and [GitHub CLI (gh)](https://cli.github.com/)
- [Tmux](https://github.com/tmux/tmux) with basic QOL configs
- [Herdr](https://herdr.dev) with Claude integration pre-installed and basic QOL configs
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configured with global CLAUDE.md, MCP servers, custom skills, hooks, and a custom statusline
- Rust toolchain (`rustup`/`cargo`) on `PATH`, plus the `rust-analyzer-lsp` Claude Code plugin for language support

## Requirements

- Linux (developed/deployed on Ubuntu WSL)
- [Homebrew](https://brew.sh) installed (Linuxbrew)
- `curl` and `git` on `PATH`

Everything else is installed by `setup.sh`. **No root required**

## Quick Start

```bash
cd "$HOME"
git clone git@github.com:ekatiyar/dotfiles.git
./dotfiles/setup.sh
gh auth login
exec zsh
```

`setup.sh` is idempotent — re-run it any time to pick up new tools or re-link
config; already-installed steps report skips/no-ops.

## What setup.sh does

1. **Preflight** — checks for `brew`, `curl`, and `git` on `PATH`; pre-create certain folders
   to prevent Stow from symlinking at too high a directory level
2. **Submodules** — `git submodule update --init --remote` (Vim bundles, Zsh plugins, skills)
3. **CLI tools** — `brew install`
4. **Oh My Zsh** — run official installer
5. **Claude Code** — run the native installer
6. **Clean legacy links** — remove any absolute symlinks that conflict with Stow
7. **Symlink w/ Stow**
8. **Review** — print any files `--adopt` imported, for git review.
9. **MCP merge** — deep-merge `.claude/.mcp.json` into `~/.claude.json`
10. **Next steps**

## How it's managed (GNU Stow)

The whole repo is a single Stow package. Install runs:

```bash
stow --dir="$HOME/dotfiles" --target="$HOME" --adopt --restow --verbose=1 .
```

- This re-links cleanly on every run (idempotent), and imports any pre-existing **real**
  file in `$HOME` into the repo rather than failing or deleting it. Adopted files surface
  as uncommitted changes.
- `.stow-local-ignore` includes Stow's default ignore list and a few others:
  - `setup.sh` — the bootstrap script itself
  - `.secrets` — machine-local secrets
  - `vendor` — vendor files which shouldn't be symlinked directly
  - `.claude/.mcp.json` — merged into `~/.claude.json`
  - `.claude/settings.local.json` — project-local

## Shell layout

`.zshrc` sources `~/.bashrc`, so the shared shell setup lives in one place:

- `.bashrc` — PATH and environment configuration plus shared shell sources.
- `.bash_aliases` — generic aliases.
- `.bash_functions` — multi-line helpers for `iwatch`, worktree-aware Git
  commands, etc.
- `.zshrc` — Oh My Zsh and plugins
- `.tmux.conf` — configures shell as `zsh`, provides basic QOL configs
- `.config/herdr/config.toml` — sets `zsh` shell, configures similar
  defaults to tmux and basic QOL configs

### Agent Skills

- Third-party skills come from upstream repos checked out as submodules under
  `vendor/` and are symlinked into `.claude/skills/`.

