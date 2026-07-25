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

test("accepts USD prices and keeps the app display in yen", async () => {
  const [manager, api, database, exchangeRate] = await Promise.all([
    source("app/SubscriptionManager.tsx"),
    source("app/api/subscriptions/route.ts"),
    source("db/subscriptions.ts"),
    source("db/exchange-rate.ts"),
  ]);

  assert.match(manager, /米ドル/);
  assert.match(manager, /currentPrice/);
  assert.match(manager, /exchangeRate=\{usdJpyRate\}/);
  assert.match(api, /currency === "USD"/);
  assert.match(api, /originalAmount \* rate/);
  assert.match(database, /original_amount/);
  assert.match(exchangeRate, /api\.frankfurter\.dev\/v2\/rate\/USD\/JPY/);
  assert.match(exchangeRate, /usd_jpy_exchange_rate/);
});

test("stores detailed contract periods and builds in-app deadline alerts", async () => {
  const [manager, fields, alerts, contractSettings, api, database, migration] =
    await Promise.all([
      source("app/SubscriptionManager.tsx"),
      source("app/ContractSettingsFields.tsx"),
      source("app/contract-alerts.ts"),
      source("db/contract-settings.ts"),
      source("app/api/subscriptions/route.ts"),
      source("db/subscriptions.ts"),
      source("drizzle/0006_worried_drax.sql"),
    ]);

  assert.match(manager, /buildContractAlerts/);
  assert.match(manager, /まもなく期限/);
  assert.match(fields, /契約期間を設定/);
  assert.match(fields, /無料体験終了日/);
  assert.match(fields, /解約期限/);
  assert.match(fields, /アプリ内通知/);
  assert.match(contractSettings, /minimumTermEndDate/);
  assert.match(contractSettings, /final_payment/);
  assert.match(alerts, /cancellation_deadline/);
  assert.match(api, /normalizeContractSettings/);
  assert.match(database, /contract_settings/);
  assert.match(migration, /ADD `contract_settings`/);
});

test("builds swipeable monthly and yearly reports with animated service bars", async () => {
  const [hero, calculations, manager, contractSettings, fields, styles] =
    await Promise.all([
      source("app/ReportHero.tsx"),
      source("app/report-calculations.ts"),
      source("app/SubscriptionManager.tsx"),
      source("db/contract-settings.ts"),
      source("app/ContractSettingsFields.tsx"),
      source("app/globals.css"),
    ]);

  assert.match(hero, /AnimatedYen/);
  assert.match(hero, /handlePointerMove/);
  assert.match(hero, /左右にスワイプ/);
  assert.match(hero, /ReportBars/);
  assert.match(calculations, /billingStartDate/);
  assert.match(calculations, /statusHistory/);
  assert.match(calculations, /buildPaymentReport/);
  assert.match(contractSettings, /StatusHistoryEntry/);
  assert.match(fields, /停止・再開の履歴/);
  assert.match(manager, /停止日を記録/);
  assert.match(styles, /--bar-scale/);
  assert.match(styles, /add-trigger\.is-pressing/);
});
