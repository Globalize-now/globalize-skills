# Globalize MCP Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an MCP server that connects AI agents to the Globalize API (`api.globalize.now`) for project creation and setup — orgs, projects, languages, repositories, glossary, style guides, API keys, and members.

**Architecture:** stdio-based MCP server using `@modelcontextprotocol/server` SDK v2. API client generated from OpenAPI spec via `openapi-typescript` + `openapi-fetch`. Auth resolves from env var → config file → interactive prompt. Each tool group is a separate file that registers tools on the server. 28 tools across 9 groups.

**Tech Stack:** TypeScript ESM, `@modelcontextprotocol/server`, `zod/v4`, `openapi-typescript`, `openapi-fetch`, Node.js >= 18.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `mcp-server/package.json` | Create | Package config, scripts, dependencies, bin entry |
| `mcp-server/tsconfig.json` | Create | TypeScript config targeting ESM |
| `mcp-server/bin/globalize-mcp.mjs` | Create | Executable shim for `npx` |
| `mcp-server/src/index.ts` | Create | Entry point — create server, resolve auth, register tools, connect transport |
| `mcp-server/src/auth.ts` | Create | API key resolution chain (env → file → interactive) |
| `mcp-server/src/client.ts` | Create | openapi-fetch wrapper with auth headers and error formatting |
| `mcp-server/src/api-types.ts` | Generated | OpenAPI types (generated at build time, not committed) |
| `mcp-server/src/tools/orgs.ts` | Create | 3 organisation tools |
| `mcp-server/src/tools/projects.ts` | Create | 4 project tools |
| `mcp-server/src/tools/languages.ts` | Create | 2 language catalog tools |
| `mcp-server/src/tools/project-languages.ts` | Create | 3 project language tools |
| `mcp-server/src/tools/repositories.ts` | Create | 4 repository tools |
| `mcp-server/src/tools/glossary.ts` | Create | 3 glossary tools |
| `mcp-server/src/tools/style-guides.ts` | Create | 3 style guide tools |
| `mcp-server/src/tools/api-keys.ts` | Create | 3 API key tools |
| `mcp-server/src/tools/members.ts` | Create | 3 member tools |
| `.gitignore` | Modify | Add `mcp-server/src/api-types.ts` and `mcp-server/dist/` |

---

## Task 1: Scaffold package, TypeScript config, and bin entry

**Files:**
- Create: `mcp-server/package.json`
- Create: `mcp-server/tsconfig.json`
- Create: `mcp-server/bin/globalize-mcp.mjs`
- Modify: `.gitignore`

- [ ] **Step 1: Create `mcp-server/package.json`**

```json
{
  "name": "@globalize-now/mcp-server",
  "version": "0.1.0",
  "type": "module",
  "description": "MCP server for the Globalize translation platform",
  "bin": {
    "globalize-mcp": "bin/globalize-mcp.mjs"
  },
  "files": [
    "bin/",
    "dist/"
  ],
  "scripts": {
    "generate": "openapi-typescript https://api.globalize.now/api/docs/json -o src/api-types.ts",
    "generate:staging": "openapi-typescript https://stage-api.globalize.now/api/docs/json -o src/api-types.ts",
    "build": "npm run generate && tsc",
    "dev": "npm run generate:staging && tsc --watch"
  },
  "engines": {
    "node": ">=18"
  },
  "dependencies": {
    "@modelcontextprotocol/server": "^2.0.0",
    "openapi-fetch": "^0.13.0",
    "zod": "^3.25.0"
  },
  "devDependencies": {
    "openapi-typescript": "^7.6.0",
    "typescript": "^5.8.0"
  }
}
```

- [ ] **Step 2: Create `mcp-server/tsconfig.json`**

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

- [ ] **Step 3: Create `mcp-server/bin/globalize-mcp.mjs`**

```js
#!/usr/bin/env node
import '../dist/index.js';
```

- [ ] **Step 4: Update `.gitignore`**

Add these lines:

```
mcp-server/dist
mcp-server/src/api-types.ts
```

