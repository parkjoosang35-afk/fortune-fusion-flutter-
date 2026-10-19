// 결과 공유 링크 — 공개 웹 랜딩페이지.
// [웹 공유 "가짜 페이지" 근본 재설계 — 대표 긴급 지시, 2027-02]
// URL 스킴(`/r/{shareId}`)과 App Links 역할(AndroidManifest
// pathPrefix="/r", assetlinks.json)은 그대로 유지하지만, **내부 렌더는
// 완전히 제거**하고 `/coupon/[token]`과 동일한 "OG 전용 SSR + 즉시 Flutter
// 앱으로 리다이렉트" 패턴으로 바꾼다.
//
// [왜 바뀌었는가] 과거에는 이 페이지가 `ServiceResultView`/
// `SharedResultView` + `SintongBottomNavBar`(자체 제작 가짜 하단바
// "홈/운세/소원방/귀인지도/마이")로 결과를 직접 그렸다. 이는 실제 운영
// 서비스(Flutter 웹앱, 진짜 하단바 "홈/신당부적/복주머니/마이")와 완전히
// 다른 모습이었고, 대표가 스크린샷 비교로 직접 지적해 전면 삭제가
// 결정되었다. 결과 렌더링(아바타·점수·오행·판정근거 등)은 이미 Flutter
// 웹앱의 `SharedResultScreen`(`/r/{shareId}` named route)에 완전히
// 구현되어 있으므로 admin_web에 다시 만들지 않는다 — `redirect-to-app.tsx`
// 참고.
//
// [SSR 필수] 카톡 크롤러는 JS를 실행하지 않으므로 generateMetadata(Server
// Component)로만 OG를 만든다. 개인 공유이므로 noindex 유지.
//
// [REQ-25 — 소원방 초대/결과 분리] resultType이 wish인 공유는 메타 문구를
// "소원방 결과"로 내보낸다(/w/ 초대는 "소원방 초대" — 화면·문구·OG가
// 서로 다르다). 초대 페이지(/w/[token])는 이번 작업에서 손대지 않았다.
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { hasOriginalImage } from '@/app/api/public/share/_shared';
import { RedirectToApp } from "./redirect-to-app";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ id: string }>;
};

async function loadSharedResult(shareId: string) {
  try {
    const shared = await prisma.sharedResult.findUnique({
      where: { shareId },
      include: { user: { select: { nickname: true } } },
    });
    if (!shared || shared.deletedAt != null || shared.status !== "active") {
      return { state: "not_found" as const };
    }

    return {
      state: "ok" as const,
      shareId: shared.shareId,
      resultType: shared.resultType,
      title: shared.title,
      description: shared.description,
      imageUrl: shared.imageUrl,
      ownerNickname: shared.user.nickname,
    };
  } catch (e) {
    console.error("[GET /r/[id]] 조회 실패:", e);
    return { state: "error" as const };
  }
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params;
  const shared = await loadSharedResult(id);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const pageUrl = `${baseUrl}/r/${id}`;

  // [REQ-25] 소원방 결과 공유는 초대(/w/)와 문구를 구분한다.
  const isWishResult = shared.state === "ok" && shared.resultType === "wish";
  const defaultTitle = "신통방통 · 결과 공유";
  const title = shared.state === "ok"
    ? isWishResult ? "신통방통 · 소원방 결과" : shared.title
    : defaultTitle;
  const description = shared.state === "ok"
    ? isWishResult ? "함께 빌었던 소원이 어떻게 되었는지 보여드려요." : shared.description
    : "링크가 만료되었거나 찾을 수 없어요.";

  // [G-4 교정] 오류/무효 토큰의 폴백 OG를 공용 브랜드 이미지로 교체.
  const brandFallback = `${baseUrl}/share-og/brand.png`;
  const ogImageUrl =
    shared.state === "ok"
       ? (hasOriginalImage(shared.imageUrl, id) ? `${baseUrl}/api/public/og/share/${id}.png` : shared.imageUrl ?? `${baseUrl}/api/public/og/share/${id}.png`)
      : brandFallback;

  return {
    title,
    description,
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

export default async function SharedResultPage({ params }: PageProps) {
  const { id } = await params;
  return <RedirectToApp shareId={id} />;
}
