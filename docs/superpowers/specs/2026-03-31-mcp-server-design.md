# Globalize MCP Server Design

## Overview

An MCP (Model Context Protocol) server that connects AI agents (Claude Code, Cursor, etc.) to the Globalize API at `api.globalize.now`. The initial scope covers project creation and setup — organisations, projects, languages, repositories, glossary, style guides, API keys, and members.

## Location

`mcp-server/` directory in the `globalization-skills` repo, alongside `cli/` and `skills/`. Published as a standalone npm package (`@globalize-now/mcp-server`), runnable via `npx`.

## Architecture

### Transport

stdio — the standard for local MCP servers. The server is launched by the AI agent's host process (e.g., Claude Code) and communicates over stdin/stdout.

### Runtime & SDK

- TypeScript compiled to ESM (matches CLI conventions)
- `@modelcontextprotocol/server` (MCP SDK v2) with `zod/v4` for tool input schemas
- `registerTool()` API (v2 pattern, replaces deprecated `server.tool()`)
- Node.js >= 18

### Project Structure

```
mcp-server/
  package.json
  tsconfig.json
  src/
    index.ts            # Entry — create McpServer, register tools, connect stdio transport
    auth.ts             # API key resolution + storage
    client.ts           # openapi-fetch wrapper with auth
    api-types.ts        # Generated from OpenAPI spec (not committed)
    tools/
      orgs.ts           # Organisation tools
      projects.ts       # Project tools
      languages.ts      # Language catalog tools
      project-languages.ts  # Project language tools
      repositories.ts   # Repository tools
      glossary.ts       # Glossary tools
      style-guides.ts   # Style guide tools
      api-keys.ts       # API key tools
      members.ts        # Member tools
  bin/
    globalize-mcp.mjs   # Executable entry point
```

## Authentication

### Resolution Chain

1. `GLOBALIZE_API_KEY` env var (for CI/testing)
2. `~/.globalize/config.json` file
3. Interactive: open `app.globalize.now/settings/api-keys` in browser, prompt user to paste key

### Config File

```json
{
  "apiKey": "glb_abc123...",
  "apiUrl": "https://api.globalize.now"
}
```

Stored at `~/.globalize/config.json`. The `apiUrl` defaults to `https://api.globalize.now` and can be overridden via `GLOBALIZE_API_URL` env var (useful for pointing to `stage-api.globalize.now`).

### Future: Local OAuth Callback (Option 1)

The auth module is designed so that the interactive step (step 3) can be replaced with a local OAuth callback flow:
- Server starts a temporary localhost HTTP server
- Opens `app.globalize.now/authorize?callback=http://localhost:{PORT}` in the browser
- User confirms in the browser (already logged in via Clerk)
- Browser redirects back with an API key
- Server stores it and shuts down the temp server

This requires an `/authorize` endpoint on the web app side. The storage and resolution chain stay the same — only step 3 changes.

## API Client

### Generated from OpenAPI Spec

Uses `openapi-typescript` + `openapi-fetch`:

1. **Type generation** (build time): `npx openapi-typescript https://api.globalize.now/api/docs/json -o src/api-types.ts`
   - Types are fetched from the network, not stored in the package
   - `generate` script runs before `build`
   - For development/staging: uses `stage-api.globalize.now`
2. **Runtime client**: `openapi-fetch` provides type-safe API calls

```ts
import createClient from 'openapi-fetch';
import type { paths } from './api-types.js';

const client = createClient<paths>({
  baseUrl: apiUrl,
  headers: { Authorization: `Bearer ${apiKey}` }
});

// Fully typed — params, body, and response inferred from OpenAPI spec
const { data } = await client.GET('/api/projects/{id}', {
  params: { path: { id } }
});
```

### Error Handling

HTTP errors are mapped to structured text responses the LLM can understand:
- 401/403 → "Authentication failed. Run the auth flow again."
- 404 → "Resource not found: {details}"
- 422 → "Validation error: {details}"
- 5xx → "Server error. Try again later."

## Tools

28 tools across 9 groups, covering the full setup surface.

### Organisations (3 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_orgs` | List user's organisations | `GET /api/orgs` |
| `create_org` | Create organisation by name | `POST /api/orgs` |
| `delete_org` | Delete organisation | `DELETE /api/orgs/{orgId}` |

### Projects (4 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_projects` | List all projects | `GET /api/projects` |
| `create_project` | Create project (name, source language, target languages) | `POST /api/projects` |
| `get_project` | Get project details | `GET /api/projects/{id}` |
| `delete_project` | Delete project | `DELETE /api/projects/{id}` |

### Languages (2 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_languages` | Search/list available languages (global catalog) | `GET /api/languages` |
| `get_language` | Get language details | `GET /api/languages/{id}` |

### Project Languages (3 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_project_languages` | List languages configured on a project | `GET /api/projects/{id}/languages` |
| `add_project_language` | Add a language to a project | `POST /api/projects/{id}/languages` |
| `remove_project_language` | Remove a language from a project | `DELETE /api/projects/{id}/languages/{languageId}` |