- [ ] **Step 5: Install dependencies**

```bash
cd mcp-server && npm install
```

- [ ] **Step 6: Commit**

```bash
git add mcp-server/package.json mcp-server/tsconfig.json mcp-server/bin/globalize-mcp.mjs mcp-server/package-lock.json .gitignore
git commit -m "feat(mcp): scaffold package, tsconfig, and bin entry"
```

---

## Task 2: Auth module — API key resolution chain

**Files:**
- Create: `mcp-server/src/auth.ts`

The auth module resolves the API key and base URL through: env var → config file → interactive prompt. It also handles writing the config file after interactive auth.

- [ ] **Step 1: Create `mcp-server/src/auth.ts`**

```ts
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

const CONFIG_DIR = join(homedir(), '.globalize');
const CONFIG_PATH = join(CONFIG_DIR, 'config.json');
const DEFAULT_API_URL = 'https://api.globalize.now';

interface AuthConfig {
  apiKey: string;
  apiUrl: string;
}

async function readConfigFile(): Promise<Partial<AuthConfig>> {
  try {
    const raw = await readFile(CONFIG_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

async function writeConfigFile(config: AuthConfig): Promise<void> {
  await mkdir(CONFIG_DIR, { recursive: true });
  await writeFile(CONFIG_PATH, JSON.stringify(config, null, 2) + '\n', 'utf-8');
}

async function promptForApiKey(apiUrl: string): Promise<string> {
  const settingsUrl = 'https://app.globalize.now/settings/api-keys';
  // Log to stderr so it doesn't interfere with stdio MCP transport on stdout
  console.error(`\nNo API key found. Create one at: ${settingsUrl}\n`);
  console.error('Paste your API key below:');

  const chunks: Buffer[] = [];
  process.stdin.resume();
  for await (const chunk of process.stdin) {
    chunks.push(chunk as Buffer);
    // Read a single line
    const text = Buffer.concat(chunks).toString().trim();
    if (text.length > 0) {
      process.stdin.pause();
      const apiKey = text;
      await writeConfigFile({ apiKey, apiUrl });
      console.error('API key saved to ~/.globalize/config.json');
      return apiKey;
    }
  }
  throw new Error('No API key provided');
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

  // 3. Interactive prompt
  const apiKey = await promptForApiKey(apiUrl);
  return { apiKey, apiUrl };
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/auth.ts
git commit -m "feat(mcp): add auth module with env/file/interactive resolution"
```

---

## Task 3: API client wrapper with error formatting

**Files:**
- Create: `mcp-server/src/client.ts`

Wraps `openapi-fetch` with auth headers and provides a helper to format HTTP errors into LLM-friendly text responses.

- [ ] **Step 1: Generate API types**

This requires the OpenAPI spec to be available. Run against staging for development:

```bash
cd mcp-server && npx openapi-typescript https://stage-api.globalize.now/api/docs/json -o src/api-types.ts
```

If the staging URL is unavailable, use production:

```bash
cd mcp-server && npx openapi-typescript https://api.globalize.now/api/docs/json -o src/api-types.ts
```

Verify the file was created and contains `paths` and `components` exports.

- [ ] **Step 2: Create `mcp-server/src/client.ts`**

```ts
import createClient, { type Client } from 'openapi-fetch';
import type { paths } from './api-types.js';

export type ApiClient = Client<paths>;

export function createApiClient(apiKey: string, apiUrl: string): ApiClient {
  return createClient<paths>({
    baseUrl: apiUrl,
    headers: { Authorization: `Bearer ${apiKey}` },
  });
}

interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
}

export function formatError(status: number | undefined, error: unknown): ToolResult {
  const detail = typeof error === 'object' && error !== null ? JSON.stringify(error) : String(error);

  if (status === 401 || status === 403) {
    return { content: [{ type: 'text', text: 'Authentication failed. Check your API key or run the auth flow again.' }] };
  }
  if (status === 404) {
    return { content: [{ type: 'text', text: `Resource not found: ${detail}` }] };
  }
  if (status === 422) {
    return { content: [{ type: 'text', text: `Validation error: ${detail}` }] };
  }
  if (status && status >= 500) {
    return { content: [{ type: 'text', text: 'Server error. Try again later.' }] };
  }
  return { content: [{ type: 'text', text: `Error: ${detail}` }] };
}

export function formatSuccess(data: unknown): ToolResult {
  return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
}
```

