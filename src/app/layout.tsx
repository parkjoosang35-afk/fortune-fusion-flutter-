import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import AdSenseLoader from "@/components/AdSenseLoader";
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
  // (사이트 소유 확인용 meta 태그이며, 광고 스크립트 자체와는 별개 — 계속 유지)
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
      <body className="min-h-full flex flex-col bg-white">
        {/* [애드센스 승인 개선 — 2026-11-02] 전체 페이지에 무조건 삽입하던
            방식에서, 콘텐츠가 충분한 공개 페이지에만 선택적으로 로더
            스크립트를 삽입하는 화이트리스트 방식으로 전환했다. 상세 근거/
            허용 목록은 AdSenseLoader.tsx 주석 참고. */}
        <AdSenseLoader />
        {children}
      </body>
    </html>
  );
}
