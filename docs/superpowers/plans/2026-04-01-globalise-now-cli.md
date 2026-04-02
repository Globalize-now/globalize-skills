# Globalise-Now CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `@globalize-now/client` — a CLI + library package that wraps the Globalize API with progressive discovery for agents and pretty output for humans, replacing the MCP server's direct API calls.

**Architecture:** Two-level subcommand CLI (`globalise-now-cli <group> <action>`) built with Commander. Each command group is a module exporting pure async functions (taking a client, returning typed data) plus a `register` function that wires them into Commander with formatting. The `register` functions take a `ClientFactory` (`() => Promise<ApiClient>`) to defer auth resolution until a command actually runs — `--help` never triggers auth. The package also exports the pure functions as a library for the MCP server to import later.

**Tech Stack:** TypeScript (ESM), Commander, openapi-fetch + openapi-typescript, cli-table3, chalk

---

## File Structure

```
api-client/
  bin/
    globalise-now-cli.mjs          # Shebang entry point
  src/
    index.ts                       # Programmatic API re-exports
    cli.ts                         # Commander program setup, group registration
    auth.ts                        # Auth resolution (extracted from mcp-server)
    client.ts                      # openapi-fetch client factory (no MCP deps)
    format.ts                      # TTY detection, JSON/table output helpers
    commands/
      orgs.ts                      # Pure functions + Commander registration
      projects.ts
      languages.ts
      project-languages.ts
      repositories.ts
      glossary.ts
      style-guides.ts
      api-keys.ts
      members.ts
      auth.ts                      # login/status/logout commands
  package.json
  tsconfig.json
```

**Key pattern — every command file exports:**
1. Pure async functions for programmatic use: `async function listOrgs(client: ApiClient)` — takes a real client, throws on error
2. A `register(group: Command, getClient: ClientFactory)` function for CLI wiring — defers auth via `ClientFactory`

The `ClientFactory` type is defined inline in each command file to avoid circular imports:
```typescript
type ClientFactory = () => Promise<ApiClient>;
```

---

### Task 1: Package scaffolding

**Files:**
- Create: `api-client/package.json`
- Create: `api-client/tsconfig.json`
- Create: `api-client/bin/globalise-now-cli.mjs`

- [ ] **Step 1: Create `api-client/package.json`**

```json
{
  "name": "@globalize-now/client",
  "version": "0.1.0",
  "type": "module",
  "description": "CLI and library client for the Globalize translation platform",
  "bin": {
    "globalise-now-cli": "bin/globalise-now-cli.mjs"
  },
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "bin/",
    "dist/"
  ],
  "scripts": {
    "generate": "openapi-typescript https://api.globalize.now/api/docs/json -o src/api-types.ts",
    "build": "npm run generate && tsc",
    "dev": "tsc --watch"
  },
  "engines": {
    "node": ">=18"
  },
  "dependencies": {
    "chalk": "^5.4.0",
    "cli-table3": "^0.6.5",
    "commander": "^13.1.0",
    "openapi-fetch": "^0.13.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "openapi-typescript": "^7.6.0",
    "typescript": "^5.8.0"
  }
}
```

- [ ] **Step 2: Create `api-client/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Create `api-client/bin/globalise-now-cli.mjs`**

```javascript
#!/usr/bin/env node
import '../dist/cli.js';
```

- [ ] **Step 4: Install dependencies**

Run: `cd api-client && npm install`
Expected: `node_modules/` created, `package-lock.json` generated

- [ ] **Step 5: Generate API types**

Run: `cd api-client && npm run generate`
Expected: `src/api-types.ts` created with `paths` type

- [ ] **Step 6: Commit**

```bash
git add api-client/package.json api-client/tsconfig.json api-client/bin/globalise-now-cli.mjs api-client/package-lock.json api-client/src/api-types.ts
git commit -m "feat(api-client): scaffold package with deps and generated types"
```

---

### Task 2: Auth module

**Files:**
- Create: `api-client/src/auth.ts`

Extracted from `mcp-server/src/auth.ts`. Key difference: `resolveAuth()` throws instead of prompting interactively — the interactive flow lives in `commands/auth.ts` (`login` command).

- [ ] **Step 1: Create `api-client/src/auth.ts`**

```typescript
import { readFile, writeFile, mkdir, unlink } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

