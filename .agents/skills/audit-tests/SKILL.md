---
name: audit-tests
description: Identify and repair tautological tests, source-text substitutes for behavioral tests, and mocks that hide real failure modes.
disable-model-invocation: true
---

# Audit Tests

## Steps

1. Read the scoped tests, production code, and requirements. Identify the behavior each test should protect; flag unclear requirements.

2. Check every scoped test against the patterns below. Support each finding with a regression it would miss or a behavior-preserving refactor that would break it.

3. Present findings by missed-regression risk and ask for approval unless the repairs are already authorized:

   | Test / location | Pattern and evidence | Behavior to protect | Proposed repair |
   | --- | --- | --- | --- |

   Include deletions, production changes, verification, and unresolved questions. For review-only requests, stop here.

4. Apply approved repairs, preserving meaningful coverage.

   **DO NOT** change expectations to match a bug or remove meaningful coverage to make tests pass. Report production bugs exposed by valid tests.

5. Verify replacements catch their intended regressions, using temporary, reversible mutations where practical. Run the affected suite. Report changes, test results, and any unverified failure modes.

## Patterns

### Tautological tests

Look for assertions that repeat internal constants, reconstruct the implementation, or calculate expected results using the same logic under test.

Derive expectations from the contract and assert observable outcomes. For a character limit, test acceptance at the boundary and rejection beyond it instead of merely asserting the constant's value.

A literal assertion is valid when the value itself is a required public contract. Establish that distinction before flagging it.

### Source-text substitutes

Look for tests that read implementation files and assert string presence, ordering, or spelling as a proxy for runtime behavior.

Execute the behavior instead. For UI order, render the component and inspect the relevant DOM or browser layout, according to what the requirement actually promises.

Source inspection is appropriate when source structure itself is the contract, such as an architectural restriction. Distinguish that from a runtime claim.

### Mocks that hide failures

Trace what the test executes and what its doubles replace. Identify relevant dependency errors, state transitions, and lifecycle constraints that the doubles cannot represent.

Keep the behavior under test real. Model relevant failures at dependency boundaries and assert the application's response. Use an integration or browser test when correctness depends on behavior the fake cannot faithfully represent.

Mocking alone is not a finding. Name the specific failure mode being concealed and the evidence that it matters. Report remaining fidelity gaps when the real environment is unavailable.
