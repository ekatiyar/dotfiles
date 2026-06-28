---
name: triage-branch-changes
description: Classify uncommitted dotfile changes as master (shared) or branch-specific, then commit each set to the right branch
disable-model-invocation: true
---

# Triage Branch Changes

Sort uncommitted changes between `master` (shared configs) and the current feature branch, then commit each set to the correct branch.

## Prerequisites

- Current branch must NOT be `master` (there's nothing to triage on master itself)
- Working tree must have uncommitted changes (staged, unstaged, or untracked)

## Steps

1. **Identify branches**: run `git branch --show-current` to get the current branch. The base branch is `master`. If already on master, stop and tell the user this skill only works from a feature branch.

2. **Collect all uncommitted changes**:
   ```bash
   git status --short
   ```
   List every changed file (staged, unstaged, untracked). If there are no changes, stop and tell the user.

3. **Classify each file** into one of three categories:
   - **master** — shared configs that benefit all branches (e.g. `.bash_aliases`, `.bash_functions`, `.claude/` skills/settings, `.gitconfig`, `.tmux.conf`, shared shell configs)
   - **branch** — files specific to the current branch (e.g. machine- or toolchain-specific configs, or changes that only make sense in the context of this branch)
   - **skip** — transient working-state files that should stay uncommitted (e.g. scratch files, temporary logs, editor swap files)

   Use these heuristics:
   - Files under `.claude/skills/` and `.claude/commands/` → **master** (workflow tools are shared)
   - `.claude/settings.json`, `.claude/settings.local.json` → **master**
   - Shell config files (`.bash_aliases`, `.bash_functions`, `.bashrc`, `.zshrc`, `.gitconfig`, `.tmux.conf`) → **master** unless the change is clearly branch-specific
   - Files with branch-name-related content or machine/toolchain-specific tooling → **branch**
   - When uncertain, default to **branch** (safer; can always cherry-pick to master later)

4. **Present the classification** to the user as a table:
   | File | Category | Reason |
   Show the proposed commit messages for each group. **Ask for approval** before proceeding. Let the user re-classify any files.

5. **Execute the commit workflow** (only after user approval):
   a. Stash ALL changes (including untracked): `git stash push --include-untracked -m "triage-branch-changes: temp stash"`
   b. Checkout master: `git checkout master`
   c. Apply ONLY the master-category files from stash:
      - For tracked files (shown as `M`/`A`/`D` in `git status`), run `git checkout stash@{0} -- <file>`
      - For untracked files (shown as `??`), run `git checkout stash@{0}^3 -- <file>` instead. `--include-untracked` stores untracked files in the stash's third parent (`^3`), so `stash@{0} -- <file>` will fail with `did not match any file(s) known to git`.
   d. Stage and commit the master changes: `git add <master-files> && git commit -m "<master commit message>"`
   e. Checkout the feature branch: `git checkout <branch>`
   f. Merge master into the feature branch: `git merge master`
   g. Reconcile the stash: try `git stash pop stash@{0}`. If all changes were master-category, step f already merged them in, so the pop exits non-zero and keeps the stash (`already exists, no checkout`) — this is expected, not a step-6 failure. Verify the content is already present (`git diff stash@{0} HEAD -- <file>` for tracked, `git show stash@{0}^3:<path> | diff - <path>` for untracked), then `git stash drop stash@{0}`. If a stashed change is NOT present (e.g. branch-category files), let the pop apply it before dropping.
   h. Stage and commit the branch-category files: `git add <branch-files> && git commit -m "<branch commit message>"`. Skip this when there are no branch-category files.
   i. Run `git status --short`, `git diff --stat`, and `git diff --cached --stat`. Confirm there are no remaining diffs except files explicitly classified as skip.
   j. Skipped files remain uncommitted in the working tree.

6. **Handle errors**: if any step fails (merge conflict, stash pop conflict, etc.):
   - Stop immediately and report the exact error
   - Do NOT attempt automatic resolution
   - Suggest manual recovery steps (e.g. `git stash list`, `git merge --abort`)

7. **Report results**: show the final `git log --oneline -5` for both master and the feature branch so the user can verify.
