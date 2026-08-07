---
name: trim-comments
description: Review comments added in the current diff, trim or delete the extraneous ones, and fold any changelog-style notes into a suggested commit message
disable-model-invocation: true
---

# Trim Comments

Hold the comments added in the current diff to the standard in CLAUDE.md, and recycle context and changelogs into the commit message.

## Steps

1. Collect the comments added in the current diff. Leave pre-existing comments and submodules alone.

2. Classify each against the code it sits on: **delete**, **trim** (one line of "why" it survives), **changelog** (strip it, but carry the text into step 3), or **keep**. Functional directives and `TODO`/`FIXME` markers stay.

3. Present the proposed edits and **ask for approval**:

   | File:line | Action | Comment | Replacement |

   Group by file, ordered `delete` first, then `trim` and `changelog`, and flag anything you were unsure about. 
   
   Follow the table with a SUGGESTED commit message carrying the changelog rationale — do NOT commit even after plan approval.

4. Apply — comment-only edits, never touching code or its formatting.

5. Report counts, and confirm the diff shows comment-only hunks.