- [ ] **Step 3: Commit**

```bash
git add mcp-server/src/client.ts
git commit -m "feat(mcp): add API client wrapper with error formatting"
```

---

## Task 4: Entry point — server setup and tool registration

**Files:**
- Create: `mcp-server/src/index.ts`

Creates the MCP server, resolves auth, creates the API client, registers all tool groups, and connects stdio transport. Tool registration imports will cause compile errors until the tool files exist — that's expected; we create them in subsequent tasks.

- [ ] **Step 1: Create `mcp-server/src/index.ts`**

```ts
import { McpServer, StdioServerTransport } from '@modelcontextprotocol/server';
import { resolveAuth } from './auth.js';
import { createApiClient } from './client.js';
import { registerOrgTools } from './tools/orgs.js';
import { registerProjectTools } from './tools/projects.js';
import { registerLanguageTools } from './tools/languages.js';
import { registerProjectLanguageTools } from './tools/project-languages.js';
import { registerRepositoryTools } from './tools/repositories.js';
import { registerGlossaryTools } from './tools/glossary.js';
import { registerStyleGuideTools } from './tools/style-guides.js';
import { registerApiKeyTools } from './tools/api-keys.js';
import { registerMemberTools } from './tools/members.js';

const server = new McpServer({
  name: 'globalize',
  version: '0.1.0',
});

const { apiKey, apiUrl } = await resolveAuth();
const client = createApiClient(apiKey, apiUrl);

registerOrgTools(server, client);
registerProjectTools(server, client);
registerLanguageTools(server, client);
registerProjectLanguageTools(server, client);
registerRepositoryTools(server, client);
registerGlossaryTools(server, client);
registerStyleGuideTools(server, client);
registerApiKeyTools(server, client);
registerMemberTools(server, client);

const transport = new StdioServerTransport();
await server.connect(transport);
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/index.ts
git commit -m "feat(mcp): add entry point with server setup and tool registration"
```

---

## Task 5: Organisation tools (3 tools)

**Files:**
- Create: `mcp-server/src/tools/orgs.ts`

Tools: `list_orgs`, `create_org`, `delete_org`

- [ ] **Step 1: Create `mcp-server/src/tools/orgs.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerOrgTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_orgs', {
    description: 'List all organisations the authenticated user belongs to',
    inputSchema: z.object({}),
  }, async () => {
    const { data, error, response } = await client.GET('/api/orgs');
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('create_org', {
    description: 'Create a new organisation',
    inputSchema: z.object({
      name: z.string().describe('Organisation name'),
    }),
  }, async ({ name }) => {
    const { data, error, response } = await client.POST('/api/orgs', {
      body: { name },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('delete_org', {
    description: 'Delete an organisation by ID',
    inputSchema: z.object({
      orgId: z.string().uuid().describe('Organisation UUID'),
    }),
  }, async ({ orgId }) => {
    const { data, error, response } = await client.DELETE('/api/orgs/{orgId}', {
      params: { path: { orgId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { deleted: true });
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/orgs.ts
git commit -m "feat(mcp): add organisation tools (list, create, delete)"
```

---

## Task 6: Project tools (4 tools)

**Files:**
- Create: `mcp-server/src/tools/projects.ts`

Tools: `list_projects`, `create_project`, `get_project`, `delete_project`

