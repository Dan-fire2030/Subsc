"use client";

import {
  ChevronLeft,
  ChevronRight,
  ReceiptText,
} from "lucide-react";
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
  const [selectedYear, setSelectedYear] = useState(currentYear);
  const trackRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef({
    active: false,
    startX: 0,
    startedAt: 0,
    delta: 0,
  });

  const monthReport = useMemo(
    () =>
      buildPaymentReport(
        items,
        { type: "month", year: currentYear, month: currentMonth },
        usdJpyRate,
      ),
    [items, currentYear, currentMonth, usdJpyRate],
  );
  const yearReport = useMemo(
    () =>
      buildPaymentReport(
        items,
        { type: "year", year: selectedYear },
        usdJpyRate,
      ),
    [items, selectedYear, usdJpyRate],
  );

  function moveTrack(nextView: "month" | "year", animate = true) {
    const track = trackRef.current;
    if (!track) return;
    track.style.transition = animate
      ? "transform 520ms cubic-bezier(.2,.8,.2,1)"
      : "none";
    track.style.transform =
      nextView === "month"
        ? "translate3d(0,0,0)"
        : "translate3d(-50%,0,0)";
  }

  function selectView(nextView: "month" | "year") {
    setView(nextView);
    moveTrack(nextView);
  }

  function handlePointerDown(event: React.PointerEvent<HTMLDivElement>) {
    if ((event.target as HTMLElement).closest("button")) return;
    dragRef.current = {
      active: true,
      startX: event.clientX,
      startedAt: event.timeStamp,
      delta: 0,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
    const track = trackRef.current;
    if (track) track.style.transition = "none";
  }

  function handlePointerMove(event: React.PointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag.active) return;
    const rawDelta = event.clientX - drag.startX;
    const atEdge =
      (view === "month" && rawDelta > 0) ||
      (view === "year" && rawDelta < 0);
    drag.delta = atEdge ? rawDelta * 0.28 : rawDelta;
    const base = view === "month" ? "0%" : "-50%";
    if (trackRef.current) {
      trackRef.current.style.transform = `translate3d(calc(${base} + ${drag.delta}px),0,0)`;
    }
  }

  function handlePointerEnd(event: React.PointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag.active) return;
    drag.active = false;
    const duration = Math.max(1, event.timeStamp - drag.startedAt);
    const velocity = drag.delta / duration;
    let nextView = view;
    if (drag.delta < -52 || velocity < -0.38) nextView = "year";
    if (drag.delta > 52 || velocity > 0.38) nextView = "month";
    selectView(nextView);
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
            onClick={() => selectView(value)}
          >
            {label}
          </button>
        ))}
      </div>
      <div
        className="report-viewport"
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerEnd}
        onPointerCancel={handlePointerEnd}
      >
        <div className="report-track" ref={trackRef}>
          <ReportPanel
            report={monthReport}
            label={`${currentMonth + 1}月の支払い`}
            detail={`${monthReport.paymentCount}回`}
          />
          <ReportPanel
            report={yearReport}
            label={`${selectedYear}年の支払い`}
            detail={`${yearReport.paymentCount}回`}
          >
            <div className="year-stepper" aria-label="表示する年">
              <button
                type="button"
                aria-label={`${selectedYear - 1}年を表示`}
                onClick={() => setSelectedYear((year) => year - 1)}
              >
                <ChevronLeft size={16} />
              </button>
              <span>{selectedYear}</span>
              <button
                type="button"
                aria-label={`${selectedYear + 1}年を表示`}
                onClick={() => setSelectedYear((year) => year + 1)}
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </ReportPanel>
        </div>
      </div>
      <div className="report-swipe-hint">
        <span className={view === "month" ? "is-active" : ""} />
        <span className={view === "year" ? "is-active" : ""} />
        <ReceiptText size={13} />
        左右にスワイプ
      </div>
    </section>
  );
}
