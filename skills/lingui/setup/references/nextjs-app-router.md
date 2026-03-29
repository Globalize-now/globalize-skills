# Next.js App Router Setup

This covers Next.js 13+ projects using the App Router with React Server Components (RSC). The setup is more involved than standard React because RSC can't use React context — LinguiJS provides a server-side `setI18n` API alongside a client-side provider.

## Packages

In addition to the core packages from Step 2, install:

| Package | Type | Purpose |
|---------|------|---------|
| `@lingui/swc-plugin` | dev | SWC macro transform (Next.js uses SWC by default) |

If the project has a `.babelrc`, use `@lingui/babel-plugin-lingui-macro` instead.

**Example (npm):**

```bash
npm install @lingui/core @lingui/react @lingui/macro
npm install -D @lingui/cli @lingui/swc-plugin
```

Note: No `@lingui/vite-plugin` — Next.js has its own build pipeline.

## Build Tool Integration (Step 4)

Add the SWC plugin to `next.config.js` (or `next.config.mjs` / `next.config.ts`):

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    swcPlugins: [['@lingui/swc-plugin', {}]],
  },
}
module.exports = nextConfig
```

For ESM config (`next.config.mjs`):

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    swcPlugins: [['@lingui/swc-plugin', {}]],
  },
}
export default nextConfig
```

If the project uses Babel instead of SWC, add the plugin to `.babelrc`:

```json
{
  "plugins": ["@lingui/babel-plugin-lingui-macro"]
}
```

## Provider Setup (Step 5)

The App Router needs three pieces: an i18n instance factory, a client provider component, and the root layout wiring. It also needs locale-based routing and middleware.

### 1. I18n Instance Factory

```ts
// src/app/appRouterI18n.ts
import { i18n, type I18n } from '@lingui/core'

const instances = new Map<string, I18n>()

export function getI18nInstance(locale: string): I18n {
  if (!instances.has(locale)) {
    const instance = i18n.make()
    // Use require for synchronous loading in server context
    const { messages } = require(`../locales/${locale}/messages.ts`)
    instance.load(locale, messages)
    instance.activate(locale)
    instances.set(locale, instance)
  }
  return instances.get(locale)!
}
```

### 2. Client Provider

```tsx
// src/app/LinguiClientProvider.tsx
'use client'

import type { Messages } from '@lingui/core'
import { I18nProvider } from '@lingui/react'
import { useMemo } from 'react'
import { getI18nInstance } from './appRouterI18n'

export function LinguiClientProvider({
  children,
  initialLocale,
  initialMessages,
}: {
  children: React.ReactNode
  initialLocale: string
  initialMessages: Messages
}) {
  const i18n = useMemo(() => {
    const instance = getI18nInstance(initialLocale)
    instance.load(initialLocale, initialMessages)
    instance.activate(initialLocale)
    return instance
  }, [initialLocale, initialMessages])

  return <I18nProvider i18n={i18n}>{children}</I18nProvider>
}
```

### 3. Locale-based Routing

Move pages under a `[lang]` dynamic segment:

```
src/app/
  [lang]/
    layout.tsx    ← root layout (was src/app/layout.tsx)
    page.tsx      ← home page (was src/app/page.tsx)
    ...other routes
  appRouterI18n.ts
  LinguiClientProvider.tsx
```

The root layout wires everything together:

```tsx
// src/app/[lang]/layout.tsx
import { setI18n } from '@lingui/react/server'
import { getI18nInstance } from '../appRouterI18n'
import { LinguiClientProvider } from '../LinguiClientProvider'

const locales = ['en', 'fr']  // adjust to match lingui.config.ts

export function generateStaticParams() {
  return locales.map((lang) => ({ lang }))
}

export default async function RootLayout({
  params,
  children,
}: {
  params: Promise<{ lang: string }>
  children: React.ReactNode
}) {
  const { lang } = await params
  const i18n = getI18nInstance(lang)
  setI18n(i18n)

  return (
    <html lang={lang}>
      <body>
        <LinguiClientProvider
          initialLocale={lang}
          initialMessages={i18n.messages}
        >
          {children}
        </LinguiClientProvider>
      </body>
    </html>
  )
}
```

Note: `params` is `Promise<{ lang: string }>` in Next.js 15+. For Next.js 13-14, use `params: { lang: string }` directly (no `await`).

### 4. Locale Middleware

Create middleware to redirect bare paths to locale-prefixed paths:

```ts
// src/middleware.ts
import { NextRequest, NextResponse } from 'next/server'

const locales = ['en', 'fr']  // adjust to match lingui.config.ts
const defaultLocale = 'en'

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  const pathnameHasLocale = locales.some(
    (locale) => pathname.startsWith(`/${locale}/`) || pathname === `/${locale}`,
  )

  if (pathnameHasLocale) return

  // Detect locale from Accept-Language header, fallback to default
  const acceptLanguage = request.headers.get('accept-language') ?? ''
  const detectedLocale =
    locales.find((locale) => acceptLanguage.includes(locale)) ?? defaultLocale

  request.nextUrl.pathname = `/${detectedLocale}${pathname}`
  return NextResponse.redirect(request.nextUrl)
}

export const config = {
  matcher: ['/((?!_next|api|favicon.ico).*)'],
}
```

### Using translations in components

Both server and client components can use the same macros:

```tsx
import { Trans, useLingui } from '@lingui/react/macro'

export function MyComponent() {
  const { t } = useLingui()
  return (
    <div>
      <h1><Trans>Welcome</Trans></h1>
      <p>{t`This works in both server and client components`}</p>
    </div>
  )
}
```

In server components, `useLingui` reads the i18n instance set by `setI18n()` in the layout. In client components, it reads from the `I18nProvider` context via `LinguiClientProvider`.
