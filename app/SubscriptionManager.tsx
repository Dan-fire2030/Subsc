"use client";

import {
  ArrowRightLeft,
  BellRing,
  CalendarDays,
  Check,
  ChevronRight,
  CirclePlus,
  CloudOff,
  CreditCard,
  Download,
  ExternalLink,
  LogOut,
  Search,
  ShieldCheck,
  SlidersHorizontal,
  RefreshCw,
  Trash2,
  UserRound,
  X,
} from "lucide-react";
import {
  useCallback,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from "react";
import Image from "next/image";
import Link from "next/link";
import { deleteAccountDataAction } from "./actions";
import {
  clearOfflineData,
  enqueueOperation,
  listOperations,
  loadSnapshot,
  removeOperation,
  saveSnapshot,
  type SyncOperation,
} from "./offline-store";
import type {
  BillingCycle,
  Currency,
  Subscription,
  SubscriptionStatus,
} from "../db/subscriptions";
import type { UsdJpyRate } from "../db/exchange-rate";
import { normalizeContractSettings } from "../db/contract-settings";
import { ContractSettingsFields } from "./ContractSettingsFields";
import { ReportHero } from "./ReportHero";
import { SwipeDeleteRow } from "./SwipeDeleteRow";
import {
  buildContractAlerts,
  isSubscriptionEnded,
  resolvedContractEndDate,
} from "./contract-alerts";

type Filter = "all" | "active" | "paused" | "archived";
type Sort = "renewal" | "price-high" | "name";
const filterOrder: Filter[] = ["all", "active", "paused", "archived"];

type EditableSubscription = Omit<Subscription, "id" | "clientId">;
type SyncState = "online" | "offline" | "pending" | "syncing";

function yen(value: number) {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(Math.round(value));
}

function dateLabel(value: string) {
  return new Intl.DateTimeFormat("ja-JP", {
    month: "short",
    day: "numeric",
  }).format(new Date(`${value}T00:00:00`));
}

function daysUntil(value: string) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return Math.ceil(
    (new Date(`${value}T00:00:00`).getTime() - today.getTime()) / 86400000,
  );
}

function normalizedSubscription(item: Subscription): Subscription {
  const currency: Currency = item.currency === "USD" ? "USD" : "JPY";
  const originalAmount =
    Number.isFinite(item.originalAmount) && item.originalAmount >= 0
      ? item.originalAmount
      : item.price;
  return {
    ...item,
    currency,
    originalAmount,
    exchangeRate:
      Number.isFinite(item.exchangeRate) && item.exchangeRate > 0
        ? item.exchangeRate
        : 1,
    contractSettings: normalizeContractSettings(item.contractSettings),
  };
}

function currentPrice(item: Subscription, usdJpyRate: number) {
  if (item.currency !== "USD") return item.price;
  const rate = usdJpyRate > 0 ? usdJpyRate : item.exchangeRate;
  return Math.round(item.originalAmount * rate);
}

function monthlyEquivalent(item: Subscription, usdJpyRate: number) {
  const price = currentPrice(item, usdJpyRate);
  return item.billingCycle === "yearly" ? price / 12 : price;
}

function renewalLabel(value: string) {
  const days = daysUntil(value);
  if (days < 0) return "更新日を確認";
  if (days === 0) return "今日";
  return `あと ${days}日`;
}

