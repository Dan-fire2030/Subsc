import { env } from "cloudflare:workers";

export type BillingCycle = "monthly" | "yearly";
export type SubscriptionStatus = "active" | "paused";

export type Subscription = {
  id: number;
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
  ] as const;
  const statements = additions
    .filter(([name]) => !columns.has(name))
    .map(([, statement]) => db.prepare(statement));
  if (statements.length) await db.batch(statements);
}

async function ready() {
  const db = env.DB;
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
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

  const seeded = await db.prepare("SELECT value FROM app_meta WHERE key = ?").bind("seeded").first();
  if (!seeded) {
    const today = new Date();
    const upcoming = (days: number) => {
      const date = new Date(today);
      date.setDate(date.getDate() + days);
      return date.toISOString().slice(0, 10);
    };
    await db.batch([
      db.prepare("INSERT INTO subscriptions (name, price, category, renewal_date, color) VALUES (?, ?, ?, ?, ?)")
        .bind("Netflix", 1490, "エンタメ", upcoming(3), "#e76f7a"),
      db.prepare("INSERT INTO subscriptions (name, price, category, renewal_date, color) VALUES (?, ?, ?, ?, ?)")
        .bind("Spotify", 980, "音楽", upcoming(8), "#72db95"),
      db.prepare("INSERT INTO subscriptions (name, price, category, renewal_date, color) VALUES (?, ?, ?, ?, ?)")
        .bind("Adobe CC", 6480, "仕事・学習", upcoming(14), "#8be9fd"),
      db.prepare("INSERT INTO subscriptions (name, price, category, renewal_date, color) VALUES (?, ?, ?, ?, ?)")
        .bind("iCloud+", 450, "生活", upcoming(21), "#c4a7e7"),
      db.prepare("INSERT INTO app_meta (key, value) VALUES (?, ?)").bind("seeded", "1"),
    ]);
  }
}

export async function listSubscriptions(): Promise<Subscription[]> {
  await ready();
  const result = await env.DB.prepare(
    `SELECT id, name, price, category, renewal_date AS renewalDate,
      billing_cycle AS billingCycle, status, color,
      website_url AS websiteUrl, notes
    FROM subscriptions ORDER BY renewal_date ASC`,
  ).all<Subscription>();
  return result.results;
}

export async function saveSubscription(input: SubscriptionInput) {
  await ready();
  if (input.id) {
    await env.DB.prepare(
      `UPDATE subscriptions
      SET name = ?, price = ?, category = ?, renewal_date = ?,
        billing_cycle = ?, status = ?, color = ?, website_url = ?,
        notes = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?`,
    ).bind(
      input.name,
      input.price,
      input.category,
      input.renewalDate,
      input.billingCycle,
      input.status,
      input.color,
      input.websiteUrl,
      input.notes,
      input.id,
    ).run();
    return;
  }
  await env.DB.prepare(
    `INSERT INTO subscriptions
      (name, price, category, renewal_date, billing_cycle, status, color, website_url, notes, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
  ).bind(
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
}

export async function deleteSubscription(id: number) {
  await ready();
  await env.DB.prepare("DELETE FROM subscriptions WHERE id = ?").bind(id).run();
}