const CONFIG_DIR = join(homedir(), '.globalize');
const CONFIG_PATH = join(CONFIG_DIR, 'config.json');
const DEFAULT_API_URL = 'https://api.globalize.now';

export interface AuthConfig {
  apiKey: string;
  apiUrl: string;
}

export async function readConfigFile(): Promise<Partial<AuthConfig>> {
  try {
    const raw = await readFile(CONFIG_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

export async function writeConfigFile(config: AuthConfig): Promise<void> {
  await mkdir(CONFIG_DIR, { recursive: true });
  await writeFile(CONFIG_PATH, JSON.stringify(config, null, 2) + '\n', 'utf-8');
}

export async function deleteConfigFile(): Promise<void> {
  try {
    await unlink(CONFIG_PATH);
  } catch {
    // File doesn't exist, that's fine
  }
}

export async function resolveAuth(): Promise<AuthConfig> {
  const apiUrl = process.env.GLOBALIZE_API_URL || DEFAULT_API_URL;

  // 1. Environment variable
  if (process.env.GLOBALIZE_API_KEY) {
    return { apiKey: process.env.GLOBALIZE_API_KEY, apiUrl };
  }

  // 2. Config file
  const config = await readConfigFile();
  if (config.apiKey) {
    return { apiKey: config.apiKey, apiUrl: config.apiUrl || apiUrl };
  }

  throw new Error(
    'No API key found. Run `globalise-now-cli auth login` to authenticate, or set GLOBALIZE_API_KEY.'
  );
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/auth.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/auth.ts
git commit -m "feat(api-client): add auth module with config file and env var resolution"
```

---

### Task 3: Client module

**Files:**
- Create: `api-client/src/client.ts`

- [ ] **Step 1: Create `api-client/src/client.ts`**

```typescript
import createClient, { type Client } from 'openapi-fetch';
import type { paths } from './api-types.js';

export type ApiClient = Client<paths>;

export function createApiClient(apiKey: string, apiUrl: string): ApiClient {
  return createClient<paths>({
    baseUrl: apiUrl,
    headers: { Authorization: `Bearer ${apiKey}` },
  });
}

export function extractError(response: Response, error: unknown): string {
  const status = response.status;
  const detail =
    typeof error === 'object' && error !== null
      ? JSON.stringify(error)
      : String(error);

  if (status === 401 || status === 403) {
    return 'Authentication failed. Check your API key or run `globalise-now-cli auth login`.';
  }
  if (status === 404) {
    return `Not found: ${detail}`;
  }
  if (status === 422) {
    return `Validation error: ${detail}`;
  }
  if (status >= 500) {
    return 'Server error. Try again later.';
  }
  return `Error: ${detail}`;
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/client.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/client.ts
git commit -m "feat(api-client): add openapi-fetch client factory"
```

---

### Task 4: Format module

**Files:**
- Create: `api-client/src/format.ts`

- [ ] **Step 1: Create `api-client/src/format.ts`**

```typescript
import chalk from 'chalk';
import Table from 'cli-table3';

export interface OutputOptions {
  json?: boolean;
}

function isJsonMode(opts: OutputOptions): boolean {
  if (opts.json) return true;
  return !process.stdout.isTTY;
}

export function output(data: unknown, opts: OutputOptions): void {
  if (isJsonMode(opts)) {
    process.stdout.write(JSON.stringify({ data }, null, 2) + '\n');
  } else {
    if (Array.isArray(data)) {
      printTable(data);
    } else if (typeof data === 'object' && data !== null) {
      printKeyValue(data as Record<string, unknown>);
    } else {
      console.log(data);
    }
  }
}

export function outputError(message: string, opts: OutputOptions): void {
  if (isJsonMode(opts)) {
    process.stdout.write(JSON.stringify({ error: message }) + '\n');
  } else {
    process.stderr.write(chalk.red(`Error: ${message}`) + '\n');
  }
  process.exitCode = 1;
}

function printTable(rows: Record<string, unknown>[]): void {
  if (rows.length === 0) {
    console.log(chalk.dim('No results.'));
    return;
  }
  const keys = Object.keys(rows[0]);
  const table = new Table({
    head: keys.map((k) => chalk.bold(k)),
    style: { head: [] },
  });
  for (const row of rows) {
    table.push(keys.map((k) => formatCell(row[k])));
  }
  console.log(table.toString());
}

function printKeyValue(obj: Record<string, unknown>): void {
  const table = new Table({ style: { head: [] } });
  for (const [key, value] of Object.entries(obj)) {
    table.push({ [chalk.bold(key)]: formatCell(value) });
  }
  console.log(table.toString());
}

function formatCell(value: unknown): string {
  if (value === null || value === undefined) return chalk.dim('—');
  if (Array.isArray(value)) return value.join(', ');
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/format.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/format.ts
git commit -m "feat(api-client): add output formatting with TTY detection"
```

---

### Task 5: Orgs commands

**Files:**
- Create: `api-client/src/commands/orgs.ts`

- [ ] **Step 1: Create `api-client/src/commands/orgs.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

// --- Pure functions (programmatic API) ---

export async function listOrgs(client: ApiClient) {
  const { data, error, response } = await client.GET('/api/orgs');
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function createOrg(client: ApiClient, name: string) {
  const { data, error, response } = await client.POST('/api/orgs', {
    body: { name },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function deleteOrg(client: ApiClient, orgId: string) {
  const { data, error, response } = await client.DELETE('/api/orgs/{orgId}', {
    params: { path: { orgId } },
  });
  if (error) throw new Error(extractError(response, error));
  return data ?? { deleted: true };
}

// --- CLI registration ---

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List all organisations')
    .action(async (_opts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listOrgs(client), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('create')
    .description('Create an organisation')
    .requiredOption('--name <name>', 'Organisation name')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await createOrg(client, cmdOpts.name), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('delete')
    .description('Delete an organisation')
    .requiredOption('--id <orgId>', 'Organisation UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await deleteOrg(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/orgs.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/orgs.ts
git commit -m "feat(api-client): add orgs commands"
```

---

### Task 6: Projects commands

**Files:**
- Create: `api-client/src/commands/projects.ts`

- [ ] **Step 1: Create `api-client/src/commands/projects.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listProjects(client: ApiClient) {
  const { data, error, response } = await client.GET('/api/projects');
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function createProject(
  client: ApiClient,
  name: string,
  sourceLanguage: string,
  targetLanguages: string[],
) {
  const { data, error, response } = await client.POST('/api/projects', {
    body: { name, sourceLanguage, targetLanguages },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function getProject(client: ApiClient, id: string) {
  const { data, error, response } = await client.GET('/api/projects/{id}', {
    params: { path: { id } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function deleteProject(client: ApiClient, id: string) {
  const { data, error, response } = await client.DELETE('/api/projects/{id}', {
    params: { path: { id } },
  });
  if (error) throw new Error(extractError(response, error));
  return data ?? { deleted: true };
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List all projects')
    .action(async (_opts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listProjects(client), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('create')
    .description('Create a project')
    .requiredOption('--name <name>', 'Project name')
    .requiredOption('--source-language <id>', 'Source language UUID')
    .requiredOption('--target-languages <ids...>', 'Target language UUIDs')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        const targets = Array.isArray(cmdOpts.targetLanguages)
          ? cmdOpts.targetLanguages
          : cmdOpts.targetLanguages.split(',');
        output(await createProject(client, cmdOpts.name, cmdOpts.sourceLanguage, targets), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('get')
    .description('Get project details')
    .requiredOption('--id <id>', 'Project UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await getProject(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('delete')
    .description('Delete a project')
    .requiredOption('--id <id>', 'Project UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await deleteProject(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/projects.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/projects.ts
git commit -m "feat(api-client): add projects commands"
```

---

### Task 7: Languages commands

**Files:**
- Create: `api-client/src/commands/languages.ts`

- [ ] **Step 1: Create `api-client/src/commands/languages.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listLanguages(client: ApiClient) {
  const { data, error, response } = await client.GET('/api/languages');
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function getLanguage(client: ApiClient, id: string) {
  const { data, error, response } = await client.GET('/api/languages/{id}', {
    params: { path: { id } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List all available languages')
    .action(async (_opts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listLanguages(client), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('get')
    .description('Get language details')
    .requiredOption('--id <id>', 'Language UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await getLanguage(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/languages.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/languages.ts
git commit -m "feat(api-client): add languages commands"
```

---

### Task 8: Project-languages commands

**Files:**
- Create: `api-client/src/commands/project-languages.ts`

- [ ] **Step 1: Create `api-client/src/commands/project-languages.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listProjectLanguages(client: ApiClient, projectId: string) {
  const { data, error, response } = await client.GET('/api/projects/{id}/languages', {
    params: { path: { id: projectId } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function addProjectLanguage(
  client: ApiClient,
  projectId: string,
  name: string,
  locale: string,
  languageId?: string,
) {
  const { data, error, response } = await client.POST('/api/projects/{id}/languages', {
    params: { path: { id: projectId } },
    body: { name, locale, languageId },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function removeProjectLanguage(
  client: ApiClient,
  projectId: string,
  languageId: string,
) {
  const { data, error, response } = await client.DELETE(
    '/api/projects/{id}/languages/{languageId}',
    { params: { path: { id: projectId, languageId } } },
  );
  if (error) throw new Error(extractError(response, error));
  return data ?? { removed: true };
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List languages in a project')
    .requiredOption('--project-id <id>', 'Project UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listProjectLanguages(client, cmdOpts.projectId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('add')
    .description('Add a language to a project')
    .requiredOption('--project-id <id>', 'Project UUID')
    .requiredOption('--name <name>', 'Display name (e.g. "French")')
    .requiredOption('--locale <bcp47>', 'BCP-47 locale code (e.g. "fr")')
    .option('--language-id <id>', 'Language UUID from global catalog')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(
          await addProjectLanguage(client, cmdOpts.projectId, cmdOpts.name, cmdOpts.locale, cmdOpts.languageId),
          opts,
        );
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('remove')
    .description('Remove a language from a project')
    .requiredOption('--project-id <id>', 'Project UUID')
    .requiredOption('--language-id <id>', 'Project language UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await removeProjectLanguage(client, cmdOpts.projectId, cmdOpts.languageId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/project-languages.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/project-languages.ts
git commit -m "feat(api-client): add project-languages commands"
```

---

### Task 9: Repositories commands

**Files:**
- Create: `api-client/src/commands/repositories.ts`

- [ ] **Step 1: Create `api-client/src/commands/repositories.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listRepositories(client: ApiClient, projectId: string) {
  const { data, error, response } = await client.GET('/api/repositories', {
    params: { query: { projectId } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function createRepository(
  client: ApiClient,
  projectId: string,
  gitUrl: string,
  provider: 'github' | 'gitlab',
  branches?: string[],
  localePathPattern?: string,
) {
  const { data, error, response } = await client.POST('/api/repositories', {
    body: { projectId, gitUrl, provider, branches, localePathPattern },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function deleteRepository(client: ApiClient, id: string) {
  const { data, error, response } = await client.DELETE('/api/repositories/{id}', {
    params: { path: { id } },
  });
  if (error) throw new Error(extractError(response, error));
  return data ?? { deleted: true };
}

export async function detectRepository(client: ApiClient, id: string) {
  const { data, error, response } = await client.POST('/api/repositories/{id}/detect', {
    params: { path: { id } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List repositories in a project')
    .requiredOption('--project-id <id>', 'Project UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listRepositories(client, cmdOpts.projectId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('create')
    .description('Connect a git repository')
    .requiredOption('--project-id <id>', 'Project UUID')
    .requiredOption('--git-url <url>', 'Git repository URL')
    .requiredOption('--provider <provider>', 'Git provider (github|gitlab)')
    .option('--branches <branches...>', 'Branches to sync (default: main)')
    .option('--locale-path-pattern <pattern>', 'Path pattern for locale files')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        const branches = cmdOpts.branches
          ? Array.isArray(cmdOpts.branches) ? cmdOpts.branches : cmdOpts.branches.split(',')
          : undefined;
        output(
          await createRepository(client, cmdOpts.projectId, cmdOpts.gitUrl, cmdOpts.provider, branches, cmdOpts.localePathPattern),
          opts,
        );
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('delete')
    .description('Delete a repository')
    .requiredOption('--id <id>', 'Repository UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await deleteRepository(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('detect')
    .description('Trigger locale file detection')
    .requiredOption('--id <id>', 'Repository UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await detectRepository(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/repositories.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/repositories.ts
git commit -m "feat(api-client): add repositories commands"
```

---

### Task 10: Glossary commands

**Files:**
- Create: `api-client/src/commands/glossary.ts`

- [ ] **Step 1: Create `api-client/src/commands/glossary.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listGlossary(client: ApiClient, projectId: string) {
  const { data, error, response } = await client.GET('/api/projects/{id}/glossary', {
    params: { path: { id: projectId } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function createGlossaryEntry(
  client: ApiClient,
  projectId: string,
  sourceTerm: string,
  targetTerm: string,
  sourceProjectLanguageId: string,
  targetProjectLanguageId: string,
) {
  const { data, error, response } = await client.POST('/api/projects/{id}/glossary', {
    params: { path: { id: projectId } },
    body: { sourceTerm, targetTerm, sourceProjectLanguageId, targetProjectLanguageId },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function deleteGlossaryEntry(
  client: ApiClient,
  projectId: string,
  entryId: string,
) {
  const { data, error, response } = await client.DELETE(
    '/api/projects/{id}/glossary/{entryId}',
    { params: { path: { id: projectId, entryId } } },
  );
  if (error) throw new Error(extractError(response, error));
  return data ?? { deleted: true };
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List glossary entries')
    .requiredOption('--project-id <id>', 'Project UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listGlossary(client, cmdOpts.projectId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('create')
    .description('Add a glossary entry')
    .requiredOption('--project-id <id>', 'Project UUID')
    .requiredOption('--source-term <term>', 'Source language term')
    .requiredOption('--target-term <term>', 'Target language translation')
    .requiredOption('--source-language-id <id>', 'Source project language UUID')
    .requiredOption('--target-language-id <id>', 'Target project language UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(
          await createGlossaryEntry(
            client, cmdOpts.projectId, cmdOpts.sourceTerm, cmdOpts.targetTerm,
            cmdOpts.sourceLanguageId, cmdOpts.targetLanguageId,
          ),
          opts,
        );
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('delete')
    .description('Delete a glossary entry')
    .requiredOption('--project-id <id>', 'Project UUID')
    .requiredOption('--entry-id <id>', 'Glossary entry UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await deleteGlossaryEntry(client, cmdOpts.projectId, cmdOpts.entryId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/glossary.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/glossary.ts
git commit -m "feat(api-client): add glossary commands"
```

---

### Task 11: Style-guides commands

**Files:**
- Create: `api-client/src/commands/style-guides.ts`

- [ ] **Step 1: Create `api-client/src/commands/style-guides.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listStyleGuides(client: ApiClient, projectId: string) {
  const { data, error, response } = await client.GET(
    '/api/projects/{id}/style-guides',
    { params: { path: { id: projectId } } },
  );
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function upsertStyleGuide(
  client: ApiClient,
  projectId: string,
  languageId: string,
  instructions: string,
) {
  const { data, error, response } = await client.PUT(
    '/api/projects/{id}/style-guides/{projectLanguageId}',
    {
      params: { path: { id: projectId, projectLanguageId: languageId } },
      body: { instructions },
    },
  );
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function deleteStyleGuide(
  client: ApiClient,
  projectId: string,
  languageId: string,
) {
  const { data, error, response } = await client.DELETE(
    '/api/projects/{id}/style-guides/{projectLanguageId}',
    { params: { path: { id: projectId, projectLanguageId: languageId } } },
  );
  if (error) throw new Error(extractError(response, error));
  return data ?? { deleted: true };
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List style guides')
    .requiredOption('--project-id <id>', 'Project UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listStyleGuides(client, cmdOpts.projectId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('upsert')
    .description('Create or update a style guide')
    .requiredOption('--project-id <id>', 'Project UUID')
    .requiredOption('--language-id <id>', 'Project language UUID')
    .requiredOption('--instructions <text>', 'Style guide instructions')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(
          await upsertStyleGuide(client, cmdOpts.projectId, cmdOpts.languageId, cmdOpts.instructions),
          opts,
        );
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('delete')
    .description('Delete a style guide')
    .requiredOption('--project-id <id>', 'Project UUID')
    .requiredOption('--language-id <id>', 'Project language UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await deleteStyleGuide(client, cmdOpts.projectId, cmdOpts.languageId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/style-guides.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/style-guides.ts
git commit -m "feat(api-client): add style-guides commands"
```

---

### Task 12: API-keys commands

**Files:**
- Create: `api-client/src/commands/api-keys.ts`

- [ ] **Step 1: Create `api-client/src/commands/api-keys.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listApiKeys(client: ApiClient, orgId: string) {
  const { data, error, response } = await client.GET('/api/orgs/{orgId}/api-keys', {
    params: { path: { orgId } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function createApiKey(client: ApiClient, orgId: string, name: string) {
  const { data, error, response } = await client.POST('/api/orgs/{orgId}/api-keys', {
    params: { path: { orgId } },
    body: { name },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function revokeApiKey(client: ApiClient, orgId: string, keyId: string) {
  const { data, error, response } = await client.DELETE(
    '/api/orgs/{orgId}/api-keys/{keyId}',
    { params: { path: { orgId, keyId } } },
  );
  if (error) throw new Error(extractError(response, error));
  return data ?? { revoked: true };
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List API keys')
    .requiredOption('--org-id <id>', 'Organisation UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listApiKeys(client, cmdOpts.orgId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('create')
    .description('Create an API key')
    .requiredOption('--org-id <id>', 'Organisation UUID')
    .requiredOption('--name <name>', 'Key name')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await createApiKey(client, cmdOpts.orgId, cmdOpts.name), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('revoke')
    .description('Revoke an API key')
    .requiredOption('--org-id <id>', 'Organisation UUID')
    .requiredOption('--key-id <id>', 'API key UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await revokeApiKey(client, cmdOpts.orgId, cmdOpts.keyId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/api-keys.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/api-keys.ts
git commit -m "feat(api-client): add api-keys commands"
```

---

### Task 13: Members commands

**Files:**
- Create: `api-client/src/commands/members.ts`

- [ ] **Step 1: Create `api-client/src/commands/members.ts`**

```typescript
import type { Command } from 'commander';
import type { ApiClient } from '../client.js';
import { extractError } from '../client.js';
import { output, outputError, type OutputOptions } from '../format.js';

type ClientFactory = () => Promise<ApiClient>;

export async function listMembers(client: ApiClient, orgId: string) {
  const { data, error, response } = await client.GET('/api/orgs/{orgId}/members', {
    params: { path: { orgId } },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function inviteMember(
  client: ApiClient,
  orgId: string,
  clerkUserId: string,
  role?: 'admin' | 'member',
) {
  const { data, error, response } = await client.POST('/api/orgs/{orgId}/members', {
    params: { path: { orgId } },
    body: { clerkUserId, role },
  });
  if (error) throw new Error(extractError(response, error));
  return data;
}

export async function removeMember(client: ApiClient, orgId: string, membershipId: string) {
  const { data, error, response } = await client.DELETE(
    '/api/orgs/{orgId}/members/{membershipId}',
    { params: { path: { orgId, membershipId } } },
  );
  if (error) throw new Error(extractError(response, error));
  return data ?? { removed: true };
}

export function register(group: Command, getClient: ClientFactory) {
  group
    .command('list')
    .description('List organisation members')
    .requiredOption('--org-id <id>', 'Organisation UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listMembers(client, cmdOpts.orgId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('invite')
    .description('Invite a member')
    .requiredOption('--org-id <id>', 'Organisation UUID')
    .requiredOption('--clerk-user-id <uid>', 'Clerk user ID')
    .option('--role <role>', 'Role: admin or member (default: member)')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await inviteMember(client, cmdOpts.orgId, cmdOpts.clerkUserId, cmdOpts.role), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command('remove')
    .description('Remove a member')
    .requiredOption('--org-id <id>', 'Organisation UUID')
    .requiredOption('--membership-id <id>', 'Membership UUID')
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await removeMember(client, cmdOpts.orgId, cmdOpts.membershipId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/members.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/members.ts
git commit -m "feat(api-client): add members commands"
```

---

### Task 14: Auth commands (login/status/logout)

**Files:**
- Create: `api-client/src/commands/auth.ts`

Note: This file's `register` function takes only `group: Command` — no `ClientFactory` needed since auth commands don't call the API.

- [ ] **Step 1: Create `api-client/src/commands/auth.ts`**

```typescript
import { createInterface } from 'node:readline/promises';
import chalk from 'chalk';
import type { Command } from 'commander';
import { readConfigFile, writeConfigFile, deleteConfigFile } from '../auth.js';

const SETTINGS_URL = 'https://app.globalize.now/settings/api-keys';
const DEFAULT_API_URL = 'https://api.globalize.now';

export function register(group: Command) {
  group
    .command('login')
    .description('Authenticate with the Globalize API')
    .action(async () => {
      const apiUrl = process.env.GLOBALIZE_API_URL || DEFAULT_API_URL;

      console.log(`\nCreate or copy an API key from: ${chalk.cyan(SETTINGS_URL)}\n`);

      const rl = createInterface({ input: process.stdin, output: process.stdout });
      try {
        const apiKey = (await rl.question('Paste your API key: ')).trim();
        if (!apiKey) {
          console.error(chalk.red('No API key provided.'));
          process.exitCode = 1;
          return;
        }
        await writeConfigFile({ apiKey, apiUrl });
        console.log(chalk.green('API key saved to ~/.globalize/config.json'));
      } finally {
        rl.close();
      }
    });

  group
    .command('status')
    .description('Show current authentication state')
    .action(async () => {
      if (process.env.GLOBALIZE_API_KEY) {
        const key = process.env.GLOBALIZE_API_KEY;
        console.log(`Source:  ${chalk.cyan('GLOBALIZE_API_KEY env var')}`);
        console.log(`Key:    ${chalk.dim(key.slice(0, 8) + '...')}`);
        console.log(`API:    ${process.env.GLOBALIZE_API_URL || DEFAULT_API_URL}`);
        return;
      }

      const config = await readConfigFile();
      if (config.apiKey) {
        console.log(`Source:  ${chalk.cyan('~/.globalize/config.json')}`);
        console.log(`Key:    ${chalk.dim(config.apiKey.slice(0, 8) + '...')}`);
        console.log(`API:    ${config.apiUrl || DEFAULT_API_URL}`);
      } else {
        console.log(chalk.yellow('Not authenticated. Run `globalise-now-cli auth login` to set up.'));
      }
    });

  group
    .command('logout')
    .description('Remove stored credentials')
    .action(async () => {
      await deleteConfigFile();
      console.log(chalk.green('Credentials removed.'));
    });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/commands/auth.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/commands/auth.ts
git commit -m "feat(api-client): add auth login/status/logout commands"
```

---

### Task 15: CLI entry point

**Files:**
- Create: `api-client/src/cli.ts`

- [ ] **Step 1: Create `api-client/src/cli.ts`**

```typescript
import { Command } from 'commander';
import chalk from 'chalk';
import { resolveAuth } from './auth.js';
import { createApiClient, type ApiClient } from './client.js';
import { register as registerOrgs } from './commands/orgs.js';
import { register as registerProjects } from './commands/projects.js';
import { register as registerLanguages } from './commands/languages.js';
import { register as registerProjectLanguages } from './commands/project-languages.js';
import { register as registerRepositories } from './commands/repositories.js';
import { register as registerGlossary } from './commands/glossary.js';
import { register as registerStyleGuides } from './commands/style-guides.js';
import { register as registerApiKeys } from './commands/api-keys.js';
import { register as registerMembers } from './commands/members.js';
import { register as registerAuth } from './commands/auth.js';

const program = new Command();

program
  .name('globalise-now-cli')
  .description('CLI client for the Globalize translation platform')
  .version('0.1.0')
  .option('--json', 'Force JSON output');

// Lazy client: resolved once on first API call
let cachedClient: ApiClient | undefined;

async function getClient(): Promise<ApiClient> {
  if (cachedClient) return cachedClient;
  try {
    const { apiKey, apiUrl } = await resolveAuth();
    cachedClient = createApiClient(apiKey, apiUrl);
    return cachedClient;
  } catch (e) {
    process.stderr.write(chalk.red((e as Error).message) + '\n');
    process.exit(1);
  }
}

// Auth commands (no API client needed)
const authGroup = program.command('auth').description('Configure authentication');
registerAuth(authGroup);

// API command groups (lazy auth via getClient)
const groups = [
  { name: 'orgs', description: 'Manage organisations', register: registerOrgs },
  { name: 'projects', description: 'Manage translation projects', register: registerProjects },
  { name: 'languages', description: 'Browse available languages', register: registerLanguages },
  { name: 'project-languages', description: 'Manage languages within a project', register: registerProjectLanguages },
  { name: 'repositories', description: 'Connect git repositories', register: registerRepositories },
  { name: 'glossary', description: 'Manage glossary term pairs', register: registerGlossary },
  { name: 'style-guides', description: 'Manage translation style guides', register: registerStyleGuides },
  { name: 'api-keys', description: 'Manage API keys', register: registerApiKeys },
  { name: 'members', description: 'Manage organisation members', register: registerMembers },
] as const;

for (const { name, description, register } of groups) {
  const group = program.command(name).description(description);
  register(group, getClient);
}

await program.parseAsync();
```

- [ ] **Step 2: Verify it compiles**

Run: `cd api-client && npx tsc --noEmit src/cli.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/cli.ts
git commit -m "feat(api-client): add CLI entry point with lazy auth"
```

---

### Task 16: Programmatic API exports

**Files:**
- Create: `api-client/src/index.ts`

- [ ] **Step 1: Create `api-client/src/index.ts`**

```typescript
// Client and auth
export { createApiClient, type ApiClient } from './client.js';
export { resolveAuth, readConfigFile, writeConfigFile, deleteConfigFile, type AuthConfig } from './auth.js';

// Orgs
export { listOrgs, createOrg, deleteOrg } from './commands/orgs.js';

// Projects
export { listProjects, createProject, getProject, deleteProject } from './commands/projects.js';

// Languages
export { listLanguages, getLanguage } from './commands/languages.js';

// Project languages
export { listProjectLanguages, addProjectLanguage, removeProjectLanguage } from './commands/project-languages.js';

// Repositories
export { listRepositories, createRepository, deleteRepository, detectRepository } from './commands/repositories.js';

// Glossary
export { listGlossary, createGlossaryEntry, deleteGlossaryEntry } from './commands/glossary.js';

// Style guides
export { listStyleGuides, upsertStyleGuide, deleteStyleGuide } from './commands/style-guides.js';

// API keys
export { listApiKeys, createApiKey, revokeApiKey } from './commands/api-keys.js';

// Members
export { listMembers, inviteMember, removeMember } from './commands/members.js';
```

- [ ] **Step 2: Full build**

Run: `cd api-client && npm run build`
Expected: `dist/` created with all compiled files, no errors

- [ ] **Step 3: Commit**

```bash
git add api-client/src/index.ts
git commit -m "feat(api-client): add programmatic API exports"
```

---

### Task 17: Build and smoke test

**Files:**
- No new files

- [ ] **Step 1: Make binary executable**

Run: `chmod +x api-client/bin/globalise-now-cli.mjs`

- [ ] **Step 2: Full build**

Run: `cd api-client && npm run build`
Expected: Clean build, `dist/` populated

- [ ] **Step 3: Test `--help`**

Run: `cd api-client && node bin/globalise-now-cli.mjs --help`
Expected: Output showing all 10 command groups (orgs, projects, languages, project-languages, repositories, glossary, style-guides, api-keys, members, auth)

- [ ] **Step 4: Test group help**

Run: `cd api-client && node bin/globalise-now-cli.mjs projects --help`
Expected: Shows `list`, `create`, `get`, `delete` subcommands with their options

- [ ] **Step 5: Test unauthenticated API call**

Run: `cd api-client && node bin/globalise-now-cli.mjs orgs list --json 2>/dev/null; echo "exit: $?"`
Expected: Exit code 1, JSON error about missing API key

- [ ] **Step 6: Test auth status without credentials**

Run: `cd api-client && node bin/globalise-now-cli.mjs auth status`
Expected: "Not authenticated" message

- [ ] **Step 7: Test invalid command**

Run: `cd api-client && node bin/globalise-now-cli.mjs nonexistent 2>&1; echo "exit: $?"`
Expected: Helpful error message about unknown command

- [ ] **Step 8: Commit (if any fixes were needed)**

```bash
git add -A api-client/
git commit -m "fix(api-client): address smoke test issues"
```
