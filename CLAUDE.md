# Globalization Skills

Agent skills for localizing software projects. Currently targeting Claude Code, with plans to support other agents.

## Repository Structure

Skills live under `skills/{library}/{operation}/`. Each skill is a self-contained directory:

```
skills/
  {library}/
    {operation}/
      SKILL.md           # Main skill file with frontmatter
      references/        # Variant-specific guides (optional)
```

Examples: `skills/lingui/setup/`, `skills/i18next/setup/`, `skills/php-intl/setup/`

## Conventions

- **Self-contained skills**: Each skill directory has everything it needs. No shared abstractions between skills. Duplication is acceptable.
- **SKILL.md frontmatter**: `name` uses `{library}-{operation}` format (e.g. `lingui-setup`). `description` explains when to trigger the skill.
- **Reference files**: Variant-specific instructions that the main SKILL.md dispatches to based on project detection (e.g. `references/nextjs-app-router.md`).
- **Detection-first**: Setup skills should detect the target project's framework, compiler, router, language, and package manager before taking action.

## Installing a Skill

Copy the skill directory into the target project's `.claude/skills/` with a flattened name:

```bash
cp -r skills/lingui/setup /path/to/project/.claude/skills/lingui-setup
```
