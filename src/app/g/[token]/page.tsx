// 귀인지도 초대 링크 — 공개 웹 랜딩페이지.
//
// [2026-10, 앱·웹 분리 개발 전면 폐기 — 사용자 명시 지시 재확인, 몇 번째
// 재수정] 이 페이지는 더 이상 "자체 폼 + 결과 카드 + 관계 지도"를 직접
// 렌더링하지 않는다. 사용자가 반복해서 분노하며 지적한 문제: "귀인지도도
// 초대장도 웹이니까, 초대장에서 입력하고 나면 신통방통 웹주소
// (`https://sintong.kr/app/#/g/{token}`)로 바로 들어가야 한다"는 것을
// admin_web에 커스텀 React 컴포넌트(GuinjiInviteInteractive, GuinjiOrbitMap,
// ServiceGrid 등)를 새로 만들어 대체 구현한 것이 근본 원인이었다 —
// `https://sintong.kr/app/`에는 이미 완전히 동작하는 Flutter 웹앱이
// 배포되어 있고, 그 안에 동일한 `/g/{token}` 경로가 입력 폼 → 계산 연출 →
// 결과 화면까지 전부 구현·검증되어 있었다(app_router.dart,
// GuinjiMapGuestJoinScreen/GuinjiGuestResultScreen). 중복 개발이었다.
//
// [남겨둔 이유] 이 서버 컴포넌트(generateMetadata)는 여전히 필요하다 —
// 카카오톡 등 SNS 공유 크롤러는 JavaScript를 실행하지 않으므로, Flutter
// 웹앱 URL을 직접 공유하면 오픈그래프 미리보기 카드(제목/설명/이미지)가
// 전혀 뜨지 않는다. 이 Next.js 서버가 `/g/{token}`을 받아 OG 메타태그만
// 서버사이드로 렌더링해 카톡 미리보기를 만들고, 실제 사람이 링크를 열면
// (크롤러가 아니라 브라우저가 JS를 실행하면) [RedirectToApp]이 즉시
// 진짜 신통방통 웹(Flutter)으로 이동시킨다.
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { RedirectToApp } from "./redirect-to-app";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ token: string }>;
  searchParams: Promise<{ v?: string }>;
};

// [Phase A-2 — 카톡 공유 바이럴 개선, OG 미리보기 카드] 기존 로직 그대로
// 유지 — 이미지/캐시버스팅 구조는 손대지 않는다(로직 변경 없음, 본문
// 렌더링 방식만 교체).
export async function generateMetadata({ params, searchParams }: PageProps): Promise<Metadata> {
  const { token } = await params;
  const { v: shareCode } = await searchParams;
  const invite = await loadInviteForMeta(token);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const ogImageUrl = shareCode
    ? `${baseUrl}/api/public/og/guinji/${token}/${shareCode}.png`
    : `${baseUrl}/api/public/og/guinji/${token}.png`;

  const title =
    invite.state === "ok"
      ? `${invite.ownerName}님이 초대한 귀인 지도`
      : "신통방통 · 귀인지도";
  const description = "생일만 넣으면, 내가 이 사람에게 어떤 사람인지 나와요.";

  return {
    title,
    description,
    openGraph: {
      title,
      description,
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

async function loadInviteForMeta(token: string) {
  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { token },
      include: { owner: { select: { nickname: true } } },
    });
    if (!map || map.deletedAt != null || map.status !== "active") {
      return { state: "not_found" as const };
    }
    return { state: "ok" as const, ownerName: map.owner.nickname };
  } catch (e) {
    console.error("[GET /g/[token]] OG 메타 조회 실패:", e);
    return { state: "error" as const };
  }
}

// [핵심] 토큰 유효성(active/revoked/not_found)은 더 이상 이 서버에서
// 미리 판정하지 않는다 — 어차피 실제 참여 폼·결과는 전부 Flutter 웹앱
// 쪽 `/g/{token}` 화면이 담당하고, 그 화면이 `joinAnonymous` 제출 시점에
// 서버(API)로부터 같은 유효성 에러("지도를 찾을 수 없어요"/"지도 주인이
// 이 링크를 중단했어요")를 그대로 받아 보여준다(API route.ts 로직 변경
// 없음). 이 페이지는 무조건 즉시 진짜 웹으로 보낸다.
export default async function GuinjiInviteLandingPage({ params }: PageProps) {
  const { token } = await params;
  return <RedirectToApp token={token} />;
}
