"use client";

import { ReceiptText } from "lucide-react";
import {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import type { Subscription } from "../db/subscriptions";
import {
  buildPaymentReport,
  type PaymentReport,
  type ReportRow,
} from "./report-calculations";

function yen(value: number) {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(Math.round(value));
}

function AnimatedYen({
  value,
  className,
}: {
  value: number;
  className?: string;
}) {
  const [displayValue, setDisplayValue] = useState(value);
  const displayedRef = useRef(value);

  useEffect(() => {
    const from = displayedRef.current;
    if (from === value) return;
    const reducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    if (reducedMotion) {
      const frame = requestAnimationFrame(() => {
        displayedRef.current = value;
        setDisplayValue(value);
      });
      return () => cancelAnimationFrame(frame);
    }
    const difference = Math.abs(value - from);
    const duration = Math.min(900, Math.max(450, 450 + Math.log10(difference + 1) * 90));
    const startedAt = performance.now();
    let frame = 0;
    const tick = (time: number) => {
      const progress = Math.min(1, (time - startedAt) / duration);
      const eased = 1 - Math.pow(1 - progress, 3);
      const next = Math.round(from + (value - from) * eased);
      displayedRef.current = next;
      setDisplayValue(next);
      if (progress < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [value]);

  return (
    <span className={className} aria-label={yen(value)}>
      {yen(displayValue)}
    </span>
  );
}

function ReportBars({ rows }: { rows: ReportRow[] }) {
  const visibleRows = rows.slice(0, 5);
  const maximum = Math.max(1, ...visibleRows.map((row) => row.amount));
  const rowNodes = useRef(new Map<string, HTMLDivElement>());
  const previousPositions = useRef(new Map<string, number>());

  useLayoutEffect(() => {
    const reducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    const currentPositions = new Map<string, number>();
    for (const row of visibleRows) {
      const node = rowNodes.current.get(row.clientId);
      if (!node) continue;
      const top = node.getBoundingClientRect().top;
      currentPositions.set(row.clientId, top);
      const previousTop = previousPositions.current.get(row.clientId);
      if (!reducedMotion && previousTop !== undefined && previousTop !== top) {
        node.animate(
          [
            { transform: `translateY(${previousTop - top}px)` },
            { transform: "translateY(0)" },
          ],
          { duration: 520, easing: "cubic-bezier(.2,.8,.2,1)" },
        );
      }
    }
    previousPositions.current = currentPositions;
  }, [visibleRows]);

  if (visibleRows.length === 0) {
    return <p className="report-empty">この期間の支払い予定はありません</p>;
  }

  return (
    <div className="report-bars" aria-label="サービス別の支払い金額">
      {visibleRows.map((row) => (
        <div
          className="report-bar-row"
          key={row.clientId}
          ref={(node) => {
            if (node) rowNodes.current.set(row.clientId, node);
            else rowNodes.current.delete(row.clientId);
          }}
        >
          <div className="report-bar-meta">
            <span>
              <i style={{ "--bar-color": row.color } as React.CSSProperties} />
              {row.name}
            </span>
            <strong>{yen(row.amount)}</strong>
          </div>
          <div className="report-bar-track">
            <span
              style={
                {
                  "--bar-scale": row.amount / maximum,
                  "--bar-color": row.color,
                } as React.CSSProperties
              }
            />
          </div>
        </div>
      ))}
      {rows.length > visibleRows.length ? (
        <p className="report-more">ほか {rows.length - visibleRows.length}件</p>
      ) : null}
    </div>
  );
}

function ReportPanel({
  report,
  label,
  detail,
  children,
}: {
  report: PaymentReport;
  label: string;
  detail: string;
  children?: React.ReactNode;
}) {
  return (
    <section className="report-panel">
      <div className="report-copy">
        <div className="report-label-row">
          <p className="eyebrow">{label}</p>
          {children}
        </div>
        <AnimatedYen value={report.total} className="total report-total" />
        <div className="report-breakdown">
          <span>経過分 {yen(report.elapsed)}</span>
          <span>今後 {yen(report.upcoming)}</span>
          <span>{detail}</span>
        </div>
      </div>
      <ReportBars rows={report.rows} />
    </section>
  );
}

export function ReportHero({
  items,
  usdJpyRate,
}: {
  items: Subscription[];
  usdJpyRate: number;
}) {
  const currentDate = new Date();
  const currentYear = currentDate.getFullYear();
  const currentMonth = currentDate.getMonth();
  const [view, setView] = useState<"month" | "year">("month");
  const [monthCursor, setMonthCursor] = useState({
    year: currentYear,
    month: currentMonth,
  });
  const [selectedYear, setSelectedYear] = useState(currentYear);
  const panelRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef({
    active: false,
    startX: 0,
    startedAt: 0,
    delta: 0,
  });

  const report = useMemo(
    () =>
      view === "month"
        ? buildPaymentReport(
            items,
            {
              type: "month",
              year: monthCursor.year,
              month: monthCursor.month,
            },
            usdJpyRate,
          )
        : buildPaymentReport(
            items,
            { type: "year", year: selectedYear },
            usdJpyRate,
          ),
    [items, monthCursor, selectedYear, usdJpyRate, view],
  );

  function shiftPeriod(direction: -1 | 1) {
    if (view === "month") {
      setMonthCursor((cursor) => {
        const next = new Date(cursor.year, cursor.month + direction, 1);
        return { year: next.getFullYear(), month: next.getMonth() };
      });
    } else {
      setSelectedYear((year) => year + direction);
    }
  }

  function animateIncoming(direction: -1 | 1) {
    requestAnimationFrame(() => {
      panelRef.current?.animate(
        [
          { transform: `translate3d(${direction * 34}px,0,0)`, opacity: 0.42 },
          { transform: "translate3d(0,0,0)", opacity: 1 },
        ],
        { duration: 420, easing: "cubic-bezier(.2,.8,.2,1)" },
      );
    });
  }

  function handlePointerDown(event: React.PointerEvent<HTMLDivElement>) {
    dragRef.current = {
      active: true,
      startX: event.clientX,
      startedAt: event.timeStamp,
      delta: 0,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
    if (panelRef.current) panelRef.current.style.transition = "none";
  }

  function handlePointerMove(event: React.PointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag.active) return;
    const rawDelta = event.clientX - drag.startX;
    drag.delta = rawDelta * 0.72;
    if (panelRef.current) {
      panelRef.current.style.transform = `translate3d(${drag.delta}px,0,0)`;
      panelRef.current.style.opacity = String(
        Math.max(0.5, 1 - Math.abs(drag.delta) / 360),
      );
    }
  }

  function handlePointerEnd(event: React.PointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag.active) return;
    drag.active = false;
    const duration = Math.max(1, event.timeStamp - drag.startedAt);
    const velocity = drag.delta / duration;
    const direction =
      drag.delta < -52 || velocity < -0.38
        ? 1
        : drag.delta > 52 || velocity > 0.38
          ? -1
          : 0;
    const panel = panelRef.current;
    if (panel) {
      panel.style.transition =
        "transform 320ms cubic-bezier(.2,.8,.2,1), opacity 240ms ease";
      panel.style.transform = "translate3d(0,0,0)";
      panel.style.opacity = "1";
    }
    if (direction) {
      shiftPeriod(direction);
      animateIncoming(direction);
    }
  }

  function handleKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    const direction = event.key === "ArrowRight" ? 1 : -1;
    shiftPeriod(direction);
    animateIncoming(direction);
  }

  return (
    <section className="hero report-hero" aria-label="支払いレポート">
      <div className="report-tabs" aria-label="レポート期間">
        {([
          ["month", "今月"],
          ["year", "年間"],
        ] as const).map(([value, label]) => (
          <button
            type="button"
            key={value}
            className={view === value ? "is-active" : ""}
            aria-pressed={view === value}
            onClick={() => setView(value)}
          >
            {label}
          </button>
        ))}
      </div>
      <div
        className="report-gesture-area"
        ref={panelRef}
        role="group"
        tabIndex={0}
        aria-label={`${view === "month" ? "月" : "年"}ごとのレポート。左右スワイプで前後へ移動`}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerEnd}
        onPointerCancel={handlePointerEnd}
        onKeyDown={handleKeyDown}
      >
        <ReportPanel
          report={report}
          label={
            view === "month"
              ? `${monthCursor.year}年${monthCursor.month + 1}月の支払い`
              : `${selectedYear}年の支払い`
          }
          detail={`${report.paymentCount}回`}
        />
      </div>
      <div className="report-swipe-hint">
        <ReceiptText size={13} />
        左右にスワイプして前後の{view === "month" ? "月" : "年"}へ
      </div>
    </section>
  );
}
