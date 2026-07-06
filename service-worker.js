/* Simple offline-first service worker for the Weekly Dinner App. */
const CACHE = "weekly-dinner-v5";
const ASSETS = [
  "./",
  "./index.html",
  "./css/styles.css",
  "./js/recipes.js",
  "./js/app.js",
  "./manifest.webmanifest",
  "./icons/icon.svg",
];

self.addEventListener("install", (e) => {
  // Do NOT skipWaiting automatically — wait until the page tells us to, so we
  // can surface a "new version available — tap to refresh" prompt instead of
  // swapping assets out from under an open session.
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)));
});

// The page posts this when the user taps "Refresh" on the update banner.
self.addEventListener("message", (e) => {
  if (e.data && e.data.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  // Network-first for navigations, cache-first for static assets.
  if (req.mode === "navigate") {
    e.respondWith(fetch(req).catch(() => caches.match("./index.html")));
    return;
  }
  e.respondWith(
    caches.match(req).then((cached) => cached || fetch(req).then((res) => {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
      return res;
    }).catch(() => cached))
  );
});
