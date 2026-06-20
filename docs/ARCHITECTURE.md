# System Brief for an AI Agent — Weekly Dinner Planner

This document is written for an AI/LLM agent that needs to fully understand this
codebase before reading, modifying, or extending it. It describes the product,
the architecture, the data model, every core algorithm, and the known
constraints. Read this first; it is the source of truth for *intent*. The code is
the source of truth for *behavior*.

---

## 1. What this app is

A **client-side Progressive Web App (PWA)** that helps one household (a couple)
plan **4 weeknight dinners per week**, generate a **grocery list grouped by
WinCo Foods aisles**, and **track pantry staples across weeks** so recurring
shopping lists shrink over time. It also rotates in a **lighter / lower-fat
dessert** each week.

It is deliberately tuned to the owners' tastes (baked into the recipe data and
default preferences):
- Cook time **30–60 min** total (prep + cook).
- Cuisines: **Mexican, Italian, Mediterranean, Indian, American Chinese,
  American**, and spicy-friendly.
- **Excluded** entirely from the recipe set: Thai, authentic Chinese, Japanese,
  Korean, seafood/fishy, rhubarb, super-fatty meats (e.g. pork belly).
- Approachable creators (Half Baked Harvest featured heavily; plus Damn
  Delicious, Budget Bytes, RecipeTin Eats, Once Upon a Chef, The Modern Proper,
  Cookie and Kate, Skinnytaste).

There is **no backend, no database, no build step, and no third-party runtime
dependency**. All logic runs in the browser; all user state lives in
`localStorage`. The app works fully offline after first load.

---

## 2. Tech stack & deployment

- **HTML + CSS + vanilla JavaScript** (ES2020+). No framework, no bundler, no npm.
- `js/app.js` is a single IIFE (`(function(){ ... })()`) using `"use strict"`.
- **PWA**: `manifest.webmanifest` + `service-worker.js` make it installable and
  offline-capable.
- **State**: persisted to `localStorage` under key `weeklyDinnerApp.v1`.
- **Hosting**: GitHub Pages, deployed by `.github/workflows/deploy-pages.yml`
  (Pages "Source: GitHub Actions"). Live URL:
  `https://bmgorham94-box.github.io/Weekly-Dinner-App/`.
- Default/active branch: `claude/weekly-meal-plan-grocery-811g9y`. Every push to
  it auto-deploys.

To run locally, serve the repo root over http(s) (e.g. `python3 -m http.server`)
and open `index.html`. Opening via `file://` works for the UI but disables the
service worker and install.

---

## 3. File map

```
index.html                       App shell: header, <main id="app">, bottom tab bar, script tags.
css/styles.css                   All styling. Warm "spice" palette; mobile-first; CSS vars in :root.
js/recipes.js                    The recipe DATABASE (const RECIPES) + const CUISINES. Pure data + helper i().
js/app.js                        ALL logic: state, pantry, plan generator, grocery builder, rendering, exports, SW registration.
manifest.webmanifest             PWA metadata (name, icons, theme, standalone display).
service-worker.js                Offline cache (cache name "weekly-dinner-v1").
icons/icon.svg                   Primary maskable app icon (vector).
icons/icon-512.png               PNG fallback icon (generated; solid brand bg + cream circle).
docs/this-week-recipes.md        Generated sample: this week's recipes + instructions + links.
docs/grocery-list.md             Generated sample: WinCo grocery list for that week.
docs/ARCHITECTURE.md             This document.
README.md                        User-facing setup/usage + the link-verification caveat.
.github/workflows/deploy-pages.yml  CI: uploads repo root as a Pages artifact and deploys.
```

`index.html` loads `js/recipes.js` **before** `js/app.js`. `recipes.js` attaches
`window.RECIPES` and `window.CUISINES`; `app.js` reads those globals. There is no
module system — ordering in the HTML matters.

---

## 4. Data model

### 4.1 Recipe (in `js/recipes.js`)

`RECIPES` is an array of objects. Helper `i(name, qty, unit, cat)` builds
ingredient objects tersely. Shape:

