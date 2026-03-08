#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TASK="${TASK:-${1:-}}"
MAX_ITERATIONS="${MAX_ITERATIONS:-${2:-5}}"
PLANNER_AGENT="${PLANNER_AGENT:-architect}"
IMPLEMENTER_AGENT="${IMPLEMENTER_AGENT:-builder}"
TESTWRITER_AGENT="${TESTWRITER_AGENT:-builder}"
FIXER_AGENT="${FIXER_AGENT:-builder}"
OPENCLAW_CMD="${OPENCLAW_CMD:-openclaw}"
read -r -a OPENCLAW_CMD_ARR <<<"$OPENCLAW_CMD"

if [[ -z "$TASK" ]]; then
  echo "ERROR: TASK is required."
  echo "Set TASK env var or pass as first argument."
  exit 1
fi

if [[ "${#OPENCLAW_CMD_ARR[@]}" -eq 0 ]]; then
  echo "ERROR: OPENCLAW_CMD is empty."
  exit 1
fi

if ! "${OPENCLAW_CMD_ARR[@]}" --help >/dev/null 2>&1; then
  echo "ERROR: OpenClaw CLI command is not runnable."
  echo "Current OPENCLAW_CMD: $OPENCLAW_CMD"
  echo "Example (docker): OPENCLAW_CMD='docker compose run --rm openclaw-cli'"
  exit 1
fi

if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: MAX_ITERATIONS must be an integer."
  exit 1
fi

REPORT_DIR=".openclaw/reports/dev-loop"
STATE_DIR=".openclaw/dev-loop"
mkdir -p "$REPORT_DIR" "$STATE_DIR"

CHECK_LOG_LAST="$STATE_DIR/check.last.log"
: > "$CHECK_LOG_LAST"

run_agent_step() {
  local role="$1"
  local agent_id="$2"
  local prompt_file="$3"
  local out_file="$4"
  local err_file="$5"

  local message
  message="$(cat "$prompt_file")"

  echo "[$role] agent=$agent_id"
  if ! "${OPENCLAW_CMD_ARR[@]}" agent --agent "$agent_id" --message "$message" >"$out_file" 2>"$err_file"; then
    echo "[$role] failed; see $err_file"
    return 1
  fi
  return 0
}

for i in $(seq 1 "$MAX_ITERATIONS"); do
  ITER_DIR="$STATE_DIR/iter-$i"
  mkdir -p "$ITER_DIR"

  PLAN_PROMPT="$ITER_DIR/planner.prompt.txt"
  IMPL_PROMPT="$ITER_DIR/implementer.prompt.txt"
  TEST_PROMPT="$ITER_DIR/testwriter.prompt.txt"
  FIX_PROMPT="$ITER_DIR/fixer.prompt.txt"

  PLAN_OUT="$ITER_DIR/planner.out.txt"
  PLAN_ERR="$ITER_DIR/planner.err.txt"
  IMPL_OUT="$ITER_DIR/implementer.out.txt"
  IMPL_ERR="$ITER_DIR/implementer.err.txt"
  TEST_OUT="$ITER_DIR/testwriter.out.txt"
  TEST_ERR="$ITER_DIR/testwriter.err.txt"
  FIX_OUT="$ITER_DIR/fixer.out.txt"
  FIX_ERR="$ITER_DIR/fixer.err.txt"

  REPORT_FILE="$REPORT_DIR/iteration-$i.md"

  cat >"$PLAN_PROMPT" <<EOF_PLAN
You are Planner in a dev loop.
Task: $TASK
Return a concise actionable plan (max 7 bullets) for this iteration only.
Focus on minimal diffs.
EOF_PLAN

  if ! run_agent_step "Planner" "$PLANNER_AGENT" "$PLAN_PROMPT" "$PLAN_OUT" "$PLAN_ERR"; then
    {
      echo "# Iteration $i"
      echo
      echo "- Result: fail"
      echo "- Stage: Planner"
      echo "- Error file: $PLAN_ERR"
    } >"$REPORT_FILE"
    exit 1
  fi

  cat >"$IMPL_PROMPT" <<EOF_IMPL
