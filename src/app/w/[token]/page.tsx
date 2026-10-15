// 소원방 초대 링크 — 공개 웹 랜딩페이지.
//
// [2026-10, 앱·웹 분리 개발 전면 폐기 — 사용자 명시 지시 재확인]
// 과거 이 페이지는 `LinkInviteView`(admin_web 자체 제작 초대장 카드 +
// 응원/메시지/복주머니 게이트 패널)를 직접 렌더링했다 — 이는 귀인지도와
// 똑같은 "앱·웹 분리 중복 개발" 실수였다. `https://sintong.kr/app/`
// (Flutter 웹앱)에는 이미 `/w/{token}` named route가 완전히 구현되어
// 있다 — LinkInviteScreen(초대장) → OtherRoomScreen(실제 소원방, 촛불,
// 응원·메시지·복주머니, 비로그인 차단까지 전부 native). 자세한 배경은
// `redirect-to-app.tsx` 상단 주석 참고.
//
// 이 파일이 서버에서 하는 유일한 일은 카카오톡 등 SNS 크롤러를 위한
// `generateMetadata()` OG 태그 생성뿐이다(크롤러는 JS를 실행하지 않아
// Flutter SPA의 동적 내용을 볼 수 없으므로 SSR 메타가 필수). 실제 사람
// 방문자는 `RedirectToApp`이 즉시 `https://sintong.kr/app/#/w/{token}`
// 으로 보낸다.
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { levelDef } from "@/lib/wishroom-engine";
import { RedirectToApp } from "./redirect-to-app";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ token: string }>;
};

async function loadRoomByToken(token: string) {
  try {
    const room = await prisma.wishRoom.findUnique({
      where: { shareToken: token },
      include: { user: { select: { nickname: true } } },
    });
    if (!room || room.deletedAt != null || room.visibility === "PRIVATE") {
      return { state: "not_found" as const };
    }
    const lvl = levelDef(room.level);
    const daysLit = Math.max(
      1,
      Math.floor((Date.now() - room.createdAt.getTime()) / (24 * 60 * 60 * 1000)) + 1,
    );
    return {
      state: "ok" as const,
      ownerNickname: room.user.nickname || "누군가",
      text: room.text,
      level: room.level,
      levelName: lvl.name,
      daysLit,
      wishColor: room.wishColor,
    };
  } catch (e) {
    console.error("[GET /w/[token]] 조회 실패:", e);
    return { state: "error" as const };
  }
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { token } = await params;
  const room = await loadRoomByToken(token);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const pageUrl = `${baseUrl}/w/${token}`;

  const title =
    room.state === "ok"
      ? `${room.ownerNickname}님의 소원방에 초대해요`
      : "신통방통 · 소원방 초대";
  const description =
    room.state === "ok"
      ? `"${room.text}"\n촛불 하나 함께 밝혀주세요`
      : "링크가 만료되었거나 찾을 수 없어요.";

  return {
    title,
    description,
    // [개인정보 원칙] 소원 본문이 포함되므로 검색엔진 색인을 막는다
    // (`/r/[id]`와 동일한 noindex 원칙).
    robots: { index: false, follow: false },
    openGraph: {
      title,
      description,
      url: pageUrl,
      // [버그 수정 — 지시서 §5 "서비스별 이미지와 설명은 구분"] 기존에는
      // 소원방 전용 이미지(public/share-og/wish.png)가 이미 존재하는데도
      // 귀인지도 이미지(og-guinji-1200x630.png)를 그대로 재사용하고
      // 있었다. 소원방 전용 이미지로 교체한다.
      images: [{ url: `${baseUrl}/share-og/wish.png`, width: 1200, height: 630 }],
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
    },
  };
}

export default async function LinkInvitePage({ params }: PageProps) {
  const { token } = await params;
  return <RedirectToApp token={token} />;
}
