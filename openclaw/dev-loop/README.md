# OpenClaw Dev Loop

This setup runs a deterministic iterative development loop through Lobster.

## Prerequisites

- `openclaw` CLI installed and gateway reachable.
- `lobster` CLI installed on the same host and available on `PATH`.
- Repository check command exists: `./scripts/check.sh`.

## Enable Plugin + Tool

```bash
openclaw plugins enable lobster
openclaw config set tools.alsoAllow '["lobster"]'
```

If you use per-agent tool policies, also allow Lobster on the agents you use:

```bash
openclaw config set agents.list.1.tools.alsoAllow '["lobster"]'
openclaw config set agents.list.2.tools.alsoAllow '["lobster"]'
```

## Run the Workflow

From repo root, call Lobster through OpenClaw:

```bash
openclaw agent --agent architect --message "Run the lobster tool with action=run, pipeline=workflows/dev-loop.lobster.yaml, argsJson={\"task\":\"<TASK>\",\"max_iterations\":5}."
```

If OpenClaw runs in Docker, run the loop with:

```bash
OPENCLAW_CMD='docker compose run --rm openclaw-cli' \
MAX_ITERATIONS=1 \
TASK='Тест пайплайна dev-loop' \
./scripts/dev-loop-runner.sh
```

If your environment supports direct Lobster invocation, this is equivalent:

```bash
lobster run --mode tool workflows/dev-loop.lobster.yaml --args-json '{"task":"<TASK>","max_iterations":5}'
```

## Reports

Per-iteration reports are written to:

- `.openclaw/reports/dev-loop/iteration-<N>.md`

Each report includes:

- changed files (`git status --short` snapshot)
- stage outputs (Planner/Implementer/TestWriter/Fixer)
- `./scripts/check.sh` result and log tail
