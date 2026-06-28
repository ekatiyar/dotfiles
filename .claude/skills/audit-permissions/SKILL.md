---
name: audit-permissions
description: Audit all .claude configs (permissions, MCPs, skills, commands) and suggest consolidation
allowed-tools: Bash(find:*), Bash(ls:*), Read, Glob
disable-model-invocation: true
---

# Audit Claude Code Configuration

Scan all `.claude` directories, report everything configured (permissions, MCP servers, skills, commands), then propose a consolidation plan.

## Steps

1. **Discover all `.claude` directories** under `$HOME`:
   ```bash
   find "$HOME" -name ".claude" -type d 2>/dev/null
   ```

2. **Inventory each `.claude` directory** — for each one found, list all contents recursively and categorize:
   - **Permission files**: `settings.json`, `settings.local.json`, any `projects/**/settings*.json`
   - **MCP configs**: `.mcp.json` or any file containing MCP server definitions
   - **Skills**: `skills/*/SKILL.md`
   - **Commands**: `commands/*.md`
   - **Other**: `CLAUDE.md`, agents, or anything else present

3. **Read and extract details from each file**:
   - For permission files: extract `permissions.allow`, `permissions.deny`, and `permissions.ask` arrays
   - For MCP configs: extract server names, transport types, and what tools they provide
   - For skills/commands: extract name, description, and allowed-tools from frontmatter

4. **Identify the scope** of each file:
   - `~/.claude/settings.json` (or its symlink target) → **user-level global**
   - `<project>/.claude/settings.json` → **project-level shared** (committed to repo)
   - `<project>/.claude/settings.local.json` → **project-level local** (not committed)
   - `~/.claude/skills/` or `~/.claude/commands/` → **user-level global**
   - `<project>/.claude/skills/` or `<project>/.claude/commands/` → **project-level**

5. **Present a report** with sections for each category:
   - **Permissions**: markdown table grouped by scope, listing every permission and which file it comes from
   - **MCP Servers**: table of server names, scope, and transport type
   - **Skills**: table of skill names, scope, and description
   - **Commands**: table of command names, scope, and description

6. **Propose a consolidation plan**:
   - Permissions appearing in 2+ project-local files → candidates to move to global `settings.json`
   - MCP servers used across multiple projects → candidates to move to global `.mcp.json`
   - Skills/commands that are generic → candidates to move to user-level `~/.claude/skills/` or `~/.claude/commands/`
   - Flag duplicates where a project-local file re-grants something already in the global config
   - Flag any permissions that appear in both `allow` and `deny` across different scopes (conflicts)
   - Note items that are correctly project-specific and should stay where they are
   - Present the plan as a numbered list of proposed changes with rationale for each

7. **Ask the user** which changes (if any) they want applied before making edits.
