// [G-6 보완 — REQ-26] sitemap.xml 동적 생성.
// 검색 허용 페이지(공개 랜딩·정책 문서)만 나열한다. 개인 공유 결과
// (/r/, /g/, /w/)는 noindex+robots disallow 정책에 따라 절대 포함하지
// 않는다 — shareId를 아는 사람만 열람한다는 개인정보 원칙 유지.
import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const now = new Date();
  // [애드센스 승인 개선 — 2026-11-02] /guide(서비스 가이드) 추가. 기존 /saju
  // 항목은 이번에 신설한 src/app/saju/page.tsx가 실제로 서빙되므로 더 이상
  // 깨진 링크가 아니다(운영 nginx 재확인 결과 라우팅 충돌 없음).
  return ["", "/saju", "/guide", "/login", "/terms", "/privacy-policy", "/account-deletion"].map((path) => ({
    url: `${baseUrl}${path}`,
    lastModified: now,
    changeFrequency: "weekly" as const,
    priority: path === "" ? 1 : path === "/saju" || path === "/guide" ? 0.8 : 0.5,
  }));
}