```js
{
  id: "hbh-butter-chicken",          // unique string id (stable key; used in plan/history)
  title: "30 Minute Spicy Indian Butter Chicken",
  creator: "Half Baked Harvest",      // display attribution
  url: "https://www.halfbakedharvest.com/butter-chicken/",  // live recipe link
  cuisine: "Indian",                  // one of CUISINES or "Dessert"
  time: 30,                           // total minutes (prep+cook); used for the maxTime filter
  servings: 4,
  spicy: true,                        // boolean; drives 🌶 badge + spicy bias
  healthy: true,                      // boolean tag (informational; not currently filtered on)
  note: "…",                          // one-line description shown on cards
  ingredients: [ { name, qty, unit, cat }, … ],
  steps: [ "Step 1 …", "Step 2 …", … ]
}
```

Ingredient object: `{ name: string, qty: number|null, unit: string, cat: string }`.
`cat` is an **ingredient category code** that drives both the WinCo aisle grouping
and the pantry-tracking behavior. Valid codes (must match `CAT_META` keys in
app.js):

`produce, herb, meat, dairy, bakery, frozen, grain, canned, condiment, oil,
spice, baking, nuts`.

`CUISINES = ["Mexican","Italian","Mediterranean","Indian","American Chinese","American"]`.
Desserts use `cuisine: "Dessert"` (not in `CUISINES`, handled separately).

Current dataset: **23 recipes = 17 dinners + 6 desserts**, spanning all six
cuisines (Mexican 4, Italian 3, Mediterranean 3, Indian 3, American Chinese 2,
American 2), 11 dinners flagged spicy, all ≤ 60 min.

### 4.2 Persistent app state (in `js/app.js`)

One JSON object in `localStorage["weeklyDinnerApp.v1"]`. `defaultState`:

```js
{
  prefs: {
    likedCuisines: [all six],   // cuisines eligible for generation
    maxTime: 60,                // minutes; recipe.time must be <=
    dinnersPerWeek: 4,
    includeDessert: true,
    preferSpicy: true,          // bias spicy recipes toward selection
    avoidWeeks: 2               // don't reuse recipes from the last N saved weeks
  },
  plan: null | {               // the current (unsaved) week
    dinnerIds: string[],        // recipe ids
    dessertId: string|null,
    createdAt: "YYYY-MM-DD"
  },
  pantry: {                     // staples currently considered "in stock"
    [normKey]: { name, cat, stockedOn: "YYYY-MM-DD", coverageWeeks: number }
  },
  history: [                    // most-recent-first; capped at 20
    { id, date: "YYYY-MM-DD", dinnerIds: string[], dessertId: string|null }
  ]
}
```

`load()` deep-merges saved state over `defaultState` (and `prefs` specifically)
so older saves remain forward-compatible. `save()` writes the whole object.
State is **per device/browser** — there is no account or cross-device sync.

---

## 5. Core algorithms (all in `js/app.js`)

### 5.1 Category metadata & WinCo ordering

`CAT_META` maps each ingredient `cat` to `{ aisle, staple, coverage? }`:
- `staple: false` → **perishable** (produce, herb, meat, dairy, bakery). Always
  re-listed every week; never tracked long-term.
- `staple: true` → tracked across weeks with a `coverage` (weeks a typical
  purchase lasts): frozen 3, grain 6, canned 8, condiment 10, oil 8, spice 16,
  baking 12, nuts 8.

`AISLE_ORDER` is the WinCo top-to-bottom shopping order used to sort the grocery
list. Produce → Herbs → Meat → Dairy → Bakery → Grains → Canned → Condiments →
Oils → Spices → Baking → Nuts → Frozen.

### 5.2 Pantry "do we need it?" — `pantryStatus(key, cat)`

Returns `{ status: "have"|"buy", detail }`.
- Perishable (`!staple`) → always `"buy"`.
- Staple → look up `pantry[key]`. If present and
  `daysSince(stockedOn) <= coverageWeeks*7` → `"have"` (with "bought ~N wk ago");
  otherwise `"buy"` ("likely run out"). Missing entry → `"buy"`.

`markPurchased(key, name, cat)` records a staple into `pantry` with today's date
and the category's coverage. **Perishables are intentionally not recorded** (they
would just clutter the pantry view and are always re-listed). `markOutOfStock(key)`
deletes a pantry entry to force the item back onto the next list.

