---
name: trim-prose
description: Cleanup user-selected prose - code comments, documents, etc
disable-model-invocation: true
---

# Trim Prose

In addition to the following instructions, when reviewing human-facing prose, invoke the `unslop` skill and apply its rules as well.

## Steps

1. Establish the requested scope. Review only the named prose, files, sections, or diff. For diff reviews, default to newly added prose unless the user asks for existing text too.

2. Read the surrounding prose, its audience, and its local style. Prefer direct wording. Delete redundancy, narration, stale context, and jargon. Keep the result focused on the current task and intended reader. Preserve meaning and any detail needed to understand or act on the text.

3. Classify each item exactly once as **delete**, **trim**, **rewrite**, **changelog**, **keep**, or **flag**:
    - **delete**: Delete text that is redundant or obvious from its context.
    - **trim**: Trim necessary rationale to its clearest short form.
    - **rewrite**: Rewrite unclear or overly verbose text.
    - **changelog**: Remove historicization from the prose, moving the useful bits into a suggested commit or PR message.
    - **keep**: Keep functional directives, `TODO`/`FIXME` markers, and non-obvious rationale
    - **flag**: Use `flag` when the intended action is unclear; state the ambiguity and escalate to the user.

4. If any item is **flag**, stop before applying edits and escalate each ambiguity to the user. If there aren't any **flag** items, proceed with the next step without requiring user input.

5. Apply the classified actions. Leave **keep** items unchanged. Do not expand the scope, change executable behavior, or alter syntax or semantics outside the requested prose changes.

6. Report what changed and any unresolved uncertainty. Verify that only the requested prose changed. For deleted historicizing comments, provide a suggested commit message derived from their useful context. Do not commit until the user approves the commit message.
