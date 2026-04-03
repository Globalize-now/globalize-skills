---
name: globalize-now-cli-use
description: >-
  Manage Globalize translation resources using the CLI. Use this skill when the user asks
  to create a translation project, add or remove languages, connect a git repository,
  manage glossaries or style guides, invite team members, manage API keys, or perform any
  Globalize platform operation. Also use when the user mentions managing translations,
  translation workflow, or wants to "set up translations for this repo." This skill assumes
  the CLI is already installed and authenticated — run globalize-now-cli-setup first if not.
---

# Globalize CLI Usage

This skill guides you through managing translation resources on the [Globalize](https://globalize.now) platform using the CLI (`globalise-now-cli`).

**Always use `--json`** when running commands programmatically. Parse JSON output to extract IDs for subsequent commands. Many operations require UUIDs returned from prior steps.

All examples use `npx @globalize-now/cli-client`. If the CLI is installed globally, replace with `globalise-now-cli`.

---

## Step 1: Prerequisite Check

Verify authentication is configured:

```bash
npx @globalize-now/cli-client auth status --json
```

If this fails or reports no credentials, run the `globalize-now-cli-setup` skill first.

---

## Step 2: Common Workflow — Create a Project and Connect a Repository

This is the most common end-to-end workflow. Follow these sub-steps in order:

### 2a. List available languages

Find the language IDs for the project's source and target languages:

```bash
npx @globalize-now/cli-client languages list --json
```

### 2b. Create a project

Use the language IDs from 2a:

```bash
npx @globalize-now/cli-client projects create \
  --name "My App" \
  --source-language en \
  --target-languages fr de ja \
  --json
```

`--target-languages` accepts space-separated or comma-separated values (`fr,de,ja` also works).

Parse the returned JSON to extract the **project ID**.

### 2c. Connect the repository

First, get the git remote URL:

```bash
git remote get-url origin
```

Then create the repository connection:

```bash
npx @globalize-now/cli-client repositories create \
  --project-id <PROJECT_ID> \
  --git-url <GIT_URL> \
  --provider github \
  --json
```

`--provider` must be `github` or `gitlab`. Optional flags: `--branches <branches...>` to track specific branches, `--locale-path-pattern <pattern>` to specify where locale files live.

Parse the returned JSON to extract the **repository ID**.

### 2d. Detect repository configuration

Auto-discover locale file patterns in the connected repository:

```bash
npx @globalize-now/cli-client repositories detect \
  --id <REPO_ID> \
  --json
```

---

## Step 3: Managing Project Languages

After project creation, add or remove target languages as needed.

**List** current project languages:

```bash
npx @globalize-now/cli-client project-languages list \
  --project-id <PROJECT_ID> \
  --json
```

This returns an array of project languages, each with its own **project language ID** (different from the global language ID). You'll need these IDs for glossary and style guide operations.

**Add** a language:

```bash
npx @globalize-now/cli-client project-languages add \
  --project-id <PROJECT_ID> \
  --name "Spanish" \
  --locale es \
  --json
```

Required: `--name` and `--locale` (BCP 47 code). Optional: `--language-id` to link to a specific global language.

**Remove** a language:

```bash
npx @globalize-now/cli-client project-languages remove \
  --project-id <PROJECT_ID> \
  --language-id <PROJECT_LANGUAGE_ID> \
  --json
```

---

## Step 4: Glossary Management

Glossaries ensure specific terms are translated consistently across languages.

**List** glossary entries:

```bash
npx @globalize-now/cli-client glossary list \
  --project-id <PROJECT_ID> \
  --json
```

**Create** a glossary entry:

```bash
npx @globalize-now/cli-client glossary create \
  --project-id <PROJECT_ID> \
  --source-term "Dashboard" \
  --target-term "Tableau de bord" \
  --source-language-id <SOURCE_PROJECT_LANGUAGE_ID> \
  --target-language-id <TARGET_PROJECT_LANGUAGE_ID> \
  --json
```

`--source-language-id` and `--target-language-id` are **project language UUIDs** from `project-languages list` (Step 3), not global language IDs.

**Delete** a glossary entry:

```bash
npx @globalize-now/cli-client glossary delete \
  --project-id <PROJECT_ID> \
  --entry-id <ENTRY_ID> \
  --json
```

---

## Step 5: Style Guide Management

Style guides provide translation instructions per language (e.g., "use formal register", "prefer British English spelling").

**List** style guides:

```bash
npx @globalize-now/cli-client style-guides list \
  --project-id <PROJECT_ID> \
  --json
```

**Create or update** a style guide:

```bash
npx @globalize-now/cli-client style-guides upsert \
  --project-id <PROJECT_ID> \
  --language-id <PROJECT_LANGUAGE_ID> \
  --instructions "Use formal register. Prefer British English spelling." \
  --json
```

`--language-id` is a **project language UUID** from `project-languages list` (Step 3).

**Delete** a style guide:

```bash
npx @globalize-now/cli-client style-guides delete \
  --project-id <PROJECT_ID> \
  --language-id <PROJECT_LANGUAGE_ID> \
  --json
```

---

## Step 6: Organisation and Team Management

These commands are less commonly needed from an agent but are available when requested.

### Organisations

```bash
npx @globalize-now/cli-client orgs list --json
npx @globalize-now/cli-client orgs create --name "My Org" --json
npx @globalize-now/cli-client orgs delete --id <ORG_ID> --json
```

### Members

```bash
npx @globalize-now/cli-client members list --org-id <ORG_ID> --json
npx @globalize-now/cli-client members invite --org-id <ORG_ID> --clerk-user-id <UID> --json
npx @globalize-now/cli-client members remove --org-id <ORG_ID> --membership-id <ID> --json
```

Optional `--role` flag on `invite`: `admin` or `member` (default: `member`).

### API Keys

```bash
npx @globalize-now/cli-client api-keys list --org-id <ORG_ID> --json
npx @globalize-now/cli-client api-keys create --org-id <ORG_ID> --name "CI Key" --json
npx @globalize-now/cli-client api-keys revoke --org-id <ORG_ID> --key-id <KEY_ID> --json
```

---

## Command Reference

| Command | Required flags | Optional flags |
|---------|---------------|----------------|
| `auth login` | *(interactive)* | |
| `auth status` | | |
| `auth logout` | | |
| `orgs list` | | |
| `orgs create` | `--name` | |
| `orgs delete` | `--id` | |
| `projects list` | | |
| `projects create` | `--name`, `--source-language`, `--target-languages` | |
| `projects get` | `--id` | |
| `projects delete` | `--id` | |
| `languages list` | | |
| `languages get` | `--id` | |
| `project-languages list` | `--project-id` | |
| `project-languages add` | `--project-id`, `--name`, `--locale` | `--language-id` |
| `project-languages remove` | `--project-id`, `--language-id` | |
| `repositories list` | `--project-id` | |
| `repositories create` | `--project-id`, `--git-url`, `--provider` | `--branches`, `--locale-path-pattern` |
| `repositories delete` | `--id` | |
| `repositories detect` | `--id` | |
| `glossary list` | `--project-id` | |
| `glossary create` | `--project-id`, `--source-term`, `--target-term`, `--source-language-id`, `--target-language-id` | |
| `glossary delete` | `--project-id`, `--entry-id` | |
| `style-guides list` | `--project-id` | |
| `style-guides upsert` | `--project-id`, `--language-id`, `--instructions` | |
| `style-guides delete` | `--project-id`, `--language-id` | |
| `api-keys list` | `--org-id` | |
| `api-keys create` | `--org-id`, `--name` | |
| `api-keys revoke` | `--org-id`, `--key-id` | |
| `members list` | `--org-id` | |
| `members invite` | `--org-id`, `--clerk-user-id` | `--role` |
| `members remove` | `--org-id`, `--membership-id` | |

---

## Common Gotchas

- **Always use `--json`**: The CLI auto-detects non-TTY and outputs JSON, but always pass `--json` explicitly when running programmatically for reliability.
- **IDs are UUIDs**: All `--id`, `--project-id`, `--org-id`, etc. expect UUID values returned from prior create/list commands. Always capture these from JSON responses.
- **Project language IDs vs global language IDs**: Glossary (`--source-language-id`, `--target-language-id`) and style guide (`--language-id`) commands use _project language_ UUIDs — the ID of a language within a specific project. Get these from `project-languages list`, not `languages list`.
- **Repository providers**: `--provider` only accepts `github` or `gitlab`.
- **Auth in non-interactive contexts**: The CLI does not fall back to interactive login when there's no TTY. Ensure `GLOBALIZE_API_KEY` is set or `~/.globalize/config.json` exists.
