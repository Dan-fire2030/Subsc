import { getChatGPTUser } from "../../chatgpt-auth";
import {
  deleteSubscriptionByClient,
  listSubscriptions,
  saveSubscription,
  type BillingCycle,
  type SubscriptionInput,
  type SubscriptionStatus,
} from "../../../db/subscriptions";

export const dynamic = "force-dynamic";

function json(data: unknown, status = 200) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "private, no-store" },
  });
}

function parseSubscription(value: unknown): SubscriptionInput | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Record<string, unknown>;
  const id = Number(item.id);
  const clientId = String(item.clientId ?? "").trim();
  const name = String(item.name ?? "").trim();
  const price = Number(item.price);
  const category = String(item.category ?? "その他");
  const renewalDate = String(item.renewalDate ?? "");
  const billingCycle = String(item.billingCycle ?? "monthly") as BillingCycle;
  const status = String(item.status ?? "active") as SubscriptionStatus;
  const color = String(item.color ?? "#007AFF");
  const websiteUrl = String(item.websiteUrl ?? "").trim();
  const notes = String(item.notes ?? "").trim();

  if (!clientId || clientId.length > 100 || !name) return null;
  if (!Number.isFinite(price) || price < 0) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(renewalDate)) return null;
  if (!["monthly", "yearly"].includes(billingCycle)) return null;
  if (!["active", "paused"].includes(status)) return null;
  if (websiteUrl) {
    try {
      const url = new URL(websiteUrl);
      if (!["http:", "https:"].includes(url.protocol)) return null;
    } catch {
      return null;
    }
  }

  return {
    id: Number.isInteger(id) && id > 0 ? id : undefined,
    clientId,
    name,
    price: Math.round(price),
    category,
    renewalDate,
    billingCycle,
    status,
    color,
    websiteUrl,
    notes: notes.slice(0, 300),
  };
}

export async function GET() {
  const user = await getChatGPTUser();
  if (!user) return json({ error: "Unauthorized" }, 401);
  return json({ subscriptions: await listSubscriptions(user.email) });
}

export async function POST(request: Request) {
  const user = await getChatGPTUser();
  if (!user) return json({ error: "Unauthorized" }, 401);

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  if (body.type === "upsert") {
    const subscription = parseSubscription(body.subscription);
    if (!subscription) return json({ error: "Invalid subscription" }, 400);
    const saved = await saveSubscription(user.email, subscription);
    return json({ subscription: saved });
  }

  if (body.type === "delete") {
    const id = Number(body.id);
    const clientId = String(body.clientId ?? "").trim();
    if (!clientId || clientId.length > 100) {
      return json({ error: "Invalid subscription" }, 400);
    }
    await deleteSubscriptionByClient(user.email, {
      id: Number.isInteger(id) && id > 0 ? id : undefined,
      clientId,
    });
    return json({ ok: true });
  }

  return json({ error: "Invalid operation" }, 400);
}
