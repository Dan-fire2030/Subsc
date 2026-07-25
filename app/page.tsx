import {
  ArrowDownRight,
  CalendarDays,
  Check,
  ChevronRight,
  CirclePlus,
  CreditCard,
  Search,
  Sparkles,
  Trash2,
  X,
} from "lucide-react";
import { revalidatePath } from "next/cache";
import type { Metadata } from "next";
import { addSubscription, deleteSubscription, listSubscriptions } from "../db/subscriptions";

export const metadata: Metadata = {
  title: "Subsc — サブスクを、すっきり管理",
  description: "毎月の固定費と次の更新日がひと目でわかる、スマホファーストのサブスク管理アプリ。",
};

function yen(value: number) {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(value);
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
  return Math.max(0, Math.ceil((new Date(`${value}T00:00:00`).getTime() - today.getTime()) / 86400000));
}

async function createSubscription(formData: FormData) {
  "use server";
  const name = String(formData.get("name") ?? "").trim();
  const price = Number(formData.get("price"));
  const category = String(formData.get("category") ?? "その他");
  const renewalDate = String(formData.get("renewalDate") ?? "");
  const color = String(formData.get("color") ?? "#c8ff3d");
  if (!name || !Number.isFinite(price) || price < 0 || !renewalDate) return;
  await addSubscription({ name, price, category, renewalDate, color });
  revalidatePath("/");
}

async function removeSubscription(formData: FormData) {
  "use server";
  const id = Number(formData.get("id"));
  if (!Number.isFinite(id)) return;
  await deleteSubscription(id);
  revalidatePath("/");
}

export default async function Home() {
  const subscriptions = await listSubscriptions();
  const monthlyTotal = subscriptions.reduce((sum, item) => sum + item.price, 0);
  const sorted = [...subscriptions].sort(
    (a, b) => new Date(a.renewalDate).getTime() - new Date(b.renewalDate).getTime(),
  );
  const next = sorted[0];

  return (
    <main className="app-shell">
      <header className="topbar">
        <a className="brand" href="/" aria-label="Subsc ホーム">
          <span className="brand-mark"><Check size={18} strokeWidth={3} /></span>
          <span>subsc</span>
        </a>
        <button className="icon-button" aria-label="サブスクを検索">
          <Search size={20} />
        </button>
      </header>

      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">MONTHLY SPEND</p>
          <p className="total">{yen(monthlyTotal)}</p>
          <p className="change"><ArrowDownRight size={15} /> 先月より ¥1,200 少なめ</p>
        </div>
        <div className="orb" aria-hidden="true">
          <span>{subscriptions.length}</span>
          <small>services</small>
        </div>
      </section>

      <section className="next-card">
        <div className="next-icon"><CalendarDays size={22} /></div>
        <div>
          <p className="card-label">次の更新</p>
          <p className="next-name">{next?.name ?? "まだ登録がありません"}</p>
        </div>
        {next && (
          <div className="next-date">
            <strong>{dateLabel(next.renewalDate)}</strong>
            <span>あと {daysUntil(next.renewalDate)}日</span>
          </div>
        )}
      </section>

      <section className="subscriptions" aria-labelledby="subscriptions-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">YOUR SUBSCRIPTIONS</p>
            <h1 id="subscriptions-title">サブスク一覧</h1>
          </div>
          <button className="filter-button" type="button">更新日順 <ChevronRight size={16} /></button>
        </div>

        <div className="list">
          {sorted.map((item) => (
            <article className="service-card" key={item.id}>
              <div className="service-logo" style={{ "--service-color": item.color } as React.CSSProperties}>
                {item.name.slice(0, 1).toUpperCase()}
              </div>
              <div className="service-main">
                <h2>{item.name}</h2>
                <p>{item.category} · {dateLabel(item.renewalDate)} 更新</p>
              </div>
              <div className="price">
                <strong>{yen(item.price)}</strong>
                <span>/月</span>
              </div>
              <form action={removeSubscription}>
                <input type="hidden" name="id" value={item.id} />
                <button className="delete-button" aria-label={`${item.name}を削除`}>
                  <Trash2 size={17} />
                </button>
              </form>
            </article>
          ))}
          {sorted.length === 0 && (
            <div className="empty-state">
              <CreditCard size={28} />
              <h2>サブスクはまだありません</h2>
              <p>下のボタンから、最初のサービスを追加しましょう。</p>
            </div>
          )}
        </div>
      </section>

      <div className="insight">
        <Sparkles size={18} />
        <p><strong>ちいさなヒント</strong> 年払いへ切り替えると、年間で約 ¥4,800 お得になりそうです。</p>
      </div>

      <details className="add-sheet">
        <summary className="add-trigger">
          <CirclePlus size={22} />
          サブスクを追加
        </summary>
        <div className="sheet-backdrop" />
        <div className="sheet-panel">
          <div className="sheet-handle" />
          <div className="sheet-title">
            <div>
              <p className="eyebrow">NEW SUBSCRIPTION</p>
              <h2>サブスクを追加</h2>
            </div>
            <span className="sheet-close" aria-hidden="true"><X size={20} /></span>
          </div>
          <form action={createSubscription} className="add-form">
            <label>
              サービス名
              <input name="name" required placeholder="例：Netflix" autoComplete="off" />
            </label>
            <div className="field-row">
              <label>
                月額
                <span className="input-prefix">¥</span>
                <input name="price" required min="0" step="1" type="number" placeholder="1,490" />
              </label>
              <label>
                次の更新日
                <input name="renewalDate" required type="date" />
              </label>
            </div>
            <div className="field-row">
              <label>
                カテゴリ
                <select name="category" defaultValue="エンタメ">
                  <option>エンタメ</option>
                  <option>仕事・学習</option>
                  <option>音楽</option>
                  <option>生活</option>
                  <option>その他</option>
                </select>
              </label>
              <label>
                カラー
                <select name="color" defaultValue="#c8ff3d">
                  <option value="#c8ff3d">ライム</option>
                  <option value="#8be9fd">スカイ</option>
                  <option value="#ff8fb1">ピンク</option>
                  <option value="#c4a7e7">パープル</option>
                </select>
              </label>
            </div>
            <button className="save-button" type="submit">
              <Check size={20} /> 保存する
            </button>
          </form>
        </div>
      </details>
      <div className="bottom-space" />
    </main>
  );
}
