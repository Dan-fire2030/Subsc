import { env } from "cloudflare:workers";

export type BillingCycle = "monthly" | "yearly";
export type SubscriptionStatus = "active" | "paused";
export type Currency = "JPY" | "USD";

export type Subscription = {
  id: number;
  clientId: string;
  currency: Currency;
  originalAmount: number;
  exchangeRate: number;
  name: string;
  price: number;
  category: string;
  renewalDate: string;
  billingCycle: BillingCycle;
  status: SubscriptionStatus;
  color: string;
  websiteUrl: string;
  notes: string;
};

export type SubscriptionInput = Omit<Subscription, "id"> & { id?: number };

async function ensureColumns(db: D1Database) {
  const info = await db.prepare("PRAGMA table_info(subscriptions)").all<{ name: string }>();
  const columns = new Set(info.results.map((column) => column.name));
  const additions = [
    ["billing_cycle", "ALTER TABLE subscriptions ADD COLUMN billing_cycle TEXT NOT NULL DEFAULT 'monthly'"],
    ["status", "ALTER TABLE subscriptions ADD COLUMN status TEXT NOT NULL DEFAULT 'active'"],
    ["website_url", "ALTER TABLE subscriptions ADD COLUMN website_url TEXT NOT NULL DEFAULT ''"],
    ["notes", "ALTER TABLE subscriptions ADD COLUMN notes TEXT NOT NULL DEFAULT ''"],
    ["updated_at", "ALTER TABLE subscriptions ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''"],
    ["user_email", "ALTER TABLE subscriptions ADD COLUMN user_email TEXT NOT NULL DEFAULT ''"],
    ["client_id", "ALTER TABLE subscriptions ADD COLUMN client_id TEXT NOT NULL DEFAULT ''"],
    ["currency", "ALTER TABLE subscriptions ADD COLUMN currency TEXT NOT NULL DEFAULT 'JPY'"],
    ["original_amount", "ALTER TABLE subscriptions ADD COLUMN original_amount REAL NOT NULL DEFAULT 0"],
    ["exchange_rate", "ALTER TABLE subscriptions ADD COLUMN exchange_rate REAL NOT NULL DEFAULT 1"],
  ] as const;
  const statements = additions
    .filter(([name]) => !columns.has(name))
    .map(([, statement]) => db.prepare(statement));
  if (statements.length) await db.batch(statements);
}

