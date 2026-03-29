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

The provider setup is identical to Vite + SWC. Create `src/i18n.ts`:

```ts
import { i18n } from '@lingui/core'

export async function loadCatalog(locale: string) {
  const { messages } = await import(`./locales/${locale}/messages.ts`)
  i18n.load(locale, messages)
  i18n.activate(locale)
}

// Load default locale
loadCatalog('en')

export { i18n }
```

Wrap the app with `I18nProvider` at the highest level — in `main.tsx`, the root route layout, or wherever the component tree begins:

```tsx
import { I18nProvider } from '@lingui/react'
import { i18n } from './i18n'

function App() {
  return (
    <I18nProvider i18n={i18n}>
      {/* app content */}
    </I18nProvider>
  )
}
```
