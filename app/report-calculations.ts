import type { Subscription } from "../db/subscriptions";
import { resolvedContractEndDate } from "./contract-alerts";

export type ReportRow = {
  clientId: string;
  name: string;
  color: string;
  amount: number;
  paymentCount: number;
};

export type PaymentReport = {
  total: number;
  elapsed: number;
  upcoming: number;
  paymentCount: number;
  rows: ReportRow[];
};

type ReportPeriod =
  | { type: "month"; year: number; month: number }
  | { type: "year"; year: number };

function localDate(year: number, month: number, day: number) {
  return new Date(year, month, day, 12, 0, 0, 0);
}

function parseDate(value: string) {
  const [year, month, day] = value.split("-").map(Number);
  return localDate(year, month - 1, day);
}

function localIso(value: Date) {
  return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, "0")}-${String(value.getDate()).padStart(2, "0")}`;
}

function daysInMonth(year: number, month: number) {
  return new Date(year, month + 1, 0).getDate();
}

function shiftedDate(
  anchor: Date,
  amount: number,
  unit: "days" | "months" | "years",
) {
  if (unit === "days") {
    const result = new Date(anchor);
    result.setDate(result.getDate() + amount);
    return result;
  }
  const monthOffset = unit === "years" ? amount * 12 : amount;
  const targetMonth = anchor.getMonth() + monthOffset;
  const targetYear = anchor.getFullYear() + Math.floor(targetMonth / 12);
  const normalizedMonth = ((targetMonth % 12) + 12) % 12;
  return localDate(
    targetYear,
    normalizedMonth,
    Math.min(anchor.getDate(), daysInMonth(targetYear, normalizedMonth)),
  );
}

function intervalFor(item: Subscription) {
  const settings = item.contractSettings;
  if (settings.enabled && settings.renewalMode !== "none") {
    if (
      item.billingCycle === "yearly" &&
      settings.renewalIntervalValue === 1 &&
      settings.renewalIntervalUnit === "months"
    ) {
      return { value: 1, unit: "years" as const };
    }
    return {
      value: Math.max(1, settings.renewalIntervalValue),
      unit: settings.renewalIntervalUnit,
    };
  }
  return item.billingCycle === "yearly"
    ? { value: 1, unit: "years" as const }
    : { value: 1, unit: "months" as const };
}

function periodBounds(period: ReportPeriod) {
  if (period.type === "month") {
    return {
      start: localDate(period.year, period.month, 1),
      end: localDate(
        period.year,
        period.month,
        daysInMonth(period.year, period.month),
      ),
    };
  }
  return {
    start: localDate(period.year, 0, 1),
    end: localDate(period.year, 11, 31),
  };
}

function billingDates(item: Subscription, period: ReportPeriod) {
  const settings = item.contractSettings;
  const anchorValue =
    settings.billingStartDate || settings.startDate || item.renewalDate;
  if (!anchorValue) return [] as Date[];
  const anchor = parseDate(anchorValue);
  const { start, end } = periodBounds(period);
  const contractStart = settings.startDate
    ? parseDate(settings.startDate)
    : null;
  const contractEndValue = resolvedContractEndDate(settings);
  const contractEnd = contractEndValue ? parseDate(contractEndValue) : null;
  const isWithinContract = (date: Date) =>
    (!contractStart || date >= contractStart) &&
    (!contractEnd || date <= contractEnd);

  if (settings.enabled && settings.renewalMode === "none") {
    return anchor >= start && anchor <= end && isWithinContract(anchor)
      ? [anchor]
      : [];
  }

  const interval = intervalFor(item);
  const searchLimit =
    interval.unit === "days"
      ? 4000
      : interval.unit === "months"
        ? 600
        : 100;
  const dates: Date[] = [];
  let firstIndex = -searchLimit;
  let lastIndex = searchLimit;
  if (
    settings.enabled &&
    settings.endMode === "payments" &&
    settings.totalPayments > 0
  ) {
    if (settings.billingStartDate || settings.startDate) {
      firstIndex = 0;
      lastIndex = settings.totalPayments - 1;
    } else {
      firstIndex = -settings.completedPayments;
      lastIndex =
        settings.totalPayments - settings.completedPayments - 1;
    }
  }
  for (let index = firstIndex; index <= lastIndex; index += 1) {
    const date = shiftedDate(
      anchor,
      index * interval.value,
      interval.unit,
    );
    if (date < start || date > end || !isWithinContract(date)) continue;
    dates.push(date);
  }
  return dates.toSorted((a, b) => a.getTime() - b.getTime());
}

function isPausedOn(item: Subscription, date: Date) {
  let paused = false;
  let hasPastHistory = false;
  for (const entry of item.contractSettings.statusHistory) {
    const eventDate = parseDate(entry.date);
    if (eventDate > date) break;
    hasPastHistory = true;
    paused = entry.event === "paused";
  }
  const today = new Date();
  today.setHours(12, 0, 0, 0);
  if (hasPastHistory) return paused;
  return item.status === "paused" && date >= today;
}

function yenPrice(item: Subscription, usdJpyRate: number) {
  if (item.currency !== "USD") return item.price;
  const rate = usdJpyRate > 0 ? usdJpyRate : item.exchangeRate;
  return Math.round(item.originalAmount * rate);
}

export function buildPaymentReport(
  items: Subscription[],
  period: ReportPeriod,
  usdJpyRate: number,
): PaymentReport {
  const now = new Date();
  now.setHours(23, 59, 59, 999);
  let elapsed = 0;
  let upcoming = 0;
  let paymentCount = 0;
  const rows: ReportRow[] = [];

  for (const item of items) {
    const price = yenPrice(item, usdJpyRate);
    const dates = billingDates(item, period).filter(
      (date) => !isPausedOn(item, date),
    );
    if (dates.length === 0) continue;
    const amount = dates.length * price;
    const elapsedCount = dates.filter((date) => date <= now).length;
    elapsed += elapsedCount * price;
    upcoming += (dates.length - elapsedCount) * price;
    paymentCount += dates.length;
    rows.push({
      clientId: item.clientId,
      name: item.name,
      color: item.color,
      amount,
      paymentCount: dates.length,
    });
  }

  return {
    total: elapsed + upcoming,
    elapsed,
    upcoming,
    paymentCount,
    rows: rows.toSorted(
      (a, b) => b.amount - a.amount || a.name.localeCompare(b.name, "ja"),
    ),
  };
}

export function describeBillingDatesForTest(
  item: Subscription,
  period: ReportPeriod,
) {
  return billingDates(item, period).map(localIso);
}