### Repositories (4 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_repositories` | List repos for a project | `GET /api/repositories` |
| `create_repository` | Connect a git repo (URL, branches, provider, locale path) | `POST /api/repositories` |
| `delete_repository` | Disconnect a repo | `DELETE /api/repositories/{id}` |
| `detect_repository` | Re-scan repo for i18n files | `POST /api/repositories/{id}/detect` |

### Glossary (3 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_glossary` | List glossary entries | `GET /api/projects/{id}/glossary` |
| `create_glossary_entry` | Add source/target term pair | `POST /api/projects/{id}/glossary` |
| `delete_glossary_entry` | Remove glossary entry | `DELETE /api/projects/{id}/glossary/{entryId}` |

### Style Guides (3 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_style_guides` | List style guides | `GET /api/projects/{id}/style-guides` |
| `upsert_style_guide` | Create/update instructions for a language | `PUT /api/projects/{id}/style-guides/{projectLanguageId}` |
| `delete_style_guide` | Remove style guide | `DELETE /api/projects/{id}/style-guides/{projectLanguageId}` |

### API Keys (3 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_api_keys` | List API keys for an org | `GET /api/orgs/{orgId}/api-keys` |
| `create_api_key` | Create new API key | `POST /api/orgs/{orgId}/api-keys` |
| `revoke_api_key` | Revoke an API key | `DELETE /api/orgs/{orgId}/api-keys/{keyId}` |

### Members (3 tools)

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `list_members` | List org members | `GET /api/orgs/{orgId}/members` |
| `invite_member` | Invite by Clerk user ID | `POST /api/orgs/{orgId}/members` |
| `remove_member` | Remove member | `DELETE /api/orgs/{orgId}/members/{membershipId}` |

## Tool Registration Pattern

Each tool file exports a function that registers tools on the server:

```ts
// tools/projects.ts
import { z } from 'zod/v4';
import type { McpServer } from '@modelcontextprotocol/server';
import type { ApiClient } from '../client.js';

export function registerProjectTools(server: McpServer, client: ApiClient) {
  server.registerTool('list_projects', {
    description: 'List all translation projects',
    inputSchema: z.object({})
  }, async () => {
    const { data, error } = await client.GET('/api/projects');
    if (error) return { content: [{ type: 'text', text: `Error: ${JSON.stringify(error)}` }] };
    return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
  });

  server.registerTool('create_project', {
    description: 'Create a new translation project',
    inputSchema: z.object({
      name: z.string().describe('Project name'),
      sourceLanguage: z.string().uuid().describe('Source language UUID'),
      targetLanguages: z.array(z.string().uuid()).describe('Target language UUIDs')
    })
  }, async ({ name, sourceLanguage, targetLanguages }) => {
    const { data, error } = await client.POST('/api/projects', {
      body: { name, sourceLanguage, targetLanguages }
    });
    if (error) return { content: [{ type: 'text', text: `Error: ${JSON.stringify(error)}` }] };
    return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
  });
}
```

## Entry Point

```ts
// src/index.ts
import { McpServer } from '@modelcontextprotocol/server';
import { StdioServerTransport } from '@modelcontextprotocol/server';
import { resolveAuth } from './auth.js';
import { createApiClient } from './client.js';
import { registerOrgTools } from './tools/orgs.js';
import { registerProjectTools } from './tools/projects.js';
// ... other tool groups

const server = new McpServer({
  name: 'globalize',
  version: '0.1.0'
});

const { apiKey, apiUrl } = await resolveAuth();
const client = createApiClient(apiKey, apiUrl);

registerOrgTools(server, client);
registerProjectTools(server, client);
// ... register all tool groups

const transport = new StdioServerTransport();
await server.connect(transport);
```

## Build & Type Generation

Types are generated at **build time** (before publish), not at runtime. End users installing via `npx` get pre-compiled JavaScript — no network access to the OpenAPI spec is needed at runtime.

```json
{
  "scripts": {
    "generate": "openapi-typescript https://api.globalize.now/api/docs/json -o src/api-types.ts",
    "generate:staging": "openapi-typescript https://stage-api.globalize.now/api/docs/json -o src/api-types.ts",
    "build": "npm run generate && tsc",
    "dev": "npm run generate:staging && tsc --watch"
  }
}
```

The `bin/globalize-mcp.mjs` is a thin executable shim that imports the compiled `dist/index.js` and runs it. It exists so `npx @globalize-now/mcp-server` works as a command.

## Installation by End Users

In Claude Code's `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "globalize": {
      "command": "npx",
      "args": ["@globalize-now/mcp-server"]
    }
  }
}
```

Or with environment-based config:

```json
{
  "mcpServers": {
    "globalize": {
      "command": "npx",
      "args": ["@globalize-now/mcp-server"],
      "env": {
        "GLOBALIZE_API_KEY": "glb_...",
        "GLOBALIZE_API_URL": "https://stage-api.globalize.now"
      }
    }
  }
}
```

## Future Expansion

The following tool groups can be added later without architectural changes:

- **Jobs** — create, start, monitor translation jobs; upload files; export translations
- **Translations** — list/browse translations per project
- **Translation Memory** — search and manage TM entries
- **Analytics** — cost and quality metrics
- **GitHub Integration** — list installations, repos, branches; detect i18n structure
- **Namespaces** — list, update, delete namespaces
