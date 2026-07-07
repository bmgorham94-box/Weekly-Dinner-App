# Weekly Dinner Planner — Design System

A hand-off spec for refining the UI. This documents the **current** visual
system (Strava-inspired) as implemented in `css/styles.css` and the inline SVG
icon set in `js/app.js`. A designer or design-focused AI can propose changes
against these tokens and components.

> **Hard constraint for any redesign:** the app is a dependency-free, offline
> vanilla-JS PWA. All styling lives in **one file** (`css/styles.css`) driven by
> CSS custom properties. **Do not rename the existing CSS custom-property token
> names or the DOM class names** — `js/app.js` renders HTML strings that key off
> both, and several components set colors inline via `var(--token)` and
> `color-mix()`. You may freely change token *values*, typography, spacing, and
> component rules. Keep it framework-free (no Tailwind/React/etc.), and keep AA
> contrast in both light and dark themes.

---

## 1. Brand & direction

- **Feel:** Strava — clean, athletic, data-forward. White/light cards, one
  strong accent (orange), heavy condensed headings, uppercase micro-labels,
  minimal chrome, generous whitespace, crisp line icons.
- **Primary accent:** Strava orange `#FC4C02` (light) / `#FC5200` (dark).
- **Icon style:** Lucide-style 24×24 line icons, `currentColor` stroke,
  `stroke-width: 2`. No emojis anywhere in the UI.

---

## 2. Color tokens

Defined in `:root` (light) and overridden in `@media (prefers-color-scheme: dark)`
**and** a `[data-theme="dark"]` block (for a future manual toggle). Token names
are load-bearing — keep them; change values freely.

| Token | Light | Dark | Role |
|---|---|---|---|
| `--bg` | `#f6f6f8` | `#1b1b1d` | page background |
| `--surface` | `#ffffff` | `#26262a` | cards, app bar, inputs |
| `--surface-sunken` | `#eeeef1` | `#151517` | insets, "have" list, chips-off |
| `--ink` | `#242428` | `#f2f2f4` | primary text |
| `--muted` | `#6d6d78` | `#a0a0ab` | secondary text |
| `--brand` | `#fc4c02` | `#fc5200` | primary buttons, links, app-bar wordmark, active tab (via brand family) |
| `--brand-2` | `#ff6b33` | `#ff7a3d` | lighter-orange highlight / accents |
| `--ochre` | `#fc4c02` | `#fc5200` | cuisine badge tint |
| `--sage` | `#5c5c66` | `#9a9aa4` | neutral gray accent (time badge) |
| `--success` | `#fc4c02` | `#fc5200` | grocery "done" / in-stock (orange; palette has no green) |
| `--line` | `#e6e6ec` | `#34343a` | borders, dividers |
| `--on-brand` | `#ffffff` | `#ffffff` | text on `--brand` |
| `--walnut` | `#242428` | `#f2f2f4` | (legacy accent, rarely used) |

Badges/warnings derive tints at render time with
`color-mix(in srgb, var(--token) N%, var(--surface))` — e.g. the "over fat cap"
badge is `--brand`, "fat high" is `--brand-2`, cuisine is `--ochre`, time is
`--sage`. If you change the palette, these stay coherent automatically.

**Meta/manifest colors to keep in sync if the app bar changes:**
`index.html` has `<meta name="theme-color">` = `#ffffff` (light) / `#1b1b1d`
(dark); `manifest.webmanifest` `theme_color` = `#fc4c02`, `background_color` =
`#f6f6f8`.

---

## 3. Typography

- **Headings:** `--font-head` = **Archivo** (700–800), fallback system sans.
  Used for h2/h3, app-bar wordmark, buttons, badges, aisle titles, tab labels.
- **Body/UI:** `--font-body` = **Inter** (400–700), fallback system sans.
- Loaded via Google Fonts `<link>` in `index.html` (`Archivo:wght@500;600;700;800`
  + `Inter:wght@400;500;600;700`). **No serif fonts** (explicit product
  requirement).

| Element | Font | Size / weight | Notes |
|---|---|---|---|
| App wordmark (`.logo`) | Archivo 800 | 18px, uppercase, `letter-spacing .03em` | orange |
| `h2` | Archivo 800 | 25px / line 1.15 / `-0.01em` | section titles |
| `.hero h2` | Archivo 800 | 29px | empty states |
| `h3` | Archivo 700 | 18px / line 1.2 | card + block titles |
| `.badge` | Archivo 700 | 11px, uppercase, `letter-spacing .04em` | pill labels |
| `.aisle-title` | Archivo 800 | 12px, uppercase, `.07em` | grocery aisles |
| `.tabbar span` | Archivo 700 | 9px, uppercase, `.04em` | tab labels |
| body | Inter 400 | 16px / line 1.5 | |
| `.small` | Inter | 13px | |

---

## 4. Spacing, radius, shadow, motion

