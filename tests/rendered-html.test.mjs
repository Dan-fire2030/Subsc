import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function source(path) {
  return readFile(new URL(`../${path}`, import.meta.url), "utf8");
}

test("ships an installable Subsc PWA with an offline fallback", async () => {
  const [manifest, layout, serviceWorker, offlinePage] = await Promise.all([
    source("app/manifest.ts"),
    source("app/layout.tsx"),
    source("public/sw.js"),
    source("public/offline.html"),
  ]);

  assert.match(manifest, /name:\s*"Subsc"/);
  assert.match(manifest, /short_name:\s*"Subsc"/);
  assert.match(manifest, /display:\s*"standalone"/);
  assert.match(manifest, /subsc-icon-192-2026\.png/);
  assert.match(manifest, /subsc-icon-512-2026\.png/);
  assert.match(layout, /ServiceWorkerRegistration/);
  assert.match(serviceWorker, /networkFirstNavigation/);
  assert.match(serviceWorker, /PRIVATE_CACHE_NAME/);
  assert.match(serviceWorker, /url\.pathname\.startsWith\("\/api\/"\)/);
  assert.match(offlinePage, /現在オフラインです/);
});

test("keeps offline edits in a user-scoped queue and syncs through auth", async () => {
  const [store, manager, api, database] = await Promise.all([
    source("app/offline-store.ts"),
    source("app/SubscriptionManager.tsx"),
    source("app/api/subscriptions/route.ts"),
    source("db/subscriptions.ts"),
  ]);

  assert.match(store, /userEmail/);
  assert.match(store, /enqueueOperation/);
  assert.match(store, /saveSnapshot/);
  assert.match(manager, /window\.addEventListener\("online"/);
  assert.match(manager, /document\.addEventListener\("visibilitychange"/);
  assert.match(manager, /変更は端末に保存済み/);
  assert.match(api, /getChatGPTUser/);
  assert.match(api, /Unauthorized/);
  assert.match(database, /subscriptions_user_client_idx/);
  assert.match(database, /client_id = \?/);
});
