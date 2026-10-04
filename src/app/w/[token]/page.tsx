// 소원방 공유 링크 — 공개 웹 랜딩페이지.
// [소원방 공유 랜딩 신설 — 사용자 리포트 "공유가 엉뚱한 화면으로 감" /
// 카카오 공유 404 버그 수정]
//
// [배경] Flutter `main_room_screen.dart`의 `_ShareSheet`가 발급하는
// 공유 URL은 `POST /wish-rooms/{id}/share-link`(share-link/route.ts)가
// 반환하는 `https://sintong.kr/w/{token}`이다. 그런데 이 라우트
// (`/w/[token]`)가 admin_web에 전혀 존재하지 않아, 앱이 설치되지
// 않았거나 App Links 검증이 안 된 환경(카카오톡 인앱 브라우저 등)에서
// 이 링크를 열면 그대로 404 페이지가 떴다 — "공유하기가 엉뚱한 화면으로
// 간다"는 사용자 리포트의 가장 유력한 원인. `/g/[token]`(귀인지도),
// `/r/[id]`(결과 공유)와 동일한 2단계 구조(App Links 검증 성공 시 앱
// 직행, 실패/미설치 시 이 SSR 랜딩 + 설치 유도 배너 + "앱에서 열기"
// 버튼)를 그대로 적용해 신설한다.
//
// [SSR 필수] 카카오톡 링크-미리보기 크롤러는 JS를 실행하지 않으므로
// `generateMetadata()`(Server Component)로만 OG 태그를 만들어야 한다.
//
// [API 재사용] `GET /api/public/wishroom/share/{token}`가 이미 동일한
// shareToken 조회 로직(LINK_INVALID 404 처리 포함)을 갖고 있지만, 그
// 핸들러는 `buildRoomView()`(로그인 세션/오늘 응원여부 등 풀 뷰 의존성)를
// 거치므로 이 공개 랜딩페이지가 필요로 하는 "제목/본문/레벨/점등일수"
// 수준의 가벼운 정보만 보여주기 위해 이 페이지에서는 Prisma로 직접
// 필요한 필드만 조회한다(완전한 중복이 아니라 요구사항이 다름 — 풀
// WishRoom view가 아니라 OG 메타 + 미리보기 카드 수준).
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { levelDef } from "@/lib/wishroom-engine";
import { LinkInviteView } from "./link-invite-view";
import { SintongBottomNavBar } from "../../g/[token]/sintong-bottom-nav-bar";

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
      images: [{ url: `${baseUrl}/guinji/og-guinji-1200x630.png`, width: 1200, height: 630 }],
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
  const room = await loadRoomByToken(token);

  return (
    <div className="min-h-screen bg-[#FBF7EF] pb-[76px]">
      <LinkInviteView
        token={token}
        state={room.state}
        ownerNickname={room.state === "ok" ? room.ownerNickname : undefined}
        text={room.state === "ok" ? room.text : undefined}
        level={room.state === "ok" ? room.level : undefined}
        levelName={room.state === "ok" ? room.levelName : undefined}
        daysLit={room.state === "ok" ? room.daysLit : undefined}
      />
      <SintongBottomNavBar />
    </div>
  );
}
