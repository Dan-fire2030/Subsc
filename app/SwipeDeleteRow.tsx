"use client";

import { Trash2 } from "lucide-react";
import { useEffect, useRef } from "react";

export function SwipeDeleteRow({
  id,
  label,
  className,
  revealed,
  highlighted,
  onReveal,
  onOpen,
  onDelete,
  children,
}: {
  id: string;
  label: string;
  className: string;
  revealed: boolean;
  highlighted: boolean;
  onReveal: (id: string | null) => void;
  onOpen: () => void;
  onDelete: () => Promise<void>;
  children: React.ReactNode;
}) {
  const foregroundRef = useRef<HTMLButtonElement>(null);
  const gestureRef = useRef({
    active: false,
    startX: 0,
    startY: 0,
    deltaX: 0,
    dragged: false,
  });
  const skipClickRef = useRef(false);

  useEffect(() => {
    const foreground = foregroundRef.current;
    if (!foreground) return;
    foreground.style.transition =
      "transform 320ms cubic-bezier(.2,.8,.2,1)";
    foreground.style.transform = revealed
      ? "translate3d(-86px,0,0)"
      : "translate3d(0,0,0)";
  }, [revealed]);

  function handlePointerDown(event: React.PointerEvent<HTMLButtonElement>) {
    gestureRef.current = {
      active: true,
      startX: event.clientX,
      startY: event.clientY,
      deltaX: 0,
      dragged: false,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
    event.currentTarget.style.transition = "none";
  }

  function handlePointerMove(event: React.PointerEvent<HTMLButtonElement>) {
    const gesture = gestureRef.current;
    if (!gesture.active) return;
    const deltaX = event.clientX - gesture.startX;
    const deltaY = event.clientY - gesture.startY;
    if (!gesture.dragged && Math.abs(deltaX) < 7 && Math.abs(deltaY) < 7) {
      return;
    }
    if (Math.abs(deltaY) > Math.abs(deltaX)) return;
    gesture.dragged = true;
    gesture.deltaX = deltaX;
    const startOffset = revealed ? -86 : 0;
    const position = Math.max(-96, Math.min(0, startOffset + deltaX));
    event.currentTarget.style.transform = `translate3d(${position}px,0,0)`;
  }

  function handlePointerEnd(event: React.PointerEvent<HTMLButtonElement>) {
    const gesture = gestureRef.current;
    if (!gesture.active) return;
    gesture.active = false;
    event.currentTarget.style.transition =
      "transform 320ms cubic-bezier(.2,.8,.2,1)";
    if (!gesture.dragged) {
      event.currentTarget.style.transform = revealed
        ? "translate3d(-86px,0,0)"
        : "translate3d(0,0,0)";
      return;
    }
    skipClickRef.current = true;
    const shouldReveal = revealed
      ? gesture.deltaX < 35
      : gesture.deltaX < -38;
    onReveal(shouldReveal ? id : null);
    requestAnimationFrame(() => {
      skipClickRef.current = false;
    });
  }

  async function handleDelete() {
    if (!window.confirm(`${label}を削除しますか？`)) return;
    onReveal(null);
    await onDelete();
  }

  return (
    <div
      id={`subscription-${id}`}
      className={`service-swipe-row ${highlighted ? "is-highlighted" : ""}`}
    >
      <button
        className="swipe-delete-action"
        type="button"
        onClick={handleDelete}
        aria-label={`${label}を削除`}
      >
        <Trash2 size={19} />
        <span>削除</span>
      </button>
      <button
        ref={foregroundRef}
        type="button"
        className={className}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerEnd}
        onPointerCancel={handlePointerEnd}
        onClick={() => {
          if (skipClickRef.current) return;
          if (revealed) {
            onReveal(null);
            return;
          }
          onOpen();
        }}
        aria-label={`${label}を編集。左にスワイプすると削除できます`}
      >
        {children}
      </button>
    </div>
  );
}
