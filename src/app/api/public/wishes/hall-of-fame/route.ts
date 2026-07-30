// 공개(비인증) 소원성 "명예의 전당" API — 신규.
// 기존 Flutter WishHallOfFameEntry는 클라이언트에서 getFeed() 결과를 집계해
// 만들었으나(파생 데이터), 이번 확장으로 관리자가 수동 선정한 성취 후기
// (wish_reviews.isFeatured=true)를 우선 노출하는 서버 집계 버전을 추가한다.
// 기존 클라이언트 집계 로직은 그대로 유지 가능(하위호환), 이 API는 신규 선택 사항.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  try {
    // 1) 관리자가 수동 선정한 성취 후기(우선 노출)
    const featuredReviews = await prisma.wishReview.findMany({
      where: { isFeatured: true, status: "visible" },
      include: { wish: { include: { user: true } } },
      orderBy: { createdAt: "desc" },
      take: 20,
    });

    // 2) 응원(support) 누적 상위 작성자 랭킹 (기존 클라이언트 집계와 동등한 서버 버전)
    const topWishes = await prisma.wish.findMany({
      where: { status: "visible", deletedAt: null },
      include: { user: true },
      orderBy: { supportCount: "desc" },
      take: 50,
    });
    const byNickname = new Map<string, { totalSupport: number; wishCount: number }>();
    for (const w of topWishes) {
      const nickname = w.isAnonymous ? "익명" : w.user.nickname;
      const entry = byNickname.get(nickname) ?? { totalSupport: 0, wishCount: 0 };
      entry.totalSupport += w.supportCount;
      entry.wishCount += 1;
      byNickname.set(nickname, entry);
    }
    const ranking = Array.from(byNickname.entries())
      .map(([nickname, v]) => ({ nickname, ...v }))
      .sort((a, b) => b.totalSupport - a.totalSupport)
      .slice(0, 10);

    return NextResponse.json(
      {
        success: true,
        data: {
          featuredReviews: featuredReviews.map((r) => ({
            id: `wr_${r.id}`,
            wishId: `wp_${r.wishId}`,
            authorNickname: r.wish.isAnonymous ? "익명" : r.wish.user.nickname,
            content: r.content,
            createdAt: r.createdAt.toISOString(),
          })),
          ranking,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/wishes/hall-of-fame] 실패:", e);
    return NextResponse.json(
      { success: false, error: "명예의 전당을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
