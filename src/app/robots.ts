// [G-6 보완 — REQ-26] robots.txt 동적 생성.
// 개인 공유 결과(/r/, /g/, /w/)는 이미 noindex 메타로 검색 차단이고,
// robots에서도 명시적으로 금지해 이중 방어를 둔다. /app/은 Flutter
// 부트스트랩, /api/는 순수 API — 크롤링 대상이 아니다.
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/r/", "/g/", "/w/", "/app/", "/api/", "/my", "/admin", "/login"],
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  };
}
