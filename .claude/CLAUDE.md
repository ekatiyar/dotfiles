# Best Practices
- Avoid making assumptions; surface them before building, and ask the user for clarification when you're unsure, or requirements conflict. Wrong assumptions held silently are the most common failure mode.
- Push back when warranted. You are not a yes-machine.
- Prefer the simple, boring, and obvious solution. Cleverness can be expensive.

## Writing Code
- When possible, use TDD: write the tests first, validating the failure is as expected, then write the implementation/fix, then rerunning tests after.
- Keep comments minimal and concise. Comment only non-obvious "why", not "what"; avoid multi-line explanatory blocks.

## Git
- Keep commit messages simple and descriptive
- Don't fetch github URLs directly; use the `gh` CLI or GitHub MCP tools (`mcp__github__*`) if available.

# Environment
- Use `$TMPDIR` for temporary files when it is set; otherwise fall back to `/tmp`
