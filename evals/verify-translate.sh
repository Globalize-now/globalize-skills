#!/bin/bash
set -uo pipefail

# Usage: verify-translate.sh <project-dir> <fixture-name>
# Checks Lingui macro usage quality in wrapped files.
# Verifies correct import paths, no module-scope t() calls, plural correctness.

WORKDIR="${1:?Usage: verify-translate.sh <project-dir> <fixture-name>}"

cd "$WORKDIR"

PASS=0
FAIL=0
WARN=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN: $1"; WARN=$((WARN + 1)); }

echo "--- Check 1: Correct import paths ---"

# Deprecated @lingui/macro should not be used — warn on any import from it
DEPRECATED_IMPORTS=$(grep -rl "from '@lingui/macro'" --include='*.ts' --include='*.tsx' src/ app/ 2>/dev/null || true)
if [ -n "$DEPRECATED_IMPORTS" ]; then
  warn "Deprecated '@lingui/macro' imports found (use '@lingui/react/macro' or '@lingui/core/macro'):"
  echo "$DEPRECATED_IMPORTS" | while read -r f; do echo "    $f"; done
else
  pass "No deprecated '@lingui/macro' imports"
fi

echo ""
echo "--- Check 2: No bare t() at module scope ---"

# Detect t`...` or t( used outside function bodies — these won't work before i18n is activated.
# Heuristic: look for t` or t( at the start of a line or after = at module scope
# (not inside a function/arrow function body)
MODULE_SCOPE_T=$(grep -rn "^const .* = t\`\|^export const .* = t\`\|^let .* = t\`\|^var .* = t\`" \
  --include='*.ts' --include='*.tsx' src/ app/ 2>/dev/null || true)

if [ -n "$MODULE_SCOPE_T" ]; then
  fail "Possible bare t\` calls at module scope (use msg\` instead):"
  echo "$MODULE_SCOPE_T" | head -10 | while read -r line; do echo "    $line"; done
else
  pass "No bare t\` calls detected at module scope"
fi

echo ""
echo "--- Check 3: Plural expressions include 'other' branch ---"

# Find ICU plural expressions without 'other'
PLURAL_NO_OTHER=$(grep -rn "{[^}]*, plural," --include='*.ts' --include='*.tsx' src/ app/ 2>/dev/null | \
  grep -v "other {" || true)

if [ -n "$PLURAL_NO_OTHER" ]; then
  fail "Plural expressions missing required 'other' branch:"
  echo "$PLURAL_NO_OTHER" | head -10 | while read -r line; do echo "    $line"; done
else
  pass "All plural expressions include 'other' branch (or no plurals found)"
fi

echo ""
echo "--- Check 4: No string concatenation in Lingui-wrapped files ---"

# Find files that use Lingui AND still have string concatenation producing user-visible text
# (very rough heuristic — flag for review, not a hard failure)
LINGUI_FILES=$(grep -rl "Trans\|useLingui\|from '@lingui" --include='*.ts' --include='*.tsx' src/ app/ 2>/dev/null || true)

CONCAT_COUNT=0
if [ -n "$LINGUI_FILES" ]; then
  while IFS= read -r file; do
    # Look for string concat patterns: "text" + var or var + "text"
    if grep -qE '"[A-Za-z][^"]*" \+|`[A-Za-z][^`]*`\s*\+' "$file" 2>/dev/null; then
      warn "Possible string concatenation in $file — verify it's not user-visible text"
      CONCAT_COUNT=$((CONCAT_COUNT + 1))
    fi
  done <<< "$LINGUI_FILES"
fi

if [ "$CONCAT_COUNT" -eq 0 ]; then
  pass "No suspicious string concatenation found in Lingui-wrapped files"
fi

# ─── Report ───

echo ""
echo "--- Translation Quality Report ---"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"

if [ $FAIL -gt 0 ]; then
  exit 1
else
  exit 0
fi
