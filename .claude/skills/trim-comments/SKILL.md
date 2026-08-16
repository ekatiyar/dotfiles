---
name: trim-comments
description: Review comments added in the current diff, trim or delete the extraneous ones, and fold any changelog-style notes into a suggested commit message
disable-model-invocation: true
---

# Trim Comments

## Steps

1. Collect the comments added in the current diff. Leave pre-existing comments alone unless specificied otherwise by the user.

2. Classify each against the code it sits on and the standard in CLAUDE.md: **delete**, **trim** (one line of "why" it survives), **changelog** (strip it, but carry the text into commit message), or **keep**. Functional directives and `TODO`/`FIXME` markers stay.

3. Present the proposed edits and **ask for approval**:

   | File:line | Action | Comment | Replacement |

   Group by file, ordered `delete` first, then `trim` and `changelog`, and flag anything you were unsure about. 
   
   Follow the table with a SUGGESTED commit message carrying the changelog rationale

4. Apply — comment-only edits, never touching code.

5. Report counts, and confirm the diff shows comment-only hunks.

6. Prompt the user to approve the commit