function localToday() {
  const date = new Date();
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function SubscriptionForm({
  item,
  onClose,
  onSave,
  onDelete,
  exchangeRate,
}: {
  item: Subscription | null;
  onClose: () => void;
  onSave: (input: EditableSubscription) => Promise<void>;
  onDelete: (item: Subscription) => Promise<void>;
  exchangeRate: UsdJpyRate;
}) {
  const [pending, setPending] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState("");
  const [currency, setCurrency] = useState<Currency>(
    item?.currency === "USD" ? "USD" : "JPY",
  );
  const [amount, setAmount] = useState(
    String(item?.originalAmount ?? item?.price ?? ""),
  );
  const [contractSettings, setContractSettings] = useState(() =>
    normalizeContractSettings(item?.contractSettings),
  );
  const [status, setStatus] = useState<SubscriptionStatus>(
    item?.status ?? "active",
  );
  const pendingHistoryId = useId();

  function handleStatusChange(nextStatus: SubscriptionStatus) {
    const originalStatus = item?.status ?? "active";
    setStatus(nextStatus);
    setContractSettings((current) => {
      const withoutPending = current.statusHistory.filter(
        (entry) => entry.id !== pendingHistoryId,
      );
      if (nextStatus === originalStatus) {
        return { ...current, statusHistory: withoutPending };
      }
      return {
        ...current,
        statusHistory: [
          ...withoutPending,
          {
            id: pendingHistoryId,
            event: nextStatus === "paused" ? "paused" : "resumed",
            date: localToday(),
          },
        ],
      };
    });
  }

  async function handleDelete() {
    if (!item || !window.confirm(`${item.name}を削除しますか？`)) return;
    setDeleting(true);
    try {
      await onDelete(item);
      onClose();
    } finally {
      setDeleting(false);
    }
  }

  async function handleSubmit(formData: FormData) {
    setError("");
    const name = String(formData.get("name") ?? "").trim();
    const originalAmount = Number(formData.get("originalAmount"));
    const renewalDate = String(formData.get("renewalDate") ?? "");
    const billingCycle = String(
      formData.get("billingCycle") ?? "monthly",
    ) as BillingCycle;
    const websiteUrl = String(formData.get("websiteUrl") ?? "").trim();

    if (!name) return setError("サービス名を入力してください。");
    if (!Number.isFinite(originalAmount) || originalAmount < 0) {
      return setError("料金は0円以上で入力してください。");
    }
    if (currency === "USD" && !exchangeRate.available) {
      return setError("ドル円レートを取得できません。オンラインで再度お試しください。");
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(renewalDate)) {
      return setError("次の更新日を選択してください。");
    }
    if (
      contractSettings.enabled &&
      contractSettings.endMode === "date" &&
      !contractSettings.endDate
    ) {
      return setError("終了日を選択してください。");
    }
    if (
      contractSettings.enabled &&
      contractSettings.endMode === "payments" &&
      contractSettings.totalPayments < 1
    ) {
      return setError("合計支払い回数を1回以上で入力してください。");
    }
    if (
      contractSettings.enabled &&
      contractSettings.endMode === "payments" &&
      contractSettings.completedPayments > contractSettings.totalPayments
    ) {
      return setError("支払い済み回数は合計回数以下で入力してください。");
    }
    if (websiteUrl) {
      try {
        const url = new URL(websiteUrl);
        if (!["http:", "https:"].includes(url.protocol)) throw new Error();
      } catch {
        return setError("公式サイトは https:// から入力してください。");
      }
    }

    setPending(true);
    try {
      await onSave({
        name,
        currency,
        originalAmount,
        exchangeRate: currency === "USD" ? exchangeRate.rate : 1,
        price:
          currency === "USD"
            ? Math.round(originalAmount * exchangeRate.rate)
            : Math.round(originalAmount),
        renewalDate,
        billingCycle,
        status,
        category: String(formData.get("category") ?? "その他"),
        color: String(formData.get("color") ?? "#007AFF"),
        websiteUrl,
        notes: String(formData.get("notes") ?? "").trim().slice(0, 300),
        contractSettings: normalizeContractSettings(contractSettings),
      });
      onClose();
    } catch {
      setError("端末への保存に失敗しました。もう一度お試しください。");
    } finally {
      setPending(false);
    }
  }

  return (
    <form action={handleSubmit} className="add-form">
      <label>
        サービス名
        <input
          name="name"
          required
          defaultValue={item?.name ?? ""}
          placeholder="例：Netflix"
          autoComplete="off"
        />
      </label>
      <fieldset className="currency-field">
        <legend>通貨</legend>
        <div className="currency-toggle">
          {([
            ["JPY", "日本円", "¥"],
            ["USD", "米ドル", "$"],
          ] as const).map(([value, label, symbol]) => (
            <button
              key={value}
              type="button"
              className={currency === value ? "is-active" : ""}
              aria-pressed={currency === value}
              onClick={() => setCurrency(value)}
            >
              <span>{symbol}</span>
              {label}
            </button>
          ))}
        </div>
        <input type="hidden" name="currency" value={currency} />
      </fieldset>
      <div className="field-row">
        <label>
          料金（{currency === "USD" ? "ドル" : "円"}）
          <span className="input-prefix">{currency === "USD" ? "$" : "¥"}</span>
          <input
            name="originalAmount"
            required
            min="0"
            step={currency === "USD" ? "0.01" : "1"}
            type="number"
            inputMode="decimal"
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
            placeholder={currency === "USD" ? "19.99" : "1,490"}
          />
        </label>
        <label>
          支払い
          <select name="billingCycle" defaultValue={item?.billingCycle ?? "monthly"}>
            <option value="monthly">月払い</option>
            <option value="yearly">年払い</option>
          </select>
        </label>
      </div>
      {currency === "USD" ? (
        <div className="rate-preview" aria-live="polite">
          <ArrowRightLeft size={18} aria-hidden="true" />
          <div>
            <strong>
              {Number(amount) >= 0 && exchangeRate.available
                ? `$${Number(amount || 0).toFixed(2)} ≈ ${yen(Number(amount || 0) * exchangeRate.rate)}`
                : "ドル円レートを取得中"}
            </strong>
            <span>
              {exchangeRate.available
                ? `1 USD = ${yen(exchangeRate.rate)} · ${exchangeRate.date || "直近"}の参照レート`
                : "オンラインになると最新レートを取得します"}
            </span>
          </div>
        </div>
      ) : null}
      <div className="field-row">
        <label>
          次の更新日
          <input
            name="renewalDate"
            required
            type="date"
            defaultValue={item?.renewalDate ?? ""}
          />
        </label>
        <label>
          利用状況
          <select
            name="status"
            value={status}
            onChange={(event) =>
              handleStatusChange(event.target.value as SubscriptionStatus)
            }
          >
            <option value="active">利用中</option>
            <option value="paused">停止中</option>
          </select>
        </label>
      </div>
      {status !== (item?.status ?? "active") ? (
        <div className="status-change-date">
          <div>
            <strong>
              {status === "paused" ? "停止日を記録" : "再開日を記録"}
            </strong>
            <span>年間レポートの計算に使用します</span>
          </div>
          <input
            aria-label={status === "paused" ? "停止日" : "再開日"}
            type="date"
            value={
              contractSettings.statusHistory.find(
                (entry) => entry.id === pendingHistoryId,
              )?.date ?? localToday()
            }
            onChange={(event) =>
              setContractSettings((current) => ({
                ...current,
                statusHistory: current.statusHistory.map((entry) =>
                  entry.id === pendingHistoryId
                    ? { ...entry, date: event.target.value }
                    : entry,
                ),
              }))
            }
          />
        </div>
      ) : null}
      <ContractSettingsFields
        value={contractSettings}
        onChange={setContractSettings}
      />
      <div className="field-row">
        <label>
          カテゴリ
          <select name="category" defaultValue={item?.category ?? "エンタメ"}>
            <option>エンタメ</option>
            <option>仕事・学習</option>
            <option>音楽</option>
            <option>生活</option>
            <option>健康</option>
            <option>その他</option>
          </select>
        </label>
        <label>
          カラー
          <select name="color" defaultValue={item?.color ?? "#007AFF"}>
            <option value="#007AFF">ブルー</option>
            <option value="#34C759">グリーン</option>
            <option value="#FF375F">ピンク</option>
            <option value="#AF52DE">パープル</option>
            <option value="#FF9F0A">オレンジ</option>
          </select>
        </label>
      </div>
      <label>
        公式サイト（任意）
        <input
          name="websiteUrl"
          type="url"
          inputMode="url"
          defaultValue={item?.websiteUrl ?? ""}
          placeholder="https://example.com"
        />
      </label>
      <label>
        メモ（任意）
        <textarea
          name="notes"
          maxLength={300}
          defaultValue={item?.notes ?? ""}
          placeholder="解約方法、プラン名など"
        />
      </label>
      {error ? (
        <p className="form-error" role="alert">{error}</p>
      ) : null}
      <div className="form-actions">
        {item ? (
          <button
            className="danger-button"
            type="button"
            disabled={deleting || pending}
            onClick={handleDelete}
          >
            <Trash2 size={19} />
            削除
          </button>
        ) : null}
        <button className="save-button" type="submit" disabled={pending || deleting}>
          <Check size={20} />
          {pending ? "保存中…" : item ? "変更を保存" : "追加する"}
        </button>
      </div>
    </form>
  );
}

export function SubscriptionManager({
  subscriptions,
  exchangeRate,
  user,
  signOutHref,
}: {
  subscriptions: Subscription[];
  exchangeRate: UsdJpyRate;
  user: { displayName: string; email: string };
  signOutHref: string;
}) {
  const [items, setItems] = useState(() =>
    subscriptions.map(normalizedSubscription),
  );
  const [usdJpyRate, setUsdJpyRate] = useState(exchangeRate);
  const [query, setQuery] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [filter, setFilter] = useState<Filter>("all");
  const [sort, setSort] = useState<Sort>("renewal");
  const [editor, setEditor] = useState<Subscription | "new" | null>(null);
  const [accountOpen, setAccountOpen] = useState(false);
  const [syncState, setSyncState] = useState<SyncState>("online");
  const [revealedClientId, setRevealedClientId] = useState<string | null>(null);
  const [scrollTargetId, setScrollTargetId] = useState<string | null>(null);
  const [highlightedClientId, setHighlightedClientId] = useState<string | null>(
    null,
  );
  const [alertClock, setAlertClock] = useState(() => Date.now());
  const itemsRef = useRef(items);
  const syncInFlight = useRef<Promise<void> | null>(null);
  const highlightTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const filterGestureRef = useRef({
    active: false,
    startX: 0,
    startY: 0,
  });
  const filterDidSwipeRef = useRef(false);

  useEffect(() => {
    const refreshAlerts = () => setAlertClock(Date.now());
    const timer = window.setInterval(refreshAlerts, 60_000);
    document.addEventListener("visibilitychange", refreshAlerts);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", refreshAlerts);
    };
  }, []);

  const persistItems = useCallback(
    async (nextItems: Subscription[]) => {
      const normalized = nextItems.map(normalizedSubscription);
      itemsRef.current = normalized;
      setItems(normalized);
      await saveSnapshot(user.email, normalized);
    },
    [user.email],
  );

  const syncPending = useCallback(async () => {
    if (!navigator.onLine) {
      const pending = await listOperations(user.email);
      setSyncState(pending.length ? "pending" : "offline");
      return;
    }
    if (syncInFlight.current) return syncInFlight.current;

    const task = (async () => {
      setSyncState("syncing");
      try {
        const operations = await listOperations(user.email);
        for (const operation of operations) {
          const response = await fetch("/api/subscriptions", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(operation),
          });
          if (!response.ok) throw new Error("sync failed");
          await removeOperation(operation.opId);
        }

        const response = await fetch("/api/subscriptions", {
          cache: "no-store",
        });
        if (!response.ok) throw new Error("refresh failed");
        const data = (await response.json()) as {
          subscriptions: Subscription[];
          exchangeRate: UsdJpyRate;
        };
        await persistItems(data.subscriptions);
        setUsdJpyRate(data.exchangeRate);
        setSyncState("online");
      } catch {
        const remaining = await listOperations(user.email);
        setSyncState(remaining.length ? "pending" : "offline");
      }
    })();

    syncInFlight.current = task;
    try {
      await task;
    } finally {
      syncInFlight.current = null;
    }
  }, [persistItems, user.email]);

  useEffect(() => {
    let active = true;
    async function initializeOfflineState() {
      const [cached, pending] = await Promise.all([
        loadSnapshot(user.email),
        listOperations(user.email),
      ]);
      if (!active) return;
      if (cached && (!navigator.onLine || pending.length > 0)) {
        const normalized = cached.map(normalizedSubscription);
        itemsRef.current = normalized;
        setItems(normalized);
      } else {
        await saveSnapshot(
          user.email,
          subscriptions.map(normalizedSubscription),
        );
      }
      if (!navigator.onLine) {
        setSyncState(pending.length ? "pending" : "offline");
        return;
      }
      await syncPending();
    }

    const handleOnline = () => void syncPending();
    const handleOffline = () => {
      void listOperations(user.email).then((pending) => {
        setSyncState(pending.length ? "pending" : "offline");
      });
    };
    const handleVisibility = () => {
      if (document.visibilityState === "visible" && navigator.onLine) {
        void syncPending();
      }
    };

    void initializeOfflineState();
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    document.addEventListener("visibilitychange", handleVisibility);
    return () => {
      active = false;
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [subscriptions, syncPending, user.email]);

  const saveLocalSubscription = useCallback(
    async (
      existing: Subscription | null,
      input: EditableSubscription,
    ) => {
      const clientId =
        existing?.clientId ??
        (typeof crypto.randomUUID === "function"
          ? crypto.randomUUID()
          : `local-${Date.now()}-${Math.random().toString(36).slice(2)}`);
      const nextItem: Subscription = {
        ...input,
        id: existing?.id ?? -Date.now(),
        clientId,
      };
      const nextItems = existing
        ? itemsRef.current.map((item) =>
            item.clientId === existing.clientId ? nextItem : item,
          )
        : [...itemsRef.current, nextItem];
      await persistItems(nextItems);
      const operation: SyncOperation = {
        opId:
          typeof crypto.randomUUID === "function"
            ? crypto.randomUUID()
            : `op-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        userEmail: user.email,
        type: "upsert",
        subscription: nextItem,
        createdAt: Date.now(),
      };
      await enqueueOperation(operation);
      setSyncState(navigator.onLine ? "syncing" : "pending");
      if (navigator.onLine) void syncPending();
    },
    [persistItems, syncPending, user.email],
  );

  const deleteLocalSubscription = useCallback(
    async (item: Subscription) => {
      await persistItems(
        itemsRef.current.filter(
          (candidate) => candidate.clientId !== item.clientId,
        ),
      );
      const operation: SyncOperation = {
        opId:
          typeof crypto.randomUUID === "function"
            ? crypto.randomUUID()
            : `op-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        userEmail: user.email,
        type: "delete",
        id: item.id,
        clientId: item.clientId,
        createdAt: Date.now(),
      };
      await enqueueOperation(operation);
      setSyncState(navigator.onLine ? "syncing" : "pending");
      if (navigator.onLine) void syncPending();
    },
    [persistItems, syncPending, user.email],
  );

  const listedItems = useMemo(
    () =>
      items.filter(
        (item) =>
          !(
            isSubscriptionEnded(item) &&
            item.contractSettings.endBehavior === "hide"
          ),
      ),
    [items],
  );
  const archived = useMemo(
    () =>
      listedItems.filter(
        (item) =>
          isSubscriptionEnded(item) &&
          item.contractSettings.endBehavior === "archive",
      ),
    [listedItems],
  );
  const active = useMemo(
    () =>
      listedItems.filter(
        (item) => item.status === "active" && !isSubscriptionEnded(item),
      ),
    [listedItems],
  );
  const paused = useMemo(
    () =>
      listedItems.filter(
        (item) =>
          item.status === "paused" &&
          !(
            isSubscriptionEnded(item) &&
            item.contractSettings.endBehavior === "archive"
          ),
      ),
    [listedItems],
  );
  const alerts = useMemo(
    () => buildContractAlerts(items, new Date(alertClock)),
    [alertClock, items],
  );
  const next = useMemo(
    () =>
      active
        .filter((item) => daysUntil(item.renewalDate) >= 0)
        .toSorted(
          (a, b) =>
            new Date(a.renewalDate).getTime() -
            new Date(b.renewalDate).getTime(),
        )[0],
    [active],
  );

  const visible = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("ja");
    const filtered = listedItems.filter((item) => {
      const isArchived =
        isSubscriptionEnded(item) &&
        item.contractSettings.endBehavior === "archive";
      const matchesFilter =
        filter === "all" ||
        (filter === "archived" && isArchived) ||
        (filter === "active" &&
          item.status === "active" &&
          !isSubscriptionEnded(item)) ||
        (filter === "paused" && item.status === "paused" && !isArchived);
      const matchesQuery =
        !normalized ||
        `${item.name} ${item.category} ${item.notes}`
          .toLocaleLowerCase("ja")
          .includes(normalized);
      return matchesFilter && matchesQuery;
    });
    return filtered.toSorted((a, b) => {
      if (sort === "price-high") {
        return (
          monthlyEquivalent(b, usdJpyRate.rate) -
          monthlyEquivalent(a, usdJpyRate.rate)
        );
      }
      if (sort === "name") return a.name.localeCompare(b.name, "ja");
      return (
        new Date(a.renewalDate).getTime() -
        new Date(b.renewalDate).getTime()
      );
    });
  }, [listedItems, query, filter, sort, usdJpyRate.rate]);

  const searchCandidates = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("ja");
    if (!normalized) return [];
    return listedItems
      .filter((item) =>
        `${item.name} ${item.category} ${item.notes}`
          .toLocaleLowerCase("ja")
          .includes(normalized),
      )
      .slice(0, 6);
  }, [listedItems, query]);

  useEffect(() => {
    if (!scrollTargetId) return;
    const frame = requestAnimationFrame(() => {
      const target = document.getElementById(
        `subscription-${scrollTargetId}`,
      );
      target?.scrollIntoView({ behavior: "smooth", block: "center" });
      setHighlightedClientId(scrollTargetId);
      setScrollTargetId(null);
      if (highlightTimerRef.current) {
        clearTimeout(highlightTimerRef.current);
      }
      highlightTimerRef.current = setTimeout(
        () => setHighlightedClientId(null),
        1400,
      );
    });
    return () => cancelAnimationFrame(frame);
  }, [scrollTargetId, visible]);

  useEffect(
    () => () => {
      if (highlightTimerRef.current) clearTimeout(highlightTimerRef.current);
    },
    [],
  );

  function goToSubscription(clientId: string) {
    setFilter("all");
    setQuery("");
    setSearchOpen(false);
    setRevealedClientId(null);
    setScrollTargetId(clientId);
  }

  function handleFilterPointerDown(
    event: React.PointerEvent<HTMLDivElement>,
  ) {
    filterGestureRef.current = {
      active: true,
      startX: event.clientX,
      startY: event.clientY,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function handleFilterPointerUp(event: React.PointerEvent<HTMLDivElement>) {
    const gesture = filterGestureRef.current;
    if (!gesture.active) return;
    gesture.active = false;
    const deltaX = event.clientX - gesture.startX;
    const deltaY = event.clientY - gesture.startY;
    if (Math.abs(deltaX) < 38 || Math.abs(deltaX) < Math.abs(deltaY)) return;
    const currentIndex = filterOrder.indexOf(filter);
    const nextIndex = Math.max(
      0,
      Math.min(
        filterOrder.length - 1,
        currentIndex + (deltaX < 0 ? 1 : -1),
      ),
    );
    filterDidSwipeRef.current = true;
    setFilter(filterOrder[nextIndex]);
    requestAnimationFrame(() => {
      filterDidSwipeRef.current = false;
    });
  }

  const closeEditor = useCallback(() => setEditor(null), []);
  const closeAccount = useCallback(() => setAccountOpen(false), []);

  useEffect(() => {
    if (!editor && !accountOpen) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeEditor();
        closeAccount();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previous;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [editor, accountOpen, closeEditor, closeAccount]);

  const handleSignOut = useCallback(
    async (event: React.MouseEvent<HTMLAnchorElement>) => {
      event.preventDefault();
      await clearOfflineData(user.email);
      navigator.serviceWorker?.controller?.postMessage({
        type: "CLEAR_PRIVATE_CACHE",
      });
      window.location.assign(signOutHref);
    },
    [signOutHref, user.email],
  );

  const handleAddPress = useCallback(
    (event: React.PointerEvent<HTMLButtonElement>) => {
      const bounds = event.currentTarget.getBoundingClientRect();
      event.currentTarget.style.setProperty(
        "--tap-x",
        `${event.clientX - bounds.left}px`,
      );
      event.currentTarget.style.setProperty(
        "--tap-y",
        `${event.clientY - bounds.top}px`,
      );
      event.currentTarget.classList.add("is-pressing");
    },
    [],
  );

  const handleAddRelease = useCallback(
    (event: React.PointerEvent<HTMLButtonElement>) => {
      event.currentTarget.classList.remove("is-pressing");
    },
    [],
  );

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/" aria-label="Subsc ホーム">
          <Image className="brand-icon" src="/subsc-favicon-2026.png" width={32} height={32} alt="" priority />
          <span>Subsc</span>
        </Link>
        <div className="top-actions">
          <button
            className={`icon-button ${searchOpen ? "is-active" : ""}`}
            aria-label={searchOpen ? "検索を閉じる" : "サブスクを検索"}
            aria-expanded={searchOpen}
            onClick={() => setSearchOpen((open) => !open)}
          >
            {searchOpen ? <X size={20} /> : <Search size={20} />}
          </button>
          <button
            className="account-button"
            type="button"
            onClick={() => setAccountOpen(true)}
            aria-label="アカウント設定を開く"
          >
            {user.displayName.slice(0, 1).toUpperCase()}
          </button>
        </div>
      </header>

      {syncState !== "online" ? (
        <div className={`connection-pill is-${syncState}`} role="status" aria-live="polite">
          {syncState === "syncing" ? (
            <RefreshCw size={15} aria-hidden="true" />
          ) : (
            <CloudOff size={15} aria-hidden="true" />
          )}
          <span>
            {syncState === "syncing"
              ? "変更を同期中…"
              : syncState === "pending"
                ? "オフライン・変更は端末に保存済み"
                : "オフライン・保存済みの一覧を表示中"}
          </span>
        </div>
      ) : null}

      {searchOpen ? (
        <div className="search-area">
          <div className="search-box">
            <Search size={18} />
            <input
              autoFocus
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="サービス名・カテゴリ・メモで検索"
              aria-label="サブスクを検索"
              role="combobox"
              aria-autocomplete="list"
              aria-controls="search-suggestions"
              aria-expanded={query.trim().length > 0}
            />
          </div>
          {query.trim() ? (
            <div className="search-suggestions" id="search-suggestions" role="listbox">
              {searchCandidates.length > 0 ? (
                searchCandidates.map((item) => (
                  <button
                    type="button"
                    role="option"
                    aria-selected="false"
                    key={item.clientId}
                    onClick={() => goToSubscription(item.clientId)}
                  >
                    <span
                      className="suggestion-logo"
                      style={{ "--service-color": item.color } as React.CSSProperties}
                    >
                      {item.name.slice(0, 1).toUpperCase()}
                    </span>
                    <span>
                      <strong>{item.name}</strong>
                      <small>{item.category}</small>
                    </span>
                    <em>{yen(monthlyEquivalent(item, usdJpyRate.rate))}/月</em>
                  </button>
                ))
              ) : (
                <p className="search-empty">一致するサブスクはありません</p>
              )}
            </div>
          ) : null}
        </div>
      ) : null}

      <ReportHero items={items} usdJpyRate={usdJpyRate.rate} />

      <section className="next-card">
        <div className="next-icon"><CalendarDays size={22} /></div>
        <div>
          <p className="card-label">次の更新</p>
          <p className="next-name">{next?.name ?? "予定はありません"}</p>
        </div>
        {next ? (
          <div className="next-date">
            <strong>{dateLabel(next.renewalDate)}</strong>
            <span>{renewalLabel(next.renewalDate)}</span>
          </div>
        ) : null}
      </section>

      {alerts.length > 0 ? (
        <section className="alerts-card" aria-labelledby="alerts-title">
          <div className="alerts-heading">
            <span><BellRing size={19} /></span>
            <div>
              <p className="card-label">まもなく期限</p>
              <h2 id="alerts-title">{alerts.length}件のお知らせ</h2>
            </div>
          </div>
          <div className="alert-list">
            {alerts.slice(0, 4).map((alert) => (
              <button
                type="button"
                key={alert.id}
                onClick={() => {
                  const item = items.find(
                    (candidate) => candidate.clientId === alert.clientId,
                  );
                  if (item) setEditor(item);
                }}
              >
                <span>
                  <strong>{alert.serviceName}</strong>
                  <small>{alert.title} · {dateLabel(alert.date)} {alert.time}</small>
                </span>
                <em>
                  {alert.hours > 0 && alert.hours < 24
                    ? `あと${alert.hours}時間`
                    : alert.days === 0
                      ? "今日"
                      : `あと${alert.days}日`}
                </em>
              </button>
            ))}
          </div>
          {alerts.length > 4 ? (
            <p className="more-alerts">ほか {alerts.length - 4}件</p>
          ) : null}
        </section>
      ) : null}

      <section className="subscriptions" aria-labelledby="subscriptions-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">登録済みサービス</p>
            <h1 id="subscriptions-title">サブスク一覧</h1>
          </div>
          <label className="sort-control">
            <SlidersHorizontal size={15} />
            <span className="sr-only">並び順</span>
            <select value={sort} onChange={(event) => setSort(event.target.value as Sort)}>
              <option value="renewal">更新日順</option>
              <option value="price-high">月額が高い順</option>
              <option value="name">名前順</option>
            </select>
          </label>
        </div>

        <div
          className="filter-tabs"
          aria-label="表示するサブスク"
          onPointerDown={handleFilterPointerDown}
          onPointerUp={handleFilterPointerUp}
          onPointerCancel={handleFilterPointerUp}
        >
          {([
            ["all", "すべて", listedItems.length],
            ["active", "利用中", active.length],
            ["paused", "停止中", paused.length],
            ["archived", "履歴", archived.length],
          ] as const).map(([value, label, count]) => (
            <button
              key={value}
              className={filter === value ? "is-active" : ""}
              aria-pressed={filter === value}
              onClick={() => {
                if (!filterDidSwipeRef.current) setFilter(value);
              }}
            >
              {label}<span>{count}</span>
            </button>
          ))}
        </div>

        <div className="list">
          {visible.map((item) => (
            <SwipeDeleteRow
              id={item.clientId}
              label={item.name}
              className={`service-card ${item.status === "paused" ? "is-paused" : ""} ${isSubscriptionEnded(item) ? "is-ended" : ""}`}
              key={item.clientId}
              revealed={revealedClientId === item.clientId}
              highlighted={highlightedClientId === item.clientId}
              onReveal={setRevealedClientId}
              onOpen={() => setEditor(item)}
              onDelete={() => deleteLocalSubscription(item)}
            >
              <span
                className="service-logo"
                style={{ "--service-color": item.color } as React.CSSProperties}
              >
                {item.name.slice(0, 1).toUpperCase()}
              </span>
              <span className="service-main">
                <span className="service-name-row">
                  <strong>{item.name}</strong>
                  {item.status === "paused" ? <em>停止中</em> : null}
                  {isSubscriptionEnded(item) ? <em>終了</em> : null}
                </span>
                <span>
                  {item.category} · {dateLabel(item.renewalDate)} 更新
                  {item.currency === "USD"
                    ? ` · $${item.originalAmount.toFixed(2)}`
                    : ""}
                </span>
                {item.contractSettings.enabled &&
                (item.contractSettings.startDate ||
                  resolvedContractEndDate(item.contractSettings)) ? (
                  <span className="period-meta">
                    {item.contractSettings.startDate
                      ? `${dateLabel(item.contractSettings.startDate)}開始`
                      : ""}
                    {resolvedContractEndDate(item.contractSettings)
                      ? `${item.contractSettings.startDate ? " · " : ""}${dateLabel(resolvedContractEndDate(item.contractSettings))}終了`
                      : ""}
                  </span>
                ) : null}
              </span>
              <span className="price">
                <strong>{yen(monthlyEquivalent(item, usdJpyRate.rate))}</strong>
                <span>{item.billingCycle === "yearly" ? "/月換算" : "/月"}</span>
              </span>
              <ChevronRight className="card-chevron" size={18} />
            </SwipeDeleteRow>
          ))}
          {visible.length === 0 ? (
            <div className="empty-state">
              <CreditCard size={28} />
              <h2>{listedItems.length === 0 ? "サブスクはまだありません" : "見つかりませんでした"}</h2>
              <p>{listedItems.length === 0 ? "下のボタンから、最初のサービスを追加しましょう。" : "検索条件や絞り込みを変更してください。"}</p>
            </div>
          ) : null}
        </div>
      </section>

      {next?.websiteUrl ? (
        <a className="renewal-link" href={next.websiteUrl} target="_blank" rel="noreferrer">
          <ExternalLink size={17} />
          {next.name} の公式サイトを開く
        </a>
      ) : null}

      <button
        className="add-trigger"
        onClick={() => setEditor("new")}
        onPointerDown={handleAddPress}
        onPointerUp={handleAddRelease}
        onPointerCancel={handleAddRelease}
        onPointerLeave={handleAddRelease}
      >
        <span className="add-icon-motion"><CirclePlus size={22} /></span>
        サブスクを追加
      </button>

      {editor ? (
        <div className="modal-root">
          <button className="sheet-backdrop" aria-label="編集画面を閉じる" onClick={closeEditor} />
          <section
            className="sheet-panel"
            role="dialog"
            aria-modal="true"
            aria-labelledby="editor-title"
          >
            <div className="sheet-handle" />
            <div className="sheet-title">
              <div>
                <p className="eyebrow">{editor === "new" ? "新規登録" : "登録内容"}</p>
                <h2 id="editor-title">{editor === "new" ? "サブスクを追加" : "登録内容を編集"}</h2>
              </div>
              <button className="sheet-close" type="button" onClick={closeEditor} aria-label="閉じる">
                <X size={20} />
              </button>
            </div>
            <SubscriptionForm
              key={editor === "new" ? "new" : editor.clientId}
              item={editor === "new" ? null : editor}
              onClose={closeEditor}
              onSave={(input) =>
                saveLocalSubscription(editor === "new" ? null : editor, input)
              }
              onDelete={deleteLocalSubscription}
              exchangeRate={usdJpyRate}
            />
          </section>
        </div>
      ) : null}
      {accountOpen ? (
        <div className="modal-root">
          <button className="sheet-backdrop" aria-label="アカウント設定を閉じる" onClick={closeAccount} />
          <section
            className="sheet-panel account-panel"
            role="dialog"
            aria-modal="true"
            aria-labelledby="account-title"
          >
            <div className="sheet-handle" />
            <div className="sheet-title">
              <div>
                <p className="eyebrow">プロフィールとデータ</p>
                <h2 id="account-title">アカウント</h2>
              </div>
              <button className="sheet-close" type="button" onClick={closeAccount} aria-label="閉じる">
                <X size={20} />
              </button>
            </div>
            <div className="account-profile">
              <span className="account-avatar"><UserRound size={24} /></span>
              <div>
                <strong>{user.displayName}</strong>
                <span>{user.email}</span>
              </div>
            </div>
            <div className="privacy-note">
              <ShieldCheck size={19} />
              <p><strong>あなた専用のデータ</strong>登録内容はログイン中のアカウントに紐づき、ほかの利用者からは表示・編集できません。</p>
            </div>
            <div className="account-actions">
              <a href="/api/export" download>
                <Download size={19} />
                CSVでデータを書き出す
              </a>
              <a href={signOutHref} onClick={handleSignOut}>
                <LogOut size={19} />
                ログアウト
              </a>
            </div>
            <div className="danger-zone">
              <div>
                <strong>このアプリのデータを削除</strong>
                <p>登録したサブスクをすべて削除します。この操作は取り消せません。</p>
              </div>
              <form
                action={deleteAccountDataAction}
                onSubmit={(event) => {
                  if (!window.confirm("登録データをすべて削除しますか？この操作は取り消せません。")) {
                    event.preventDefault();
                    return;
                  }
                  void clearOfflineData(user.email);
                  navigator.serviceWorker?.controller?.postMessage({
                    type: "CLEAR_PRIVATE_CACHE",
                  });
                }}
              >
                <button type="submit">
                  <Trash2 size={18} />
                  全データを削除
                </button>
              </form>
            </div>
          </section>
        </div>
      ) : null}
      <div className="bottom-space" />
    </main>
  );
}