- [ ] **Step 1: Create `mcp-server/src/tools/projects.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerProjectTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_projects', {
    description: 'List all translation projects',
    inputSchema: z.object({}),
  }, async () => {
    const { data, error, response } = await client.GET('/api/projects');
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('create_project', {
    description: 'Create a new translation project',
    inputSchema: z.object({
      name: z.string().describe('Project name'),
      sourceLanguage: z.string().uuid().describe('Source language UUID'),
      targetLanguages: z.array(z.string().uuid()).describe('Target language UUIDs'),
    }),
  }, async ({ name, sourceLanguage, targetLanguages }) => {
    const { data, error, response } = await client.POST('/api/projects', {
      body: { name, sourceLanguage, targetLanguages },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('get_project', {
    description: 'Get project details by ID',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.GET('/api/projects/{id}', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('delete_project', {
    description: 'Delete a project by ID',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.DELETE('/api/projects/{id}', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { deleted: true });
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/projects.ts
git commit -m "feat(mcp): add project tools (list, create, get, delete)"
```

---

## Task 7: Language catalog tools (2 tools)

**Files:**
- Create: `mcp-server/src/tools/languages.ts`

Tools: `list_languages`, `get_language`

- [ ] **Step 1: Create `mcp-server/src/tools/languages.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerLanguageTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_languages', {
    description: 'Search and list available languages from the global catalog. Use to find language UUIDs for project setup.',
    inputSchema: z.object({}),
  }, async () => {
    const { data, error, response } = await client.GET('/api/languages');
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('get_language', {
    description: 'Get details for a specific language by ID',
    inputSchema: z.object({
      id: z.string().uuid().describe('Language UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.GET('/api/languages/{id}', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/languages.ts
git commit -m "feat(mcp): add language catalog tools (list, get)"
```

---

## Task 8: Project language tools (3 tools)

**Files:**
- Create: `mcp-server/src/tools/project-languages.ts`

Tools: `list_project_languages`, `add_project_language`, `remove_project_language`

- [ ] **Step 1: Create `mcp-server/src/tools/project-languages.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerProjectLanguageTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_project_languages', {
    description: 'List languages configured on a project',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.GET('/api/projects/{id}/languages', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('add_project_language', {
    description: 'Add a language to a project',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
      languageId: z.string().uuid().describe('Language UUID from the global catalog'),
    }),
  }, async ({ id, languageId }) => {
    const { data, error, response } = await client.POST('/api/projects/{id}/languages', {
      params: { path: { id } },
      body: { languageId },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('remove_project_language', {
    description: 'Remove a language from a project',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
      languageId: z.string().uuid().describe('Project language UUID'),
    }),
  }, async ({ id, languageId }) => {
    const { data, error, response } = await client.DELETE('/api/projects/{id}/languages/{languageId}', {
      params: { path: { id, languageId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { removed: true });
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/project-languages.ts
git commit -m "feat(mcp): add project language tools (list, add, remove)"
```

---

## Task 9: Repository tools (4 tools)

**Files:**
- Create: `mcp-server/src/tools/repositories.ts`

Tools: `list_repositories`, `create_repository`, `delete_repository`, `detect_repository`

- [ ] **Step 1: Create `mcp-server/src/tools/repositories.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerRepositoryTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_repositories', {
    description: 'List repositories connected to a project',
    inputSchema: z.object({}),
  }, async () => {
    const { data, error, response } = await client.GET('/api/repositories');
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('create_repository', {
    description: 'Connect a git repository to a project for translation file syncing',
    inputSchema: z.object({
      projectId: z.string().uuid().describe('Project UUID'),
      url: z.string().describe('Git repository URL'),
      branch: z.string().describe('Branch to sync'),
      provider: z.string().describe('Git provider (e.g. github)'),
      localePath: z.string().describe('Path pattern for locale files in the repo'),
    }),
  }, async ({ projectId, url, branch, provider, localePath }) => {
    const { data, error, response } = await client.POST('/api/repositories', {
      body: { projectId, url, branch, provider, localePath },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('delete_repository', {
    description: 'Disconnect a repository',
    inputSchema: z.object({
      id: z.string().uuid().describe('Repository UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.DELETE('/api/repositories/{id}', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { deleted: true });
  });

  server.registerTool('detect_repository', {
    description: 'Re-scan a repository to detect i18n files and structure',
    inputSchema: z.object({
      id: z.string().uuid().describe('Repository UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.POST('/api/repositories/{id}/detect', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/repositories.ts
git commit -m "feat(mcp): add repository tools (list, create, delete, detect)"
```

