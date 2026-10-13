// [G-6 보완 — REQ-26] sitemap.xml 동적 생성.
// 검색 허용 페이지(공개 랜딩·정책 문서)만 나열한다. 개인 공유 결과
// (/r/, /g/, /w/)는 noindex+robots disallow 정책에 따라 절대 포함하지
// 않는다 — shareId를 아는 사람만 열람한다는 개인정보 원칙 유지.
import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const now = new Date();
  return ["", "/saju", "/login", "/terms", "/privacy-policy", "/account-deletion"].map((path) => ({
    url: `${baseUrl}${path}`,
    lastModified: now,
    changeFrequency: "weekly" as const,
    priority: path === "" ? 1 : 0.5,
  }));
}
