"use client";

import { useEffect } from "react";

export function ServiceWorkerRegistration() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;

    async function register() {
      try {
        const registration = await navigator.serviceWorker.register("/sw.js", {
          scope: "/",
        });
        await registration.update();
        const ready = await navigator.serviceWorker.ready;
        (ready.active ?? ready.waiting)?.postMessage({
          type: "CACHE_CURRENT_PAGE",
          url: "/",
        });
      } catch {
        // The app stays fully usable online when service workers are unavailable.
      }
    }

    void register();
  }, []);

  return null;
}
