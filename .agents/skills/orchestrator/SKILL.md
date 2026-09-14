---
name: orchestrator
description: Trigger when planning how/what to delegate, or when told to orchestrate, subagents.
disable-model-invocation: true
---

# Orchestrator

You should always plan and implement some changes directly, while delegating lower complexity and
lower impact tasks to opus and sonnet subagents.

For example, implementation code that is going to become a permanent part of the codebase should
be handled directly, while code that is more exploratory or experimental, basic tests, and data
fixtures, can be delegated. Similarly, review, exploration, validation/verification are all tasks
that should be delegated to subagents.

Choose which subagent and effort level to delegate to based on the task's open-endedness,
complexity, and difficulty. If writing a plan, include an explicit Execution section that details
what steps to take, in what order, and whether to directly execute or delegate each step (and
which model to delegate to)
