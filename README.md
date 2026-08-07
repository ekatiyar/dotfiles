# Dotfiles

My personal terminal configuration dotfiles. The repo mirrors `$HOME`: every
tracked file sits at the path it should occupy in your home directory, and
[GNU Stow](https://www.gnu.org/software/stow/) symlinks it into place.

## What's Included

- [Vim](https://github.com/vim/vim) configuration with [pathogen](https://github.com/tpope/vim-pathogen), [onedark](https://github.com/joshdick/onedark.vim), and [lightline](https://github.com/itchyny/lightline.vim)
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) configured with the `git` plugin plus [you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), and [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [Zoxide](https://github.com/ajeetdsouza/zoxide) as a replacement for `cd`, plus [fzf](https://github.com/junegunn/fzf) for fuzzy file finding
- [ripgrep](https://github.com/BurntSushi/ripgrep), the [GitHub CLI](https://cli.github.com/), and [tealdeer](https://github.com/dbrgn/tealdeer) (`tldr`)
- [tmux](https://github.com/tmux/tmux) with [TPM](https://github.com/tmux-plugins/tpm) using [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) + [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration: shared global instructions, MCP servers, custom skills, policy hooks, and a custom statusline
- [llama.cpp](https://github.com/ggml-org/llama.cpp) build pipeline and serving utilities
- Rust toolchain (`rustup`/`cargo`) on `PATH`, plus the `rust-analyzer-lsp` Claude Code plugin for language support

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

Then, inside tmux, press `prefix+I` once to have TPM install tmux-resurrect
and tmux-continuum.

`setup.sh` is idempotent — re-run it any time to pick up new tools or re-link
config; already-installed steps report skips/no-ops.

## What setup.sh does

Tools are installed **first**, then Stow runs **once** so it links leaf files
into the real directories those tools create.

1. **Preflight** — checks for `brew` and `git` on `PATH`; pre-create certain folders
   to prevent Stow from symlinking at too high a directory level
2. **Submodules** — `git submodule update --init --recursive` (vim bundles, zsh plugins, tpm).
3. **CLI tools** — `brew install`
4. **Oh My Zsh** — official installer with `KEEP_ZSHRC=yes` (leaves rc files for Stow).
5. **Claude Code** — native installer (`curl … claude.ai/install.sh`).
6. **Clean legacy links** — remove stale absolute symlinks pointing into the repo.
7. **Stow** — single `stow --adopt --restow` pass links everything.
8. **Review** — print any files `--adopt` imported, for git review.
9. **MCP merge** — deep-merge `.claude/.mcp.json` into `~/.claude.json`
10. **Next steps**

## How it's managed (GNU Stow)

The whole repo is a single Stow package. Install runs:

```bash
stow --dir="$HOME/dotfiles" --target="$HOME" --adopt --restow --verbose=1 .
```

- `--restow` re-links cleanly on every run (idempotent).
- `--adopt` imports any pre-existing **real** file in `$HOME` into the repo
  rather than failing or deleting it. Adopted files surface as uncommitted
  changes.
- `.stow-local-ignore` includes Stow's default ignore list and a few others:
  - `setup.sh` — the bootstrap script itself
  - `.secrets` — machine-local secrets
  - `.claude/.mcp.json` — merged into `~/.claude.json`
  - `.claude/settings.local.json` — project-local
  - `.oh-my-zsh/custom/example.zsh` — comes w/ Oh My Zsh install 

## Shell layout

`.zshrc` sources `~/.bashrc`, so the shared shell setup lives in one place:

- `.bashrc` — PATH , setting environment variables, and sourcing of `~/.bash_aliases`,
  `~/.bash_functions`, `~/.llama_functions`, and `~/.secrets`.
- `.bash_aliases` — generic aliases
- `.bash_functions` — multi-line bash operations, like a worktree-aware
  `git branch -v`, alias-aware `watch`, and a helper to execute saved Claude Code plans
- `.llama_functions` — `llmb` and `llama-router` bash functions
- `.zshrc` — Oh My Zsh, plugins
- `.tmux.conf` — configures shell as `zsh`, provides basic QOL configs, and loads TPM plugins

## Local LLM & Claude Integration

- `llmb` — pulls latest and builds `llama-cli`/`llama-server`
- `llama-router` — serves model presets from `.config/llama.cpp/preset.ini`
- `lclclaude` alias — routes all Claude Code model tiers to local llama.cpp presets

### WSL tuning (one-time manual step, requires root) - NOT part of `setup.sh`

- Keep idle CPU-resident weights from being paged out

  ```bash
  echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-llama.conf
  sudo sysctl --system
  ```

- Reduces TLB pressure for `load-mode = none` MOE models running on CPU

  ```bash
  printf 'w /sys/kernel/mm/transparent_hugepage/enabled - - - - always\n' \
    | sudo tee /etc/tmpfiles.d/99-llama-thp.conf
  sudo systemd-tmpfiles --create /etc/tmpfiles.d/99-llama-thp.conf
  ```

  Verify while a model is loaded: `grep AnonHugePages /proc/$(pgrep -x llama-server)/smaps_rollup`

- `.wslconfig` (Windows-side)

  ```ini
  [wsl2]
  memory=113GB
  swap=8GB
  guiApplications=false

  [experimental]
  autoMemoryReclaim=gradual
  ```