async function ready() {
  const db = env.DB;
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS users (
      email TEXT PRIMARY KEY NOT NULL,
      display_name TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id TEXT NOT NULL DEFAULT '',
      user_email TEXT NOT NULL DEFAULT '',
      currency TEXT NOT NULL DEFAULT 'JPY',
      original_amount REAL NOT NULL DEFAULT 0,
      exchange_rate REAL NOT NULL DEFAULT 1,
      name TEXT NOT NULL,
      price INTEGER NOT NULL,
      category TEXT NOT NULL,
      renewal_date TEXT NOT NULL,
      billing_cycle TEXT NOT NULL DEFAULT 'monthly',
      status TEXT NOT NULL DEFAULT 'active',
      color TEXT NOT NULL DEFAULT '#c8ff3d',
      website_url TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )`),
  ]);
  await ensureColumns(db);
  await db.prepare(
    "UPDATE subscriptions SET client_id = 'server-' || id WHERE client_id = ''",
  ).run();
  await db.prepare(
    `UPDATE subscriptions
     SET currency = 'JPY',
       original_amount = price,
       exchange_rate = 1
     WHERE original_amount <= 0`,
  ).run();
  await db.batch([
    db.prepare("CREATE INDEX IF NOT EXISTS subscriptions_user_email_idx ON subscriptions (user_email)"),
    db.prepare("CREATE INDEX IF NOT EXISTS subscriptions_user_renewal_idx ON subscriptions (user_email, renewal_date)"),
    db.prepare("CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_user_client_idx ON subscriptions (user_email, client_id)"),
  ]);
}

export async function registerUser(email: string, displayName: string) {
  await ready();
  const db = env.DB;
  await db.prepare(
    `INSERT INTO users (email, display_name)
     VALUES (?, ?)
     ON CONFLICT(email) DO UPDATE SET
       display_name = excluded.display_name,
       last_seen_at = CURRENT_TIMESTAMP`,
  ).bind(email, displayName).run();

  await db.prepare(
    "INSERT OR IGNORE INTO app_meta (key, value) VALUES ('legacy_claimed_to', ?)",
  ).bind(email).run();
  const owner = await db.prepare(
    "SELECT value FROM app_meta WHERE key = 'legacy_claimed_to'",
  ).first<{ value: string }>();
  if (owner?.value === email) {
    await db.prepare(
      "UPDATE subscriptions SET user_email = ? WHERE user_email = ''",
    ).bind(email).run();
  }
}

export async function listSubscriptions(userEmail: string): Promise<Subscription[]> {
  await ready();
  const result = await env.DB.prepare(
    `SELECT id, client_id AS clientId, currency,
      original_amount AS originalAmount, exchange_rate AS exchangeRate,
      name, price, category, renewal_date AS renewalDate,
      billing_cycle AS billingCycle, status, color,
      website_url AS websiteUrl, notes
    FROM subscriptions
    WHERE user_email = ?
    ORDER BY renewal_date ASC`,
  ).bind(userEmail).all<Subscription>();
  return result.results;
}

async function findSubscription(
  userEmail: string,
  input: Pick<SubscriptionInput, "id" | "clientId">,
) {
  await ready();
  if (input.id && input.id > 0) {
    const byId = await env.DB.prepare(
      "SELECT id FROM subscriptions WHERE id = ? AND user_email = ?",
    ).bind(input.id, userEmail).first<{ id: number }>();
    if (byId) return byId.id;
  }
  const byClientId = await env.DB.prepare(
    "SELECT id FROM subscriptions WHERE client_id = ? AND user_email = ?",
  ).bind(input.clientId, userEmail).first<{ id: number }>();
  return byClientId?.id;
}

async function getSubscription(userEmail: string, id: number) {
  return env.DB.prepare(
    `SELECT id, client_id AS clientId, currency,
      original_amount AS originalAmount, exchange_rate AS exchangeRate,
      name, price, category,
      renewal_date AS renewalDate, billing_cycle AS billingCycle,
      status, color, website_url AS websiteUrl, notes
    FROM subscriptions WHERE id = ? AND user_email = ?`,
  ).bind(id, userEmail).first<Subscription>();
}

export async function saveSubscription(
  userEmail: string,
  input: SubscriptionInput,
): Promise<Subscription> {
  await ready();
  const existingId = await findSubscription(userEmail, input);
  if (existingId) {
    await env.DB.prepare(
      `UPDATE subscriptions
      SET currency = ?, original_amount = ?, exchange_rate = ?,
        name = ?, price = ?, category = ?, renewal_date = ?,
        billing_cycle = ?, status = ?, color = ?, website_url = ?,
        notes = ?, client_id = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND user_email = ?`,
    ).bind(
      input.currency,
      input.originalAmount,
      input.exchangeRate,
      input.name,
      input.price,
      input.category,
      input.renewalDate,
      input.billingCycle,
      input.status,
      input.color,
      input.websiteUrl,
      input.notes,
      input.clientId,
      existingId,
      userEmail,
    ).run();
    const updated = await getSubscription(userEmail, existingId);
    if (!updated) throw new Error("保存したサブスクを確認できませんでした。");
    return updated;
  }
  const inserted = await env.DB.prepare(
    `INSERT INTO subscriptions
      (client_id, user_email, currency, original_amount, exchange_rate,
       name, price, category, renewal_date, billing_cycle, status, color,
       website_url, notes, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
  ).bind(
    input.clientId,
    userEmail,
    input.currency,
    input.originalAmount,
    input.exchangeRate,
    input.name,
    input.price,
    input.category,
    input.renewalDate,
    input.billingCycle,
    input.status,
    input.color,
    input.websiteUrl,
    input.notes,
  ).run();
  const created = await getSubscription(userEmail, Number(inserted.meta.last_row_id));
  if (!created) throw new Error("追加したサブスクを確認できませんでした。");
  return created;
}

export async function deleteSubscription(userEmail: string, id: number) {
  await ready();
  await env.DB.prepare(
    "DELETE FROM subscriptions WHERE id = ? AND user_email = ?",
  ).bind(id, userEmail).run();
}

export async function deleteSubscriptionByClient(
  userEmail: string,
  input: { id?: number; clientId: string },
) {
  await ready();
  await env.DB.prepare(
    `DELETE FROM subscriptions
     WHERE user_email = ? AND (client_id = ? OR id = ?)`,
  ).bind(
    userEmail,
    input.clientId,
    input.id && input.id > 0 ? input.id : -1,
  ).run();
}

export async function deleteUserData(userEmail: string) {
  await ready();
  const db = env.DB;
  await db.batch([
    db.prepare("DELETE FROM subscriptions WHERE user_email = ?").bind(userEmail),
    db.prepare("DELETE FROM users WHERE email = ?").bind(userEmail),
  ]);
}
