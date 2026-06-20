/* =====================================================================
 * Weekly Dinner App — core logic
 * Vanilla JS, no build step, fully offline (localStorage). PWA installable.
 * ===================================================================== */

(function () {
  "use strict";

  // ---- Ingredient category metadata: WinCo aisle + pantry behavior ----
  // staple:true items are tracked across weeks (you keep leftovers).
  // coverage = how many weeks a typical purchase realistically lasts.
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

  // WinCo-style aisle ordering for the grocery list (shop top to bottom).
  const AISLE_ORDER = [
    "Produce",
    "Produce — Fresh Herbs",
    "Meat",
    "Dairy & Eggs",
    "Bakery & Bread",
    "Pasta, Rice & Grains",
    "Canned & Jarred",
    "Condiments & Sauces",
    "Oils & Vinegars",
    "Spices & Seasonings",
    "Baking & Sweeteners",
    "Nuts & Seeds",
    "Frozen",
  ];

  // -------------------------- State / storage --------------------------
  const STORAGE_KEY = "weeklyDinnerApp.v1";
  const defaultState = {
    prefs: {
      likedCuisines: ["Mexican", "Italian", "Mediterranean", "Indian", "American Chinese", "American"],
      maxTime: 60,
      dinnersPerWeek: 4,
      includeDessert: true,
      preferSpicy: true,
      avoidWeeks: 2, // don't repeat recipes used within this many recent weeks
    },
    plan: null,            // { dinnerIds:[], dessertId, createdAt }
    pantry: {},            // key -> { name, cat, stockedOn(ISO), coverageWeeks }
    history: [],           // [{ id, date, dinnerIds, dessertId, bought:{key:true} }]
  };

  let state = load();

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return structuredClone(defaultState);
      const parsed = JSON.parse(raw);
      // shallow-merge to tolerate older saves
      return Object.assign(structuredClone(defaultState), parsed, {
        prefs: Object.assign({}, defaultState.prefs, parsed.prefs || {}),
      });
    } catch (e) {
      console.warn("Failed to load state, starting fresh", e);
      return structuredClone(defaultState);
    }
  }
  function save() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }

  // ------------------------------ Utils --------------------------------
  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));
  const todayISO = () => new Date().toISOString().slice(0, 10);
  const recipeById = (id) => RECIPES.find((r) => r.id === id);
  const esc = (s) =>
    String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  function normKey(name) {
    return String(name).toLowerCase().replace(/\(.*?\)/g, "").replace(/[^a-z0-9 ]/g, "").trim();
  }
  function daysBetween(aISO, bISO) {
    return Math.round((new Date(bISO) - new Date(aISO)) / 86400000);
  }
  function shuffle(arr) {
    const a = arr.slice();
    for (let k = a.length - 1; k > 0; k--) {
      const j = Math.floor(Math.random() * (k + 1));
      [a[k], a[j]] = [a[j], a[k]];
    }
    return a;
  }

  // --------------------- Pantry "do we need it?" -----------------------
  // Returns { status: 'have'|'buy', detail } for a staple ingredient key.
  function pantryStatus(key, cat) {
    const meta = CAT_META[cat] || {};
    if (!meta.staple) return { status: "buy", detail: "" }; // perishable -> always buy
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
    // Only track staples across weeks. Perishables are always re-listed, so
    // recording them would just clutter the pantry view.
    if (!meta.staple) return;
    state.pantry[key] = {
      name,
      cat,
      stockedOn: todayISO(),
      coverageWeeks: meta.coverage,
    };
  }
  function markOutOfStock(key) {
    delete state.pantry[key];
  }

  // ------------------------- Meal plan engine --------------------------
  function eligibleDinners() {
    const prefs = state.prefs;
    const recentIds = new Set();
    state.history.slice(0, prefs.avoidWeeks).forEach((w) => (w.dinnerIds || []).forEach((id) => recentIds.add(id)));
    return RECIPES.filter(
      (r) =>
        r.cuisine !== "Dessert" &&
        prefs.likedCuisines.includes(r.cuisine) &&
        r.time <= prefs.maxTime &&
        !recentIds.has(r.id)
    );
  }

  function generatePlan() {
    const prefs = state.prefs;
    let pool = eligibleDinners();
    // If filtering by recent weeks emptied the pool, relax it.
    if (pool.length < prefs.dinnersPerWeek) {
      pool = RECIPES.filter(
        (r) => r.cuisine !== "Dessert" && prefs.likedCuisines.includes(r.cuisine) && r.time <= prefs.maxTime
      );
    }
    // Bias spicy picks toward the front if preferred, but keep variety.
    let ordered = shuffle(pool);
    if (prefs.preferSpicy) {
      ordered.sort((a, b) => (b.spicy ? 1 : 0) - (a.spicy ? 1 : 0) - 0.5 + Math.random());
    }

    // Greedy pick favoring distinct cuisines first.
    const picked = [];
    const usedCuisines = new Set();
    for (const r of ordered) {
      if (picked.length >= prefs.dinnersPerWeek) break;
      if (!usedCuisines.has(r.cuisine)) {
        picked.push(r);
        usedCuisines.add(r.cuisine);
      }
    }
    // Fill remaining slots with anything left.
    for (const r of ordered) {
      if (picked.length >= prefs.dinnersPerWeek) break;
      if (!picked.includes(r)) picked.push(r);
    }

    const plan = { dinnerIds: picked.slice(0, prefs.dinnersPerWeek).map((r) => r.id), dessertId: null, createdAt: todayISO() };
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
    const prefs = state.prefs;
    const current = new Set(state.plan.dinnerIds);
    let pool = eligibleDinners().filter((r) => !current.has(r.id));
    if (!pool.length) pool = RECIPES.filter((r) => r.cuisine !== "Dessert" && prefs.likedCuisines.includes(r.cuisine) && r.time <= prefs.maxTime && !current.has(r.id));
    if (!pool.length) return;
    const replacement = shuffle(pool)[0];
    state.plan.dinnerIds[index] = replacement.id;
    save();
  }
  function rerollDessert() {
    if (!state.plan) return;
    const desserts = RECIPES.filter((r) => r.cuisine === "Dessert" && r.id !== state.plan.dessertId);
    const chosen = shuffle(desserts)[0];
    if (chosen) { state.plan.dessertId = chosen.id; save(); }
  }
  function swapDinner(index, newId) {
    if (!state.plan) return;
    state.plan.dinnerIds[index] = newId;
    save();
  }

  // ----------------------- Grocery aggregation -------------------------
  // Build aisle-grouped list from current plan, applying pantry logic.
  function buildGrocery(includeDessert) {
    if (!state.plan) return { aisles: [], haveItems: [] };
    const ids = state.plan.dinnerIds.slice();
    if (includeDessert && state.plan.dessertId) ids.push(state.plan.dessertId);

    const map = new Map(); // key -> { name, cat, parts:[{qty,unit,from}] }
    ids.forEach((id) => {
      const r = recipeById(id);
      if (!r) return;
      r.ingredients.forEach((ing) => {
        const key = normKey(ing.name);
        if (!map.has(key)) map.set(key, { key, name: ing.name, cat: ing.cat, parts: [] });
        map.get(key).parts.push({ qty: ing.qty, unit: ing.unit, from: r.title });
      });
    });

    const buy = {}; // aisle -> items[]
    const haveItems = [];
    for (const item of map.values()) {
      const ps = pantryStatus(item.key, item.cat);
      const aisle = (CAT_META[item.cat] || {}).aisle || "Other";
      const entry = {
        key: item.key,
        name: item.name,
        cat: item.cat,
        aisle,
        qty: combineQty(item.parts),
        usedIn: item.parts.map((p) => p.from),
        detail: ps.detail,
      };
      if (ps.status === "have") {
        haveItems.push(entry);
      } else {
        (buy[aisle] = buy[aisle] || []).push(entry);
      }
    }

    const aisles = AISLE_ORDER.filter((a) => buy[a]).map((a) => ({
      aisle: a,
      items: buy[a].sort((x, y) => x.name.localeCompare(y.name)),
    }));
    haveItems.sort((a, b) => a.name.localeCompare(b.name));
    return { aisles, haveItems };
  }

  // Combine quantity parts: sum when units match & numeric, else join.
  function combineQty(parts) {
    const byUnit = {};
    const text = [];
    parts.forEach((p) => {
      if (typeof p.qty === "number" && p.unit !== undefined) {
        byUnit[p.unit] = (byUnit[p.unit] || 0) + p.qty;
      } else {
        text.push([p.qty, p.unit].filter(Boolean).join(" "));
      }
    });
    const pieces = Object.entries(byUnit).map(([unit, qty]) => {
      const q = Math.round(qty * 100) / 100;
      return [q, unit].filter((x) => x !== "" && x !== undefined).join(" ");
    });
    return pieces.concat(text).join(" + ") || "as needed";
  }

  // --------------------------- Rendering -------------------------------
  const app = $("#app");

  function render() {
    const tab = location.hash.replace("#", "") || "plan";
    $$(".tabbar button").forEach((b) => b.classList.toggle("active", b.dataset.tab === tab));
    if (tab === "plan") renderPlan();
    else if (tab === "grocery") renderGrocery();
    else if (tab === "pantry") renderPantry();
    else if (tab === "browse") renderBrowse();
    else if (tab === "history") renderHistory();
    else if (tab === "settings") renderSettings();
    else renderPlan();
  }

  function cuisineBadge(c) {
    return `<span class="badge cuisine">${esc(c)}</span>`;
  }
  function metaLine(r) {
    return `${cuisineBadge(r.cuisine)}${r.spicy ? '<span class="badge spicy">🌶 spicy</span>' : ""}<span class="badge time">⏱ ${r.time} min</span><span class="badge">${esc(r.creator)}</span>`;
  }

  function renderPlan() {
    if (!state.plan) {
      app.innerHTML = `
        <section class="hero">
          <h2>This week's dinners</h2>
          <p class="muted">No plan yet. Generate 4 dinners that match your tastes — spicy-friendly, 30–60 min, from creators you like.</p>
          <button class="primary big" id="genBtn">✨ Generate this week's plan</button>
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
          <button class="ghost" id="regen">↻ Regenerate all</button>
        </div>
        <p class="muted">Created ${esc(state.plan.createdAt)}. Tap ↻ on a meal to swap it.</p>
        <div class="cards">
          ${dinners.map((r, idx) => recipeCard(r, idx)).join("")}
        </div>
        ${dessert ? `<h3 class="section-title">Lighter dessert</h3><div class="cards">${recipeCard(dessert, -1, true)}</div>` : ""}
        <div class="actions">
          <a class="primary" href="#grocery">🛒 View grocery list</a>
          <button class="ghost" id="saveWeek">✅ We shopped — save this week</button>
        </div>
      </section>`;

    $("#regen").onclick = () => { generatePlan(); render(); };
    $$("[data-reroll]").forEach((b) => (b.onclick = () => { rerollSlot(+b.dataset.reroll); render(); }));
    const rd = $("[data-reroll-dessert]");
    if (rd) rd.onclick = () => { rerollDessert(); render(); };
    $$("[data-swap]").forEach((sel) => (sel.onchange = () => { swapDinner(+sel.dataset.swap, sel.value); render(); }));
    $("#saveWeek").onclick = saveCurrentWeek;
  }

  function recipeCard(r, idx, isDessert) {
    const swap = isDessert
      ? `<button class="icon" data-reroll-dessert title="Swap dessert">↻</button>`
      : `<button class="icon" data-reroll="${idx}" title="Swap meal">↻</button>`;
    const swapSelect = isDessert
      ? ""
      : `<select class="swap" data-swap="${idx}" title="Pick a specific meal">
           <option value="">Swap to…</option>
           ${RECIPES.filter((x) => x.cuisine !== "Dessert").map((x) => `<option value="${x.id}">${esc(x.title)} (${esc(x.cuisine)})</option>`).join("")}
         </select>`;
    return `
      <article class="card">
        <div class="card-head">
          <h3>${esc(r.title)}</h3>
          ${swap}
        </div>
        <div class="badges">${metaLine(r)}</div>
        <p class="note">${esc(r.note || "")}</p>
        <div class="card-actions">
          <a href="${esc(r.url)}" target="_blank" rel="noopener">Open recipe ↗</a>
          ${swapSelect}
        </div>
      </article>`;
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
        <p class="muted">Organized by WinCo aisle. Check items as you buy them — staples (spices, oils, canned, grains) are tracked so we skip them when you should still have some.</p>
        ${aisles.map(aisleBlock).join("") || '<p class="muted">Nothing to buy — you have it all!</p>'}
        ${haveItems.length ? `
          <details class="have">
            <summary>🗄 Skipping ${haveItems.length} item(s) you likely already have</summary>
            <ul class="have-list">
              ${haveItems.map((it) => `<li>${esc(it.name)} <span class="muted">— ${esc(it.detail)}</span> <button class="link" data-need="${esc(it.key)}">need it anyway</button></li>`).join("")}
            </ul>
          </details>` : ""}
        <div class="actions">
          <button class="ghost" id="copyGrocery">📋 Copy list</button>
          <button class="ghost" id="dlGrocery">⬇ Download .md</button>
          <button class="primary" id="boughtAll">✅ Mark checked items as bought</button>
        </div>
      </section>`;

    $$('[data-need]').forEach((b) => (b.onclick = () => { markOutOfStock(b.dataset.need); save(); render(); }));
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
                <input type="checkbox" data-buykey="${esc(it.key)}" data-buyname="${esc(it.name)}" data-buycat="${esc(it.cat)}">
                <span class="g-name">${esc(it.name)}</span>
                <span class="g-qty">${esc(it.qty)}</span>
              </label>
              <div class="g-used muted">for ${esc(it.usedIn.join(", "))}</div>
            </li>`).join("")}
        </ul>
      </div>`;
  }

  function renderPantry() {
    const keys = Object.keys(state.pantry);
    const rows = keys
      .map((k) => ({ key: k, ...state.pantry[k] }))
      .sort((a, b) => (a.cat || "").localeCompare(b.cat || "") || a.name.localeCompare(b.name));
    app.innerHTML = `
      <section>
        <h2>Pantry tracker</h2>
        <p class="muted">Staples you've bought. We assume a typical package lasts a while and won't re-add it until it should be running low. Tap "ran out" to force it back on the list.</p>
        ${rows.length ? `
        <table class="pantry">
          <thead><tr><th>Item</th><th>Bought</th><th>Status</th><th></th></tr></thead>
          <tbody>
          ${rows.map((r) => {
            const ps = pantryStatus(r.key, r.cat);
            const age = daysBetween(r.stockedOn, todayISO());
            const wk = Math.round(age / 7);
            return `<tr>
              <td>${esc(r.name)}</td>
              <td class="muted">${wk === 0 ? "this week" : wk + " wk ago"}</td>
              <td>${ps.status === "have" ? '<span class="ok">in stock</span>' : '<span class="warn">low/empty</span>'}</td>
              <td><button class="link" data-out="${esc(r.key)}">ran out</button></td>
            </tr>`;
          }).join("")}
          </tbody>
        </table>` : '<p class="muted">Nothing tracked yet. Check off staples on your grocery list and tap "Mark checked items as bought".</p>'}
        ${rows.length ? '<button class="ghost" id="clearPantry">Clear pantry</button>' : ""}
      </section>`;
    $$('[data-out]').forEach((b) => (b.onclick = () => { markOutOfStock(b.dataset.out); save(); render(); }));
    const cp = $("#clearPantry");
    if (cp) cp.onclick = () => { if (confirm("Clear all tracked pantry items?")) { state.pantry = {}; save(); render(); } };
  }

  function renderBrowse() {
    app.innerHTML = `
      <section>
        <h2>All recipes</h2>
        <p class="muted">${RECIPES.filter((r) => r.cuisine !== "Dessert").length} dinners + ${RECIPES.filter((r) => r.cuisine === "Dessert").length} lighter desserts. Every link was confirmed live.</p>
        <div class="filterbar" id="filterbar">
          <button class="chip active" data-f="all">All</button>
          ${CUISINES.map((c) => `<button class="chip" data-f="${esc(c)}">${esc(c)}</button>`).join("")}
          <button class="chip" data-f="Dessert">Dessert</button>
          <button class="chip" data-f="spicy">🌶 Spicy</button>
        </div>
        <div class="cards" id="browseCards">${RECIPES.map(browseCard).join("")}</div>
      </section>`;
    $$("#filterbar .chip").forEach((b) => (b.onclick = () => {
      $$("#filterbar .chip").forEach((x) => x.classList.remove("active"));
      b.classList.add("active");
      const f = b.dataset.f;
      $("#browseCards").innerHTML = RECIPES.filter((r) =>
        f === "all" ? true : f === "spicy" ? r.spicy : r.cuisine === f
      ).map(browseCard).join("");
    }));
  }
  function browseCard(r) {
    return `
      <article class="card">
        <h3>${esc(r.title)}</h3>
        <div class="badges">${metaLine(r)}</div>
        <p class="note">${esc(r.note || "")}</p>
        <a href="${esc(r.url)}" target="_blank" rel="noopener">Open recipe ↗</a>
      </article>`;
  }

  function renderHistory() {
    app.innerHTML = `
      <section>
        <h2>Past weeks</h2>
        <p class="muted">We avoid repeating these recipes in your next ${state.prefs.avoidWeeks} weeks, and use them to keep your pantry up to date.</p>
        ${state.history.length ? state.history.map((w, idx) => `
          <div class="aisle">
            <div class="row-between"><h3 class="aisle-title">Week of ${esc(w.date)}</h3><button class="link" data-delweek="${idx}">delete</button></div>
            <ul class="have-list">
              ${(w.dinnerIds || []).map((id) => { const r = recipeById(id); return r ? `<li>${esc(r.title)} <span class="muted">— ${esc(r.cuisine)}</span></li>` : ""; }).join("")}
              ${w.dessertId && recipeById(w.dessertId) ? `<li>🍨 ${esc(recipeById(w.dessertId).title)}</li>` : ""}
            </ul>
          </div>`).join("") : '<p class="muted">No saved weeks yet. On the Plan tab, tap "We shopped — save this week".</p>'}
      </section>`;
    $$('[data-delweek]').forEach((b) => (b.onclick = () => { state.history.splice(+b.dataset.delweek, 1); save(); render(); }));
  }

  function renderSettings() {
    const p = state.prefs;
    app.innerHTML = `
      <section>
        <h2>Preferences</h2>
        <div class="field">
          <label>Cuisines you want in rotation</label>
          <div class="filterbar">
            ${CUISINES.map((c) => `<button class="chip ${p.likedCuisines.includes(c) ? "active" : ""}" data-cuisine="${esc(c)}">${esc(c)}</button>`).join("")}
          </div>
        </div>
        <div class="field">
          <label>Max cook time: <strong id="mtVal">${p.maxTime}</strong> min</label>
          <input type="range" id="maxTime" min="20" max="90" step="5" value="${p.maxTime}">
        </div>
        <div class="field">
          <label>Dinners per week: <strong id="dpwVal">${p.dinnersPerWeek}</strong></label>
          <input type="range" id="dpw" min="2" max="7" step="1" value="${p.dinnersPerWeek}">
        </div>
        <div class="field check"><label><input type="checkbox" id="dessert" ${p.includeDessert ? "checked" : ""}> Include a lighter dessert each week</label></div>
        <div class="field check"><label><input type="checkbox" id="spicy" ${p.preferSpicy ? "checked" : ""}> Lean spicy when possible 🌶</label></div>
        <div class="field">
          <label>Don't repeat a recipe for <strong id="awVal">${p.avoidWeeks}</strong> week(s)</label>
          <input type="range" id="aw" min="0" max="6" step="1" value="${p.avoidWeeks}">
        </div>
        <div class="actions">
          <button class="primary" id="savePrefs">Save preferences</button>
          <button class="ghost" id="resetAll">Reset app data</button>
        </div>
        <p class="muted small">Dislikes are pre-filtered out of the whole recipe set: no Thai, authentic Chinese, Japanese, Korean, seafood/fish, rhubarb, or super-fatty meats.</p>
      </section>`;

    $$('[data-cuisine]').forEach((b) => (b.onclick = () => b.classList.toggle("active")));
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
      state.prefs.avoidWeeks = +$("#aw").value;
      save();
      toast("Preferences saved.");
      location.hash = "plan";
    };
    $("#resetAll").onclick = () => {
      if (confirm("Erase plan, pantry, history and preferences?")) { state = structuredClone(defaultState); save(); location.hash = "plan"; render(); }
    };
  }

  // --------------------------- Save a week -----------------------------
  function saveCurrentWeek() {
    if (!state.plan) return;
    state.history.unshift({
      id: "w" + Date.now(),
      date: todayISO(),
      dinnerIds: state.plan.dinnerIds.slice(),
      dessertId: state.plan.dessertId,
    });
    state.history = state.history.slice(0, 20);
    save();
    toast("Week saved. Generate next week's plan whenever you're ready!");
    location.hash = "history";
    render();
  }

  // --------------------------- Doc exports -----------------------------
  function groceryMarkdown() {
    const includeDessert = state.prefs.includeDessert && state.plan && state.plan.dessertId;
    const { aisles, haveItems } = buildGrocery(includeDessert);
    let md = `# Grocery List — WinCo Foods\n\n_Week of ${todayISO()}_\n\n`;
    aisles.forEach((a) => {
      md += `## ${a.aisle}\n`;
      a.items.forEach((it) => (md += `- [ ] ${it.name} — ${it.qty}\n`));
      md += `\n`;
    });
    if (haveItems.length) {
      md += `## Already have (skipping)\n`;
      haveItems.forEach((it) => (md += `- ${it.name} (${it.detail})\n`));
    }
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
    let md = `## ${n}. ${r.title}\n`;
    md += `- **Creator:** ${r.creator}\n- **Cuisine:** ${r.cuisine}${r.spicy ? " 🌶" : ""}\n- **Total time:** ${r.time} min · Serves ${r.servings}\n- **Link:** ${r.url}\n\n`;
    md += `**Ingredients**\n`;
    r.ingredients.forEach((ing) => (md += `- ${[ing.qty, ing.unit, ing.name].filter((x) => x !== "" && x != null).join(" ")}\n`));
    md += `\n**Instructions**\n`;
    r.steps.forEach((s, i) => (md += `${i + 1}. ${s}\n`));
    md += `\n`;
    return md;
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

  // expose a couple of export helpers on the global menu buttons
  window.__exportRecipes = () => download("this-week-recipes.md", recipesMarkdown());
  window.__copyRecipes = () => copyText(recipesMarkdown());

  // ------------------------------ Boot ---------------------------------
  window.addEventListener("hashchange", render);
  document.addEventListener("DOMContentLoaded", () => {
    $$(".tabbar button").forEach((b) => (b.onclick = () => (location.hash = b.dataset.tab)));
    const er = $("#exportRecipes"); if (er) er.onclick = window.__exportRecipes;
    render();
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("./service-worker.js").catch(() => {});
  });

  // If DOM already parsed
  if (document.readyState !== "loading") {
    $$(".tabbar button").forEach((b) => (b.onclick = () => (location.hash = b.dataset.tab)));
    render();
  }
})();
