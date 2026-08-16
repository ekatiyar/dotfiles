---
name: make-skill
description: Write a new skill matching this repo's conventions for structure, length, and tone. Use when asked to create, add, or scaffold a skill.
---

# Make Skill

## Steps

1. Read the existing skills. Match their structure, tone, and length; they are the spec.

2. Draft it with intent and constraints, not mechanics. Instruct rather than rationalize, and skip any intro line that only restates the frontmatter.

3. Pin down what a model shouldn't guess: user-facing output — tables, ordering, what to flag. Then ask whether the skill should be model-invocable

4. Give the skill one approval gate that shows everything known by that point rather than holding output back for a later step, and mark whatever must not happen even after approval with an explicit **DO NOT**. Close it with a report/verify step.

5. Present the full draft, its path, and the frontmatter decisions for approval.

6. Write the file, then have a subagent review it cold against this skill — bubble up the findings from the review — and apply what the user finds valid.
