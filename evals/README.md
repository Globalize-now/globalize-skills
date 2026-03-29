# Skill Evals

Evaluates whether skills produce working setups when followed by Claude Code.

## Quick Start

Run a single eval:

```bash
./evals/run-eval.sh lingui/setup vite-swc
```

Run all evals:

```bash
./evals/run-all.sh
```

## How It Works

1. **Prepare** a fixture project in a temp directory (copy local or clone git repo)
2. **Install** the skill into `.claude/skills/`
3. **Run** Claude Code headlessly with a setup prompt
4. **Verify** the result with automated checks

## Fixtures

Fixtures are defined in `evals/fixtures.json`. Each entry specifies how to obtain the project and which variant checks to run.

| Fixture | Type | Stack | Variant |
|---------|------|-------|---------|
| `nextjs-app-router` | local | Next.js 15 + App Router + TypeScript | `nextjs-app-router` |
| `vite-swc` | local | Vite 6 + React 19 + SWC + TypeScript | `vite-swc` |
| `vite-babel` | local | Vite 6 + React 19 + Babel + TypeScript | `vite-babel` |
| `shadcn-admin` | git | Vite + React + SWC + TanStack Router | `vite-swc` |

### Git Fixtures

Git fixtures are real-world applications cloned from remote repositories. They are defined in `fixtures.json` with `"type": "git"`:

```json
{
  "shadcn-admin": {
    "type": "git",
    "repo": "https://github.com/satnaing/shadcn-admin.git",
    "commit": "a750f776f952997b6488714cdffde4badaa6c3e6",
    "variant": "vite-swc"
  }
}
```

- **repo**: Git clone URL
- **commit**: Pinned to a specific commit for reproducibility
- **variant**: Which variant-specific checks to run (decoupled from fixture name, so `shadcn-admin` uses `vite-swc` checks)

## Verification Layers

### Layer 1: Functional Correctness
- Lingui config exists with correct locales
- Core packages installed
- `lingui extract` and `lingui compile` work
- `npm run build` succeeds

### Layer 2: Code Quality
- TypeScript passes (`tsc --noEmit`)
- No `any` types in i18n files

### Layer 3: Variant-Specific
- Correct plugins in build config
- Framework-specific wiring (middleware, provider, routing)

## String-Wrapping Verification

When an expectations file exists at `evals/expectations/<fixture>.json`, an additional verification layer runs to check that the agent wrapped hardcoded UI strings with Lingui macros.

### Three checks

1. **Specific string wrapping**: Each expected string is checked in its file. It should be inside a Lingui wrapper (`<Trans>`, `t()`, `msg()`, `defineMessage()`), not bare text.
2. **Breadth**: Counts distinct source files using Lingui APIs. Must meet `min_files_with_trans` threshold.
3. **Catalog depth**: Runs `lingui extract` and counts extracted `msgid` entries. Must meet `min_extracted_messages` threshold.

### Expectations file format

```json
{
  "wrapped_strings": [
    { "file": "src/features/dashboard/index.tsx", "original": "Dashboard" }
  ],
  "min_files_with_trans": 5,
  "min_extracted_messages": 10
}
```

## Behavior Analysis

Checks agent output for:
- Project detection happened before installation
- Correct variant identified
- No original files deleted
- Only i18n-related files created
- Modified files tracked (informational, using pre-agent backup)

Git fixtures with expectations files get a relaxed output conciseness threshold (1500 vs 500 lines).

## Interpreting Results

```
PASS: All checks passed
FAIL: Hard failures — the setup is broken
WARN: Soft issues — works but could be better
```

## Improving Skills

When an eval fails:

1. Check which verification failed
2. Read `.eval-agent-output.txt` in the work dir (use `KEEP_WORKDIR=1`)
3. Identify which skill step or reference file needs updating
4. Fix the skill
5. Re-run the eval

Keep the work directory for debugging:

```bash
KEEP_WORKDIR=1 ./evals/run-eval.sh lingui/setup vite-swc
```
