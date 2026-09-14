---
name: commit-changes
description: Split staged changes into grouped commits modeled after the author's own commit history
disable-model-invocation: true
---

# Commit Changes

## Steps

1. Stop if nothing is staged, or there are unstaged files present. Otherwise read `git diff --staged`

2. **Group the changed files by concern** — one reviewable idea per commit: a bug fix, a feature, a test-infra change. Order the groups so each commits after anything it depends on (a test after the source change it exercises). Trivial changes should be folded into the nearest substantive commit, or grouped together into fewer commits.

3. Take a look at the author's own commits in the touched paths (`git log --author="$(git config user.name)" --no-merges --format='%s%n%b%n--' -20 -- <paths>`, widened to the whole repo if that is thin). Model your commit messages after their writing style, verbosity, and scope.

4. **Present the grouping** as a table, with the commit message drafted for each group, and **ask for approval**:

   | File | Commit group | Reason |

   Follow it with every commit in order with its full message, flag anything you were unsure about, and let the user re-group, reorder, or correct the wording before you proceed.

5. **Execute** each approved group in order with `git commit -m "<message>" -- <paths>`, which commits those paths' working-tree content and leaves the rest of the index untouched.

   **DO NOT** push, pass `--no-verify`, amend, or rebase. On any failure, stop and report the error.

6. **Report** `git log --oneline -N` (N = number of groups) and confirm every commit carries the approved order and message, and that `git diff --staged` is empty.
