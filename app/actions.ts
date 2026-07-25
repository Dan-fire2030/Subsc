"use server";

import { redirect } from "next/navigation";
import { deleteUserData } from "../db/subscriptions";
import { chatGPTSignOutPath, getChatGPTUser } from "./chatgpt-auth";

async function authenticatedEmail() {
  const user = await getChatGPTUser();
  if (!user) throw new Error("認証が必要です。もう一度ログインしてください。");
  return user.email;
}

export async function deleteAccountDataAction() {
  const userEmail = await authenticatedEmail();
  await deleteUserData(userEmail);
  redirect(chatGPTSignOutPath("/"));
}
