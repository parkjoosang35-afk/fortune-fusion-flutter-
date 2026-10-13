// 결과 공유 링크 — 공개 웹 랜딩페이지.
// [앱·웹 공유 구조 전면 정리 v1.0 — REQ-24/26/27] URL 스킴(`/r/{shareId}`)과
// App Links 역할(AndroidManifest pathPrefix="/r", assetlinks.json)은 그대로
// 유지하고, **내부 렌더만** "공통 흰색 카드"에서 서비스별 결과 뷰로 교체했다.
// 서비스별 뷰는 src/app/r/[id]/service-result-view.tsx 참고.
//
// [G-4 폴백 OG 교정 — REQ-26] 기존에는 조회 실패/오류 시 OG 이미지가
// guinji 전용 이미지(og-guinji-1200x630.png)로 하드코딩돼, 어떤 서비스
// 링크든 오류 카드에 귀인지도 이미지가 붙었다. 신통방통 공용 브랜드 OG
// (public/share-og/brand.png, Q5 기본안 신설)로 교체한다.
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
import { SharedResultView } from "./shared-result-view";
import { ServiceResultView, isStructuredPayload, BRAND_BG, GOLD, SERIF } from "./service-result-view";
import { WebShareButton } from "./web-share-button";
import { SintongBottomNavBar } from "../../g/[token]/sintong-bottom-nav-bar";
import { OG_CONFIG, isValidShareContentType } from "@/lib/share-og-config";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ id: string }>;
};

function resultTypeLabelOf(resultType: string): string {
  if (isValidShareContentType(resultType)) return OG_CONFIG[resultType].label;
  return "결과";
}

async function loadSharedResult(shareId: string) {
  try {
    const shared = await prisma.sharedResult.findUnique({
      where: { shareId },
      include: { user: { select: { nickname: true } } },
    });
    if (!shared || shared.deletedAt != null || shared.status !== "active") {
      return { state: "not_found" as const };
    }

    let payload: unknown = null;
    try {
      payload = JSON.parse(shared.payload);
    } catch {
      payload = null;
    }

    return {
      state: "ok" as const,
      shareId: shared.shareId,
      resultType: shared.resultType,
      title: shared.title,
      description: shared.description,
      payload,
      imageUrl: shared.imageUrl,
      ownerNickname: shared.user.nickname,
      createdAt: shared.createdAt,
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
  const shared = await loadSharedResult(id);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";

  const outer: React.CSSProperties = {
    minHeight: "100vh",
    background: BRAND_BG,
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
  };
  const card: React.CSSProperties = {
    width: "100%",
    maxWidth: 480,
    margin: "0 auto",
    padding: "28px 20px 60px",
    boxSizing: "border-box",
  };

  if (shared.state !== "ok") {
    const message =
      shared.state === "not_found"
        ? "결과를 찾을 수 없어요.\n링크가 만료되었거나 삭제되었을 수 있어요."
        : "일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요.";
    return (
      <main style={outer}>
        <div style={card}>
          <div style={{ textAlign: "center", padding: "70px 0" }}>
            <div style={{ fontSize: 44 }}>🕯️</div>
            <h1 style={{ fontFamily: SERIF, fontSize: 19, color: "#F5EFE6", marginTop: 18, whiteSpace: "pre-wrap" }}>{message}</h1>
            <p style={{ fontSize: 13, color: "#8F857A", marginTop: 10 }}>신통방통 — 정통사주 · 귀인지도 · 타로 · 소원방 · 관상 · 손금</p>
          </div>
        </div>
        <SintongBottomNavBar />
      </main>
    );
  }

  if (hasOriginalImage(shared.imageUrl, shared.shareId)) {
    return (
      <main style={outer}>
        <div style={{ width: '100%', maxWidth: 480 }}>
          {/* 원본 PNG는 재배치/요약/잘라내지 않는다. 공유 도구는 이미지 밖에 둔다. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={shared.imageUrl!} alt={`${shared.title} · 원래 결과 전체`} style={{ display: 'block', width: '100%', height: 'auto' }} />
          <div style={{ padding: 20 }}>
            <a href={shared.imageUrl!} download={`sintong_${shared.shareId}.png`} style={{ color: GOLD }}>원본 결과 저장</a>
            <WebShareButton shareUrl={`${baseUrl}/r/${shared.shareId}?src=web`} title={shared.title} description={shared.description} />
          </div>
        </div>
      </main>
    );
  }
  const label = resultTypeLabelOf(shared.resultType);
  const structured = isStructuredPayload(shared.payload, shared.resultType);
  const createdAt = shared.createdAt ? new Intl.DateTimeFormat("ko-KR", { dateStyle: "medium", timeStyle: "short" }).format(shared.createdAt) : null;

  return (
    <main style={outer}>
      <div style={card}>
        <header style={{ textAlign: "center", marginBottom: 22 }}>
          <p style={{ margin: 0, fontSize: 11, letterSpacing: 3, color: GOLD }}>SINTONG BANGTONG</p>
          <h1 style={{ fontFamily: SERIF, fontSize: 22, color: "#F5EFE6", margin: "8px 0 0" }}>
            {shared.ownerNickname ? `${shared.ownerNickname}님의 ${label}` : label}
          </h1>
        </header>
        {structured ? (
          <ServiceResultView resultType={shared.resultType} payload={shared.payload} createdAt={createdAt} />
        ) : (
          // [하위 호환] `kind` 구조화 이전(legacy)에 생성된 공유 링크 —
          // 기존 공통 뷰를 그대로 사용한다(REQ-27 기존 링크 동작 보장).
          <SharedResultView
            shareId={shared.shareId}
            state="ok"
            title={shared.title}
            description={shared.description}
            resultType={shared.resultType}
            resultTypeLabel={label}
            payload={shared.payload}
            ownerNickname={shared.ownerNickname}
          />
        )}
        <WebShareButton
          shareUrl={`${baseUrl}/r/${shared.shareId}?src=web`}
          title={shared.title}
          description={shared.description}
        />
        <p style={{ marginTop: 18, fontSize: 12, color: "#8F857A", textAlign: "center" }}>
          앱에서 보면 더 자세한 결과를 볼 수 있어요
        </p>
      </div>
      <SintongBottomNavBar />
    </main>
  );
}
