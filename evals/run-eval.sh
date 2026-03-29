#!/bin/bash
set -euo pipefail

# Usage: ./evals/run-eval.sh <skill-dir> <fixture-name>
# Example: ./evals/run-eval.sh lingui/setup nextjs-app-router
#
# Runs a skill against a fixture project using Claude Code headlessly,
# then verifies the result.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILL_DIR="${1:?Usage: run-eval.sh <skill-dir> <fixture-name>}"
FIXTURE="${2:?Usage: run-eval.sh <skill-dir> <fixture-name>}"

# Derive skill name from directory (lingui/setup -> lingui-setup)
SKILL_NAME="$(echo "$SKILL_DIR" | tr '/' '-')"

SKILL_PATH="$REPO_ROOT/skills/$SKILL_DIR"
MANIFEST="$SCRIPT_DIR/fixtures.json"

if [ ! -d "$SKILL_PATH" ]; then
  echo "ERROR: Skill not found: $SKILL_PATH"
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: Fixture manifest not found: $MANIFEST"
  exit 1
fi

# Read fixture config from manifest
FIXTURE_CONFIG=$(jq -e ".\"$FIXTURE\"" "$MANIFEST" 2>/dev/null) || {
  echo "ERROR: Fixture '$FIXTURE' not found in $MANIFEST"
  exit 1
}

FIXTURE_TYPE=$(echo "$FIXTURE_CONFIG" | jq -r '.type')
VARIANT=$(echo "$FIXTURE_CONFIG" | jq -r '.variant')

# Create temp working directory
WORKDIR=$(mktemp -d)
echo "==> Work directory: $WORKDIR"

cleanup() {
  if [ "${KEEP_WORKDIR:-}" = "1" ]; then
    echo "==> Keeping work directory: $WORKDIR"
  else
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

# 1. Prepare fixture in temp directory
echo "==> Preparing fixture: $FIXTURE (type: $FIXTURE_TYPE, variant: $VARIANT)"

if [ "$FIXTURE_TYPE" = "local" ]; then
  FIXTURE_PATH="$REPO_ROOT/$(echo "$FIXTURE_CONFIG" | jq -r '.path')"
  if [ ! -d "$FIXTURE_PATH" ]; then
    echo "ERROR: Fixture not found: $FIXTURE_PATH"
    exit 1
  fi
  cp -R "$FIXTURE_PATH/." "$WORKDIR/"
elif [ "$FIXTURE_TYPE" = "git" ]; then
  REPO_URL=$(echo "$FIXTURE_CONFIG" | jq -r '.repo')
  COMMIT=$(echo "$FIXTURE_CONFIG" | jq -r '.commit')
  echo "==> Cloning $REPO_URL at $COMMIT"
  git clone "$REPO_URL" "$WORKDIR" 2>&1 | tail -3
  cd "$WORKDIR"
  git checkout "$COMMIT" 2>&1 | tail -1
else
  echo "ERROR: Unknown fixture type: $FIXTURE_TYPE"
  exit 1
fi

# 2. Install skill
echo "==> Installing skill: $SKILL_NAME"
mkdir -p "$WORKDIR/.claude/skills/$SKILL_NAME"
cp -R "$SKILL_PATH/." "$WORKDIR/.claude/skills/$SKILL_NAME/"

# 3. Install dependencies
echo "==> Installing dependencies..."
cd "$WORKDIR"
npm install --silent 2>&1 | tail -3

# 4. Snapshot file list before agent runs (for behavior analysis)
find . -type f -not -path './node_modules/*' -not -path './.claude/*' -not -path './.git/*' | sort > .eval-files-before.txt

# 5. Pre-agent backup (for modified-file detection)
echo "==> Creating pre-agent backup..."
mkdir -p .eval-backup
rsync -a --exclude='node_modules' --exclude='.claude' --exclude='.git' --exclude='.eval-backup' --exclude='.eval-files-before.txt' . .eval-backup/

# 6. Run the agent
echo "==> Running Claude Code agent..."
PROMPT="Set up LinguiJS i18n in this project. Use English (en) as source locale and Spanish (es) and French (fr) as target locales."

AGENT_OUTPUT=$(claude -p "$PROMPT" --dangerously-skip-permissions 2>&1) || true
echo "$AGENT_OUTPUT" > .eval-agent-output.txt
echo "==> Agent output saved to .eval-agent-output.txt"

# 7. Snapshot file list after agent runs
find . -type f -not -path './node_modules/*' -not -path './.claude/*' -not -path './.git/*' | sort > .eval-files-after.txt

# 8. Run verification
echo ""
echo "============================================"
echo "  VERIFICATION: $SKILL_NAME / $FIXTURE"
echo "============================================"
echo ""

"$SCRIPT_DIR/verify-lingui-setup.sh" "$WORKDIR" "$FIXTURE" "$VARIANT"
VERIFY_EXIT=$?

# 9. Run behavior checks
echo ""
echo "============================================"
echo "  BEHAVIOR: $SKILL_NAME / $FIXTURE"
echo "============================================"
echo ""

"$SCRIPT_DIR/check-behavior.sh" "$WORKDIR" "$FIXTURE" "$VARIANT"
BEHAVIOR_EXIT=$?

# 10. Run string-wrapping verification (if expectations exist)
STRING_EXIT=0
EXPECTATIONS="$SCRIPT_DIR/expectations/$FIXTURE.json"
if [ -f "$EXPECTATIONS" ]; then
  echo ""
  echo "============================================"
  echo "  STRING WRAPPING: $SKILL_NAME / $FIXTURE"
  echo "============================================"
  echo ""

  "$SCRIPT_DIR/verify-string-wrapping.sh" "$WORKDIR" "$FIXTURE"
  STRING_EXIT=$?
fi

# Summary
echo ""
echo "============================================"
echo "  SUMMARY: $SKILL_NAME / $FIXTURE"
echo "============================================"
if [ $VERIFY_EXIT -eq 0 ] && [ $BEHAVIOR_EXIT -eq 0 ] && [ $STRING_EXIT -eq 0 ]; then
  echo "  RESULT: PASS"
else
  echo "  RESULT: FAIL"
  [ $VERIFY_EXIT -ne 0 ] && echo "  - Verification checks failed"
  [ $BEHAVIOR_EXIT -ne 0 ] && echo "  - Behavior checks failed"
  [ $STRING_EXIT -ne 0 ] && echo "  - String wrapping checks failed"
fi
echo "============================================"

exit $(( VERIFY_EXIT + BEHAVIOR_EXIT + STRING_EXIT ))
