// 복주머니 마케팅 쿠폰 등록 링크 — 공개 웹 랜딩페이지.
//
// [앱·웹 분리 원칙 — `/w/[token]`·`/g/[token]`·`/r/[id]`와 동일하게 적용]
// 쿠폰 미리보기(resolve) → 로그인 유도 → 실제 등록(redeem)까지의 전체 흐름은
// 이미 Flutter 웹앱(`https://sintong.kr/app/`)의 `/coupon/{token}` named
// route(app_router.dart → BokjuCouponResolveScreen)에 완전히 구현되어
// 있다(비로그인 시 PendingBokjuCouponStore에 토큰을 저장해두고 로그인
// 완료 후 자동 복귀하는 것까지 전부 native에서 처리). 이 Next.js 서버에
// 쿠폰 등록 폼이나 결과 카드를 중복으로 만들지 않는다.
//
// 이 페이지가 서버에서 하는 유일한 일은 카카오톡 등 SNS 크롤러를 위한
// `generateMetadata()` OG 태그 생성뿐이다(크롤러는 JS를 실행하지 않아
// Flutter SPA의 동적 내용을 볼 수 없으므로 SSR 메타가 필수). 실제 사람
// 방문자는 `RedirectToApp`이 즉시 `https://sintong.kr/app/#/coupon/{token}`
// 으로 보낸다.
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { RedirectToApp } from "./redirect-to-app";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ token: string }>;
};

async function loadCouponByToken(token: string) {
  try {
    const coupon = await prisma.bokjuCoupon.findUnique({
      where: { redeemToken: token },
      include: { campaign: true },
    });
    if (!coupon) {
      return { state: "not_found" as const };
    }
    return {
      state: "ok" as const,
      campaignTitle: coupon.campaign.title,
      grantAmount: coupon.campaign.grantAmount,
      guideText: coupon.campaign.guideText,
    };
  } catch (e) {
    console.error("[GET /coupon/[token]] OG 메타 조회 실패:", e);
    return { state: "error" as const };
  }
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { token } = await params;
  const coupon = await loadCouponByToken(token);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:4300";
  const pageUrl = `${baseUrl}/coupon/${token}`;
  const ogImageUrl = `${baseUrl}/share-og/bokju-coupon.png`;

  const title = coupon.state === "ok" ? `${coupon.campaignTitle} — 복주머니 쿠폰 받기` : "신통방통 · 복주머니 쿠폰";
  const description =
    coupon.state === "ok"
      ? (coupon.guideText ?? `지금 등록하면 복주머니 ${coupon.grantAmount.toLocaleString()}개를 바로 받아요!`)
      : "링크가 만료되었거나 찾을 수 없어요.";

  return {
    title,
    description,
    // [개인정보 원칙] 캠페인명/안내문구 외 개인정보는 노출하지 않지만,
    // 쿠폰 링크 특성상(공유용이 아니라 수령자 개인 전달용) 검색엔진 색인은
    // 막는다(`/w/[token]`·`/r/[id]`와 동일한 noindex 원칙).
    robots: { index: false, follow: false },
    openGraph: {
      title,
      description,
      url: pageUrl,
      images: [{ url: ogImageUrl, width: 1200, height: 630 }],
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [ogImageUrl],
    },
  };
}

export default async function BokjuCouponLandingPage({ params }: PageProps) {
  const { token } = await params;
  return <RedirectToApp token={token} />;
}
