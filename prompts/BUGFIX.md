# BUGFIX

## Failure-Driven Fix Process

1. Read the exact failing command and stack trace.
2. Identify the first actionable failure point.
3. Find root cause in source (not just symptom).
4. Apply the smallest safe fix.
5. Re-run checks.

## Root Cause Notes (required)

For each fix, record:
- failing command
- failing file/line
- root cause
- why the chosen fix is minimal and correct

## Anti-Patterns

- Do not mask failures with broad try/catch.
- Do not skip tests to get green.
- Do not introduce fallback behavior without requirement.
