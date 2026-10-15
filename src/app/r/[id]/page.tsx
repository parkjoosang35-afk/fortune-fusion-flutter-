// 결과 공유 링크 — 공개 웹 랜딩페이지.
//
// [2026-10, 앱·웹 분리 개발 전면 폐기 — 결과 공유 페이지까지 동일 적용]
// 과거 이 페이지는 `service-result-view.tsx`/`shared-result-view.tsx`로
// 타로·정통사주·관상·손금·귀인지도·소원방 6종 결과를 admin_web에서
// 직접 다시 그려 보여줬다 — 귀인지도/소원방 초대장과 완전히 똑같은
// "앱·웹 분리 중복 개발" 실수였다. `https://sintong.kr/app/`(Flutter
// 웹앱)에는 이미 `/r/{shareId}` named route가 완전히 구현되어 있다
// (`SharedResultScreen` — 6종 결과 전부 표시). 자세한 배경은
// `redirect-to-app.tsx` 상단 주석 참고.
//
// 이 파일이 서버에서 하는 유일한 일은 카카오톡 등 SNS 크롤러를 위한
// `generateMetadata()` OG 태그 생성뿐이다(크롤러는 JS를 실행하지 않아
// Flutter SPA의 동적 내용을 볼 수 없으므로 SSR 메타가 필수). 실제 사람
// 방문자는 `RedirectToApp`이 즉시 `https://sintong.kr/app/#/r/{shareId}`
// 으로 보낸다. App Links 역할(AndroidManifest pathPrefix="/r",
// assetlinks.json)은 URL 스킴이 그대로이므로 영향 없음.
//
// [REQ-25 — 소원방 초대/결과 분리] resultType이 wish인 공유는 메타 문구를
// "소원방 결과"로 내보낸다(/w/ 초대는 "소원방 초대" — 문구가 다르다).
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
