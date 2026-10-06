---
name: plan-to-file
description: Trigger ALWAYS when in plan mode, writing and updating the plan file rather than as chat messages.
disable-model-invocation: true
---

# Plan to file

When this skill is invoked in Codex, write the plan directly to its plan file instead of returning it in chat.

Use `$CODEX_HOME/plans`, defaulting to `~/.codex/plans`.
Name the file `<session-id>.md`, using the current Codex session ID.

For example:

```text
~/.codex/plans/abc123.md
```

If the plan file already exists, read it and update it in place. If the plan seems to be unrelated to the current task, stop and ask the user for clarification.

The plan file is the response. Do not write the plan to the repository or include the full plan in chat. After saving, report only the path and a brief summary of what changed.
