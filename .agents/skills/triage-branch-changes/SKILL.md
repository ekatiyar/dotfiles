---
name: triage-branch-changes
description: Classify uncommitted dotfile changes across all local branches, then commit each set to the branch that owns it
disable-model-invocation: true
---

# Triage Branch Changes

## Steps

1. Stop if the tree is clean. Otherwise fetch, and fast-forward every local branch that tracks a remote. Report any branch that won't fast-forward and stop.

2. Work out what each local branch is for, from its name and its recent commits. Every one is a candidate target, not just the default/master branch and the one you are on.

3. **Classify each changed file** as **master** (shared: `.claude/` skills/settings, shell configs, `.gitconfig`, etc.), **branch** (specific to a given branch's function), or **skip** (transient scratch/state files). Split by hunk when one file mixes categories, and compare it across the branches first so existing branch-specific content stays branch-specific. When uncertain, default to branch — it can always be cherry-picked to master later.

4. **Present the classification** as a table with proposed commit messages, and **ask for approval**.

   | File / hunk | Branch | Reason |

   Group the table by branch, shared first and **skip** last, and flag anything you were unsure about. Follow it with every commit you intend to make, in order, grouped under the branch each one lands on, with its full message, including any merge between branches. Let the user re-classify anything before you proceed.

5. **Execute**: stash everything (`--include-untracked`), commit the approved master files/hunks on master, merge master back into the feature branch, then restore and commit the approved branch files/hunks. Skipped changes stay uncommitted. Verify with `git status` that nothing unexpected remains.

   Before popping or dropping the stash, compare every originally tracked path with the feature branch's committed plus working-tree state (`git diff --exit-code stash@{0} -- <paths>`), and compare every originally untracked file with its copy in the stash's **third parent** (`git show stash@{0}^3:<path> | diff - <path>`). If every comparison is clean, drop the stash without popping; otherwise restore the missing changes first.

   **DO NOT** push, resolve a conflict on your own, or commit anything classified **skip**.

6. **On any failure** (merge/pop conflict): stop, report the exact error, and suggest manual recovery steps — do NOT attempt automatic resolution.

7. **Report** the final `git log --oneline -5` for every branch you touched, and confirm `git status` shows only the **skip** changes, the triage stash is gone, and any pre-existing stashes are unchanged.
