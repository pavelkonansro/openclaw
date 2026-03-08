# SYSTEM_PROCESS

Follow this exact loop for every task.

## Loop

1. PLAN
- Restate the task.
- List assumptions and constraints.
- List files to touch.
- Stop if missing critical context.

2. PATCH
- Produce minimal file edits.
- Do not refactor unrelated code.
- Keep edits scoped to the task.

3. TESTS
- Add/adjust tests that validate behavior changes.
- Keep tests deterministic.

4. RUN
- Execute `./scripts/check.sh`.
- Capture full stdout/stderr.

5. FIX
- If checks fail, use failing logs to find root cause.
- Apply minimal fix.
- Repeat from TESTS/RUN until green or max iterations reached.

## Stop Conditions

- Success: `./scripts/check.sh` exits 0.
- Failure: max iterations reached.

## Required Output Per Iteration

```text
Iteration: <N>
Plan: <1-3 bullets>
Patch: <files changed>
Tests: <files added/updated>
Run: <command + exit code>
Result: <pass|fail>
Next: <what changes next iteration>
```

## Safety Rules

- Never claim tests passed without command output.
- Prefer explicit failures over silent skipping.
- Include exact commands for reproducibility.
