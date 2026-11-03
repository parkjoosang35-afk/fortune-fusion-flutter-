"use client";

// [애드센스 승인 개선 지시서 — 2026-11-02]
// [배경] 기존에는 admin_web의 모든 페이지(로그인/회원탈퇴/쿠폰 랜딩 등 콘텐츠가
// 거의 없는 화면 포함)에 AdSense 로더 스크립트가 무조건 삽입되어 있었다. 이
// 스크립트가 심어진 페이지는 Google이 Auto ads 대상으로 간주해 실제로 광고를
// 꽂아 넣을 수 있는데, "로그인하세요 / 이메일 / 비밀번호" 수준의 텍스트만 있는
// 화면에 광고가 나가는 구조가 "게시자 콘텐츠가 없는 화면에 광고 게재" 심사
// 거부 사유로 이어졌다(실측: /login 75자, /account-deletion 105자).
//
// [해결 방식 — 화이트리스트 전환] 전체 페이지에 무조건 심던 방식에서, 콘텐츠가
// 충분하다고 확인된 공개 페이지에만 명시적으로 허용하는 방식으로 바꾼다.
// 새로 광고를 켤 페이지가 생기면 이 배열에 추가하는 것으로 충분하며, 반대로
// 이 배열에 없는 페이지는 절대 광고 스크립트 자체가 로드되지 않는다(Auto ads
// 대상에서 원천 제외).
//
// [제외 확인 — 콘텐츠 부족/개인용 화면] /login, /account-deletion,
// /coupon/[token](개인 수령용 쿠폰 랜딩), /my/guinji(로그인 전용 관리 화면),
// /g/[token]·/w/[token]·/r/[id]·/web-result/[id](개인 공유 결과, 기존에도
// robots noindex 처리됨), /partner/**(파트너 전용 포털) — 전부 이 배열에
// 포함하지 않는다.
//
// [유지 — 콘텐츠 충분 확인] /terms, /privacy-policy(법적 고지문, 3,000자+),
// /saju·/guide(신규 SSR 안내 페이지, 독창적 설명 콘텐츠).
import { usePathname } from "next/navigation";
import Script from "next/script";

const ADSENSE_PUBLISHER_ID = "ca-pub-4640621040048656";

// [참고] "/"(루트)는 운영 nginx가 admin_web을 거치지 않고 pc_landing 정적
// 파일을 직접 서빙하므로(location = / ), 이 화이트리스트와 무관하게 pc_landing
// 자체의 <script> 태그로 별도 관리된다(index.html 참고). admin_web의 루트
// 라우트(src/app/page.tsx)는 /dashboard로 즉시 redirect되는 내부 전용
// 경로라 여기 포함할 필요가 없다.
const AD_ALLOWED_PATHS: readonly string[] = [
  "/saju",
  "/guide",
  "/terms",
  "/privacy-policy",
];

export default function AdSenseLoader() {
  const pathname = usePathname();
  if (!pathname || !AD_ALLOWED_PATHS.includes(pathname)) return null;

  return (
    <Script
      id="adsbygoogle-loader"
      async
      src={`https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_PUBLISHER_ID}`}
      crossOrigin="anonymous"
      strategy="afterInteractive"
    />
  );
}
