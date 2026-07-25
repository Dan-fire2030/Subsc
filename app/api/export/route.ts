import { getChatGPTUser } from "../../chatgpt-auth";
import { listSubscriptions } from "../../../db/subscriptions";

export const dynamic = "force-dynamic";

function csvCell(value: string | number) {
  const text = String(value).replaceAll('"', '""');
  return `"${text}"`;
}

export async function GET() {
  const user = await getChatGPTUser();
  if (!user) return new Response("Unauthorized", { status: 401 });

  const subscriptions = await listSubscriptions(user.email);
  const header = [
    "サービス名",
    "料金",
    "支払いサイクル",
    "カテゴリ",
    "次の更新日",
    "利用状況",
    "公式サイト",
    "メモ",
  ];
  const rows = subscriptions.map((item) => [
    item.name,
    item.price,
    item.billingCycle === "yearly" ? "年払い" : "月払い",
    item.category,
    item.renewalDate,
    item.status === "active" ? "利用中" : "停止中",
    item.websiteUrl,
    item.notes,
  ]);
  const csv = `\uFEFF${[header, ...rows]
    .map((row) => row.map(csvCell).join(","))
    .join("\r\n")}`;

  return new Response(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="subsc-export.csv"',
      "Cache-Control": "private, no-store",
    },
  });
}