`normKey(name)` is the canonical pantry/grocery key: lowercase, strip
parenthetical text `(…)`, strip non-alphanumerics, trim. This is how ingredients
from different recipes are matched as "the same item" (e.g. "olive oil" used by
five recipes collapses to one key).

### 5.3 Weekly plan generation — `generatePlan()`

1. `eligibleDinners()`: filter `RECIPES` to `cuisine !== "Dessert"`,
   `prefs.likedCuisines.includes(cuisine)`, `time <= prefs.maxTime`, and **not**
   used in the last `prefs.avoidWeeks` history entries.
2. If that pool is smaller than `dinnersPerWeek`, **relax** the no-repeat filter
   (keep cuisine + time filters) so generation never starves.
3. Shuffle (Fisher–Yates). If `preferSpicy`, apply a soft sort nudging spicy
   recipes forward (randomized, not strict).
4. **Greedy distinct-cuisine pick**: take recipes whose cuisine hasn't been used
   yet until `dinnersPerWeek` is reached → maximizes variety. Then **backfill**
   remaining slots from the shuffled pool if distinct cuisines ran out.
5. Dessert: if `includeDessert`, pick a random dessert not used in the last
   `avoidWeeks` (falling back to any dessert).
6. Writes `state.plan` and `save()`s.

Related: `rerollSlot(index)` replaces one dinner with a random eligible recipe
not already in the plan; `rerollDessert()` swaps the dessert; `swapDinner(index,
newId)` sets a specific recipe chosen from the UI dropdown.

### 5.4 Grocery aggregation — `buildGrocery(includeDessert)`

1. Collect ingredient occurrences across `plan.dinnerIds` (+ dessert) into a
   `Map` keyed by `normKey`, each value `{ name, cat, parts: [{qty,unit,from}] }`.
2. For each item, `pantryStatus` decides `have` vs `buy`. `have` items go to a
   collapsed "already have" list; `buy` items are grouped by `CAT_META.aisle`.
3. `combineQty(parts)` merges quantities: sums numeric quantities **that share
   the same unit string**, and joins everything else with `" + "`. (Known
   limitation: `"cup"` and `"cups"` are different strings, so they don't merge —
   acceptable, still readable.)
4. Aisles are emitted in `AISLE_ORDER`; items sorted alphabetically.
5. Returns `{ aisles: [{aisle, items}], haveItems }`.

### 5.5 Document export

- `recipesMarkdown()` → "This Week's Dinners" doc (per-recipe: creator, cuisine,
  time/servings, link, ingredients, numbered steps).
- `groceryMarkdown()` → WinCo grocery list grouped by aisle, with an "already
  have (skipping)" section.
- `download(name, text)` builds a `Blob` and clicks a temp `<a download>`.
- `copyText(text)` uses `navigator.clipboard` with a `<textarea>+execCommand`
  fallback.
- The static `docs/*.md` files were generated by a one-off Node script using the
  **same** aggregation logic, so they match what the app produces.

---

## 6. UI architecture

- **No framework.** `js/app.js` renders by setting `innerHTML` on
  `<main id="app">`, then wiring event handlers with direct `onclick`/`onchange`.
- **Routing** is hash-based: `location.hash` ∈ `{plan, grocery, pantry, browse,
  history, settings}`. `render()` reads the hash and calls the matching
  `renderX()`. The bottom tab bar buttons set `location.hash`; a `hashchange`
  listener re-renders.
- Small helpers: `$`/`$$` (querySelector/All), `esc()` (HTML-escape — used on all
  interpolated user/data strings), `toast()` (transient message), `todayISO()`,
  `daysBetween()`, `shuffle()`, `recipeById()`.
- Views:
  - **plan** — generate/regenerate, per-meal reroll + swap dropdown, dessert,
    links to grocery, "We shopped — save this week" (`saveCurrentWeek()` pushes
    the plan onto `history`).
  - **grocery** — aisle blocks with checkboxes; "Mark checked items as bought"
    calls `markPurchased` for each checked item; copy/download buttons; "already
    have" `<details>` with per-item "need it anyway".
  - **pantry** — table of tracked staples with age + in-stock/low status and
    "ran out"; clear-all.
  - **browse** — all recipes with cuisine/spicy chip filters.
  - **history** — saved weeks (delete per week).
  - **settings** — edit prefs (cuisine chips, sliders, checkboxes); save; reset
    all data.

