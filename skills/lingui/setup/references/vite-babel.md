# Vite + Babel Setup

This covers Vite projects using `@vitejs/plugin-react` (Babel-based, without the `-swc` suffix).

## Packages

In addition to the core packages from Step 2, install:

| Package | Type | Purpose |
|---------|------|---------|
| `@lingui/babel-plugin-lingui-macro` | dev | Babel macro transform |
| `@lingui/vite-plugin` | dev | Vite integration for catalog compilation |

**Example (npm):**

```bash
npm install @lingui/core @lingui/react @lingui/macro
npm install -D @lingui/cli @lingui/babel-plugin-lingui-macro @lingui/vite-plugin
```

## Build Tool Integration (Step 4)

Modify `vite.config.ts` to add the Babel plugin and the Lingui Vite plugin:

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { lingui } from '@lingui/vite-plugin'

export default defineConfig({
  plugins: [
    react({
      babel: {
        plugins: ['@lingui/babel-plugin-lingui-macro'],
      },
    }),
    lingui(),
  ],
})
```

If the project already has Babel plugins configured in the `react()` call, add `@lingui/babel-plugin-lingui-macro` to the existing array.

## Provider Setup (Step 5)

The provider setup is identical to Vite + SWC — refer to `references/vite-swc.md` for full details. The same two paths apply:

- **Per-page catalogs** (file-based routing): Create a minimal `src/i18n.ts` with `activateLocale`, load catalogs at the route level.
- **Single catalog** (plain SPA): Create `src/i18n.ts` with `loadCatalog`, load the global catalog at app init.

Wrap the app with `I18nProvider` at the highest level — in `main.tsx`, the root route layout, or wherever the component tree begins.
