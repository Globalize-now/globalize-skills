# Real-World Eval: shadcn-admin

Adds a real-world application (shadcn-admin) as an eval target for the lingui-setup skill, alongside the existing minimal fixtures. Tests both infrastructure setup and actual string wrapping on a 200+ file Vite + React + SWC + TanStack Router admin dashboard.

## Goal

Verify that the lingui-setup skill works reliably on a real-world app:

1. Infrastructure setup succeeds (config, packages, plugins, provider, build)
2. Agent wraps hardcoded UI strings with Lingui macros
3. Wrapped strings produce extractable translation catalogs

## Fixture Manifest

### `evals/fixtures.json`

Replace the implicit "fixtures live at `fixtures/<name>`" convention with an explicit manifest:

```json
{
  "nextjs-app-router": {
    "type": "local",
    "path": "fixtures/nextjs-app-router",
    "variant": "nextjs-app-router"
  },
  "vite-swc": {
    "type": "local",
    "path": "fixtures/vite-swc",
    "variant": "vite-swc"
  },
  "vite-babel": {
    "type": "local",
    "path": "fixtures/vite-babel",
    "variant": "vite-babel"
  },
  "shadcn-admin": {
    "type": "git",
    "repo": "https://github.com/satnaing/shadcn-admin.git",
    "commit": "a750f776f952997b6488714cdffde4badaa6c3e6",
    "variant": "vite-swc"
  }
}
```

**Fields:**

- `type`: `"local"` (copy from repo) or `"git"` (clone from remote)
- `path`: Relative path within this repo (local only)
- `repo`: Git clone URL (git only)
- `commit`: Pinned commit hash for reproducibility (git only)
- `variant`: Which variant-specific checks to run. Decoupled from fixture name so a git fixture like `shadcn-admin` can map to `vite-swc` variant checks.

## run-eval.sh Changes

The script reads fixture config from `evals/fixtures.json` using `jq` (required dependency):

1. Look up the fixture name in the manifest
2. If `type` is `"local"`: copy from `path` as before
3. If `type` is `"git"`: `git clone <repo>` into temp dir, then `git checkout <commit>`
4. Extract `variant` from the manifest and pass it to verification scripts as a separate argument (instead of using fixture name as variant)
5. **Pre-agent backup**: Before running the agent, copy the entire source tree (excluding `node_modules`) to `$WORKDIR/.eval-backup/`. This enables modified-file detection in `check-behavior.sh`.

Everything else stays the same: install skill, install deps, snapshot files, run agent, snapshot again, run verification.

## run-all.sh Changes

Add one line:

```bash
run_eval "lingui/setup" "shadcn-admin"
```

## verify-lingui-setup.sh Changes

Accept variant as a separate (optional) third argument:

```bash
# Before: variant was always $FIXTURE
# After: variant comes from arg or falls back to $FIXTURE
VARIANT="${3:-$FIXTURE}"
```

The `case` statement switches on `$VARIANT` instead of `$FIXTURE`. No other changes needed — shadcn-admin maps to `vite-swc` so it gets the same infrastructure checks.

## check-behavior.sh Changes

### Modified files tracking

Add a diff of before/after file snapshots to report modified files (informational, not pass/fail):

```bash
# Files that existed before and still exist but were modified
BACKUP_DIR=".eval-backup"
MODIFIED_FILES=$(comm -12 "$FILES_BEFORE" "$FILES_AFTER" | while read -r f; do
  if ! diff -q "$BACKUP_DIR/$f" "$f" >/dev/null 2>&1; then
    echo "$f"
  fi
done)
```

This uses the pre-agent backup created by `run-eval.sh` at `$WORKDIR/.eval-backup/`.

### Relaxed checks for git fixtures

Accept variant as a third argument (same pattern as verify script). When an expectations file exists at `evals/expectations/<fixture>.json`:

- Skip the "all new files are i18n-related" check for modified files (the agent is expected to modify non-i18n files to wrap strings)
- Raise the output conciseness threshold from 500 to 1500 lines

### No unexpected deletions

Same check as today. No files from the before-snapshot should disappear.

## String-Wrapping Verification

### `evals/verify-string-wrapping.sh`

New script. Only runs when an expectations file exists for the fixture.

**Usage:** `verify-string-wrapping.sh <project-dir> <fixture-name>`