---

## Task 10: Glossary tools (3 tools)

**Files:**
- Create: `mcp-server/src/tools/glossary.ts`

Tools: `list_glossary`, `create_glossary_entry`, `delete_glossary_entry`

- [ ] **Step 1: Create `mcp-server/src/tools/glossary.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerGlossaryTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_glossary', {
    description: 'List glossary entries for a project',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.GET('/api/projects/{id}/glossary', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('create_glossary_entry', {
    description: 'Add a glossary term pair (source term and target translation)',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
      sourceTerm: z.string().describe('Source language term'),
      targetTerm: z.string().describe('Target language translation'),
      languageId: z.string().uuid().describe('Target language UUID'),
    }),
  }, async ({ id, sourceTerm, targetTerm, languageId }) => {
    const { data, error, response } = await client.POST('/api/projects/{id}/glossary', {
      params: { path: { id } },
      body: { sourceTerm, targetTerm, languageId },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('delete_glossary_entry', {
    description: 'Remove a glossary entry',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
      entryId: z.string().uuid().describe('Glossary entry UUID'),
    }),
  }, async ({ id, entryId }) => {
    const { data, error, response } = await client.DELETE('/api/projects/{id}/glossary/{entryId}', {
      params: { path: { id, entryId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { deleted: true });
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/glossary.ts
git commit -m "feat(mcp): add glossary tools (list, create, delete)"
```

---

## Task 11: Style guide tools (3 tools)

**Files:**
- Create: `mcp-server/src/tools/style-guides.ts`

Tools: `list_style_guides`, `upsert_style_guide`, `delete_style_guide`

- [ ] **Step 1: Create `mcp-server/src/tools/style-guides.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerStyleGuideTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_style_guides', {
    description: 'List style guides for a project',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
    }),
  }, async ({ id }) => {
    const { data, error, response } = await client.GET('/api/projects/{id}/style-guides', {
      params: { path: { id } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('upsert_style_guide', {
    description: 'Create or update translation style instructions for a specific language in a project',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
      projectLanguageId: z.string().uuid().describe('Project language UUID'),
      instructions: z.string().describe('Style guide instructions text'),
    }),
  }, async ({ id, projectLanguageId, instructions }) => {
    const { data, error, response } = await client.PUT('/api/projects/{id}/style-guides/{projectLanguageId}', {
      params: { path: { id, projectLanguageId } },
      body: { instructions },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('delete_style_guide', {
    description: 'Remove a style guide from a project language',
    inputSchema: z.object({
      id: z.string().uuid().describe('Project UUID'),
      projectLanguageId: z.string().uuid().describe('Project language UUID'),
    }),
  }, async ({ id, projectLanguageId }) => {
    const { data, error, response } = await client.DELETE('/api/projects/{id}/style-guides/{projectLanguageId}', {
      params: { path: { id, projectLanguageId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { deleted: true });
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/style-guides.ts
git commit -m "feat(mcp): add style guide tools (list, upsert, delete)"
```

---

## Task 12: API key tools (3 tools)

**Files:**
- Create: `mcp-server/src/tools/api-keys.ts`

Tools: `list_api_keys`, `create_api_key`, `revoke_api_key`

