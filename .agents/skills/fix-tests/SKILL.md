---
name: fix-tests
description: Fix failing tests by running the project's test suite, reading failures, and updating test expectations
disable-model-invocation: true
---

# Fix Failing Tests

1. Run the failing tests with the project's test runner (verbose output with a short traceback where supported) to identify failures.
2. Read ONLY the failing test files and the specific source lines referenced in tracebacks.
3. Modify ONLY test files -- never change source/production code unless the bug is clearly in production code.
4. Update test expectations/data to match current source behavior.
5. Re-run the failing tests. Repeat until green.
6. If stuck on the same failure, stop and explain the blocker.
7. Report: tests fixed, total passing, what changed and why.
