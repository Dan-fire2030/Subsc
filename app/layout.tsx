import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import { ServiceWorkerRegistration } from "./ServiceWorkerRegistration";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host") ?? "localhost:3000";
  const protocol = requestHeaders.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const ogImage = `${protocol}://${host}/og.png`;
  const title = "Subsc — サブスクを、すっきり管理";
  const description = "毎月の固定費と次の更新日がひと目でわかる、スマホファーストのサブスク管理アプリ。";
  return {
    title,
    description,
    applicationName: "Subsc",
    manifest: "/manifest.webmanifest",
    appleWebApp: {
      capable: true,
      title: "Subsc",
      statusBarStyle: "default",
    },
    icons: {
      icon: [
        { url: "/subsc-favicon-2026.png", sizes: "32x32", type: "image/png" },
        { url: "/subsc-icon-192-2026.png", sizes: "192x192", type: "image/png" },
      ],
      shortcut: "/subsc-favicon-2026.png",
      apple: [{ url: "/subsc-apple-touch-2026.png", sizes: "180x180", type: "image/png" }],
    },
    openGraph: { title, description, type: "website", images: [{ url: ogImage, width: 1672, height: 941 }] },
    twitter: { card: "summary_large_image", title, description, images: [ogImage] },
  };
}

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  colorScheme: "light",
  themeColor: "#f2f2f7",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja">
      <body>
        {children}
        <ServiceWorkerRegistration />
      </body>
    </html>
  );
}