- **Spacing (8px grid):** `--s1:4 --s2:8 --s3:16 --s4:24 --s5:32 --s6:48`.
  Container gutter = `--s3` (16px). Card padding = `--s4` (24px). Section rhythm
  ≈ `--s4`. Body has `padding-bottom: calc(92px + safe-area)` to clear the
  floating tab bar.
- **Radius:** `--r-sm:8 --r-md:12 --r-lg:18 --r-pill:999`. Cards use `--r-lg`;
  buttons `--r-md`; chips/tab bar `--r-pill`.
- **Shadows (neutral, soft):** `--shadow-sm` (resting cards), `--shadow-md`
  (hover/raised), `--shadow-nav` (floating tab bar). Light and dark variants.
- **Motion:** `--dur-fast:150ms --dur:220ms`, `--ease: cubic-bezier(.2,.7,.3,1)`.
  All transitions collapse under `prefers-reduced-motion`.

---

## 5. Layout

- Single column, `.container { max-width: 720px; margin: 0 auto; padding: 24px 16px 16px }`.
- **App bar** (`.appbar`): sticky, white/dark `--surface`, 1px bottom `--line`,
  orange uppercase wordmark + a small icon. Respects `env(safe-area-inset-top)`.
- **Bottom tab bar** (`.tabbar`): fixed, **floating glass pill** — centered,
  `width: min(100vw - 24px, 640px)`, `backdrop-filter: blur`, `--shadow-nav`,
  `--r-pill`. 6 tabs (Plan, Grocery, Pantry, Recipes, History, Prefs). Active
  tab = orange icon + label (`.tabbar button.active { color: var(--brand) }`,
  icon scales 1.06). Respects `env(safe-area-inset-bottom)`.
- **Cards** (`.card`) are the primary surface for recipes and blocks.

---

## 6. Components (class → intent)

- `.primary` — filled orange CTA (Archivo 700, icon + label, `inline-flex`).
- `.ghost` / `.ghost.small` — outlined/subtle button; `.small` used in headers.
- `.icon` — 40px round icon button.
- `.link` — inline text link (orange, underlined).
- `.card` / `.card-head` / `.card-actions` / `.note` — recipe & content cards.
- `.badges` + `.badge` (+ `.badge.cuisine|.spicy|.time|.est`) — pill metadata.
  `.badge.est` is the dashed "~est" (unverified-macros) marker.
- `.chip` / `.chip.active` — filter chips (Recipes tab, Prefs cuisine/training).
- `.filterbar` — wrapping row of chips.
- `.grocery-list` + `.g-name/.g-qty/.g-used` — checkable aisle lists;
  `li:has(input:checked)` strikes through.
- `.aisle` / `.aisle-title` — WinCo aisle groupings.
- `table.pantry` + `.ok/.warn` — pantry status table.
- `.field` / `.field.check` — Prefs & Add-recipe form rows.
- `#toast` — bottom transient toast.
- Overlays (share dialog, update banner) are built inline in `js/app.js` with
  `var(--token)` styles — restyle via tokens.

---

## 7. Icon set

Inline SVGs live in the `ICONS` map in `js/app.js` (helper `ic(name, cls)`),
sizing via `.ic` (18px), `.ic-lg` (22px, tab bar), `.ic-sm` (14px, in badges).
Current icons: `sparkle, refresh, shuffle, cart, share, check, external,
activity, copy, download, upload, edit, x, layers, flame, zap, alert, box`.
Tab-bar + logo icons are inline in `index.html`. To add an icon: add a path to
`ICONS` and call `ic('name')`. Keep the 24×24 / stroke-2 / `currentColor` style.

---

## 8. Screens to design against

1. **Plan** — macro-summary card + 4 recipe cards (each: title, badges
   [cuisine/spicy/quick/macros/fat-warning/protein], note, notes disclosure,
   Recipe link, **Swap this meal**, **Double**, specific-meal dropdown) +
   dessert + actions (Grocery / Share / Save week).
2. **Grocery** — aisle-grouped checkable list + "already have" disclosure +
   Copy / Download / Mark-as-bought.
3. **Pantry** — status table.
4. **Recipes** — filter chips (cuisine / protein / high-protein / low-fat /
   quick) + card grid + **Add recipe**.
5. **Add recipe** (`#add`) — form.
6. **History** — saved weeks.
7. **Prefs** — cuisines, sliders, macro targets, training days, backup/restore.

---

## 9. What a refinement pass could improve (open prompts)

- Stronger visual hierarchy on the Plan macro-summary (progress bars vs target?).
- A real "completed/checked" treatment for grocery (color, motion).
- Card density options (comfortable vs compact).
- Empty-state illustrations (must be inline SVG, no external assets).
- Optional: a manual light/dark toggle (the `[data-theme]` hook already exists;
  no JS sets it yet).
- Reconsider whether `--success` should introduce a green (currently orange to
  stay monochrome) — a designer's call.

Deliver changes as edits to `css/styles.css` (values/rules), `index.html`
(fonts/meta/tab-bar SVGs), and the `ICONS` map — nothing else required.
