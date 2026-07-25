import { env } from "cloudflare:workers";

const CACHE_KEY = "usd_jpy_exchange_rate";
const CACHE_MAX_AGE_MS = 4 * 60 * 60 * 1000;
const FRANKFURTER_URL = "https://api.frankfurter.dev/v2/rate/USD/JPY";

export type UsdJpyRate = {
  rate: number;
  date: string;
  fetchedAt: number;
  stale: boolean;
  available: boolean;
};

type StoredRate = Omit<UsdJpyRate, "stale" | "available">;

async function ensureStorage() {
  await env.DB.prepare(`CREATE TABLE IF NOT EXISTS app_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )`).run();
}

async function readStoredRate(): Promise<StoredRate | null> {
  await ensureStorage();
  const row = await env.DB.prepare(
    "SELECT value FROM app_meta WHERE key = ?",
  ).bind(CACHE_KEY).first<{ value: string }>();
  if (!row) return null;
  try {
    const value = JSON.parse(row.value) as StoredRate;
    if (
      !Number.isFinite(value.rate) ||
      value.rate <= 0 ||
      !value.date ||
      !Number.isFinite(value.fetchedAt)
    ) {
      return null;
    }
    return value;
  } catch {
    return null;
  }
}

async function storeRate(value: StoredRate) {
  await env.DB.prepare(
    `INSERT INTO app_meta (key, value) VALUES (?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
  ).bind(CACHE_KEY, JSON.stringify(value)).run();
}

export async function getUsdJpyRate(): Promise<UsdJpyRate> {
  const stored = await readStoredRate();
  if (stored && Date.now() - stored.fetchedAt < CACHE_MAX_AGE_MS) {
    return { ...stored, stale: false, available: true };
  }

  try {
    const response = await fetch(FRANKFURTER_URL, {
      headers: { Accept: "application/json" },
    });
    if (!response.ok) throw new Error("Exchange rate request failed");
    const data = (await response.json()) as {
      rate?: number;
      date?: string;
    };
    if (
      !Number.isFinite(data.rate) ||
      Number(data.rate) <= 0 ||
      !data.date
    ) {
      throw new Error("Invalid exchange rate response");
    }
    const fresh = {
      rate: Number(data.rate),
      date: data.date,
      fetchedAt: Date.now(),
    };
    await storeRate(fresh);
    return { ...fresh, stale: false, available: true };
  } catch {
    if (stored) return { ...stored, stale: true, available: true };
    return {
      rate: 0,
      date: "",
      fetchedAt: 0,
      stale: true,
      available: false,
    };
  }
}
