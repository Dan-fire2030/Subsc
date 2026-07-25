import type { Subscription } from "../db/subscriptions";
import {
  notificationEventLabels,
  type ContractSettings,
  type NotificationEvent,
} from "../db/contract-settings";

export type ContractAlert = {
  id: string;
  clientId: string;
  serviceName: string;
  event: NotificationEvent;
  title: string;
  date: string;
  time: string;
  days: number;
  hours: number;
};

function dateAtMidnight(value: string) {
  return new Date(`${value}T00:00:00`);
}

function isoDate(value: Date) {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, "0");
  const day = String(value.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function addToDate(value: string, amount: number, unit: "days" | "months" | "years") {
  if (!value) return "";
  const date = dateAtMidnight(value);
  if (unit === "days") date.setDate(date.getDate() + amount);
  if (unit === "months") date.setMonth(date.getMonth() + amount);
  if (unit === "years") date.setFullYear(date.getFullYear() + amount);
  return isoDate(date);
}

function subtractDays(value: string, amount: number) {
  return addToDate(value, -amount, "days");
}

function daysFromToday(value: string, now = new Date()) {
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  return Math.ceil((dateAtMidnight(value).getTime() - today.getTime()) / 86400000);
}

function hoursFromNow(value: string, time: string, now = new Date()) {
  const target = new Date(`${value}T${time || "09:00"}:00`);
  return Math.ceil((target.getTime() - now.getTime()) / 3600000);
}

export function resolvedContractEndDate(settings: ContractSettings) {
  if (!settings.enabled) return "";
  if (settings.endMode === "date") return settings.endDate;
  if (settings.contractTerm === "custom") return settings.contractTermEndDate;
  if (!settings.startDate) return "";
  if (settings.contractTerm === "1_month") {
    return addToDate(settings.startDate, 1, "months");
  }
  if (settings.contractTerm === "1_year") {
    return addToDate(settings.startDate, 1, "years");
  }
  if (settings.contractTerm === "2_years") {
    return addToDate(settings.startDate, 2, "years");
  }
  return "";
}

export function isSubscriptionEnded(item: Subscription) {
  const settings = item.contractSettings;
  if (!settings.enabled) return false;
  if (
    settings.endMode === "payments" &&
    settings.totalPayments > 0 &&
    settings.completedPayments >= settings.totalPayments
  ) {
    return true;
  }
  const endDate = resolvedContractEndDate(settings);
  return Boolean(endDate && daysFromToday(endDate) < 0);
}

function eventDates(item: Subscription) {
  const settings = item.contractSettings;
  const values: Partial<Record<NotificationEvent, string>> = {
    billing_start: settings.billingStartDate,
    trial_end: settings.freeTrialEndDate,
    contract_end: resolvedContractEndDate(settings),
    minimum_term_end: settings.minimumTermEndDate,
  };
  if (settings.cancellationDeadlineMode === "date") {
    values.cancellation_deadline = settings.cancellationDeadlineDate;
  }
  if (settings.cancellationDeadlineMode === "days_before") {
    values.cancellation_deadline = subtractDays(
      item.renewalDate,
      settings.cancellationDeadlineDaysBefore,
    );
  }
  if (settings.renewalMode === "automatic") values.renewal = item.renewalDate;
  if (settings.renewalMode === "manual") {
    values.manual_renewal = item.renewalDate;
  }
  if (
    settings.endMode === "payments" &&
    settings.totalPayments > 0 &&
    settings.completedPayments >= settings.totalPayments - 1
  ) {
    values.final_payment = item.renewalDate;
  }
  return values;
}

export function buildContractAlerts(items: Subscription[], now = new Date()) {
  const alerts: ContractAlert[] = [];
  for (const item of items) {
    const settings = item.contractSettings;
    if (
      item.status !== "active" ||
      !settings.enabled ||
      !settings.notifications.enabled
    ) {
      continue;
    }
    const notificationTime = settings.notifications.time || "09:00";
    const maximumHourLead = Math.max(
      -1,
      ...settings.notifications.leadHours,
    );
    for (const [event, date] of Object.entries(eventDates(item)) as [
      NotificationEvent,
      string,
    ][]) {
      if (!date || !settings.notifications.events[event]) continue;
      const days = daysFromToday(date, now);
      const hours = hoursFromNow(date, notificationTime, now);
      const matchesDayLead = settings.notifications.leadDays.some(
        (lead) => days >= 0 && days <= lead,
      );
      const matchesHourLead =
        hours >= 0 && maximumHourLead >= 0 && hours <= maximumHourLead;
      if (!matchesDayLead && !matchesHourLead) continue;
      alerts.push({
        id: `${item.clientId}-${event}-${date}`,
        clientId: item.clientId,
        serviceName: item.name,
        event,
        title: notificationEventLabels[event],
        date,
        time: notificationTime,
        days,
        hours,
      });
    }
  }
  return alerts.toSorted(
    (a, b) =>
      a.hours - b.hours || a.serviceName.localeCompare(b.serviceName, "ja"),
  );
}
