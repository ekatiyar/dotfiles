---
name: triage-branch-changes
description: Classify uncommitted dotfile changes across all local branches, then commit each set to the branch that owns it
disable-model-invocation: true
---

# Triage Branch Changes

## Steps

1. Stop if the tree is clean. Otherwise fetch, and fast-forward every local branch that tracks a remote. Report any branch that won't fast-forward and stop.

2. Work out what each local branch is for, from its name and its recent commits. Every one is a candidate target, not just the default/master branch and the one you are on.

3. **Classify each changed file** as **master** (shared: `.claude/` skills/settings, shell configs, `.gitconfig`, etc.), **branch** (specific to a given branch's function), or **skip** (transient scratch/state files). When uncertain, default to branch — it can always be cherry-picked to master later.

4. **Present the classification** as a table with proposed commit messages, and **ask for approval**.

   | File | Branch | Reason |

   Group the table by branch, shared first and **skip** last, and flag anything you were unsure about. Follow it with every commit you intend to make, in order, grouped under the branch each one lands on, with its full message, including any merge between branches. Let the user re-classify anything before you proceed.

5. **Execute**: stash everything (`--include-untracked`), commit the master set on master, merge master back into the feature branch, then restore and commit the branch set. Skipped files stay uncommitted. Verify with `git status` that nothing unexpected remains.

   Gotchas: untracked files live in the stash's **third parent** — restore with `git checkout stash@{0}^3 -- <file>`, not `stash@{0}`. If all changes were master-category, `git stash pop` fails with "already exists, no checkout" because the merge already brought them in — this is expected; verify the content is present and `git stash drop`.

   **DO NOT** push, resolve a conflict on your own, or commit anything classified **skip**.

6. **On any failure** (merge/pop conflict): stop, report the exact error, and suggest manual recovery steps — do NOT attempt automatic resolution.

7. **Report** the final `git log --oneline -5` for every branch you touched, and confirm `git status` shows only the **skip** files and `git stash list` is empty.
