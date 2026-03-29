#!/bin/bash
set -uo pipefail

# Runs all skill evals and reports results.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

TOTAL=0
PASSED=0
FAILED=0
RESULTS=()

run_eval() {
  local skill="$1"
  local fixture="$2"
  TOTAL=$((TOTAL + 1))

  echo ""
  echo "========================================"
  echo "  EVAL: $skill / $fixture"
  echo "========================================"
  echo ""

  if "$SCRIPT_DIR/run-eval.sh" "$skill" "$fixture"; then
    PASSED=$((PASSED + 1))
    RESULTS+=("PASS  $skill / $fixture")
  else
    FAILED=$((FAILED + 1))
    RESULTS+=("FAIL  $skill / $fixture")
  fi
}

# ─── lingui/setup evals ───
run_eval "lingui/setup" "nextjs-app-router"
run_eval "lingui/setup" "vite-swc"
run_eval "lingui/setup" "vite-babel"
run_eval "lingui/setup" "shadcn-admin"

# ─── lingui/translate evals ───
run_translate_eval() {
  local fixture="$1"
  TOTAL=$((TOTAL + 1))

  echo ""
  echo "========================================"
  echo "  EVAL: lingui/translate / $fixture"
  echo "========================================"
  echo ""

  if "$SCRIPT_DIR/run-eval-translate.sh" "$fixture"; then
    PASSED=$((PASSED + 1))
    RESULTS+=("PASS  lingui/translate / $fixture")
  else
    FAILED=$((FAILED + 1))
    RESULTS+=("FAIL  lingui/translate / $fixture")
  fi
}

run_translate_eval "nextjs-app-router"
run_translate_eval "vite-swc"
run_translate_eval "vite-babel"
run_translate_eval "shadcn-admin"

# ─── Summary ───
echo ""
echo "========================================"
echo "  ALL EVALS COMPLETE"
echo "========================================"
echo ""
for r in "${RESULTS[@]}"; do
  echo "  $r"
done
echo ""
echo "  Total: $TOTAL  Passed: $PASSED  Failed: $FAILED"
echo "========================================"

if [ $FAILED -gt 0 ]; then
  exit 1
fi
