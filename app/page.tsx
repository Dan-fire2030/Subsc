import type { Metadata } from "next";
import { SubscriptionManager } from "./SubscriptionManager";
import { listSubscriptions } from "../db/subscriptions";

export const metadata: Metadata = {
  title: "Subsc — サブスクを、すっきり管理",
  description: "毎月の固定費と次の更新日がひと目でわかる、スマホファーストのサブスク管理アプリ。",
};

export default async function Home() {
  const subscriptions = await listSubscriptions();
  return <SubscriptionManager subscriptions={subscriptions} />;
}
