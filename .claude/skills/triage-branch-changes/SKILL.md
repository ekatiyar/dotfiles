---
name: triage-branch-changes
description: Classify uncommitted dotfile changes across all local branches, then commit each set to the branch that owns it
disable-model-invocation: true
---

# Triage Branch Changes

## Steps

1. Stop if the tree is clean. Otherwise fetch, and fast-forward every local branch that tracks a remote. Report any branch that won't fast-forward and stop.

2. Work out what each local branch is for, from its name and its recent commits. Every one is a candidate target, not just the default branch and the one you are on.

3. Classify every uncommitted change (staged, unstaged, untracked) onto one branch, or **skip**:
   - Config that every branch benefits from → the shared default branch.
   - Anything belonging to a branch's concern → that branch, even when it lives in shared-looking config.
   - Scratch files, logs, editor swap files → **skip**; they stay uncommitted.
   - `.gitmodules` and submodule pointer bumps → always flag; `git stash` does not recurse into submodules, so a bump rides along on every branch switch.
   - When uncertain, prefer the narrower branch over the shared one.

4. Present one approval gate and wait for it (via ExitPlanMode when in plan mode):

   | File | Branch | Reason |

   Group the table by branch, shared first and **skip** last, and flag anything you were unsure about. Follow it with every commit you intend to make, in order, grouped under the branch each one lands on, with its full message, including any merge between branches. Let the user re-classify anything before you proceed.

5. Commit. When everything lands on the branch you are already on, just commit it and skip the rest of this step.
   a. Stash everything, including untracked files.
   b. For each target branch, shared first: check it out, restore that branch's files from the stash, then commit. Tracked files come back with `git checkout stash@{0} -- <file>`; untracked ones live in the stash's third parent, so those need `stash@{0}^3 -- <file>`. Deletions do not come back from the stash at all — replay them with `git rm`, and treat a rename as its delete and add halves.
   c. Return to the branch you started on, and merge in any branch whose changes it should carry.
   d. `git stash pop` to bring the **skip** files back. A pop that fails with `already exists, no checkout` means a merge already carried the committed content in — confirm the skip files are in the working tree and the committed content is present, then `git stash drop`.

   **DO NOT** push, resolve a conflict on your own, or commit anything classified **skip**.

6. On any failure, stop and report the exact error with recovery hints (`git stash list`, `git merge --abort`). Do not attempt to fix it.

7. Report `git log --oneline -5` for every branch you touched, and confirm `git status` shows only the **skip** files and `git stash list` is empty.
