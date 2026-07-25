export type ContractEndMode = "none" | "date" | "payments";
export type ContractTerm =
  | "none"
  | "1_month"
  | "1_year"
  | "2_years"
  | "custom";
export type RenewalMode = "automatic" | "manual" | "none";
export type IntervalUnit = "days" | "months" | "years";
export type CancellationDeadlineMode = "none" | "date" | "days_before";
export type EndReason =
  | "none"
  | "canceled"
  | "trial_ended"
  | "service_ended"
  | "switched"
  | "other";
export type EndBehavior = "keep" | "archive" | "hide";
export type NotificationEvent =
  | "billing_start"
  | "trial_end"
  | "cancellation_deadline"
  | "renewal"
  | "contract_end"
  | "minimum_term_end"
  | "manual_renewal"
  | "final_payment";
export type StatusHistoryEvent = "paused" | "resumed";
export type StatusHistoryEntry = {
  id: string;
  event: StatusHistoryEvent;
  date: string;
};

export type ContractSettings = {
  enabled: boolean;
  startDate: string;
  billingStartDate: string;
  endMode: ContractEndMode;
  endDate: string;
  totalPayments: number;
  completedPayments: number;
  freeTrialEndDate: string;
  contractTerm: ContractTerm;
  contractTermEndDate: string;
  renewalMode: RenewalMode;
  renewalIntervalValue: number;
  renewalIntervalUnit: IntervalUnit;
  minimumTermEndDate: string;
  cancellationRequestedDate: string;
  cancellationDeadlineMode: CancellationDeadlineMode;
  cancellationDeadlineDate: string;
  cancellationDeadlineDaysBefore: number;
  endReason: EndReason;
  endReasonNote: string;
  endBehavior: EndBehavior;
  statusHistory: StatusHistoryEntry[];
  notifications: {
    enabled: boolean;
    leadDays: number[];
    leadHours: number[];
    time: string;
    events: Record<NotificationEvent, boolean>;
  };
};

export const notificationEventLabels: Record<NotificationEvent, string> = {
  billing_start: "課金開始",
  trial_end: "無料体験終了",
  cancellation_deadline: "解約期限",
  renewal: "自動更新",
  contract_end: "契約終了",
  minimum_term_end: "最低利用期間終了",
  manual_renewal: "手動更新",
  final_payment: "最終支払い",
};

export const defaultContractSettings: ContractSettings = {
  enabled: false,
  startDate: "",
  billingStartDate: "",
  endMode: "none",
  endDate: "",
  totalPayments: 0,
  completedPayments: 0,
  freeTrialEndDate: "",
  contractTerm: "none",
  contractTermEndDate: "",
  renewalMode: "automatic",
  renewalIntervalValue: 1,
  renewalIntervalUnit: "months",
  minimumTermEndDate: "",
  cancellationRequestedDate: "",
  cancellationDeadlineMode: "none",
  cancellationDeadlineDate: "",
  cancellationDeadlineDaysBefore: 0,
  endReason: "none",
  endReasonNote: "",
  endBehavior: "keep",
  statusHistory: [],
  notifications: {
    enabled: true,
    leadDays: [1, 3, 7],
    leadHours: [],
    time: "09:00",
    events: {
      billing_start: true,
      trial_end: true,
      cancellation_deadline: true,
      renewal: true,
      contract_end: true,
      minimum_term_end: true,
      manual_renewal: true,
      final_payment: true,
    },
  },
};

const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function dateValue(value: unknown) {
  const text = String(value ?? "");
  return datePattern.test(text) ? text : "";
}

function enumValue<T extends string>(
  value: unknown,
  values: readonly T[],
  fallback: T,
) {
  return values.includes(value as T) ? (value as T) : fallback;
}

function integerValue(value: unknown, fallback: number, max = 9999) {
  const number = Number(value);
  return Number.isFinite(number)
    ? Math.min(max, Math.max(0, Math.round(number)))
    : fallback;
}

