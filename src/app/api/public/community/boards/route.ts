// 공개(비인증) 커뮤니티 게시판 목록 API — CommunityPostRepository.getBoards() 대응.
// [Phase6-2 - 커뮤니티 실API 연동] admin_web에 이미 존재하는 community_boards(마스터)
// 테이블을 그대로 조회해 반환한다(공개 여부/soft delete 필터만 적용).
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  try {
    const boards = await prisma.communityBoard.findMany({
      where: { isPublic: true, status: "active", deletedAt: null },
      orderBy: { sortOrder: "asc" },
    });

    const data = boards.map((b) => ({
      id: `board_${b.id}`,
      code: b.code,
      name: b.name,
      description: b.description,
      sortOrder: b.sortOrder,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/community/boards] 실패:", e);
    return NextResponse.json(
      { success: false, error: "게시판 목록을 불러오지 못했습니다." },
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
