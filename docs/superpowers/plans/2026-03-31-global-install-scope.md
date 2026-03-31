# Global Install Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `--target=global|local|<path>` flag and interactive scope prompt to the CLI so users can install skills into `~/.claude/skills/` (global) or the current project (local).

**Architecture:** New `cli/lib/scope.mjs` owns all scope logic — path resolution, agent filtering, interactive prompt. `add.mjs` and `wizard.mjs` import from it. `update.mjs` inherits the change for free since it delegates to `add`. Converters are untouched.

**Tech Stack:** Node.js ESM (`node:os`, `node:path`), `@inquirer/prompts` (already installed), `node:test` for unit tests.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `cli/lib/scope.mjs` | Create | `resolveTargetDir`, `filterAgentsForScope`, `GLOBAL_SUPPORT`, `promptScope` |
| `cli/test/scope.test.mjs` | Create | Unit tests for pure functions in `scope.mjs` |
| `cli/commands/add.mjs` | Modify | Parse `--target`, call scope resolution/prompt, filter agents |
| `cli/commands/wizard.mjs` | Modify | Add scope prompt after agent selection, replace hardcoded `process.cwd()` |

---

## Task 1: Create `cli/lib/scope.mjs` — pure functions

**Files:**
- Create: `cli/lib/scope.mjs`
- Create: `cli/test/scope.test.mjs`

- [ ] **Step 1: Write failing tests for `resolveTargetDir` and `GLOBAL_SUPPORT`**

Create `cli/test/scope.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import { resolveTargetDir, GLOBAL_SUPPORT, filterAgentsForScope } from '../lib/scope.mjs';

test('resolveTargetDir: global resolves to homedir', () => {
  assert.equal(resolveTargetDir('global'), os.homedir());
});

test('resolveTargetDir: local resolves to cwd', () => {
  assert.equal(resolveTargetDir('local'), process.cwd());
});

test('resolveTargetDir: absolute path passes through', () => {
  assert.equal(resolveTargetDir('/tmp/mydir'), '/tmp/mydir');
});

test('resolveTargetDir: relative path resolves to absolute', () => {
  assert.equal(resolveTargetDir('./foo'), path.resolve('./foo'));
});

test('GLOBAL_SUPPORT: claude is supported', () => {
  assert.equal(GLOBAL_SUPPORT.claude, true);
});

test('GLOBAL_SUPPORT: codex is not supported', () => {
  assert.equal(GLOBAL_SUPPORT.codex, false);
});

test('GLOBAL_SUPPORT: cursor is not supported', () => {
  assert.equal(GLOBAL_SUPPORT.cursor, false);
});

test('filterAgentsForScope: passes all agents for local scope', () => {
  const result = filterAgentsForScope(['claude', 'codex', 'cursor'], process.cwd());
  assert.deepEqual(result, ['claude', 'codex', 'cursor']);
});

test('filterAgentsForScope: keeps only supported agents for global scope', () => {
  const result = filterAgentsForScope(['claude', 'codex', 'cursor'], os.homedir());
  assert.deepEqual(result, ['claude']);
});

test('filterAgentsForScope: passes all agents for custom path', () => {
  const result = filterAgentsForScope(['claude', 'codex', 'cursor'], '/some/custom/path');
  assert.deepEqual(result, ['claude', 'codex', 'cursor']);
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd cli && node --test 'test/**/*.test.mjs'
```

Expected: error — `Cannot find module '../lib/scope.mjs'`

- [ ] **Step 3: Implement `resolveTargetDir`, `GLOBAL_SUPPORT`, and `filterAgentsForScope` in `cli/lib/scope.mjs`**

```js
import os from 'node:os';
import path from 'node:path';

export const GLOBAL_SUPPORT = {
  claude: true,
  codex: false,
  cursor: false,
};

export function resolveTargetDir(target) {
  if (target === 'global') return os.homedir();
  if (target === 'local') return process.cwd();
  return path.resolve(target);
}

export function filterAgentsForScope(agents, targetDir) {
  if (targetDir !== os.homedir()) return agents;
  return agents.filter((agent) => {
    if (!GLOBAL_SUPPORT[agent]) {
      console.warn(`  ⚠ Skipping ${agent} — global install not supported`);
      return false;
    }
    return true;
  });
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd cli && node --test 'test/**/*.test.mjs'
```

Expected: all 10 tests pass, no failures.

- [ ] **Step 5: Commit**

```bash
git add cli/lib/scope.mjs cli/test/scope.test.mjs
git commit -m "feat(scope): add resolveTargetDir, GLOBAL_SUPPORT, filterAgentsForScope"
```

---

## Task 2: Add `promptScope()` to `cli/lib/scope.mjs`

**Files:**
- Modify: `cli/lib/scope.mjs`

`promptScope` uses `@inquirer/select` and is interactive — no unit test. It is a thin wrapper over `resolveTargetDir` which is already tested.

- [ ] **Step 1: Add `promptScope` export to `cli/lib/scope.mjs`**

Append to the existing file after the `filterAgentsForScope` function:

