---
name: audit-permissions
description: Audit all .claude configs (permissions, MCPs, skills, commands) and suggest consolidation
disable-model-invocation: true
---

# Audit Claude Code Configuration

Scan all `.claude` directories, report everything configured, then propose a consolidation plan.

1. **Discover**: find every `.claude` directory under `~`.

2. **Inventory**: read each directory's settings files, MCP configs, skills, and commands, noting the scope of each (user-level global vs. project-level shared `settings.json` vs. project-level local `settings.local.json`).

3. **Report** tables per category (permissions, MCP servers, skills, commands) showing each item, its scope, and source file.

4. **Propose consolidation**: items duplicated across projects → candidates for the global scope; flag redundant re-grants and allow/deny conflicts; note what is correctly project-specific. Present as a numbered plan with rationale.

5. **Ask the user** which changes to apply before making any edits.
