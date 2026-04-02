# Globalise-Now CLI Design

## Context

The Globalize MCP server (`@globalize-now/mcp-server`) exposes 28 tools across 9 groups to interact with the Globalize API. Every MCP-connected agent must load all 28 tool schemas upfront, consuming significant LLM context before any work begins.

The CLI replaces this with progressive discovery: agents call `globalise-now-cli --help` to see 9 command groups, then drill into a group to see its subcommands. This reduces upfront context from ~28 tool schemas to a single shell command.

The CLI serves both LLM agents (JSON output, scriptable) and human developers (pretty tables, colors). It becomes the single source of truth for API logic — the MCP server will be refactored into a thin adapter that imports the CLI's core library.

## Package

- **Directory:** `api-client/`
- **npm name:** `@globalize-now/client`
- **Binary:** `globalise-now-cli`
- **Language:** TypeScript (ESM), compiled to `dist/`
- **Node:** >= 18

## Command Structure

Two-level subcommand pattern: `globalise-now-cli <group> <action> [options]`

### Top-level groups

| Group | Description |
|-------|-------------|
| `orgs` | Manage organisations |
| `projects` | Manage translation projects |
| `languages` | Browse available languages |
| `project-languages` | Manage languages within a project |
| `repositories` | Connect git repositories |
| `glossary` | Manage glossary term pairs |
| `style-guides` | Manage translation style guides |
| `api-keys` | Manage API keys |
| `members` | Manage organisation members |
| `auth` | Configure authentication |

### Commands per group

**orgs**
- `list` — List all organisations
- `create --name <name>` — Create an organisation
- `delete --id <orgId>` — Delete an organisation

**projects**
- `list` — List all projects
- `create --name <name> --source-language <id> --target-languages <id,...>` — Create a project
- `get --id <id>` — Get project details
- `delete --id <id>` — Delete a project

**languages**
- `list` — List all available languages
- `get --id <id>` — Get language details

**project-languages**
- `list --project-id <id>` — List languages in a project
- `add --project-id <id> --name <name> --locale <bcp47> [--language-id <id>]` — Add a language
- `remove --project-id <id> --language-id <id>` — Remove a language

**repositories**
- `list --project-id <id>` — List repositories
- `create --project-id <id> --git-url <url> --provider <github|gitlab> [--branches <b,...>] [--locale-path-pattern <pat>]` — Connect a repository
- `delete --id <id>` — Delete a repository
- `detect --id <id>` — Trigger locale file detection

**glossary**
- `list --project-id <id>` — List glossary entries
- `create --project-id <id> --source-term <term> --target-term <term> --source-language-id <id> --target-language-id <id>` — Add an entry
- `delete --project-id <id> --entry-id <id>` — Delete an entry

**style-guides**
- `list --project-id <id>` — List style guides
- `upsert --project-id <id> --language-id <id> --instructions <text>` — Create or update a style guide
- `delete --project-id <id> --language-id <id>` — Delete a style guide

**api-keys**
- `list --org-id <id>` — List API keys
- `create --org-id <id> --name <name>` — Create an API key
- `revoke --org-id <id> --key-id <id>` — Revoke an API key

**members**
- `list --org-id <id>` — List members
- `invite --org-id <id> --clerk-user-id <uid> [--role <admin|member>]` — Invite a member
- `remove --org-id <id> --membership-id <id>` — Remove a member

**auth**
- `login` — Interactive: opens browser to API key settings, prompts to paste key
- `status` — Show current authentication state (org, key prefix)
- `logout` — Remove stored credentials

## Authentication

Same resolution chain as the MCP server:

1. `GLOBALIZE_API_KEY` environment variable
2. `~/.globalize/config.json` file (`{ "apiKey": "...", "apiUrl": "..." }`)
3. `globalise-now-cli auth login` interactive flow

`GLOBALIZE_API_URL` env var overrides the default `https://api.globalize.now` base URL.

## Output Formatting

Auto-detect based on stdout:

| Condition | Format |
|-----------|--------|
| stdout is TTY | Pretty tables with colors |
| stdout is piped / non-TTY | JSON |
| `--json` flag present | JSON (regardless of TTY) |

**JSON output** is always a single JSON object to stdout:
```json
{ "data": [...] }
```

**Errors** use exit code 1. In JSON mode: `{"error": "message"}` to stdout. In TTY mode: colored error message to stderr.

## Technology Stack

| Concern | Library |
|---------|---------|
| Arg parsing | `commander` |
| HTTP client | `openapi-fetch` + generated types from API spec |
| Tables | `cli-table3` |
| Colors | `chalk` |
| Type generation | `openapi-typescript` (same script as MCP server) |

## Directory Structure

```
api-client/
  bin/
    globalise-now-cli.mjs        # #!/usr/bin/env node entry point
  src/
    index.ts                     # Programmatic API exports
    cli.ts                       # Commander setup, group registration
    auth.ts                      # Auth resolution (shared logic with MCP)
    client.ts                    # openapi-fetch client factory
    format.ts                    # TTY detection, JSON/table output
    commands/
      orgs.ts                    # Org commands
      projects.ts                # Project commands
      languages.ts               # Language commands
      project-languages.ts       # Project language commands
      repositories.ts            # Repository commands
      glossary.ts                # Glossary commands
      style-guides.ts            # Style guide commands
      api-keys.ts                # API key commands
      members.ts                 # Member commands
      auth.ts                    # Auth commands (login/status/logout)
  package.json
  tsconfig.json
```

## Programmatic API

The package exports a library alongside the CLI binary, so the MCP server can import it:

```typescript
// Exported from api-client/src/index.ts
export { createClient } from './client.js';
export { resolveAuth } from './auth.js';
export { listOrgs, createOrg, deleteOrg } from './commands/orgs.js';
// ... etc for all command groups
```

Each command function takes a client instance and returns typed data — no formatting, no side effects. The CLI layer calls these functions and formats output. The MCP server will call the same functions and format for MCP.

## MCP Server Migration Path

1. Build the CLI package with full API coverage
2. Refactor MCP server to depend on `@globalize-now/client`
3. MCP tool handlers become thin wrappers: parse MCP input, call CLI function, format MCP output
4. Remove duplicated API client code from MCP server

## Verification

1. `npm run build` succeeds in `api-client/`
2. `globalise-now-cli --help` shows all 10 command groups
3. `globalise-now-cli projects --help` shows subcommands with options
4. `globalise-now-cli auth login` stores key to `~/.globalize/config.json`
5. `globalise-now-cli orgs list` returns data from API (TTY: table, piped: JSON)
6. `globalise-now-cli projects list --json` forces JSON output
7. Invalid commands show helpful error messages
8. Missing auth shows clear "run `globalise-now-cli auth login`" guidance
