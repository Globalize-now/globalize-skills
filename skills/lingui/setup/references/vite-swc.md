# Vite + SWC Setup

This covers Vite projects using `@vitejs/plugin-react-swc` — including plain Vite, TanStack Router, React Router, and any other SWC-based Vite setup.

## Packages

In addition to the core packages from Step 2, install:

| Package | Type | Purpose |
|---------|------|---------|
| `@lingui/swc-plugin` | dev | SWC macro transform |
| `@lingui/vite-plugin` | dev | Vite integration for catalog compilation |

**Example (npm):**

```bash
npm install @lingui/core @lingui/react @lingui/macro
npm install -D @lingui/cli @lingui/swc-plugin @lingui/vite-plugin
```

## Build Tool Integration (Step 4)

Modify `vite.config.ts` to add the SWC plugin and the Lingui Vite plugin:

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'
import { lingui } from '@lingui/vite-plugin'

export default defineConfig({
  plugins: [
    react({
      plugins: [['@lingui/swc-plugin', {}]],
    }),
    lingui(),
  ],
})
```

If the project already has other Vite plugins (e.g., TanStack Router plugin), keep them — just add the `lingui()` plugin alongside them and add `@lingui/swc-plugin` to the `react()` plugin's `plugins` array.

**Example with TanStack Router:**

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'
import { TanStackRouterVite } from '@tanstack/router-plugin/vite'
import { lingui } from '@lingui/vite-plugin'

export default defineConfig({
  plugins: [
    TanStackRouterVite(),
    react({
      plugins: [['@lingui/swc-plugin', {}]],
    }),
    lingui(),
  ],
})
```

## Provider Setup (Step 5)

The setup depends on whether the project uses per-page catalogs (file-based routing) or a single global catalog.

### Per-page catalogs (TanStack Router, React Router with file-based routing)

Create a minimal i18n setup file — catalog loading happens at the route level, not here:

```ts
// src/i18n.ts
import { i18n } from '@lingui/core'

const RTL_LOCALES = new Set(['ar', 'he', 'fa', 'ur', 'ps', 'sd', 'yi'])

function getDirection(locale: string): 'ltr' | 'rtl' {
  return RTL_LOCALES.has(locale.split('-')[0]) ? 'rtl' : 'ltr'
}

export function activateLocale(locale: string, messages: Record<string, string>) {
  i18n.loadAndActivate({ locale, messages })
  document.documentElement.lang = locale
  document.documentElement.dir = getDirection(locale)
}

export { i18n }
```

Wrap the app with `I18nProvider` at the root (same as single catalog — only the loading location changes).

**TanStack Router** — wrap in `__root.tsx`, load catalogs in each route:

```tsx
// src/routes/__root.tsx
import { createRootRoute, Outlet } from '@tanstack/react-router'
import { I18nProvider } from '@lingui/react'
import { i18n } from '../i18n'

export const Route = createRootRoute({
  component: () => (
    <I18nProvider i18n={i18n}>
      <Outlet />
    </I18nProvider>
  ),
})
```

```tsx
// src/routes/about.tsx
import { createFileRoute } from '@tanstack/react-router'
import { Trans } from '@lingui/react/macro'
import { activateLocale } from '../i18n'

export const Route = createFileRoute('/about')({
  beforeLoad: async () => {
    const locale = 'en' // determine from URL, context, or state
    const { messages } = await import('./locales/about/' + locale + '.ts')
    activateLocale(locale, messages)
  },
  component: AboutPage,
})

function AboutPage() {
  return <h1><Trans>About us</Trans></h1>
}
```

**React Router** — wrap in root layout, load catalogs in each route loader:

```tsx
// Root layout (unchanged)
import { Outlet } from 'react-router'
import { I18nProvider } from '@lingui/react'
import { i18n } from './i18n'

export default function RootLayout() {
  return (
    <I18nProvider i18n={i18n}>
      <Outlet />
    </I18nProvider>
  )
}
```

```tsx
// app/routes/about.tsx
import { Trans } from '@lingui/react/macro'
import { activateLocale } from '../i18n'

export async function loader() {
  const locale = 'en' // determine from URL params or cookie
  const { messages } = await import('./locales/about/' + locale + '.ts')
  activateLocale(locale, messages)
  return null
}

export default function AboutPage() {
  return <h1><Trans>About us</Trans></h1>
}
```

Each route loads its own co-located catalog. Shared component strings are duplicated across route catalogs — this is the expected trade-off for smaller per-page bundles.

### Single catalog (plain SPA without file-based routing)

Create an i18n setup file that loads the global catalog:

```ts
// src/i18n.ts
import { i18n } from '@lingui/core'

const RTL_LOCALES = new Set(['ar', 'he', 'fa', 'ur', 'ps', 'sd', 'yi'])

function getDirection(locale: string): 'ltr' | 'rtl' {
  return RTL_LOCALES.has(locale.split('-')[0]) ? 'rtl' : 'ltr'
}

export async function loadCatalog(locale: string) {
  const { messages } = await import(`./locales/${locale}/messages.ts`)
  i18n.loadAndActivate({ locale, messages })
  document.documentElement.lang = locale
  document.documentElement.dir = getDirection(locale)
}

// Load default locale
loadCatalog('en')

export { i18n }
```

Wrap the app with `I18nProvider` in `main.tsx`:

```tsx
import { I18nProvider } from '@lingui/react'
import { i18n } from './i18n'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <I18nProvider i18n={i18n}>
    <App />
  </I18nProvider>,
)
```
