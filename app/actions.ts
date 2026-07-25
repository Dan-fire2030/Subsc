"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  deleteSubscription,
  deleteUserData,
  saveSubscription,
  type BillingCycle,
  type SubscriptionStatus,
} from "../db/subscriptions";
import { chatGPTSignOutPath, getChatGPTUser } from "./chatgpt-auth";

export type SaveState = {
  ok: boolean;
  message: string;
};

async function authenticatedEmail() {
  const user = await getChatGPTUser();
  if (!user) throw new Error("認証が必要です。もう一度ログインしてください。");
  return user.email;
}

export async function saveSubscriptionAction(
  _previous: SaveState,
  formData: FormData,
): Promise<SaveState> {
  const userEmail = await authenticatedEmail();
  const idValue = String(formData.get("id") ?? "");
  const id = idValue ? Number(idValue) : undefined;
  const name = String(formData.get("name") ?? "").trim();
  const price = Number(formData.get("price"));
  const category = String(formData.get("category") ?? "その他");
  const renewalDate = String(formData.get("renewalDate") ?? "");
  const billingCycle = String(formData.get("billingCycle") ?? "monthly") as BillingCycle;
  const status = String(formData.get("status") ?? "active") as SubscriptionStatus;
  const color = String(formData.get("color") ?? "#c8ff3d");
  const websiteUrl = String(formData.get("websiteUrl") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (id !== undefined && (!Number.isInteger(id) || id <= 0)) {
    return { ok: false, message: "編集対象を確認できませんでした。" };
  }
  if (!name) return { ok: false, message: "サービス名を入力してください。" };
  if (!Number.isFinite(price) || price < 0) {
    return { ok: false, message: "料金は0円以上で入力してください。" };
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(renewalDate)) {
    return { ok: false, message: "次の更新日を選択してください。" };
  }
  if (!["monthly", "yearly"].includes(billingCycle)) {
    return { ok: false, message: "支払いサイクルを選択してください。" };
  }
  if (!["active", "paused"].includes(status)) {
    return { ok: false, message: "利用状況を選択してください。" };
  }
  if (websiteUrl) {
    try {
      const url = new URL(websiteUrl);
      if (!["http:", "https:"].includes(url.protocol)) throw new Error();
    } catch {
      return { ok: false, message: "公式サイトは https:// から入力してください。" };
    }
  }

  await saveSubscription(userEmail, {
    id,
    name,
    price: Math.round(price),
    category,
    renewalDate,
    billingCycle,
    status,
    color,
    websiteUrl,
    notes: notes.slice(0, 300),
  });
  revalidatePath("/");
  return { ok: true, message: id ? "更新しました。" : "追加しました。" };
}

export async function deleteSubscriptionAction(id: number) {
  const userEmail = await authenticatedEmail();
  if (!Number.isInteger(id) || id <= 0) return;
  await deleteSubscription(userEmail, id);
  revalidatePath("/");
}

export async function deleteAccountDataAction() {
  const userEmail = await authenticatedEmail();
  await deleteUserData(userEmail);
  redirect(chatGPTSignOutPath("/"));
}
