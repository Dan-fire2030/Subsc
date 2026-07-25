import { env } from "cloudflare:workers";

export type Subscription = {
  id: number;
  name: string;
  price: number;
  category: string;
  renewalDate: string;
  color: string;
};

async function ready() {
  const db = env.DB;
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price INTEGER NOT NULL,
      category TEXT NOT NULL,
      renewal_date TEXT NOT NULL,
      color TEXT NOT NULL DEFAULT '#c8ff3d',
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )`),
  ]);

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
    "SELECT id, name, price, category, renewal_date AS renewalDate, color FROM subscriptions ORDER BY renewal_date ASC",
  ).all<Subscription>();
  return result.results;
}

export async function addSubscription(input: Omit<Subscription, "id">) {
  await ready();
  await env.DB.prepare(
    "INSERT INTO subscriptions (name, price, category, renewal_date, color) VALUES (?, ?, ?, ?, ?)",
  ).bind(input.name, input.price, input.category, input.renewalDate, input.color).run();
}

export async function deleteSubscription(id: number) {
  await ready();
  await env.DB.prepare("DELETE FROM subscriptions WHERE id = ?").bind(id).run();
}
