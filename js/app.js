/* =====================================================================
 * Weekly Dinner App — core logic
 * Vanilla JS, no build step, fully offline (localStorage). PWA installable.
 *
 * Feature sections (see commit history):
 *  1. Macro-aware dinner generation (per-serving macros, daily targets,
 *     fixed meals, training-day fat cap, macro scoring + UI).
 *  2. Recipe filters (protein / high-protein / low-fat / quick-win) +
 *     quick-win surfacing + cook-double leftovers.
 *  3. Backup / export + restore of all app state.
 *  4. Share-code sync between two phones (added in a later commit).
 *  5. Polish: auto-check staples, shared recipe notes, passive learning.
 * ===================================================================== */

(function () {
  "use strict";

  // ---- Ingredient category metadata: WinCo aisle + pantry behavior ----
  const CAT_META = {
    produce:   { aisle: "Produce",                 staple: false },
    herb:      { aisle: "Produce — Fresh Herbs",   staple: false },
    meat:      { aisle: "Meat",                    staple: false },
    dairy:     { aisle: "Dairy & Eggs",            staple: false },
    bakery:    { aisle: "Bakery & Bread",          staple: false },
    frozen:    { aisle: "Frozen",                  staple: true,  coverage: 3 },
    grain:     { aisle: "Pasta, Rice & Grains",    staple: true,  coverage: 6 },
    canned:    { aisle: "Canned & Jarred",         staple: true,  coverage: 8 },
    condiment: { aisle: "Condiments & Sauces",     staple: true,  coverage: 10 },
    oil:       { aisle: "Oils & Vinegars",         staple: true,  coverage: 8 },
    spice:     { aisle: "Spices & Seasonings",     staple: true,  coverage: 16 },
    baking:    { aisle: "Baking & Sweeteners",     staple: true,  coverage: 12 },
    nuts:      { aisle: "Nuts & Seeds",            staple: true,  coverage: 8 },
  };

  const AISLE_ORDER = [
    "Produce", "Produce — Fresh Herbs", "Meat", "Dairy & Eggs", "Bakery & Bread",
    "Pasta, Rice & Grains", "Canned & Jarred", "Condiments & Sauces", "Oils & Vinegars",
    "Spices & Seasonings", "Baking & Sweeteners", "Nuts & Seeds", "Frozen",
  ];

  // Staples we usually have on hand → auto-checked on the grocery list.
  const COMMON_STAPLE_CATS = ["spice", "oil", "baking"];

  // Thresholds for the high-protein / low-fat filters (per serving).
  const HIGH_PROTEIN_G = 35;
  const LOW_FAT_G = 15;

  // Macro generator scoring weights (see README/summary for rationale).
  const W_MACRO = 1.0;   // protein-fit vs fat-budget — strong but not sole driver
  const W_SPICY = 0.15;  // gentle spicy lean
  const W_LEARN = 0.2;   // passive preference learning
  const TEMP = 0.55;     // softmax temperature — keeps variety, avoids tunneling

  const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  // -------------------------- State / storage --------------------------
  const STORAGE_KEY = "weeklyDinnerApp.v1"; // key kept stable for migration
  const SCHEMA_VERSION = 2;
  const defaultState = {
    schemaVersion: SCHEMA_VERSION,
    prefs: {
      likedCuisines: ["Mexican", "Italian", "Mediterranean", "Indian", "American Chinese", "American"],
      maxTime: 60,
      dinnersPerWeek: 4,
      includeDessert: true,
      preferSpicy: true,
      avoidWeeks: 2,
      autocheckStaples: true,
      macros: {
        enabled: true,
        // Daily targets (the day's totals across all meals).
        daily: { protein: 306, carbs: 218, fat: 62 },
        // Macros already covered by fixed breakfast/lunch/snacks/shakes.
        // (Editable placeholder — adjust to your meal-prep + shake numbers.)
        fixed: { protein: 220, carbs: 140, fat: 35 },
        trainingFatCap: 75,          // hard daily fat cap on training days
        trainingDays: [1, 3, 5],     // 0=Sun … 6=Sat (default Mon/Wed/Fri)
      },
    },
    plan: null,     // { dinnerIds:[], dessertId, createdAt, checked:{}, doubles:{} }
    pantry: {},     // key -> { name, cat, stockedOn(ISO), coverageWeeks }
    history: [],    // [{ id, date, dinnerIds, dessertId }]
    notes: {},      // recipeId -> string (shared household memory)
    learning: {},   // recipeId -> number (passive preference weight)
  };

  let state = load();

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      const parsed = raw ? JSON.parse(raw) : {};
      return normalizeState(parsed);
    } catch (e) {
      console.warn("Failed to load state, starting fresh", e);
      return structuredClone(defaultState);
    }
  }

  // Safe migration: deep-merge a (possibly older/partial) blob over defaults
  // WITHOUT dropping history/pantry. Tolerates v1 saves with no macros/plan.checked.
  function normalizeState(parsed) {
    const d = defaultState;
    const s = structuredClone(d);
    const p = parsed || {};
    s.prefs = Object.assign({}, d.prefs, p.prefs || {});
    const pm = (p.prefs && p.prefs.macros) || {};
    s.prefs.macros = Object.assign({}, d.prefs.macros, pm);
    s.prefs.macros.daily = Object.assign({}, d.prefs.macros.daily, pm.daily || {});
    s.prefs.macros.fixed = Object.assign({}, d.prefs.macros.fixed, pm.fixed || {});
    s.prefs.macros.trainingDays = Array.isArray(pm.trainingDays) ? pm.trainingDays.slice() : d.prefs.macros.trainingDays.slice();
    s.pantry = p.pantry && typeof p.pantry === "object" ? p.pantry : {};
    s.history = Array.isArray(p.history) ? p.history : [];
    s.notes = p.notes && typeof p.notes === "object" ? p.notes : {};
    s.learning = p.learning && typeof p.learning === "object" ? p.learning : {};
    s.plan = p.plan && typeof p.plan === "object" ? p.plan : null;
    if (s.plan) {
      s.plan.dinnerIds = Array.isArray(s.plan.dinnerIds) ? s.plan.dinnerIds : [];
      s.plan.checked = s.plan.checked && typeof s.plan.checked === "object" ? s.plan.checked : {};
      s.plan.doubles = s.plan.doubles && typeof s.plan.doubles === "object" ? s.plan.doubles : {};
    }
    s.schemaVersion = SCHEMA_VERSION;
    return s;
  }

  function save() { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }

  // ------------------------------ Utils --------------------------------
  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));
  const todayISO = () => new Date().toISOString().slice(0, 10);
  const recipeById = (id) => RECIPES.find((r) => r.id === id);
  const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
  const esc = (s) =>
    String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  // Inline SVG icon set (Lucide-style line icons) — replaces emojis for a
  // cohesive, modern look. currentColor stroke so they inherit text color.
  const ICONS = {
    sparkle: '<path d="M12 3l1.9 5.3L19 10l-5.1 1.7L12 17l-1.9-5.3L5 10l5.1-1.7z"/>',
    refresh: '<path d="M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-15 6.7L3 16"/><path d="M3 21v-5h5"/>',
    shuffle: '<path d="M16 3h5v5"/><path d="M4 20 21 3"/><path d="M21 16v5h-5"/><path d="m15 15 6 6"/><path d="m4 4 5 5"/>',
    cart: '<circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/>',
    share: '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.6 13.5 6.8 4M15.4 6.5 8.6 10.5"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    external: '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
    activity: '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>',
    copy: '<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M7 10l5 5 5-5"/><path d="M12 15V3"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M17 8l-5-5-5 5"/><path d="M12 3v12"/>',
    edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    layers: '<path d="M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.9a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z"/><path d="m6.08 9.5-3.48 1.58a1 1 0 0 0 0 1.83l8.58 3.9a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83L17.92 9.5"/>',
    flame: '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
    zap: '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>',
    alert: '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/>',
    box: '<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="M3.3 7 12 12l8.7-5"/><path d="M12 22V12"/>',
  };
  function ic(name, cls) {
    return `<svg class="ic ${cls || ""}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ""}</svg>`;
  }

  function normKey(name) {
    return String(name).toLowerCase().replace(/\(.*?\)/g, "").replace(/[^a-z0-9 ]/g, "").trim();
  }
  function daysBetween(aISO, bISO) { return Math.round((new Date(bISO) - new Date(aISO)) / 86400000); }
  function shuffle(arr) {
    const a = arr.slice();
    for (let k = a.length - 1; k > 0; k--) { const j = Math.floor(Math.random() * (k + 1)); [a[k], a[j]] = [a[j], a[k]]; }
    return a;
  }
  const macroOf = (r) => (r && r.macros) || { calories: 0, protein: 0, carbs: 0, fat: 0 };

  // --------------------- Macro targets / scoring -----------------------
  function macroTargets() {
    const M = state.prefs.macros;
    return {
      remProtein: Math.max(1, M.daily.protein - M.fixed.protein),
      remCarbs: Math.max(0, M.daily.carbs - M.fixed.carbs),
      restFat: Math.max(1, M.daily.fat - M.fixed.fat),
      trainFat: Math.max(1, M.trainingFatCap - M.fixed.fat),
    };
  }
  function isTrainingToday() { return state.prefs.macros.trainingDays.includes(new Date().getDay()); }

  // Macro fit: reward filling remaining protein, penalize exceeding the (rest-day)
  // fat budget. Returns roughly [-1, 1.1]; 0 when macro mode is off.
  function fitScore(r) {
    if (!state.prefs.macros.enabled) return 0;
    const t = macroTargets();
    const mac = macroOf(r);
    const proteinScore = Math.min(mac.protein / t.remProtein, 1.1);
    const fatPenalty = 0.8 * Math.max(0, (mac.fat - t.restFat) / t.restFat);
    return proteinScore - fatPenalty;
  }
  function weightOf(r) {
    const fit = fitScore(r);
    const spicy = state.prefs.preferSpicy && r.spicy ? 1 : 0;
    const learn = clamp((state.learning[r.id] || 0) / 3, -1, 1);
    return Math.exp((W_MACRO * fit + W_SPICY * spicy + W_LEARN * learn) / TEMP);
  }
  function pickWeighted(list) {
    if (!list.length) return null;
    const ws = list.map(weightOf);
    const sum = ws.reduce((a, b) => a + b, 0);
    let x = Math.random() * sum;
    for (let i = 0; i < list.length; i++) { x -= ws[i]; if (x <= 0) return list[i]; }
    return list[list.length - 1];
  }
  // Soft protein-variety nudge: lightly down-weight a candidate if the same
  // primaryProtein already appears 2+ times in the week being built. A
  // tie-breaker only — subordinate to the macro-fit weight, and never applied
  // to vegetarian/none so meatless nights aren't penalized.
  function proteinDiversityFactor(r, picked) {
    const p = r.primaryProtein;
    if (p === "none" || p === "vegetarian") return 1;
    const same = picked.filter((x) => x.primaryProtein === p).length;
    if (same >= 2) return 0.45;
    if (same === 1) return 0.8;
    return 1;
  }
  function pickWeightedDiverse(list, picked) {
    if (!list.length) return null;
    const ws = list.map((r) => weightOf(r) * proteinDiversityFactor(r, picked));
    const sum = ws.reduce((a, b) => a + b, 0);
    let x = Math.random() * sum;
    for (let i = 0; i < list.length; i++) { x -= ws[i]; if (x <= 0) return list[i]; }
    return list[list.length - 1];
  }

  // --------------------- Pantry "do we need it?" -----------------------
  function pantryStatus(key, cat) {
    const meta = CAT_META[cat] || {};
    if (!meta.staple) return { status: "buy", detail: "" };
    const p = state.pantry[key];
    if (!p) return { status: "buy", detail: "" };
    const ageDays = daysBetween(p.stockedOn, todayISO());
    const lifeDays = (p.coverageWeeks || meta.coverage || 8) * 7;
    if (ageDays <= lifeDays) {
      const wk = Math.max(0, Math.round(ageDays / 7));
      return { status: "have", detail: wk === 0 ? "bought this week" : `bought ~${wk} wk ago` };
    }
    return { status: "buy", detail: "likely run out" };
  }
  function markPurchased(key, name, cat) {
    const meta = CAT_META[cat] || {};
    if (!meta.staple) return;
    state.pantry[key] = { name, cat, stockedOn: todayISO(), coverageWeeks: meta.coverage };
  }
  function markOutOfStock(key) { delete state.pantry[key]; }

  // ------------------------- Meal plan engine --------------------------
  function eligibleDinners() {
    const prefs = state.prefs;
    const recentIds = new Set();
    state.history.slice(0, prefs.avoidWeeks).forEach((w) => (w.dinnerIds || []).forEach((id) => recentIds.add(id)));
    return RECIPES.filter(
      (r) => r.cuisine !== "Dessert" && prefs.likedCuisines.includes(r.cuisine) && r.time <= prefs.maxTime && !recentIds.has(r.id)
    );
  }
  function relaxedDinners() {
    const prefs = state.prefs;
    return RECIPES.filter((r) => r.cuisine !== "Dessert" && prefs.likedCuisines.includes(r.cuisine) && r.time <= prefs.maxTime);
  }

  function generatePlan() {
    const prefs = state.prefs;
    let pool = eligibleDinners();
    if (pool.length < prefs.dinnersPerWeek) pool = relaxedDinners();

    // Distinct-cuisine variety as a constraint; macro/spicy/learn weighting +
    // softmax randomness inside it so it never tunnels onto the same meals.
    let remaining = pool.slice();
    const picked = [];
    const used = new Set();
    while (picked.length < prefs.dinnersPerWeek) {
      const cands = remaining.filter((r) => !used.has(r.cuisine));
      if (!cands.length) break;
      const ch = pickWeightedDiverse(cands, picked);
      picked.push(ch); used.add(ch.cuisine);
      remaining = remaining.filter((r) => r !== ch);
    }
    while (picked.length < prefs.dinnersPerWeek && remaining.length) {
      const ch = pickWeightedDiverse(remaining, picked);
      picked.push(ch);
      remaining = remaining.filter((r) => r !== ch);
    }

    const plan = { dinnerIds: picked.map((r) => r.id), dessertId: null, createdAt: todayISO(), checked: {}, doubles: {} };
    if (prefs.includeDessert) {
      const desserts = RECIPES.filter((r) => r.cuisine === "Dessert");
      const recentDesserts = new Set(state.history.slice(0, prefs.avoidWeeks).map((w) => w.dessertId));
      const dpool = desserts.filter((d) => !recentDesserts.has(d.id));
      const chosen = shuffle(dpool.length ? dpool : desserts)[0];
      plan.dessertId = chosen ? chosen.id : null;
    }
    state.plan = plan;
    save();
  }

  function rerollSlot(index) {
    if (!state.plan) return;
    const current = new Set(state.plan.dinnerIds);
    const oldId = state.plan.dinnerIds[index];
    let pool = eligibleDinners().filter((r) => !current.has(r.id));
    if (!pool.length) pool = relaxedDinners().filter((r) => !current.has(r.id));
    if (!pool.length) return;
    const others = state.plan.dinnerIds.filter((_, i) => i !== index).map(recipeById).filter(Boolean);
    const replacement = pickWeightedDiverse(pool, others);
    state.plan.dinnerIds[index] = replacement.id;
    if (state.plan.doubles) delete state.plan.doubles[oldId];
    learnSwapAway(oldId); // passive learning: down-weight what gets swapped out
    save();
  }
  function rerollDessert() {
    if (!state.plan) return;
    const desserts = RECIPES.filter((r) => r.cuisine === "Dessert" && r.id !== state.plan.dessertId);
    const chosen = shuffle(desserts)[0];
    if (chosen) { state.plan.dessertId = chosen.id; save(); }
  }
  function swapDinner(index, newId) {
    if (!state.plan || !newId) return;
    const oldId = state.plan.dinnerIds[index];
    state.plan.dinnerIds[index] = newId;
    if (state.plan.doubles) delete state.plan.doubles[oldId];
    learnSwapAway(oldId);
    save();
  }
  function toggleDouble(id) {
    if (!state.plan) return;
    state.plan.doubles = state.plan.doubles || {};
    if (state.plan.doubles[id]) delete state.plan.doubles[id]; else state.plan.doubles[id] = true;
    save();
  }

  // ----------------------- Passive preference learning -----------------
  function learnSwapAway(id) {
    if (!id) return;
    state.learning[id] = clamp((state.learning[id] || 0) - 1, -5, 5);
  }
  function learnCooked(ids) {
    ids.forEach((id) => { if (id) state.learning[id] = clamp((state.learning[id] || 0) + 1, -5, 5); });
  }

  // ----------------------- Grocery aggregation -------------------------
  function buildGrocery(includeDessert) {
    if (!state.plan) return { aisles: [], haveItems: [] };
    const ids = state.plan.dinnerIds.slice();
    if (includeDessert && state.plan.dessertId) ids.push(state.plan.dessertId);
    const doubles = state.plan.doubles || {};

    const map = new Map();
    ids.forEach((id) => {
      const r = recipeById(id);
      if (!r) return;
      const scale = doubles[id] ? 2 : 1;
      r.ingredients.forEach((ing) => {
        const key = normKey(ing.name);
        if (!map.has(key)) map.set(key, { key, name: ing.name, cat: ing.cat, parts: [] });
        map.get(key).parts.push({ qty: ing.qty, unit: ing.unit, from: r.title, scale });
      });
    });

    const buy = {};
    const haveItems = [];
    for (const item of map.values()) {
      const ps = pantryStatus(item.key, item.cat);
      const aisle = (CAT_META[item.cat] || {}).aisle || "Other";
      const entry = {
        key: item.key, name: item.name, cat: item.cat, aisle,
        qty: combineQty(item.parts),
        usedIn: [...new Set(item.parts.map((p) => p.from + (p.scale > 1 ? " (×2)" : "")))],
        detail: ps.detail,
      };
      if (ps.status === "have") haveItems.push(entry);
      else (buy[aisle] = buy[aisle] || []).push(entry);
    }
    const aisles = AISLE_ORDER.filter((a) => buy[a]).map((a) => ({
      aisle: a, items: buy[a].sort((x, y) => x.name.localeCompare(y.name)),
    }));
    haveItems.sort((a, b) => a.name.localeCompare(b.name));
    return { aisles, haveItems };
  }

  // Normalize unit strings so "cup"/"cups", "tbsp"/"tablespoon", etc. merge
  // instead of splitting an ingredient into two lines (which double-counts).
  const UNIT_ALIASES = {
    cup: "cup", cups: "cup",
    tbsp: "tbsp", tbs: "tbsp", tbl: "tbsp", tablespoon: "tbsp", tablespoons: "tbsp",
    tsp: "tsp", teaspoon: "tsp", teaspoons: "tsp",
    clove: "clove", cloves: "clove",
    lb: "lb", lbs: "lb", pound: "lb", pounds: "lb",
    oz: "oz", ounce: "oz", ounces: "oz",
    can: "can", cans: "can", jar: "jar", jars: "jar",
    head: "head", heads: "head", slice: "slice", slices: "slice",
    pinch: "pinch", pinches: "pinch", sprig: "sprig", sprigs: "sprig", stalk: "stalk", stalks: "stalk",
  };
  function normUnit(u) {
    if (u == null) return "";
    const k = String(u).trim().toLowerCase();
    return UNIT_ALIASES[k] !== undefined ? UNIT_ALIASES[k] : k; // compound units (e.g. "15 oz can") pass through unchanged
  }

  function combineQty(parts) {
    const byUnit = {};
    const text = [];
    parts.forEach((p) => {
      const scale = p.scale || 1;
      if (typeof p.qty === "number" && p.unit !== undefined) {
        const u = normUnit(p.unit);
        byUnit[u] = (byUnit[u] || 0) + p.qty * scale;
      } else {
        text.push([p.qty, p.unit].filter(Boolean).join(" ") + (scale > 1 ? " (×2)" : ""));
      }
    });
    const pieces = Object.entries(byUnit).map(([unit, qty]) => {
      const q = Math.round(qty * 100) / 100;
      return [q, unit].filter((x) => x !== "" && x !== undefined).join(" ");
    });
    return pieces.concat(text).join(" + ") || "as needed";
  }

  // grocery line default-checked? explicit value wins, else auto-check staples
  function lineChecked(key, cat) {
    const c = state.plan && state.plan.checked;
    if (c && Object.prototype.hasOwnProperty.call(c, key)) return !!c[key];
    return state.prefs.autocheckStaples && COMMON_STAPLE_CATS.includes(cat);
  }

  // --------------------------- Rendering -------------------------------
  const app = $("#app");

  function render() {
    const tab = location.hash.replace("#", "") || "plan";
    $$(".tabbar button").forEach((b) => b.classList.toggle("active", b.dataset.tab === tab));
    if (tab === "grocery") renderGrocery();
    else if (tab === "pantry") renderPantry();
    else if (tab === "browse") renderBrowse();
    else if (tab === "history") renderHistory();
    else if (tab === "settings") renderSettings();
    else renderPlan();
  }

  function cuisineBadge(c) { return `<span class="badge cuisine">${esc(c)}</span>`; }

  function quickBadge(r) {
    return r.quickWin
      ? `<span class="badge" style="background:color-mix(in srgb,var(--ochre) 16%,var(--surface));color:color-mix(in srgb,var(--ochre) 55%,var(--ink))">${ic("zap", "ic-sm")} quick</span>`
      : "";
  }
  function macroBadge(r) {
    if (!state.prefs.macros.enabled) return "";
    const m = macroOf(r);
    return `<span class="badge macro" title="Per serving">${m.protein}P · ${m.carbs}C · ${m.fat}F · ${m.calories}kcal</span>` +
      (r.estimated ? `<span class="badge est" title="Estimated — not verified from a source">~est</span>` : "");
  }
  function fatWarnBadge(r) {
    if (!state.prefs.macros.enabled) return "";
    const t = macroTargets();
    const fat = macroOf(r).fat;
    if (fat > t.trainFat) return `<span class="badge" style="background:color-mix(in srgb,var(--brand) 16%,var(--surface));color:var(--brand)">${ic("alert", "ic-sm")} over fat cap</span>`;
    if (fat > t.restFat) return `<span class="badge" style="background:color-mix(in srgb,var(--brand-2) 18%,var(--surface));color:color-mix(in srgb,var(--brand-2) 45%,var(--ink))">fat high</span>`;
    return "";
  }
  // A single dinner serving can't supply a whole day's remaining protein, so the
  // "good protein" bar is the smaller of (remaining gap) or a genuinely high-
  // protein dinner (HIGH_PROTEIN_G) — i.e. an achievable, meaningful threshold.
  function proteinBar() { return Math.min(macroTargets().remProtein, HIGH_PROTEIN_G); }
  function proteinFillBadge(r) {
    if (!state.prefs.macros.enabled) return "";
    if (macroOf(r).protein >= proteinBar())
      return `<span class="badge" style="background:color-mix(in srgb,var(--success) 16%,var(--surface));color:var(--success)">${ic("check", "ic-sm")} high protein</span>`;
    return "";
  }
  function metaLine(r, withMacros) {
    return `${cuisineBadge(r.cuisine)}${r.spicy ? `<span class="badge spicy">${ic("flame", "ic-sm")} spicy</span>` : ""}` +
      `<span class="badge time">${r.time} min</span>${quickBadge(r)}` +
      `${withMacros ? macroBadge(r) + fatWarnBadge(r) + proteinFillBadge(r) : ""}` +
      `<span class="badge">${esc(r.creator)}</span>`;
  }

  // Plan-top macro summary card
  function macroSummaryHTML(dinners) {
    if (!state.prefs.macros.enabled || !dinners.length) return "";
    const t = macroTargets();
    const n = dinners.length;
    const sum = dinners.reduce((a, r) => { const m = macroOf(r); a.p += m.protein; a.c += m.carbs; a.f += m.fat; a.k += m.calories; return a; }, { p: 0, c: 0, f: 0, k: 0 });
    const avg = { p: Math.round(sum.p / n), c: Math.round(sum.c / n), f: Math.round(sum.f / n), k: Math.round(sum.k / n) };
    const meetsProtein = dinners.filter((r) => macroOf(r).protein >= proteinBar()).length;
    const overCap = dinners.filter((r) => macroOf(r).fat > t.trainFat).length;
    const train = isTrainingToday();
    return `
      <article class="card" style="background:var(--surface-sunken)">
        <div class="card-head"><h3>${ic("activity")} Dinner macro targets</h3><span class="badge">${train ? "training day" : "rest day"}</span></div>
        <p class="note" style="margin-top:6px">Each dinner should add about <strong>${t.remProtein}g protein</strong> (daily ${state.prefs.macros.daily.protein} − fixed ${state.prefs.macros.fixed.protein}) and stay under
        <strong>${t.restFat}g fat</strong> on rest days / <strong>${t.trainFat}g</strong> on training days. Carbs remaining ≈ ${t.remCarbs}g.</p>
        <div class="badges">
          <span class="badge macro">avg dinner: ${avg.p}P · ${avg.c}C · ${avg.f}F · ${avg.k}kcal</span>
          <span class="badge" style="background:color-mix(in srgb,var(--success) 16%,var(--surface));color:var(--success)">${meetsProtein}/${n} hit protein</span>
          ${overCap ? `<span class="badge" style="background:color-mix(in srgb,var(--brand) 16%,var(--surface));color:var(--brand)">${overCap} over fat cap</span>` : ""}
        </div>
        <p class="note small" style="margin-top:8px">* macro values are estimates — verify against the linked recipe before competition prep.</p>
      </article>`;
  }

  function renderPlan() {
    if (!state.plan) {
      app.innerHTML = `
        <section class="hero">
          <h2>This week's dinners</h2>
          <p class="muted">No plan yet. Generate dinners that match your tastes and macros — high-protein, spicy-friendly, 30–60 min.</p>
          <button class="primary big" id="genBtn">${ic("sparkle")} Generate this week's plan</button>
        </section>`;
      $("#genBtn").onclick = () => { generatePlan(); render(); };
      return;
    }
    const dinners = state.plan.dinnerIds.map(recipeById).filter(Boolean);
    const dessert = state.plan.dessertId ? recipeById(state.plan.dessertId) : null;

    app.innerHTML = `
      <section>
        <div class="row-between">
          <h2>This week's dinners</h2>
          <button class="ghost small" id="regen">${ic("refresh")} New week</button>
        </div>
        <p class="muted">Saved ${esc(state.plan.createdAt)} — stays here until you change it. Tap <strong>Swap this meal</strong> on any card to replace just that one.</p>
        ${macroSummaryHTML(dinners)}
        <div class="cards">${dinners.map((r, idx) => recipeCard(r, idx)).join("")}</div>
        ${dessert ? `<h3 class="section-title">Lighter dessert</h3><div class="cards">${recipeCard(dessert, -1, true)}</div>` : ""}
        <div class="actions">
          <a class="primary" href="#grocery">${ic("cart")} Grocery list</a>
          <button class="ghost" id="shareWeek">${ic("share")} Share</button>
          <button class="ghost" id="saveWeek">${ic("check")} Save week</button>
        </div>
      </section>`;

    $("#regen").onclick = () => { generatePlan(); render(); };
    $$("[data-reroll]").forEach((b) => (b.onclick = () => { rerollSlot(+b.dataset.reroll); render(); }));
    const rd = $("[data-reroll-dessert]"); if (rd) rd.onclick = () => { rerollDessert(); render(); };
    $$("[data-swap]").forEach((sel) => (sel.onchange = () => { swapDinner(+sel.dataset.swap, sel.value); render(); }));
    $$("[data-double]").forEach((b) => (b.onclick = () => { toggleDouble(b.dataset.double); render(); }));
    wireNoteEditors();
    $("#saveWeek").onclick = saveCurrentWeek;
    const sw = $("#shareWeek"); if (sw) sw.onclick = openShareDialog; // defined in sync section
  }

  function recipeCard(r, idx, isDessert) {
    const doubled = !isDessert && state.plan && state.plan.doubles && state.plan.doubles[r.id];
    const doubleBadge = doubled ? ` <span class="badge" style="background:var(--brand);color:var(--on-brand)">${ic("layers", "ic-sm")} 2×</span>` : "";
    const controls = isDessert
      ? `<button class="ghost small" data-reroll-dessert>${ic("shuffle")} Swap</button>`
      : `<button class="ghost small" data-reroll="${idx}">${ic("shuffle")} Swap this meal</button>
         <button class="ghost small" data-double="${r.id}" title="Cook double for leftovers"${doubled ? ' style="background:var(--brand);color:var(--on-brand)"' : ""}>${ic("layers")} ${doubled ? "Doubling" : "Double"}</button>`;
    const swapSelect = isDessert ? "" :
      `<select class="swap" data-swap="${idx}" title="Or pick a specific meal" style="width:100%;margin-top:var(--s2)">
         <option value="">Or pick a specific meal…</option>
         ${RECIPES.filter((x) => x.cuisine !== "Dessert").map((x) => `<option value="${x.id}">${esc(x.title)} (${esc(x.cuisine)})</option>`).join("")}
       </select>`;
    return `
      <article class="card">
        <div class="card-head"><h3>${esc(r.title)}${doubleBadge}</h3></div>
        <div class="badges">${metaLine(r, true)}</div>
        <p class="note">${esc(r.note || "")}</p>
        ${noteEditorHTML(r.id)}
        <div class="card-actions">
          <a href="${esc(r.url)}" target="_blank" rel="noopener">${ic("external")} Recipe</a>
          ${controls}
        </div>
        ${swapSelect}
      </article>`;
  }

  // Shared per-recipe notes ("we doubled the chili last time")
  function noteEditorHTML(id) {
    const val = state.notes[id] || "";
    return `
      <details class="card-note" ${val ? "open" : ""} style="margin:4px 0 2px">
        <summary class="muted small" style="cursor:pointer;display:flex;align-items:center;gap:6px">${ic("edit", "ic-sm")} Notes${val ? "" : " (add)"}</summary>
        <textarea data-noteid="${esc(id)}" rows="2" placeholder="Shared notes for both of you…"
          style="width:100%;margin-top:6px;padding:8px;border:1px solid var(--line);border-radius:var(--r-sm);background:var(--surface);color:var(--ink);font:inherit;font-size:13px">${esc(val)}</textarea>
      </details>`;
  }
  function wireNoteEditors() {
    $$("[data-noteid]").forEach((ta) => {
      ta.oninput = () => {
        const id = ta.dataset.noteid;
        const v = ta.value.trim();
        if (v) state.notes[id] = ta.value; else delete state.notes[id];
        save();
      };
    });
  }

  function renderGrocery() {
    if (!state.plan) {
      app.innerHTML = `<section><h2>Grocery list</h2><p class="muted">Generate a plan first.</p><a class="primary" href="#plan">Go to plan</a></section>`;
      return;
    }
    const includeDessert = state.prefs.includeDessert && state.plan.dessertId;
    const { aisles, haveItems } = buildGrocery(includeDessert);
    const totalBuy = aisles.reduce((n, a) => n + a.items.length, 0);

    app.innerHTML = `
      <section>
        <div class="row-between"><h2>Grocery list — WinCo</h2><span class="muted">${totalBuy} to buy</span></div>
        <p class="muted">By WinCo aisle. Staples you usually keep are auto-checked${state.prefs.autocheckStaples ? "" : " (off)"} so you review only real shopping. Checks sync when you Share the week.</p>
        ${aisles.map(aisleBlock).join("") || '<p class="muted">Nothing to buy — you have it all!</p>'}
        ${haveItems.length ? `
          <details class="have">
            <summary style="display:flex;align-items:center;gap:8px">${ic("box")} Skipping ${haveItems.length} item(s) you likely already have</summary>
            <ul class="have-list">
              ${haveItems.map((it) => `<li>${esc(it.name)} <span class="muted">— ${esc(it.detail)}</span> <button class="link" data-need="${esc(it.key)}">need it anyway</button></li>`).join("")}
            </ul>
          </details>` : ""}
        <div class="actions">
          <button class="ghost" id="copyGrocery">${ic("copy")} Copy</button>
          <button class="ghost" id="dlGrocery">${ic("download")} Download</button>
          <button class="primary" id="boughtAll">${ic("check")} Mark as bought</button>
        </div>
      </section>`;

    $$('[data-need]').forEach((b) => (b.onclick = () => { markOutOfStock(b.dataset.need); save(); render(); }));
    // persist each checkbox toggle (powers sync + survives navigation)
    $$('input[data-buykey]').forEach((cb) => (cb.onchange = () => {
      state.plan.checked = state.plan.checked || {};
      state.plan.checked[cb.dataset.buykey] = cb.checked;
      save();
    }));
    $("#copyGrocery").onclick = () => copyText(groceryMarkdown());
    $("#dlGrocery").onclick = () => download("grocery-list.md", groceryMarkdown());
    $("#boughtAll").onclick = () => {
      $$('input[data-buykey]:checked').forEach((cb) => markPurchased(cb.dataset.buykey, cb.dataset.buyname, cb.dataset.buycat));
      save();
      toast("Saved to pantry — we'll skip these next week while they last.");
      render();
    };
  }

  function aisleBlock(a) {
    return `
      <div class="aisle">
        <h3 class="aisle-title">${esc(a.aisle)}</h3>
        <ul class="grocery-list">
          ${a.items.map((it) => `
            <li>
              <label>
                <input type="checkbox" ${lineChecked(it.key, it.cat) ? "checked" : ""} data-buykey="${esc(it.key)}" data-buyname="${esc(it.name)}" data-buycat="${esc(it.cat)}">
                <span class="g-name">${esc(it.name)}</span>
                <span class="g-qty">${esc(it.qty)}</span>
              </label>
              <div class="g-used muted">for ${esc(it.usedIn.join(", "))}</div>
            </li>`).join("")}
        </ul>
      </div>`;
  }

  function renderPantry() {
    const rows = Object.keys(state.pantry)
      .map((k) => ({ key: k, ...state.pantry[k] }))
      .sort((a, b) => (a.cat || "").localeCompare(b.cat || "") || a.name.localeCompare(b.name));
    app.innerHTML = `
      <section>
        <h2>Pantry tracker</h2>
        <p class="muted">Staples you've bought. We assume a typical package lasts a while and won't re-add it until it should be running low. Tap "ran out" to force it back.</p>
        ${rows.length ? `
        <table class="pantry">
          <thead><tr><th>Item</th><th>Bought</th><th>Status</th><th></th></tr></thead>
          <tbody>
          ${rows.map((r) => {
            const ps = pantryStatus(r.key, r.cat);
            const wk = Math.round(daysBetween(r.stockedOn, todayISO()) / 7);
            return `<tr>
              <td>${esc(r.name)}</td>
              <td class="muted">${wk === 0 ? "this week" : wk + " wk ago"}</td>
              <td>${ps.status === "have" ? '<span class="ok">in stock</span>' : '<span class="warn">low/empty</span>'}</td>
              <td><button class="link" data-out="${esc(r.key)}">ran out</button></td>
            </tr>`;
          }).join("")}
          </tbody>
        </table>` : '<p class="muted">Nothing tracked yet. Check off staples on your grocery list and tap "Mark checked as bought".</p>'}
        ${rows.length ? '<button class="ghost" id="clearPantry">Clear pantry</button>' : ""}
      </section>`;
    $$('[data-out]').forEach((b) => (b.onclick = () => { markOutOfStock(b.dataset.out); save(); render(); }));
    const cp = $("#clearPantry");
    if (cp) cp.onclick = () => { if (confirm("Clear all tracked pantry items?")) { state.pantry = {}; save(); render(); } };
  }

  // ------------------------------ Browse + filters ---------------------
  const browseFilters = { group: "all", protein: "all", highProtein: false, lowFat: false, quick: false };

  function browseMatch(r) {
    const f = browseFilters;
    if (f.group === "Dessert") { if (r.cuisine !== "Dessert") return false; }
    else if (f.group === "spicy") { if (!r.spicy) return false; }
    else if (f.group !== "all") { if (r.cuisine !== f.group) return false; }
    if (f.protein !== "all" && r.primaryProtein !== f.protein) return false;
    if (f.highProtein && macroOf(r).protein < HIGH_PROTEIN_G) return false;
    if (f.lowFat && macroOf(r).fat > LOW_FAT_G) return false;
    if (f.quick && !r.quickWin) return false;
    return true;
  }

  function renderBrowse() {
    const proteins = [...new Set(RECIPES.filter((r) => r.cuisine !== "Dessert").map((r) => r.primaryProtein))];
    const chip = (active, attr, val, label) => `<button class="chip ${active ? "active" : ""}" data-${attr}="${esc(val)}">${esc(label)}</button>`;
    app.innerHTML = `
      <section>
        <h2>All recipes</h2>
        <p class="muted">${RECIPES.filter((r) => r.cuisine !== "Dessert").length} dinners + ${RECIPES.filter((r) => r.cuisine === "Dessert").length} lighter desserts. Every link confirmed live.</p>
        <div class="filterbar" id="fGroup">
          ${chip(browseFilters.group === "all", "g", "all", "All")}
          ${CUISINES.map((c) => chip(browseFilters.group === c, "g", c, c)).join("")}
          ${chip(browseFilters.group === "Dessert", "g", "Dessert", "Dessert")}
          ${chip(browseFilters.group === "spicy", "g", "spicy", "Spicy")}
        </div>
        <div class="filterbar" id="fProtein">
          ${chip(browseFilters.protein === "all", "p", "all", "Any protein")}
          ${proteins.map((p) => chip(browseFilters.protein === p, "p", p, p[0].toUpperCase() + p.slice(1))).join("")}
        </div>
        <div class="filterbar" id="fToggles">
          ${chip(browseFilters.highProtein, "t", "highProtein", "High protein")}
          ${chip(browseFilters.lowFat, "t", "lowFat", "Low fat")}
          ${chip(browseFilters.quick, "t", "quick", "Quick win")}
        </div>
        <div class="cards" id="browseCards"></div>
      </section>`;
    const repaint = () => { $("#browseCards").innerHTML = RECIPES.filter(browseMatch).map(browseCard).join("") || '<p class="muted">No recipes match those filters.</p>'; wireNoteEditors(); };
    $$("#fGroup .chip").forEach((b) => (b.onclick = () => { browseFilters.group = b.dataset.g; renderBrowse(); }));
    $$("#fProtein .chip").forEach((b) => (b.onclick = () => { browseFilters.protein = b.dataset.p; renderBrowse(); }));
    $$("#fToggles .chip").forEach((b) => (b.onclick = () => { const k = b.dataset.t; browseFilters[k] = !browseFilters[k]; renderBrowse(); }));
    repaint();
  }
  function browseCard(r) {
    return `
      <article class="card">
        <h3>${esc(r.title)}</h3>
        <div class="badges">${metaLine(r, true)}</div>
        <p class="note">${esc(r.note || "")}</p>
        ${noteEditorHTML(r.id)}
        <div class="card-actions"><a href="${esc(r.url)}" target="_blank" rel="noopener">${ic("external")} Recipe</a></div>
      </article>`;
  }

  function renderHistory() {
    app.innerHTML = `
      <section>
        <h2>Past weeks</h2>
        <p class="muted">We avoid repeating these recipes for your next ${state.prefs.avoidWeeks} weeks, and use them to keep your pantry current.</p>
        ${state.history.length ? state.history.map((w, idx) => `
          <div class="aisle">
            <div class="row-between"><h3 class="aisle-title">Week of ${esc(w.date)}</h3><button class="link" data-delweek="${idx}">delete</button></div>
            <ul class="have-list">
              ${(w.dinnerIds || []).map((id) => { const r = recipeById(id); return r ? `<li>${esc(r.title)} <span class="muted">— ${esc(r.cuisine)}</span></li>` : ""; }).join("")}
              ${w.dessertId && recipeById(w.dessertId) ? `<li>${esc(recipeById(w.dessertId).title)} <span class="muted">— dessert</span></li>` : ""}
            </ul>
          </div>`).join("") : '<p class="muted">No saved weeks yet. On the Plan tab, tap "We shopped — save week".</p>'}
      </section>`;
    $$('[data-delweek]').forEach((b) => (b.onclick = () => { state.history.splice(+b.dataset.delweek, 1); save(); render(); }));
  }

  // ------------------------------ Settings -----------------------------
  function renderSettings() {
    const p = state.prefs;
    const M = p.macros;
    const t = macroTargets();
    app.innerHTML = `
      <section>
        <h2>Preferences</h2>

        <div class="field">
          <label>Cuisines in rotation</label>
          <div class="filterbar">${CUISINES.map((c) => `<button class="chip ${p.likedCuisines.includes(c) ? "active" : ""}" data-cuisine="${esc(c)}">${esc(c)}</button>`).join("")}</div>
        </div>
        <div class="field"><label>Max cook time: <strong id="mtVal">${p.maxTime}</strong> min</label><input type="range" id="maxTime" min="20" max="90" step="5" value="${p.maxTime}"></div>
        <div class="field"><label>Dinners per week: <strong id="dpwVal">${p.dinnersPerWeek}</strong></label><input type="range" id="dpw" min="2" max="7" step="1" value="${p.dinnersPerWeek}"></div>
        <div class="field check"><label><input type="checkbox" id="dessert" ${p.includeDessert ? "checked" : ""}> Include a lighter dessert each week</label></div>
        <div class="field check"><label><input type="checkbox" id="spicy" ${p.preferSpicy ? "checked" : ""}> Lean spicy when possible 🌶</label></div>
        <div class="field check"><label><input type="checkbox" id="autocheck" ${p.autocheckStaples ? "checked" : ""}> Auto-check pantry staples on the grocery list</label></div>
        <div class="field"><label>Don't repeat a recipe for <strong id="awVal">${p.avoidWeeks}</strong> week(s)</label><input type="range" id="aw" min="0" max="6" step="1" value="${p.avoidWeeks}"></div>

        <h2 style="margin-top:var(--s5)">Macro targets</h2>
        <div class="field check"><label><input type="checkbox" id="mEnabled" ${M.enabled ? "checked" : ""}> Macro-aware dinner generation</label></div>
        <p class="muted small">Dinner should fill the protein your fixed breakfast/lunch/shakes don't cover, while staying under the fat budget. Everything below is editable.</p>
        <div class="field"><label>Daily targets (g): protein / carbs / fat</label>
          <div class="filterbar">
            ${numInput("dProtein", M.daily.protein)} ${numInput("dCarbs", M.daily.carbs)} ${numInput("dFat", M.daily.fat)}
          </div>
        </div>
        <div class="field"><label>Fixed meals already cover (g): protein / carbs / fat</label>
          <div class="filterbar">
            ${numInput("fProtein", M.fixed.protein)} ${numInput("fCarbs", M.fixed.carbs)} ${numInput("fFat", M.fixed.fat)}
          </div>
        </div>
        <div class="field"><label>Training-day fat cap (g)</label><div class="filterbar">${numInput("fatCap", M.trainingFatCap)}</div></div>
        <div class="field"><label>Training days (higher carbs, fat up to the cap)</label>
          <div class="filterbar">${WEEKDAYS.map((d, i) => `<button class="chip ${M.trainingDays.includes(i) ? "active" : ""}" data-trainday="${i}">${d}</button>`).join("")}</div>
        </div>
        <p class="muted small">→ Right now dinner should add ≈ <strong>${t.remProtein}g protein</strong>, keep fat ≤ <strong>${t.restFat}g</strong> (rest) / <strong>${t.trainFat}g</strong> (training).</p>

        <div class="actions"><button class="primary" id="savePrefs">Save preferences</button></div>

        <h2 style="margin-top:var(--s5)">Backup &amp; restore</h2>
        <p class="muted small">Your data lives only on this device. Export a backup before clearing browser data, or to move to a new phone.</p>
        <div class="actions">
          <button class="ghost" id="exportData">${ic("download")} Export backup</button>
          <button class="ghost" id="importData">${ic("upload")} Restore</button>
        </div>
        <input type="file" id="importFile" accept="application/json,.json" style="display:none">

        <div class="actions" style="margin-top:var(--s5)"><button class="ghost" id="resetAll">Reset app data</button></div>
        <p class="muted small">Dislikes are pre-filtered from the recipe set: no Thai, authentic Chinese, Japanese, Korean, seafood/fish, rhubarb, or super-fatty meats.</p>
      </section>`;

    $$('[data-cuisine]').forEach((b) => (b.onclick = () => b.classList.toggle("active")));
    $$('[data-trainday]').forEach((b) => (b.onclick = () => b.classList.toggle("active")));
    $("#maxTime").oninput = (e) => ($("#mtVal").textContent = e.target.value);
    $("#dpw").oninput = (e) => ($("#dpwVal").textContent = e.target.value);
    $("#aw").oninput = (e) => ($("#awVal").textContent = e.target.value);

    $("#savePrefs").onclick = () => {
      state.prefs.likedCuisines = $$('[data-cuisine].active').map((b) => b.dataset.cuisine);
      if (!state.prefs.likedCuisines.length) state.prefs.likedCuisines = CUISINES.slice();
      state.prefs.maxTime = +$("#maxTime").value;
      state.prefs.dinnersPerWeek = +$("#dpw").value;
      state.prefs.includeDessert = $("#dessert").checked;
      state.prefs.preferSpicy = $("#spicy").checked;
      state.prefs.autocheckStaples = $("#autocheck").checked;
      state.prefs.avoidWeeks = +$("#aw").value;
      const M2 = state.prefs.macros;
      M2.enabled = $("#mEnabled").checked;
      M2.daily = { protein: numVal("dProtein"), carbs: numVal("dCarbs"), fat: numVal("dFat") };
      M2.fixed = { protein: numVal("fProtein"), carbs: numVal("fCarbs"), fat: numVal("fFat") };
      M2.trainingFatCap = numVal("fatCap");
      M2.trainingDays = $$('[data-trainday].active').map((b) => +b.dataset.trainday);
      save();
      toast("Preferences saved.");
      location.hash = "plan";
    };

    $("#exportData").onclick = exportBackup;
    $("#importData").onclick = () => $("#importFile").click();
    $("#importFile").onchange = (e) => { const f = e.target.files[0]; if (f) importBackupFile(f); };
    $("#resetAll").onclick = () => {
      if (confirm("Erase plan, pantry, history, notes and preferences on this device?")) {
        state = structuredClone(defaultState); save(); location.hash = "plan"; render();
      }
    };
  }
  function numInput(id, val) {
    return `<input type="number" id="${id}" value="${val}" inputmode="numeric"
      style="width:84px;padding:8px;border:1px solid var(--line);border-radius:var(--r-sm);background:var(--surface);color:var(--ink);font:inherit">`;
  }
  function numVal(id) { const v = parseInt($("#" + id).value, 10); return isNaN(v) ? 0 : Math.max(0, v); }

  // --------------------------- Save a week -----------------------------
  function saveCurrentWeek() {
    if (!state.plan) return;
    state.history.unshift({
      id: "w" + Date.now(), date: todayISO(),
      dinnerIds: state.plan.dinnerIds.slice(), dessertId: state.plan.dessertId,
    });
    state.history = state.history.slice(0, 20);
    learnCooked(state.plan.dinnerIds); // cooked it → surface more often
    save();
    toast("Week saved. Generate next week whenever you're ready!");
    location.hash = "history";
    render();
  }

  // ----------------------- Backup / export + restore -------------------
  function exportBackup() {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = `weekly-dinner-backup-${todayISO()}.json`; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    toast("Backup downloaded.");
  }
  function importBackupFile(file) {
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const obj = JSON.parse(reader.result);
        if (!obj || typeof obj !== "object" || (!obj.prefs && !obj.history && !obj.pantry)) {
          toast("That doesn't look like a valid backup."); return;
        }
        const counts = `${(obj.history || []).length} week(s), ${Object.keys(obj.pantry || {}).length} pantry item(s)`;
        if (!confirm(`Restore this backup? It replaces all data on THIS device with:\n${counts}.`)) return;
        state = normalizeState(obj);
        save(); toast("Backup restored."); location.hash = "plan"; render();
      } catch (e) { toast("Could not read that file."); }
    };
    reader.readAsText(file);
  }

  // --------------------------- Doc exports -----------------------------
  function groceryMarkdown() {
    const includeDessert = state.prefs.includeDessert && state.plan && state.plan.dessertId;
    const { aisles, haveItems } = buildGrocery(includeDessert);
    let md = `# Grocery List — WinCo Foods\n\n_Week of ${todayISO()}_\n\n`;
    aisles.forEach((a) => { md += `## ${a.aisle}\n`; a.items.forEach((it) => (md += `- [ ] ${it.name} — ${it.qty}\n`)); md += `\n`; });
    if (haveItems.length) { md += `## Already have (skipping)\n`; haveItems.forEach((it) => (md += `- ${it.name} (${it.detail})\n`)); }
    return md;
  }
  function recipesMarkdown() {
    if (!state.plan) return "# No plan generated yet\n";
    let md = `# This Week's Dinners\n\n_Week of ${todayISO()}_\n\n`;
    state.plan.dinnerIds.map(recipeById).filter(Boolean).forEach((r, i) => (md += recipeMd(r, i + 1)));
    if (state.plan.dessertId) { const d = recipeById(state.plan.dessertId); if (d) md += recipeMd(d, "🍨 Dessert"); }
    return md;
  }
  function recipeMd(r, n) {
    const m = macroOf(r);
    let md = `## ${n}. ${r.title}\n`;
    md += `- **Creator:** ${r.creator}\n- **Cuisine:** ${r.cuisine}${r.spicy ? " 🌶" : ""}\n- **Total time:** ${r.time} min · Serves ${r.servings}\n`;
    md += `- **Macros/serving (${r.estimated ? "estimated" : "verified"}):** ${m.protein}g P · ${m.carbs}g C · ${m.fat}g F · ${m.calories} kcal\n`;
    md += `- **Link:** ${r.url}\n\n**Ingredients**\n`;
    r.ingredients.forEach((ing) => (md += `- ${[ing.qty, ing.unit, ing.name].filter((x) => x !== "" && x != null).join(" ")}\n`));
    md += `\n**Instructions**\n`;
    r.steps.forEach((s, i) => (md += `${i + 1}. ${s}\n`));
    return md + `\n`;
  }

  // ------------------------------ Helpers UI ---------------------------
  function download(name, text) {
    const blob = new Blob([text], { type: "text/markdown" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = name; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function copyText(text) {
    if (navigator.clipboard) navigator.clipboard.writeText(text).then(() => toast("Copied to clipboard."), () => fallbackCopy(text));
    else fallbackCopy(text);
  }
  function fallbackCopy(text) {
    const ta = document.createElement("textarea");
    ta.value = text; document.body.appendChild(ta); ta.select();
    try { document.execCommand("copy"); toast("Copied."); } catch (e) {}
    document.body.removeChild(ta);
  }
  let toastTimer;
  function toast(msg) {
    let t = $("#toast");
    if (!t) { t = document.createElement("div"); t.id = "toast"; document.body.appendChild(t); }
    t.textContent = msg; t.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove("show"), 2600);
  }

  // -------------------- Sync (share-code between phones) ---------------
  // Backend-free: encode the current week's plan + grocery checks (+ notes for
  // those recipes) into a compact URL-safe code. One person generates it, the
  // other taps the link or pastes the code. Loading never touches History.
  function b64urlEncode(str) {
    return btoa(unescape(encodeURIComponent(str))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  function b64urlDecode(code) {
    const s = code.replace(/-/g, "+").replace(/_/g, "/");
    const pad = s.length % 4 ? "=".repeat(4 - (s.length % 4)) : "";
    return decodeURIComponent(escape(atob(s + pad)));
  }
  function encodeShare() {
    if (!state.plan) return null;
    const checkedTrue = Object.keys(state.plan.checked || {}).filter((k) => state.plan.checked[k]);
    const doubled = Object.keys(state.plan.doubles || {}).filter((k) => state.plan.doubles[k]);
    const ids = state.plan.dinnerIds.concat(state.plan.dessertId ? [state.plan.dessertId] : []);
    const planNotes = {};
    ids.forEach((id) => { if (state.notes[id]) planNotes[id] = state.notes[id]; });
    const payload = {
      v: 1,
      p: { d: state.plan.dinnerIds, x: state.plan.dessertId || null, c: state.plan.createdAt || todayISO(), db: doubled },
      ck: checkedTrue,
      n: planNotes,
    };
    return b64urlEncode(JSON.stringify(payload));
  }
  function decodeShare(code) {
    const o = JSON.parse(b64urlDecode(code));
    if (!o || o.v !== 1 || !o.p || !Array.isArray(o.p.d)) throw new Error("bad share payload");
    return o;
  }
  function shareURL(code) { return location.origin + location.pathname + "#share=" + code; }

  function applySharedWithConfirm(payload) {
    const pl = payload.p;
    const n = (pl.d || []).length;
    if (!confirm(`Load this shared week (${n} dinner${n === 1 ? "" : "s"})?\nThis replaces your current plan and grocery checks. Your saved History stays intact.`)) return false;
    state.plan = { dinnerIds: pl.d || [], dessertId: pl.x || null, createdAt: pl.c || todayISO(), doubles: {}, checked: {} };
    (pl.db || []).forEach((id) => { state.plan.doubles[id] = true; });
    (payload.ck || []).forEach((k) => { state.plan.checked[k] = true; });
    if (payload.n && typeof payload.n === "object") Object.assign(state.notes, payload.n); // merge shared notes
    save();
    toast("Shared week loaded.");
    location.hash = "plan";
    render();
    return true;
  }

  // Returns true if the current hash was a share code (and consumes it).
  function maybeHandleShareHash() {
    const m = (location.hash || "").match(/^#?share=(.+)$/);
    if (!m) return false;
    const code = m[1];
    // clear the hash without firing another route event, then process
    if (window.history && history.replaceState) history.replaceState(null, "", location.pathname + location.search + "#plan");
    else location.hash = "plan";
    try { applySharedWithConfirm(decodeShare(code)); }
    catch (e) { toast("That share code couldn't be read."); render(); }
    return true;
  }

  function openShareDialog() {
    if (!state.plan) { toast("Generate a plan first."); return; }
    const code = encodeShare();
    const url = shareURL(code);
    closeShareDialog();
    const ov = document.createElement("div");
    ov.id = "share-overlay";
    ov.setAttribute("style",
      "position:fixed;inset:0;z-index:70;display:flex;align-items:center;justify-content:center;padding:16px;" +
      "background:color-mix(in srgb,var(--ink) 45%,transparent);-webkit-backdrop-filter:blur(4px);backdrop-filter:blur(4px)");
    ov.innerHTML = `
      <div role="dialog" aria-label="Share this week" style="background:var(--surface);color:var(--ink);border:1px solid var(--line);border-radius:var(--r-lg);box-shadow:var(--shadow-md);max-width:480px;width:100%;max-height:86vh;overflow:auto;padding:18px">
        <div class="row-between"><h3 style="display:flex;align-items:center;gap:8px">${ic("share")} Share this week</h3><button class="icon" id="shareClose" title="Close">${ic("x")}</button></div>
        <p class="muted small">Send this to your partner — it carries the 4 dinners, any 2× doubles, your grocery check-offs, and recipe notes. Their History is untouched.</p>
        <div class="actions" style="margin-top:10px">
          ${navigator.share ? `<button class="primary" id="shareNative">${ic("share")} Share link…</button>` : ""}
          <button class="ghost" id="shareCopyLink">${ic("copy")} Copy link</button>
          <button class="ghost" id="shareCopyCode">Copy code</button>
        </div>
        <textarea readonly rows="3" id="shareLinkBox" style="width:100%;margin-top:10px;padding:8px;border:1px solid var(--line);border-radius:var(--r-sm);background:var(--surface-sunken);color:var(--ink);font:inherit;font-size:12px">${esc(url)}</textarea>
        <hr style="border:none;border-top:1px solid var(--line);margin:16px 0">
        <h3 style="font-size:16px">Load a shared week</h3>
        <p class="muted small">Paste a link or code your partner sent you.</p>
        <textarea rows="3" id="loadBox" placeholder="Paste #share=… link or code" style="width:100%;margin-top:8px;padding:8px;border:1px solid var(--line);border-radius:var(--r-sm);background:var(--surface);color:var(--ink);font:inherit;font-size:12px"></textarea>
        <div class="actions"><button class="primary" id="loadShared">Load shared week</button></div>
      </div>`;
    document.body.appendChild(ov);
    ov.addEventListener("click", (e) => { if (e.target === ov) closeShareDialog(); });
    $("#shareClose").onclick = closeShareDialog;
    const cl = $("#shareCopyLink"); if (cl) cl.onclick = () => copyText(url);
    const cc = $("#shareCopyCode"); if (cc) cc.onclick = () => copyText(code);
    const sn = $("#shareNative"); if (sn) sn.onclick = () => navigator.share({ title: "Our dinner plan", text: "This week's dinners + grocery list", url }).catch(() => {});
    $("#loadShared").onclick = () => {
      const raw = ($("#loadBox").value || "").trim();
      if (!raw) { toast("Paste a link or code first."); return; }
      const mm = raw.match(/share=([^\s&#]+)/);
      const code2 = mm ? mm[1] : raw;
      try { if (applySharedWithConfirm(decodeShare(code2))) closeShareDialog(); }
      catch (e) { toast("That code couldn't be read."); }
    };
  }
  function closeShareDialog() { const o = $("#share-overlay"); if (o) o.remove(); }

  function onRoute() { if (maybeHandleShareHash()) return; render(); }

  window.__exportRecipes = () => download("this-week-recipes.md", recipesMarkdown());

  // --------------------- Service worker + update flow ------------------
  function registerSW() {
    if (!("serviceWorker" in navigator)) return;
    navigator.serviceWorker.register("./service-worker.js").then((reg) => {
      if (reg.waiting && navigator.serviceWorker.controller) showUpdateBanner(reg);
      reg.addEventListener("updatefound", () => {
        const nw = reg.installing; if (!nw) return;
        nw.addEventListener("statechange", () => {
          if (nw.state === "installed" && navigator.serviceWorker.controller) showUpdateBanner(reg);
        });
      });
    }).catch(() => {});
    let refreshing = false;
    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (refreshing) return; refreshing = true; location.reload();
    });
  }
  function showUpdateBanner(reg) {
    if ($("#update-banner")) return;
    const bar = document.createElement("div");
    bar.id = "update-banner";
    bar.setAttribute("style",
      "position:fixed;left:50%;transform:translateX(-50%);bottom:calc(96px + env(safe-area-inset-bottom));" +
      "z-index:60;display:flex;gap:12px;align-items:center;background:var(--ink);color:var(--surface);" +
      "padding:10px 14px;border-radius:var(--r-md);box-shadow:var(--shadow-md);font-size:14px;max-width:92%");
    bar.innerHTML = `<span>New version available</span><button id="update-go" style="background:var(--brand);color:var(--on-brand);border:none;border-radius:var(--r-sm);padding:6px 12px;font:inherit;font-weight:600;cursor:pointer">Refresh</button>`;
    document.body.appendChild(bar);
    $("#update-go").onclick = () => { if (reg.waiting) reg.waiting.postMessage({ type: "SKIP_WAITING" }); };
  }

  // ------------------------------ Boot ---------------------------------
  function boot() {
    $$(".tabbar button").forEach((b) => (b.onclick = () => (location.hash = b.dataset.tab)));
    const er = $("#exportRecipes"); if (er) er.onclick = window.__exportRecipes;
    save(); // persist the migrated/normalized shape so it's durable
    maybeHandleShareHash();
    render();
    registerSW();
  }
  window.addEventListener("hashchange", onRoute);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
