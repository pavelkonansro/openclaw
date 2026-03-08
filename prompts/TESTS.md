# TESTS

## Pytest Rules

- Prefer unit tests over broad integration tests.
- Use fixtures for setup; avoid global mutable state.
- No network calls in unit tests.
- Freeze time or random seeds when needed.
- Assert observable behavior, not internals.

## Coverage Expectations

- Add tests for new branches and error paths touched by the patch.
- Keep scope proportional to change size.

## Determinism Checklist

- Stable ordering in assertions.
- No dependency on wall clock unless mocked.
- No dependency on external services.

## Execution

- Run the repository gate via `./scripts/check.sh`.
- If a subset is needed while iterating, still run the full check before done.