---

## 7. PWA & offline

- `manifest.webmanifest`: standalone display, theme `#b5341f`, icons (SVG
  maskable + PNG fallback), `start_url`/`scope` are relative (`./`) so it works
  under the `/Weekly-Dinner-App/` Pages subpath.
- `service-worker.js` (cache `weekly-dinner-v1`):
  - `install` pre-caches the core assets (`ASSETS` array) and `skipWaiting()`.
  - `activate` deletes old caches and `clients.claim()`.
  - `fetch`: **network-first** for navigations (fallback to cached
    `index.html`), **cache-first** for other GET assets (with background cache
    fill). Registered from `app.js` on `DOMContentLoaded`.
- **Bump the cache name** (`weekly-dinner-v1` → `-v2`) when changing cached
  assets, or clients may serve stale files.

---

## 8. Known constraints, quirks & caveats (read before "fixing" things)

- **Recipe-link verification.** Links were confirmed *live via web search* at
  build time, but pages were **not** machine-fetched: the build environment
  blocks outbound page fetches, and **Delish + The Pioneer Woman block this
  tool entirely** (both fetch and search), so they were intentionally omitted and
  similar creators substituted. **Half Baked Harvest ingredient amounts are
  faithful reconstructions** of those published recipes, not scraped — treat the
  linked page as authoritative for exact quantities.
- **Per-device state.** No sync/accounts. Two phones keep independent plans and
  pantries. Designate one "shared" device if a single source of truth is wanted.
- **Quantity math is string-unit based**, not a real unit system. `combineQty`
  won't reconcile `cup` vs `cups`, or `tbsp` vs `cup`. Good enough for a shopping
  list; do not rely on it for precise scaling.
- **Pantry coverage is a heuristic** (fixed weeks per category), not consumption
  tracking. It assumes "bought a package → have enough until coverage expires."
  Users correct it with "ran out."
- **No servings scaling.** Recipes are listed at their published servings (≈4),
  which yields leftovers for two; the grocery list does not scale to household
  size.
- **`structuredClone`** is used for defaults (fine in modern browsers/Node 17+).

---

## 9. How to extend (common tasks)

- **Add a recipe**: append an object to `RECIPES` in `js/recipes.js` with a
  unique `id`, a valid `cuisine` (or `"Dessert"`), `time`, `spicy`, a `note`, and
  `ingredients` using only valid `cat` codes (so they land in the right WinCo
  aisle and get correct pantry behavior). No other code changes needed.
- **Add an ingredient category / aisle**: add a key to `CAT_META` (with `aisle`,
  `staple`, and `coverage` if staple) **and** insert its aisle name into
  `AISLE_ORDER`. Then use the new `cat` on ingredients.
- **Change pantry longevity**: edit `coverage` values in `CAT_META`.
- **Change defaults** (cuisines, dinners/week, dessert, spicy bias, no-repeat
  window): edit `defaultState.prefs`. Existing users keep their saved prefs
  unless they reset.
- **Add a view/tab**: add a `<button data-tab="x">` in `index.html`'s `.tabbar`,
  a `renderX()` in `app.js`, and a branch in `render()`.
- After asset changes, **bump the service-worker cache name**.

---

## 10. One-paragraph mental model

It's a static, framework-free PWA. `recipes.js` is a hand-curated database of
constraint-satisfying recipes. `app.js` holds a single `localStorage` state blob
and a few pure-ish functions: a **generator** that filters recipes by
preference/time/recency and greedily maximizes cuisine variety; a **grocery
builder** that unions recipe ingredients by a normalized key, groups them into
WinCo aisles, and subtracts a **category-coverage pantry model** so staples
bought in prior weeks drop off the list until they'd plausibly run out; and a
`innerHTML`-based, hash-routed UI. Deployment is a trivial GitHub Actions job that
publishes the repo root to GitHub Pages.
