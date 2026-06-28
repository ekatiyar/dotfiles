# Best Practices
- When possible, use TDD: write the tests first, validating the failure is as expected, then write the implementation/fix, then rerunning tests after.

## Git Practices

- Pre-commit hooks handle formatting - don't run manual linting
- Keep commit messages simple and descriptive
- Standard flow: `git add` -> `git commit` -> if hooks modify files -> `git add` -> `git commit` again
- Don't fetch github URLs directly; use the `gh` CLI or GitHub MCP tools (`mcp__github__*`) if available.

# Environment

- Use `$TMPDIR` for temporary files when it is set; otherwise fall back to `/tmp`
