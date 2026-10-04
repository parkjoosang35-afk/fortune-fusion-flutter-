// 결과 공유 링크 — 공개 웹 랜딩페이지.
// [sintong-share-proposal.pdf §6] `https://sintong.kr/r/{shareId}`.
//
// [핵심 목적] 이 링크가 앱 설치자에게는 Android App Links(autoVerify)로
// 즉시 앱이 열리게 하고(AndroidManifest.xml pathPrefix="/r"), 미설치자
// /iOS(AASA 미설정 시)에게는 이 서버 렌더링 페이지가 열려 "정상적으로
// 결과를 볼 수 있는" 경험 + 설치 유도 배너를 제공한다(guinji `/g/[token]`
// 과 동일한 2단계 구조 — Phase A 문서 참고).
//
// [SSR 필수 — 제안서 R4 "가장 흔한 실패 원인"] 카카오톡 링크-미리보기
// 크롤러는 JS를 실행하지 않으므로 `generateMetadata()`(Server Component)
// 로만 OG 태그를 만들어야 한다. 클라이언트 렌더/useEffect 삽입은 불가.
//
// [noindex — 개인정보 원칙] 공유 결과는 shareId를 아는 사람만 봐야 하며
// 검색엔진에 노출되면 안 된다(NFR-03과 동일한 취지).
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { SharedResultView } from "./shared-result-view";
import { SintongBottomNavBar } from "../../g/[token]/sintong-bottom-nav-bar";
import { OG_CONFIG, isValidShareContentType } from "@/lib/share-og-config";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ id: string }>;
};

// [2027-02 central OG config] Display label mapping is no longer declared
// directly here. It is looked up from the central config
// (`@/lib/share-og-config`) OG_CONFIG.label (fortune remains included there
// as legacy-only, so it still displays correctly as "오늘의 운세").
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

  const title = shared.state === "ok" ? shared.title : "신통방통 · 결과 공유";
  const description =
    shared.state === "ok" ? shared.description : "링크가 만료되었거나 찾을 수 없어요.";
  const ogImageUrl =
    shared.state === "ok"
      ? shared.imageUrl ?? `${baseUrl}/api/public/og/share/${id}.png`
      : `${baseUrl}/guinji/og-guinji-1200x630.png`;

  return {
    title,
    description,
    // [개인정보 원칙] shareId를 아는 사람만 접근해야 하며 검색엔진 색인 금지.
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

  return (
    <div className="min-h-screen bg-[#FBF7EF] pb-[76px]">
      <SharedResultView
        shareId={id}
        state={shared.state}
        title={shared.state === "ok" ? shared.title : undefined}
        description={shared.state === "ok" ? shared.description : undefined}
        resultType={shared.state === "ok" ? shared.resultType : undefined}
        resultTypeLabel={
          shared.state === "ok" ? resultTypeLabelOf(shared.resultType) : undefined
        }
        payload={shared.state === "ok" ? shared.payload : undefined}
        ownerNickname={shared.state === "ok" ? shared.ownerNickname : undefined}
      />
      <SintongBottomNavBar />
    </div>
  );
}
