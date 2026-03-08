# LLM Development Workflow (Plan -> Patch -> Tests -> Run -> Fix)

This repository uses a single repeatable loop for LLM-assisted changes:

1. **Plan**: understand task, constraints, and touched files.
2. **Patch**: apply minimal code edits.
3. **Tests**: add or update focused tests.
4. **Run**: execute the full repository gate (`./scripts/check.sh`).
5. **Fix**: use failures to make minimal corrections and repeat.

The loop ends only when checks pass or max iterations are reached.

## Canonical Check Command

Use:

```bash
./scripts/check.sh
```

This script validates both stacks in one place:

- Python: `pytest`, `ruff check .`, `black --check .`, and `mypy .` if configured.
- JavaScript: `npm test`, `npm run lint`, and `npm run typecheck` if present.

The script is fail-fast and explicit. Missing required tools fail with install guidance.

## Prompt Governance Files

Use these files as policy inputs for any LLM agent:

- `prompts/SYSTEM_PROCESS.md`
- `prompts/PATCH_FORMAT.md`
- `prompts/TESTS.md`
- `prompts/BUGFIX.md`

## Iteration Reporting Contract

Each loop iteration should produce:

- iteration number
- short plan bullets
- changed files
- tests added/changed
- run command and exit code
- fail/pass result
- next action

## OpenClaw Dev Loop

`workflows/dev-loop.lobster.yaml` is the workflow definition.

`scripts/dev-loop-runner.sh` executes the iterative process with role steps:

- Planner
- Implementer
- TestWriter
- Runner
- Fixer

The runner writes markdown reports to:

- `.openclaw/reports/dev-loop/iteration-<N>.md`

and stops when:

- `./scripts/check.sh` succeeds, or
- `MAX_ITERATIONS` is reached (default `5`).

## Expected Operator Usage

1. Ensure OpenClaw CLI and gateway are available.
2. Ensure `lobster` CLI is installed and on `PATH` on the gateway host.
3. Enable `lobster` plugin/tool in OpenClaw config.
4. Invoke `dev-loop` with a concrete task.

See `openclaw/dev-loop/openclaw.config.json5` and `openclaw/dev-loop/README.md` for exact commands.
