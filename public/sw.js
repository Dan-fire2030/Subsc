const CACHE_NAME = "subsc-shell-v2";
const PRIVATE_CACHE_NAME = "subsc-private-v1";
const OFFLINE_URL = "/offline.html";
const STATIC_ASSETS = [
  OFFLINE_URL,
  "/subsc-favicon-2026.png",
  "/subsc-apple-touch-2026.png",
  "/subsc-icon-192-2026.png",
  "/subsc-icon-512-2026.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter(
              (key) =>
                key.startsWith("subsc-") &&
                ![CACHE_NAME, PRIVATE_CACHE_NAME].includes(key),
            )
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

async function cachePrivatePage(url) {
  const response = await fetch(url, {
    credentials: "include",
    headers: { Accept: "text/html" },
  });
  if (response.ok && !response.redirected) {
    const cache = await caches.open(PRIVATE_CACHE_NAME);
    await cache.put("/", response.clone());
  }
}

self.addEventListener("message", (event) => {
  if (event.data?.type === "CACHE_CURRENT_PAGE") {
    event.waitUntil(cachePrivatePage(event.data.url || "/"));
  }
  if (event.data?.type === "CLEAR_PRIVATE_CACHE") {
    event.waitUntil(caches.delete(PRIVATE_CACHE_NAME));
  }
});

async function networkFirstNavigation(request) {
  try {
    const response = await fetch(request);
    if (response.ok && !response.redirected) {
      const cache = await caches.open(PRIVATE_CACHE_NAME);
      await cache.put("/", response.clone());
    }
    return response;
  } catch {
    return (
      (await caches.match("/", { cacheName: PRIVATE_CACHE_NAME })) ??
      (await caches.match(OFFLINE_URL)) ??
      new Response("Offline", { status: 503 })
    );
  }
}

async function cacheFirstAsset(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) {
    const cache = await caches.open(CACHE_NAME);
    await cache.put(request, response.clone());
  }
  return response;
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (
    url.pathname.startsWith("/api/") ||
    url.pathname.startsWith("/signin-with-chatgpt")
  ) {
    return;
  }

  if (request.mode === "navigate") {
    event.respondWith(networkFirstNavigation(request));
    return;
  }

  if (
    ["script", "style", "font", "image"].includes(request.destination) ||
    url.pathname === "/manifest.webmanifest"
  ) {
    event.respondWith(cacheFirstAsset(request));
  }
});
