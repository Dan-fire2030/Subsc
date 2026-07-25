"use client";

import {
  CalendarDays,
  Check,
  ChevronRight,
  CirclePlus,
  CreditCard,
  Download,
  ExternalLink,
  LogOut,
  Search,
  ShieldCheck,
  SlidersHorizontal,
  Trash2,
  UserRound,
  X,
} from "lucide-react";
import {
  useActionState,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import Image from "next/image";
import Link from "next/link";
import {
  deleteAccountDataAction,
  deleteSubscriptionAction,
  saveSubscriptionAction,
  type SaveState,
} from "./actions";
import type { Subscription } from "../db/subscriptions";

type Filter = "all" | "active" | "paused";
type Sort = "renewal" | "price-high" | "name";

const initialSaveState: SaveState = { ok: false, message: "" };

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

function monthlyEquivalent(item: Subscription) {
  return item.billingCycle === "yearly" ? item.price / 12 : item.price;
}

function renewalLabel(value: string) {
  const days = daysUntil(value);
  if (days < 0) return "更新日を確認";
  if (days === 0) return "今日";
  return `あと ${days}日`;
}

function SubscriptionForm({
  item,
  onClose,
}: {
  item: Subscription | null;
  onClose: () => void;
}) {
  const [state, formAction, pending] = useActionState(
    saveSubscriptionAction,
    initialSaveState,
  );
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (state.ok) onClose();
  }, [state.ok, onClose]);

  async function handleDelete() {
    if (!item || !window.confirm(`${item.name}を削除しますか？`)) return;
    setDeleting(true);
    await deleteSubscriptionAction(item.id);
    onClose();
  }

  return (
    <form action={formAction} className="add-form">
      {item ? <input type="hidden" name="id" value={item.id} /> : null}
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
      <div className="field-row">
        <label>
          料金
          <span className="input-prefix">¥</span>
          <input
            name="price"
            required
            min="0"
            step="1"
            type="number"
            inputMode="numeric"
            defaultValue={item?.price ?? ""}
            placeholder="1,490"
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
          <select name="status" defaultValue={item?.status ?? "active"}>
            <option value="active">利用中</option>
            <option value="paused">停止中</option>
          </select>
        </label>
      </div>
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
      {state.message && !state.ok ? (
        <p className="form-error" role="alert">{state.message}</p>
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
  user,
  signOutHref,
}: {
  subscriptions: Subscription[];
  user: { displayName: string; email: string };
  signOutHref: string;
}) {
  const [query, setQuery] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [filter, setFilter] = useState<Filter>("all");
  const [sort, setSort] = useState<Sort>("renewal");
  const [editor, setEditor] = useState<Subscription | "new" | null>(null);
  const [accountOpen, setAccountOpen] = useState(false);

  const active = useMemo(
    () => subscriptions.filter((item) => item.status === "active"),
    [subscriptions],
  );
  const monthlyTotal = useMemo(
    () => active.reduce((sum, item) => sum + monthlyEquivalent(item), 0),
    [active],
  );
  const yearlyTotal = monthlyTotal * 12;
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
    const filtered = subscriptions.filter((item) => {
      const matchesFilter = filter === "all" || item.status === filter;
      const matchesQuery =
        !normalized ||
        `${item.name} ${item.category} ${item.notes}`
          .toLocaleLowerCase("ja")
          .includes(normalized);
      return matchesFilter && matchesQuery;
    });
    return filtered.toSorted((a, b) => {
      if (sort === "price-high") {
        return monthlyEquivalent(b) - monthlyEquivalent(a);
      }
      if (sort === "name") return a.name.localeCompare(b.name, "ja");
      return (
        new Date(a.renewalDate).getTime() -
        new Date(b.renewalDate).getTime()
      );
    });
  }, [subscriptions, query, filter, sort]);

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

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/" aria-label="Subsc ホーム">
          <Image className="brand-icon" src="/favicon-32.png" width={32} height={32} alt="" priority />
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

      {searchOpen ? (
        <div className="search-box">
          <Search size={18} />
          <input
            autoFocus
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="サービス名・カテゴリ・メモで検索"
            aria-label="サブスクを検索"
          />
        </div>
      ) : null}

      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">今月のサブスク</p>
          <p className="total">{yen(monthlyTotal)}</p>
          <p className="yearly-total">年間換算 {yen(yearlyTotal)}</p>
        </div>
        <div className="orb" aria-label={`利用中 ${active.length}件`}>
          <span>{active.length}</span>
          <small>利用中</small>
        </div>
      </section>

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

        <div className="filter-tabs" aria-label="表示するサブスク">
          {([
            ["all", "すべて", subscriptions.length],
            ["active", "利用中", active.length],
            ["paused", "停止中", subscriptions.length - active.length],
          ] as const).map(([value, label, count]) => (
            <button
              key={value}
              className={filter === value ? "is-active" : ""}
              aria-pressed={filter === value}
              onClick={() => setFilter(value)}
            >
              {label}<span>{count}</span>
            </button>
          ))}
        </div>

        <div className="list">
          {visible.map((item) => (
            <button
              type="button"
              className={`service-card ${item.status === "paused" ? "is-paused" : ""}`}
              key={item.id}
              onClick={() => setEditor(item)}
              aria-label={`${item.name}を編集`}
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
                </span>
                <span>{item.category} · {dateLabel(item.renewalDate)} 更新</span>
              </span>
              <span className="price">
                <strong>{yen(monthlyEquivalent(item))}</strong>
                <span>{item.billingCycle === "yearly" ? "/月換算" : "/月"}</span>
              </span>
              <ChevronRight className="card-chevron" size={18} />
            </button>
          ))}
          {visible.length === 0 ? (
            <div className="empty-state">
              <CreditCard size={28} />
              <h2>{subscriptions.length === 0 ? "サブスクはまだありません" : "見つかりませんでした"}</h2>
              <p>{subscriptions.length === 0 ? "下のボタンから、最初のサービスを追加しましょう。" : "検索条件や絞り込みを変更してください。"}</p>
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

      <button className="add-trigger" onClick={() => setEditor("new")}>
        <CirclePlus size={22} />
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
              key={editor === "new" ? "new" : editor.id}
              item={editor === "new" ? null : editor}
              onClose={closeEditor}
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
              <a href={signOutHref}>
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
                  }
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