```js
import { select } from '@inquirer/prompts';

export async function promptScope() {
  const choice = await select({
    message: 'Install scope:',
    choices: [
      { name: `Global  — available in all projects (${os.homedir()})`, value: 'global' },
      { name: `Local   — this project only (${process.cwd()})`, value: 'local' },
    ],
  });
  return resolveTargetDir(choice);
}
```

The full `cli/lib/scope.mjs` should now look like:

```js
import os from 'node:os';
import path from 'node:path';
import { select } from '@inquirer/prompts';

export const GLOBAL_SUPPORT = {
  claude: true,
  codex: false,
  cursor: false,
};

export function resolveTargetDir(target) {
  if (target === 'global') return os.homedir();
  if (target === 'local') return process.cwd();
  return path.resolve(target);
}

export function filterAgentsForScope(agents, targetDir) {
  if (targetDir !== os.homedir()) return agents;
  return agents.filter((agent) => {
    if (!GLOBAL_SUPPORT[agent]) {
      console.warn(`  ⚠ Skipping ${agent} — global install not supported`);
      return false;
    }
    return true;
  });
}

export async function promptScope() {
  const choice = await select({
    message: 'Install scope:',
    choices: [
      { name: `Global  — available in all projects (${os.homedir()})`, value: 'global' },
      { name: `Local   — this project only (${process.cwd()})`, value: 'local' },
    ],
  });
  return resolveTargetDir(choice);
}
```

- [ ] **Step 2: Run existing tests to confirm nothing broke**

```bash
cd cli && node --test 'test/**/*.test.mjs'
```

Expected: all 10 tests still pass.

- [ ] **Step 3: Commit**

```bash
git add cli/lib/scope.mjs
git commit -m "feat(scope): add promptScope interactive selector"
```

---

## Task 3: Update `cli/commands/add.mjs`

**Files:**
- Modify: `cli/commands/add.mjs`

- [ ] **Step 1: Update `add.mjs` with `--target` parsing and scope resolution**

Replace the full contents of `cli/commands/add.mjs` with:

```js
import { listSkills, fetchSkill, fetchPresets } from '../lib/registry.mjs';
import { detectAgents, ALL_AGENTS } from '../lib/detect.mjs';
import { resolveTargetDir, filterAgentsForScope, promptScope } from '../lib/scope.mjs';
import { install as installClaude } from '../converters/claude.mjs';
import { install as installCodex } from '../converters/codex.mjs';
import { install as installCursor } from '../converters/cursor.mjs';

const CONVERTERS = {
  claude: installClaude,
  codex: installCodex,
  cursor: installCursor,
};

function parseArgs(args) {
  const flags = {};
  const positional = [];

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--agent' && args[i + 1]) {
      flags.agent = args[++i];
    } else if (args[i] === '--preset' && args[i + 1]) {
      flags.preset = args[++i];
    } else if (args[i] === '--repo' && args[i + 1]) {
      flags.repo = args[++i];
    } else if (args[i] === '--target' && args[i + 1]) {
      flags.target = args[++i];
    } else if (args[i] === '--no-cache') {
      flags.noCache = true;
    } else if (!args[i].startsWith('--')) {
      positional.push(args[i]);
    }
  }

  return { ...flags, skills: positional };
}

export async function run(args = []) {
  const { skills: skillNames, preset, agent, repo, noCache, target } = parseArgs(args);

  const targetDir = target !== undefined
    ? resolveTargetDir(target)
    : await promptScope();

  // Resolve which skills to install
  let toInstall = [...skillNames];
  if (preset) {
    const presets = await fetchPresets({ repo, noCache });
    if (!presets[preset]) {
      console.error(`Unknown preset: ${preset}`);
      process.exit(1);
    }
    toInstall.push(...presets[preset].skills);
  }

  if (toInstall.length === 0) {
    console.error('No skills specified. Use: globalize-skills add <skill> or --preset <name>');
    process.exit(1);
  }

  // Resolve agent targets
  const detectedAgents = agent === 'all'
    ? ALL_AGENTS
    : agent
      ? [agent]
      : detectAgents(targetDir);

  const agents = filterAgentsForScope(detectedAgents, targetDir);

  if (agents.length === 0) {
    console.error('No supported agents for the selected scope.');
    process.exit(1);
  }

  // Fetch available skills to resolve paths
  const allSkills = await listSkills({ repo, noCache });
  const skillMap = Object.fromEntries(allSkills.map((s) => [s.name, s]));

  for (const name of toInstall) {
    const skillInfo = skillMap[name];
    if (!skillInfo) {
      console.error(`Unknown skill: ${name}`);
      continue;
    }

    const { files } = await fetchSkill(skillInfo.path, { repo, noCache });

    for (const agentName of agents) {
      const converter = CONVERTERS[agentName];
      const result = converter({ name, files, targetDir });
      console.log(`  Installed ${name} for ${agentName} → ${result.dir}`);
    }
  }
}
```

- [ ] **Step 2: Run tests to confirm nothing broke**