- [ ] **Step 1: Create `mcp-server/src/tools/api-keys.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerApiKeyTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_api_keys', {
    description: 'List API keys for an organisation',
    inputSchema: z.object({
      orgId: z.string().uuid().describe('Organisation UUID'),
    }),
  }, async ({ orgId }) => {
    const { data, error, response } = await client.GET('/api/orgs/{orgId}/api-keys', {
      params: { path: { orgId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('create_api_key', {
    description: 'Create a new API key for an organisation',
    inputSchema: z.object({
      orgId: z.string().uuid().describe('Organisation UUID'),
      name: z.string().describe('Key name for identification'),
    }),
  }, async ({ orgId, name }) => {
    const { data, error, response } = await client.POST('/api/orgs/{orgId}/api-keys', {
      params: { path: { orgId } },
      body: { name },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('revoke_api_key', {
    description: 'Revoke an API key',
    inputSchema: z.object({
      orgId: z.string().uuid().describe('Organisation UUID'),
      keyId: z.string().uuid().describe('API key UUID'),
    }),
  }, async ({ orgId, keyId }) => {
    const { data, error, response } = await client.DELETE('/api/orgs/{orgId}/api-keys/{keyId}', {
      params: { path: { orgId, keyId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { revoked: true });
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/api-keys.ts
git commit -m "feat(mcp): add API key tools (list, create, revoke)"
```

---

## Task 13: Member tools (3 tools)

**Files:**
- Create: `mcp-server/src/tools/members.ts`

Tools: `list_members`, `invite_member`, `remove_member`

- [ ] **Step 1: Create `mcp-server/src/tools/members.ts`**

```ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';
import { formatError, formatSuccess } from '../client.js';

export function registerMemberTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_members', {
    description: 'List members of an organisation',
    inputSchema: z.object({
      orgId: z.string().uuid().describe('Organisation UUID'),
    }),
  }, async ({ orgId }) => {
    const { data, error, response } = await client.GET('/api/orgs/{orgId}/members', {
      params: { path: { orgId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('invite_member', {
    description: 'Invite a user to an organisation by their user ID',
    inputSchema: z.object({
      orgId: z.string().uuid().describe('Organisation UUID'),
      userId: z.string().describe('Clerk user ID of the person to invite'),
    }),
  }, async ({ orgId, userId }) => {
    const { data, error, response } = await client.POST('/api/orgs/{orgId}/members', {
      params: { path: { orgId } },
      body: { userId },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data);
  });

  server.registerTool('remove_member', {
    description: 'Remove a member from an organisation',
    inputSchema: z.object({
      orgId: z.string().uuid().describe('Organisation UUID'),
      membershipId: z.string().uuid().describe('Membership UUID'),
    }),
  }, async ({ orgId, membershipId }) => {
    const { data, error, response } = await client.DELETE('/api/orgs/{orgId}/members/{membershipId}', {
      params: { path: { orgId, membershipId } },
    });
    if (error) return formatError(response.status, error);
    return formatSuccess(data ?? { removed: true });
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp-server/src/tools/members.ts
git commit -m "feat(mcp): add member tools (list, invite, remove)"
```

---

## Task 14: Build verification and type generation

**Files:**
- None new — verifies existing files compile correctly

- [ ] **Step 1: Generate types and build**

```bash
cd mcp-server && npm run build
```

Expected: TypeScript compiles successfully. `dist/` directory contains compiled `.js` and `.d.ts` files.

- [ ] **Step 2: Fix any type errors**

If the build fails due to OpenAPI type mismatches (e.g., path parameter names don't match the spec), adjust the tool files to match the actual API spec types. Common issues:
- Path parameter names might differ from the spec doc (e.g., `{id}` vs `{projectId}`)
- Request body shapes might have additional required fields
- Response types might be wrapped differently

Read the generated `src/api-types.ts` to see the actual path signatures and adjust tool files accordingly.

- [ ] **Step 3: Verify the binary runs**

```bash
cd mcp-server && node bin/globalize-mcp.mjs --help 2>&1 || echo "Server started (expected — it waits for MCP messages on stdin)"
```

The server will hang waiting for stdin input — that's correct behavior for a stdio MCP server. Kill it with Ctrl+C.

- [ ] **Step 4: Commit any fixes**

```bash
cd mcp-server
git add -A
git commit -m "fix(mcp): resolve type errors from OpenAPI spec alignment"
```

Only commit if there were changes. If the build succeeded cleanly, skip this step.