export function normalizeContractSettings(
  value: unknown,
): ContractSettings {
  const item =
    value && typeof value === "object"
      ? (value as Record<string, unknown>)
      : {};
  const rawNotifications =
    item.notifications && typeof item.notifications === "object"
      ? (item.notifications as Record<string, unknown>)
      : {};
  const rawEvents =
    rawNotifications.events && typeof rawNotifications.events === "object"
      ? (rawNotifications.events as Record<string, unknown>)
      : {};
  const leadDays = Array.isArray(rawNotifications.leadDays)
    ? [
        ...new Set(
          rawNotifications.leadDays
            .map((day) => integerValue(day, -1, 365))
            .filter((day) => day >= 0),
        ),
      ].sort((a, b) => a - b)
    : defaultContractSettings.notifications.leadDays;
  const leadHours = Array.isArray(rawNotifications.leadHours)
    ? [
        ...new Set(
          rawNotifications.leadHours
            .map((hour) => integerValue(hour, -1, 168))
            .filter((hour) => hour >= 0),
        ),
      ].sort((a, b) => a - b)
    : [];
  const notificationTime = /^\d{2}:\d{2}$/.test(
    String(rawNotifications.time ?? ""),
  )
    ? String(rawNotifications.time)
    : "09:00";
  const statusHistory = Array.isArray(item.statusHistory)
    ? item.statusHistory
        .slice(0, 200)
        .map((entry, index) => {
          const row =
            entry && typeof entry === "object"
              ? (entry as Record<string, unknown>)
              : {};
          const event = enumValue(
            row.event,
            ["paused", "resumed"] as const,
            "paused",
          );
          const date = dateValue(row.date);
          return {
            id:
              String(row.id ?? "").trim().slice(0, 100) ||
              `history-${index}-${event}-${date}`,
            event,
            date,
          };
        })
        .filter((entry) => entry.date)
        .toSorted((a, b) => a.date.localeCompare(b.date))
    : [];

  const events = Object.fromEntries(
    Object.keys(notificationEventLabels).map((event) => [
      event,
      typeof rawEvents[event] === "boolean" ? rawEvents[event] : true,
    ]),
  ) as Record<NotificationEvent, boolean>;

  return {
    enabled: item.enabled === true,
    startDate: dateValue(item.startDate),
    billingStartDate: dateValue(item.billingStartDate),
    endMode: enumValue(
      item.endMode,
      ["none", "date", "payments"] as const,
      "none",
    ),
    endDate: dateValue(item.endDate),
    totalPayments: integerValue(item.totalPayments, 0),
    completedPayments: integerValue(item.completedPayments, 0),
    freeTrialEndDate: dateValue(item.freeTrialEndDate),
    contractTerm: enumValue(
      item.contractTerm,
      ["none", "1_month", "1_year", "2_years", "custom"] as const,
      "none",
    ),
    contractTermEndDate: dateValue(item.contractTermEndDate),
    renewalMode: enumValue(
      item.renewalMode,
      ["automatic", "manual", "none"] as const,
      "automatic",
    ),
    renewalIntervalValue: Math.max(
      1,
      integerValue(item.renewalIntervalValue, 1),
    ),
    renewalIntervalUnit: enumValue(
      item.renewalIntervalUnit,
      ["days", "months", "years"] as const,
      "months",
    ),
    minimumTermEndDate: dateValue(item.minimumTermEndDate),
    cancellationRequestedDate: dateValue(item.cancellationRequestedDate),
    cancellationDeadlineMode: enumValue(
      item.cancellationDeadlineMode,
      ["none", "date", "days_before"] as const,
      "none",
    ),
    cancellationDeadlineDate: dateValue(item.cancellationDeadlineDate),
    cancellationDeadlineDaysBefore: integerValue(
      item.cancellationDeadlineDaysBefore,
      0,
      365,
    ),
    endReason: enumValue(
      item.endReason,
      [
        "none",
        "canceled",
        "trial_ended",
        "service_ended",
        "switched",
        "other",
      ] as const,
      "none",
    ),
    endReasonNote: String(item.endReasonNote ?? "").trim().slice(0, 100),
    endBehavior: enumValue(
      item.endBehavior,
      ["keep", "archive", "hide"] as const,
      "keep",
    ),
    statusHistory,
    notifications: {
      enabled:
        typeof rawNotifications.enabled === "boolean"
          ? rawNotifications.enabled
          : true,
      leadDays,
      leadHours,
      time: notificationTime,
      events,
    },
  };
}

export function parseContractSettings(value: unknown) {
  if (typeof value !== "string") return normalizeContractSettings(value);
  try {
    return normalizeContractSettings(JSON.parse(value));
  } catch {
    return normalizeContractSettings(null);
  }
}

export function serializeContractSettings(value: unknown) {
  return JSON.stringify(normalizeContractSettings(value));
}