You are Implementer in a dev loop.
Task: $TASK
Plan:
$(cat "$PLAN_OUT")
Apply minimal code changes now.
Do not run broad refactors.
EOF_IMPL

  if ! run_agent_step "Implementer" "$IMPLEMENTER_AGENT" "$IMPL_PROMPT" "$IMPL_OUT" "$IMPL_ERR"; then
    {
      echo "# Iteration $i"
      echo
      echo "- Result: fail"
      echo "- Stage: Implementer"
      echo "- Error file: $IMPL_ERR"
    } >"$REPORT_FILE"
    exit 1
  fi

  cat >"$TEST_PROMPT" <<EOF_TEST
You are TestWriter in a dev loop.
Task: $TASK
Plan:
$(cat "$PLAN_OUT")
Implementer output:
$(cat "$IMPL_OUT")
Add or update tests for changed behavior.
Keep tests deterministic and minimal.
EOF_TEST

  if ! run_agent_step "TestWriter" "$TESTWRITER_AGENT" "$TEST_PROMPT" "$TEST_OUT" "$TEST_ERR"; then
    {
      echo "# Iteration $i"
      echo
      echo "- Result: fail"
      echo "- Stage: TestWriter"
      echo "- Error file: $TEST_ERR"
    } >"$REPORT_FILE"
    exit 1
  fi

  CHECK_EXIT=0
  ./scripts/check.sh >"$CHECK_LOG_LAST" 2>&1 || CHECK_EXIT=$?

  {
    echo "# Iteration $i"
    echo
    echo "## Summary"
    if [[ $CHECK_EXIT -eq 0 ]]; then
      echo "- Result: pass"
    else
      echo "- Result: fail"
    fi
    echo "- Task: $TASK"
    echo "- Command: ./scripts/check.sh"
    echo "- Exit code: $CHECK_EXIT"
    echo
    echo "## Changed Files"
    git status --short || true
    echo
    echo "## Planner Output"
    echo '```text'
    cat "$PLAN_OUT"
    echo '```'
    echo
    echo "## Implementer Output"
    echo '```text'
    cat "$IMPL_OUT"
    echo '```'
    echo
    echo "## TestWriter Output"
    echo '```text'
    cat "$TEST_OUT"
    echo '```'
    echo
    echo "## Check Log Tail"
    echo '```text'
    tail -n 120 "$CHECK_LOG_LAST"
    echo '```'
  } >"$REPORT_FILE"

  if [[ $CHECK_EXIT -eq 0 ]]; then
    echo "Dev loop succeeded at iteration $i"
    echo "Report: $REPORT_FILE"
    exit 0
  fi

  if [[ "$i" -lt "$MAX_ITERATIONS" ]]; then
    cat >"$FIX_PROMPT" <<EOF_FIX
You are Fixer in a dev loop.
Task: $TASK
Current failure from ./scripts/check.sh:
$(cat "$CHECK_LOG_LAST")
Apply the minimal code fix and keep the solution scoped.
EOF_FIX

    if ! run_agent_step "Fixer" "$FIXER_AGENT" "$FIX_PROMPT" "$FIX_OUT" "$FIX_ERR"; then
      {
        echo "# Iteration $i"
        echo
        echo "- Result: fail"
        echo "- Stage: Fixer"
        echo "- Error file: $FIX_ERR"
      } >>"$REPORT_FILE"
      exit 1
    fi

    {
      echo
      echo "## Fixer Output"
      echo '```text'
      cat "$FIX_OUT"
      echo '```'
    } >>"$REPORT_FILE"
  fi

done

echo "Dev loop failed after $MAX_ITERATIONS iterations"
echo "Last check log: $CHECK_LOG_LAST"
exit 1
