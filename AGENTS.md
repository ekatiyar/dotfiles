# Dotfiles

- `setup.sh` mirrors this repo into `$HOME` via GNU Stow. `~/.claude/{CLAUDE.md,settings.json,skills,hooks}`, `~/.codex/{AGENTS.md,config.toml}` and shell rc files symlink here, so edits are live. Add root files not meant for `$HOME` to `.stow-local-ignore`.
- `.codex/AGENTS.md` holds global instructions for Claude and Codex; put repo-specific notes here.
- Skills live in `.agents/skills/<name>/SKILL.md`; some are symlinks into `vendor/` submodules, so search with `find -L`.
- `.zshrc` sources `.bashrc`, which sources `.bash_aliases` and `.bash_functions`. Keep those portable across bash and zsh.
- Keep Claude permissions (`.claude/settings.json`) and Codex rules (`.codex/rules/default.rules`) in sync.
- `./check.sh` automatically picks up `*.test.sh` files; run it before committing.