**Expectations file:** `evals/expectations/<fixture-name>.json`

### Expectations file format

```json
{
  "wrapped_strings": [
    { "file": "src/features/dashboard/index.tsx", "original": "Dashboard" },
    { "file": "src/features/dashboard/index.tsx", "original": "Total Revenue" },
    { "file": "src/features/dashboard/index.tsx", "original": "Subscriptions" },
    { "file": "src/features/dashboard/index.tsx", "original": "Recent Sales" },
    { "file": "src/features/dashboard/index.tsx", "original": "Download" },
    { "file": "src/components/layout/data/sidebar-data.ts", "original": "Dashboard" },
    { "file": "src/components/layout/data/sidebar-data.ts", "original": "Settings" },
    { "file": "src/components/layout/data/sidebar-data.ts", "original": "Tasks" },
    { "file": "src/features/auth/sign-in/components/user-auth-form.tsx", "original": "Please enter your email" }
  ],
  "min_files_with_trans": 5,
  "min_extracted_messages": 10
}
```

### Check 1: Specific string wrapping

For each entry in `wrapped_strings`, read the file and check that the `original` string no longer appears as a bare string literal or raw JSX text. It should be inside a Lingui wrapper (`<Trans>`, `t()`, `msg()`, `defineMessage()`).

The check is: grep for the original string in the file. If it still appears as bare text (not inside a Lingui macro call), it's a FAIL.

Implementation approach: after the agent runs, for each expected string, grep for it in the file. If found, check the surrounding context for Lingui wrappers. A simple heuristic:

- If the line containing the string also contains `Trans`, `t(`, `msg(`, or `defineMessage` — PASS
- If the string no longer appears in the file at all (agent may have restructured) — WARN (not fail, since the string may have been moved to a catalog or renamed)
- If the string appears bare with no wrapper — FAIL

### Check 2: Breadth

Count distinct source files (`.ts`, `.tsx`) that contain `Trans`, `useLingui`, or `t(`. Must meet `min_files_with_trans` threshold.

### Check 3: Catalog depth

Run `npx lingui extract --clean`, then count non-header `msgid` entries in the generated `.po` files. Must meet `min_extracted_messages` threshold.

### Integration with run-eval.sh

After running `verify-lingui-setup.sh` and `check-behavior.sh`, check if `evals/expectations/$FIXTURE.json` exists. If so, run `verify-string-wrapping.sh`. Include its exit code in the overall pass/fail.

## Expectations: shadcn-admin

### `evals/expectations/shadcn-admin.json`

The strings target three patterns the agent must handle:

| Pattern | Example file | Strings |
|---------|-------------|---------|
| Inline JSX text | `src/features/dashboard/index.tsx` | "Dashboard", "Total Revenue", "Subscriptions", "Recent Sales", "Download" |
| Data object literals | `src/components/layout/data/sidebar-data.ts` | "Dashboard", "Settings", "Tasks" |
| Validation messages | `src/features/auth/sign-in/components/user-auth-form.tsx` | "Please enter your email" |

**Thresholds:**

- `min_files_with_trans`: 5 (agent should touch dashboard, sidebar, at least a few forms/pages)
- `min_extracted_messages`: 10 (a real app should yield dozens; 10 is a conservative floor)

## README Updates

Add to `evals/README.md`:

- **Git fixtures** section explaining `fixtures.json`, pinned commits, and the `variant` field
- **String-wrapping verification** section explaining expectations files and the three checks
- Updated fixtures table with shadcn-admin entry

## File Summary

| File | Status | Description |
|------|--------|-------------|
| `evals/fixtures.json` | New | Fixture manifest with local/git types |
| `evals/run-eval.sh` | Modified | Read manifest, git clone support, pass variant |
| `evals/run-all.sh` | Modified | Add shadcn-admin entry |
| `evals/verify-lingui-setup.sh` | Modified | Accept variant as separate arg |
| `evals/check-behavior.sh` | Modified | Modified files tracking, relaxed checks for git fixtures |
| `evals/verify-string-wrapping.sh` | New | Thorough string-wrapping verification |
| `evals/expectations/shadcn-admin.json` | New | Expected wrapped strings |
| `evals/README.md` | Modified | Document git fixtures and string wrapping |

No changes to skills or existing fixtures.
