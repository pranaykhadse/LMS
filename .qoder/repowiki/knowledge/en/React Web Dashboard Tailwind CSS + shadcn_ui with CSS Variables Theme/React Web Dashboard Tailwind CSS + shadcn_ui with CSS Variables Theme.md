---
kind: frontend_style
name: 'React Web Dashboard: Tailwind CSS + shadcn/ui with CSS Variables Theme'
category: frontend_style
scope:
    - '**'
source_files:
    - src/styles/theme.css
    - src/styles/tailwind.css
    - src/styles/fonts.css
    - src/styles/globals.css
    - src/main.tsx
    - src/app/App.tsx
    - src/app/components/ui/button.tsx
    - src/app/components/ui/utils.ts
---

## What system/approach is used

The web frontend (`src/`) is a React application styled with **Tailwind CSS v4** and the **shadcn/ui** component library. The styling stack consists of:
- Tailwind CSS v4 via `@import 'tailwindcss' source(none)` in `src/styles/tailwind.css`, with `@source '../**/*.{js,ts,jsx,tsx}'` to scan the app for class names.
- A shadcn/ui-compatible theme defined as CSS custom properties in `src/styles/theme.css`, using `oklch()` color values and a `@theme inline { ... }` block that maps semantic tokens (e.g. `--color-primary`, `--color-background`) to design tokens.
- Dark mode support via a `.dark` class selector that redefines the same CSS variables, plus an `@custom-variant dark (&:is(.dark *));` declaration.
- Animation utilities from `tw-animate-css` imported in `tailwind.css`.
- Google Fonts Inter loaded via `src/styles/fonts.css`.

The Flutter side (`lib/`, `android/`, `ios/`) has no custom CSS — it uses Flutter's native widget styling, so this card focuses on the React dashboard under `src/`.

## Key files and packages

- `src/styles/theme.css` — Central design token surface: light/dark CSS variables for background, foreground, primary, secondary, muted, accent, destructive, border, input, ring, chart palette, sidebar tokens, and radius; mapped into Tailwind's `@theme` namespace.
- `src/styles/tailwind.css` — Tailwind entry point importing the framework and `tw-animate-css`.
- `src/styles/fonts.css` — Imports Inter font family from Google Fonts.
- `src/styles/globals.css` — Present but empty; base styles live in `theme.css` under `@layer base`.
- `src/main.tsx` — Bootstraps React and imports `./styles/index.css` (which presumably chains into `tailwind.css`).
- `src/app/components/ui/*.tsx` — Full shadcn/ui primitive set (button, dialog, table, tabs, select, form, sonner, etc.) built on Radix primitives (`@radix-ui/react-*`) and `class-variance-authority` for variant-driven styling.
- `src/app/App.tsx` — The main dashboard view, composed almost entirely of Tailwind utility classes with inline `style` overrides for brand colors (e.g. `#5b5bd6`, `#1a1a2e`, `#f4f5f7`) and fixed-width layout (`width: "1440px"`, `margin: "0 auto"`).

## Architecture and conventions

- **Design tokens via CSS variables**: All colors, radii, and semantic roles are declared once in `theme.css` as CSS custom properties under `:root` and `.dark`. Components consume them through Tailwind's `@theme` mapping (e.g. `bg-primary`, `text-foreground`, `border-border`).
- **Dark mode strategy**: Toggle by adding/removing the `dark` class on the root element; the `@custom-variant dark (&:is(.dark *));` rule ensures descendant selectors work inside `.dark`.
- **Component styling via cva**: Each shadcn/ui component (e.g. `button.tsx`) defines variants with `class-variance-authority` (`cva`) and composes classes through a shared `cn` helper. Variants cover `variant` (default, destructive, outline, secondary, ghost, link) and `size` (default, sm, lg, icon).
- **Layered CSS**: Global resets and typography defaults live in `theme.css` under `@layer base`, which lets Tailwind utilities override them naturally.
- **Brand palette mixed with tokens**: While the component layer uses semantic tokens, `App.tsx` frequently hardcodes brand hex colors directly in JSX (e.g. `#5b5bd6` for accents, `#1a1a2e` for the top bar, `#f4f5f7` for page background). These could be promoted to tokens in `theme.css` for consistency.
- **Fixed desktop layout**: The dashboard renders at a fixed `1440px` width centered on screen, indicating a desktop-first, non-responsive approach for the current dashboard view.

## Conventions and constraints

- **Use shadcn/ui primitives** for all reusable UI elements — components under `src/app/components/ui/` are the single source of truth for buttons, dialogs, forms, tables, etc., rather than ad-hoc HTML.
- **Prefer semantic token classes** (`bg-primary`, `text-muted-foreground`, `border-destructive`, `rounded-lg`) over raw color values when possible, since the `@theme` mapping exists to support them.
- **Dark-mode aware styling**: Any new visual state should respect the `.dark` variant; use the existing CSS variable tokens so components automatically adapt to dark mode.
- **Typography baseline**: Base typography (h1–h4, label, button, input) is centralized in `theme.css` `@layer base`; pages should rely on Tailwind text utilities (`text-sm`, `text-base`, `text-xl`) layered on top.
- **Font family**: Inter is the global font, loaded via `fonts.css`; components can also specify it inline as seen in `App.tsx`.
- **Animations**: Use `tw-animate-css` utilities imported in `tailwind.css` rather than custom keyframes for transitions and entrance effects.