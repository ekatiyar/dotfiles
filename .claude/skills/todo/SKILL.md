---
name: todo
description: Find all TODO(claude) comments (any case) in the repo, group them, and present an ExitPlanMode plan to address them
disable-model-invocation: true
---


# TODO(claude) Workflow

1. **Find all TODOs**: scan all tracked files for case-insensitive `TODO(claude)` markers:
   ```bash
   rg -i 'todo\(claude\)' --line-number
   ```
   If none are found, stop and tell the user.

2. **Plan**: use ExitPlanMode to present a plan that:
   - Groups related TODOs together (e.g. TODOs in the same file or feature area)
   - Proposes a concrete change for each TODO
   - Lists which test files will be run to verify
   - Flags any TODOs that need clarification before implementation
