# Dotfiles

My personal terminal configuration dotfiles. The repo mirrors `$HOME`: every
tracked file sits at the path it should occupy in your home directory, and
[GNU Stow](https://www.gnu.org/software/stow/) symlinks it into place.

## What's Included

- [Vim](https://github.com/vim/vim) configuration with [pathogen](https://github.com/tpope/vim-pathogen), [onedark](https://github.com/joshdick/onedark.vim), and [lightline](https://github.com/itchyny/lightline.vim)
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) configured with the `git` plugin plus [you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), and [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [Zoxide](https://github.com/ajeetdsouza/zoxide) as a replacement for `cd`, plus [fzf](https://github.com/junegunn/fzf) for fuzzy file finding
- [ripgrep](https://github.com/BurntSushi/ripgrep), the [GitHub CLI](https://cli.github.com/), and [tealdeer](https://github.com/dbrgn/tealdeer) (`tldr`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration, including shared global instructions, an MCP definition, and custom skills

## Requirements

- Linux (developed/deployed on Ubuntu WSL)
- [Homebrew](https://brew.sh) installed (Linuxbrew)
- `git` on `PATH`

Everything else — GNU Stow, the CLI tools, Oh My Zsh, and Claude Code — is
installed by `setup.sh`. **No root and no host package manager** required:
`setup.sh` is 100% sudo-free and never touches `apt`.

## Quick Start

```bash
cd "$HOME"
git clone --recursive git@github.com:ekatiyar/dotfiles.git
./dotfiles/setup.sh
gh auth login
exec zsh
```

`setup.sh` is idempotent — re-run it any time to pick up new tools or re-link
config; already-installed steps report skips/no-ops.

## What setup.sh does

Tools are installed **first**, then Stow runs **once** so it links leaf files
into the real directories those tools create.

1. **Preflight** — require `brew` and `git` on `PATH` (it never installs either);
   create `~/.local/bin` and the runtime dir `~/.claude` so Stow descends into it
   instead of folding it whole.
2. **Submodules** — `git submodule update --init --recursive` (vim bundles, zsh plugins).
3. **CLI tools** — `brew install stow zoxide fzf ripgrep gh tealdeer jq zsh`, skipping
   formulae already present. fzf's `install` then generates `~/.fzf.{bash,zsh}`
   without editing the rc files.
4. **Oh My Zsh** — official installer with `KEEP_ZSHRC=yes` (leaves rc files for Stow).
5. **Claude Code** — native installer (`curl … claude.ai/install.sh`).
6. **Clean legacy links** — remove stale absolute symlinks pointing into the repo.
7. **Stow** — single `stow --adopt --restow` pass links everything.
8. **Review** — print any files `--adopt` imported, for git review.
9. **MCP merge** — deep-merge `.claude/.mcp.json` into `~/.claude.json` (atomic, validated).
10. **Next steps** — `gh auth login`, `exec zsh`.

## How it's managed (GNU Stow)

The whole repo is a single Stow package. Install runs:

```bash
stow --dir="$HOME/dotfiles" --target="$HOME" --adopt --restow --verbose=1 .
```

- `--restow` re-links cleanly on every run (idempotent).
- `--adopt` imports any pre-existing **real** file in `$HOME` into the repo
  rather than failing or deleting it. Adopted files surface as uncommitted
  changes — review with `git -C ~/dotfiles status` / `diff`, and
  `git checkout -- <path>` to restore the tracked version of anything you didn't
  mean to keep.

### What `.stow-local-ignore` excludes

`.stow-local-ignore` replaces Stow's default ignore list, so it keeps the
defaults (VCS metadata, editor backups, `README`/`LICENSE`) and adds:

- `setup.sh` — the bootstrap script itself
- `.secrets` — machine-local secrets, never symlinked
- `.claude/.mcp.json` — merged into `~/.claude.json`, not symlinked
- `.claude/settings.local.json` — machine-local, not symlinked
- `.oh-my-zsh/custom/example.zsh` — Oh My Zsh boilerplate (avoids a spurious adopt diff)

## Shell layout

`.zshrc` sources `~/.bashrc`, so the shared shell setup lives in one place:

- `.bashrc` — PATH (including `brew shellenv`), fzf, `FZF_DEFAULT_COMMAND`,
  the `GITHUB_TOKEN` export (from `gh auth token`, used by the GitHub MCP server),
  and sourcing of `~/.bash_aliases`, `~/.bash_functions`, and `~/.secrets`.
- `.bash_aliases` — generic aliases (`cd`→`z`, `gc`, `ll`, …).
- `.bash_functions` — `gbv`, a worktree-aware `git branch -v`.
- `.zshrc` — Oh My Zsh, plugins, and `zoxide init` (zoxide runs as an `eval`,
  not the OMZ plugin, so set `DISABLE_ZOXIDE=1` to turn it off).
- `.tmux.conf` — sets `default-shell` to whichever `zsh` is on `PATH` (Homebrew
  or system), falling back to `/usr/bin/zsh`.
