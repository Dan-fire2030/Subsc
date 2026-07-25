import type { Metadata } from "next";
import { SubscriptionManager } from "./SubscriptionManager";
import { chatGPTSignOutPath, requireChatGPTUser } from "./chatgpt-auth";
import { listSubscriptions, registerUser } from "../db/subscriptions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Subsc — サブスクを、すっきり管理",
  description: "毎月の固定費と次の更新日がひと目でわかる、スマホファーストのサブスク管理アプリ。",
};

export default async function Home() {
  const user = await requireChatGPTUser("/");
  await registerUser(user.email, user.displayName);
  const subscriptions = await listSubscriptions(user.email);
  return (
    <SubscriptionManager
      subscriptions={subscriptions}
      user={{ displayName: user.displayName, email: user.email }}
      signOutHref={chatGPTSignOutPath("/")}
    />
  );
}
