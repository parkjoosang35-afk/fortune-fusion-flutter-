import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  // [애드센스 소유 인증 — 2026-10-13] 게시자 ca-pub-4640621040048656.
  verification: { google: "ca-pub-4640621040048656" },
  title: "Fortune Fusion Admin",
  description: "Fortune Fusion 관리자 시스템",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="ko"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <head>
        {/* [애드센스 소유 인증 — 2026-10-13] 게시자 ca-pub-4640621040048656. */}
        <script
          async
          src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-4640621040048656"
          crossOrigin="anonymous"
        ></script>
      </head>
      <body className="min-h-full flex flex-col bg-white">{children}</body>
    </html>
  );
}
