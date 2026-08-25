// 개봉 대기 소원 목록 API — bokjumeoni-plan §03 SERVER API
// `GET /wishes/pending-openings` 대응.
//
// [배경] Phase01에서는 unlockAt/wishState 서버 필드가 없어 Flutter가
// createdAt+100일 로컬 근사치로 "개봉 화면 자동 트리거"를 판정했다
// (wish_room_box_opening_trigger.dart 참고). Phase02-A에서 실제 unlockAt/
// wishState 필드가 생겼으므로, 이 API가 "unlockAt이 지났고 아직 개봉
// 화면을 보여준 적 없는(openedBoxAt이 null인) 내 소원" 목록을 반환한다.
// 클라이언트는 이 응답이 있으면 07 Box Opening 화면을 자동으로 띄운다
// (호출부 교체는 별도 Flutter 작업 — 이 커밋은 서버 API만 추가).
//
// [정책] "이루어짐"(wishState='fulfilled')이 아니라 "봉인 기간 만료"만
// 개봉 대상으로 본다 — fulfilled는 사용자가 능동적으로 표시하는 것이라
// pending-openings 목록에 강제로 끼워 넣지 않는다(중복 알림 방지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  requireUser,
  resolveWishUnlockAt,
  toWishDto,
  unauthorizedResponse,
  type WishRow,
} from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    // unlockAt이 DB에 저장되어 있지 않은(null) 레코드도 있으므로, SQL
    // 레벨에서 "sealedAt + 100일 < now"까지 함께 걸러낼 수 없다(SQLite는
    // 날짜 산술 WHERE절을 Prisma로 표현하기 까다로움). 따라서 후보군만
    // (openedBoxAt이 아직 없는 내 소원) SQL로 좁히고, 실제 만료 판정은
    // resolveWishUnlockAt()으로 애플리케이션 레벨에서 수행한다 — 사용자당
    // 소원 개수가 많지 않으므로 성능 문제 없음.
    const candidates = await prisma.wish.findMany({
      where: { userId: auth.userId, deletedAt: null, openedBoxAt: null },
      include: { user: { select: { nickname: true } } },
      orderBy: [{ sealedAt: "asc" }],
    });

    const now = new Date();
    const rows = candidates as unknown as WishRow[];
    const pending = rows.filter((w) => resolveWishUnlockAt(w) <= now);

    const data = pending.map((w) => toWishDto(w, auth.userId));
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/pending-openings] 실패:", e);
    return NextResponse.json(
      { success: false, error: "개봉 대기 소원 목록을 불러오지 못했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
