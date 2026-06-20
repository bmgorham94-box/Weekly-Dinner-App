# 🍽️ Weekly Dinner Planner

A mobile app for the two of you to plan **4 weeknight dinners a week**, build a
**WinCo-organized grocery list**, and **track pantry staples across weeks** so
your shopping lists get shorter over time. Built to your tastes:

- ⏱ **30–60 minutes** total (prep + cook)
- 🌶 **Spicy-friendly** and flavorful, but healthy-ish — no bland filler
- 🥘 Cuisines you like: **Mexican, Italian, Mediterranean, Indian, American Chinese, American**
- 🚫 Pre-filtered out: Thai, authentic Chinese, Japanese, Korean, anything fishy, rhubarb, super-fatty meats
- 🍨 A rotating **lighter / lower-fat dessert** each week
- 👩‍🍳 Recipes from creators in your style (Half Baked Harvest featured heavily, plus Damn Delicious, Budget Bytes, RecipeTin Eats, Once Upon a Chef, The Modern Proper, Cookie and Kate, Skinnytaste)

It's a **Progressive Web App (PWA)**: no app store needed. It installs to your
home screen, works offline, and stores everything privately on each phone.

---

## 📱 How to put it on your phones

The app is plain HTML/JS, so the easiest way to run it on both phones is to host
the folder for free with **GitHub Pages**:

1. Push this repo to GitHub (this branch).
2. In the repo, go to **Settings → Pages**.
3. Under "Build and deployment", set **Source: Deploy from a branch**, pick this
   branch and the **`/ (root)`** folder, then **Save**.
4. Wait ~1 minute. GitHub gives you a URL like
   `https://<your-username>.github.io/<repo-name>/`.
5. Open that URL on each phone:
   - **iPhone (Safari):** Share → **Add to Home Screen**.
   - **Android (Chrome):** ⋮ menu → **Install app / Add to Home Screen**.

Now it behaves like a normal app icon. Each phone keeps its own plan/pantry, so
pick one phone as the "shared" one if you want a single source of truth.

> You can also just open `index.html` in any browser to try it, but install +
> offline mode need it served over http(s) (GitHub Pages handles that).

---

## 🧭 How to use it

- **Plan** — Tap *Generate this week's plan*. You get 4 dinners (variety of
  cuisines, leaning spicy if you want) + a lighter dessert. Tap **↻** on any meal
  to swap it, or use the dropdown to pick a specific recipe. Every card links to
  the real recipe page.
- **Grocery** — A WinCo aisle-by-aisle list aggregated from your 4 dinners +
  dessert. Check items off as you shop, then tap **Mark checked items as bought**.
  Use **Copy** or **Download .md** to get the list as a document.
- **Pantry** — The clever part. When you mark staples (spices, oils, canned
  goods, rice/pasta) as bought, the app remembers and **won't add them again next
  week until they should be running low** (e.g. a spice jar lasts ~16 weeks, olive
  oil ~8, canned goods ~8). Tap **ran out** to force something back on the list.
  Perishables (produce, meat, dairy) are always re-listed.
- **Recipes** — Browse the full recipe library; filter by cuisine or 🌶 spicy.
- **History** — Saved weeks. The generator avoids repeating recent recipes (you
  set how many weeks in **Prefs**).
- **Prefs** — Tune cuisines, max cook time, dinners per week, dessert on/off,
  spicy bias, and the no-repeat window.

The ⬇ **Recipes** button in the top bar downloads *this week's recipes* as a
document (instructions + links).

---

## 📄 The two documents you asked for

Pre-generated for a sample first week, and regenerable any time from the app:

- [`docs/this-week-recipes.md`](docs/this-week-recipes.md) — recipes, full
  instructions, and verified links.
- [`docs/grocery-list.md`](docs/grocery-list.md) — the WinCo grocery list for
  that week, grouped by aisle, with pantry staples flagged.

---

## ⚠️ A note on link verification

You asked me to verify the links work. Important detail: the build environment
**blocks automated web-fetching** of recipe pages, and **Delish + The Pioneer
Woman block this tool entirely** (both fetching and search). So:

- **Half Baked Harvest, Damn Delicious, Budget Bytes, RecipeTin Eats, Once Upon a
  Chef, The Modern Proper, Cookie and Kate, Skinnytaste** — every URL was
  confirmed **live and current via web search**.
- Because pages couldn't be machine-read, **Half Baked Harvest ingredient amounts
  are faithful reconstructions** of those well-known recipes — tap the link to
  confirm exact quantities (they open fine in a normal phone browser).
- **Delish and Pioneer Woman** couldn't be verified from here, so I substituted
  similar approachable creators rather than ship links I couldn't check. Say the
  word and I can add specific Delish/Pioneer Woman recipes if you paste the links.

---

## 🗂️ Project structure

```
index.html              app shell + bottom tab bar
css/styles.css          mobile styling
js/recipes.js           recipe database (23 recipes: 17 dinners + 6 desserts)
js/app.js               plan generator, grocery aggregation, pantry tracking
manifest.webmanifest    PWA metadata (installable)
service-worker.js       offline caching
icons/                  app icon (SVG + PNG)
docs/                   the two generated documents
```

No dependencies, no build step. Everything runs in the browser.