```bash
cd cli && node --test 'test/**/*.test.mjs'
```

Expected: all 10 tests pass.

- [ ] **Step 3: Smoke-test the flag manually**

```bash
cd cli && node bin.mjs add --target local --help 2>&1 || true
```

Expected: no crash from parsing (will fail on missing skill name, which is expected).

- [ ] **Step 4: Commit**

```bash
git add cli/commands/add.mjs
git commit -m "feat(add): add --target flag and interactive scope prompt"
```

---

## Task 4: Update `cli/commands/wizard.mjs`

**Files:**
- Modify: `cli/commands/wizard.mjs`

- [ ] **Step 1: Update `wizard.mjs` to add scope prompt and agent filtering**

Replace the full contents of `cli/commands/wizard.mjs` with:

```js
import { select, checkbox, Separator } from '@inquirer/prompts';
import { listSkills, fetchSkill, fetchPresets } from '../lib/registry.mjs';
import { detectAgents, ALL_AGENTS } from '../lib/detect.mjs';
import { promptScope, filterAgentsForScope } from '../lib/scope.mjs';
import { install as installClaude } from '../converters/claude.mjs';
import { install as installCodex } from '../converters/codex.mjs';
import { install as installCursor } from '../converters/cursor.mjs';

const CONVERTERS = {
  claude: installClaude,
  codex: installCodex,
  cursor: installCursor,
};

const AGENT_LABELS = {
  claude: 'Claude Code',
  codex: 'Codex',
  cursor: 'Cursor',
};

export async function run() {
  const action = await select({
    message: 'What would you like to do?',
    choices: [
      { name: 'Add skills', value: 'add' },
      { name: 'Update installed skills', value: 'update' },
      { name: 'List available skills', value: 'list' },
    ],
  });

  if (action === 'list') {
    const { run: listRun } = await import('./list.mjs');
    await listRun();
    return;
  }

  const noCache = action === 'update';
  const [skills, presets] = await Promise.all([
    listSkills({ noCache }),
    fetchPresets({ noCache }),
  ]);

  // Build choices: presets first, then individual skills
  const choices = [];

  const presetEntries = Object.entries(presets);
  if (presetEntries.length > 0) {
    choices.push(new Separator('── Presets ──'));
    for (const [name, preset] of presetEntries) {
      choices.push({
        name: `${name} — ${preset.description}`,
        value: `preset:${name}`,
      });
    }
    choices.push(new Separator('── Individual skills ──'));
  }

  for (const skill of skills) {
    const desc = skill.description.length > 60
      ? skill.description.slice(0, 57) + '...'
      : skill.description;
    choices.push({
      name: `${skill.name} — ${desc}`,
      value: `skill:${skill.name}`,
    });
  }

  const selected = await checkbox({
    message: 'Which skills?',
    choices,
    required: true,
  });

  // Resolve selections to skill names
  const skillNames = new Set();
  for (const item of selected) {
    if (item.startsWith('preset:')) {
      const presetName = item.slice('preset:'.length);
      for (const s of presets[presetName].skills) {
        skillNames.add(s);
      }
    } else {
      skillNames.add(item.slice('skill:'.length));
    }
  }

  // Agent selection
  const detected = detectAgents(process.cwd());
  const detectedLabel = detected.map((a) => AGENT_LABELS[a]).join(', ');

  const agentChoice = await select({
    message: `Install for which agents? (detected: ${detectedLabel})`,
    choices: [
      { name: `All detected (${detectedLabel})`, value: 'detected' },
      ...ALL_AGENTS.map((a) => ({ name: `${AGENT_LABELS[a]} only`, value: a })),
      { name: 'All agents', value: 'all' },
    ],
  });

  const selectedAgents = agentChoice === 'detected'
    ? detected
    : agentChoice === 'all'
      ? ALL_AGENTS
      : [agentChoice];

  // Scope selection
  const targetDir = await promptScope();
  const agents = filterAgentsForScope(selectedAgents, targetDir);

  if (agents.length === 0) {
    console.error('\nNo supported agents for the selected scope. Aborting.');
    return;
  }

  // Install
  const skillMap = Object.fromEntries(skills.map((s) => [s.name, s]));
  console.log();

  for (const name of skillNames) {
    const skillInfo = skillMap[name];
    if (!skillInfo) {
      console.error(`Unknown skill: ${name}`);
      continue;
    }

    const { files } = await fetchSkill(skillInfo.path, { noCache });

    for (const agentName of agents) {
      const converter = CONVERTERS[agentName];
      const result = converter({ name, files, targetDir });
      console.log(`  Installed ${name} for ${AGENT_LABELS[agentName]} → ${result.dir}`);
    }
  }
}
```

- [ ] **Step 2: Run tests to confirm nothing broke**

```bash
cd cli && node --test 'test/**/*.test.mjs'
```

Expected: all 10 tests pass.

- [ ] **Step 3: Commit**

```bash
git add cli/commands/wizard.mjs
git commit -m "feat(wizard): add scope prompt after agent selection"
```
