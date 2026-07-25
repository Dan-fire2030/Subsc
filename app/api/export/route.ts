import { getChatGPTUser } from "../../chatgpt-auth";
import { listSubscriptions } from "../../../db/subscriptions";
import { notificationEventLabels } from "../../../db/contract-settings";

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
    "表示金額（円）",
    "元の通貨",
    "元の金額",
    "換算レート",
    "支払いサイクル",
    "カテゴリ",
    "次の更新日",
    "利用状況",
    "契約期間設定",
    "利用開始日",
    "課金開始日",
    "終了設定",
    "終了日",
    "合計支払い回数",
    "支払い済み回数",
    "無料体験終了日",
    "契約期間",
    "契約期間の終了日",
    "更新方式",
    "更新間隔",
    "最低利用期間の終了日",
    "解約申請日",
    "解約期限",
    "終了理由",
    "終了理由のメモ",
    "終了後の状態",
    "アプリ内通知",
    "通知タイミング",
    "通知内容",
    "公式サイト",
    "メモ",
  ];
  const rows = subscriptions.map((item) => {
    const settings = item.contractSettings;
    const cancellationDeadline =
      settings.cancellationDeadlineMode === "date"
        ? settings.cancellationDeadlineDate
        : settings.cancellationDeadlineMode === "days_before"
          ? `更新日の${settings.cancellationDeadlineDaysBefore}日前`
          : "";
    const interval =
      settings.renewalMode === "none"
        ? ""
        : `${settings.renewalIntervalValue} ${settings.renewalIntervalUnit}`;
    const notificationEvents = Object.entries(settings.notifications.events)
      .filter(([, enabled]) => enabled)
      .map(([event]) =>
        notificationEventLabels[
          event as keyof typeof notificationEventLabels
        ],
      )
      .join("・");
    return [
      item.name,
      item.price,
      item.currency,
      item.originalAmount,
      item.exchangeRate,
      item.billingCycle === "yearly" ? "年払い" : "月払い",
      item.category,
      item.renewalDate,
      item.status === "active" ? "利用中" : "停止中",
      settings.enabled ? "有効" : "無効",
      settings.startDate,
      settings.billingStartDate,
      settings.endMode,
      settings.endDate,
      settings.totalPayments,
      settings.completedPayments,
      settings.freeTrialEndDate,
      settings.contractTerm,
      settings.contractTermEndDate,
      settings.renewalMode,
      interval,
      settings.minimumTermEndDate,
      settings.cancellationRequestedDate,
      cancellationDeadline,
      settings.endReason,
      settings.endReasonNote,
      settings.endBehavior,
      settings.notifications.enabled ? "有効" : "無効",
      settings.notifications.leadDays
        .map((day) => (day === 0 ? "当日" : `${day}日前`))
        .join("・"),
      notificationEvents,
      item.websiteUrl,
      item.notes,
    ];
  });
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
