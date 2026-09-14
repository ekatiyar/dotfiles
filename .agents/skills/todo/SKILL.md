---
name: todo
description: Find all TODO(agent) comments (any case) in the repo, group them, and present a plan to address them
disable-model-invocation: true
---


# TODO(agent) Workflow

1. **Find all TODOs**: scan all tracked files for case-insensitive `TODO(agent)` markers:
   ```bash
   rg -i 'todo\(agent\)' --line-number --hidden --glob '!.git'
   ```
   If none are found, stop and tell the user.

2. **Plan**: Present a plan that:
   - Groups related TODOs together (e.g. TODOs in the same file or feature area)
   - Proposes a concrete change for each TODO
   - Lists which test files will be run to verify
   - Flags any TODOs that need clarification before implementation
