// 공개 부적 사용 처리 API — Flutter AmuletRepository.use() 대응.
// user_amulets.status를 used로 변경하고 amulet_usage_logs에 사용 이력을 남긴다.
// [경제 감사 2026-10-12 C-4] 기존에는 인증·소유권 검증이 없어 임의의
// userAmuletId로 타인의 보유 부적을 used로 마킹할 수 있었다(같은 파일군의
// amulets/gift는 userId 조건이 있었는데 use에만 누락). requireUser 강제 +
// 소유자 조건 추가로 gift 라우트와 동일한 패턴으로 수렴시킨다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseUserAmuletId(raw: unknown): number | null {
  const s = String(raw ?? "");
  const m = s.match(/^ua_(\d+)$/) ?? s.match(/^(\d+)$/);
  if (!m) return null;
  return Number(m[1]);
}

export async function POST(request: NextRequest) {
  let body: { userAmuletId?: string | number; contextType?: string; contextId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userAmuletId = parseUserAmuletId(body.userAmuletId);
  if (userAmuletId == null) {
    return NextResponse.json(
      { success: false, error: "userAmuletId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    await prisma.$transaction(async (tx) => {
      const userAmulet = await tx.userAmulet.findFirst({
        where: { id: userAmuletId, deletedAt: null, userId: auth.userId },
      });
      if (!userAmulet) {
        throw new Error("NOT_FOUND");
      }
      if (userAmulet.status !== "held") {
        throw new Error("NOT_HELD");
      }

      await tx.userAmulet.update({
        where: { id: userAmuletId },
        data: { status: "used" },
      });

      await tx.amuletUsageLog.create({
        data: {
          userAmuletId,
          usedContextType: body.contextType ?? null,
          usedContextId: body.contextId ?? null,
        },
      });
    });

    return NextResponse.json({ success: true, data: null }, { headers: CORS_HEADERS });
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "보유하지 않은 부적입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "NOT_HELD") {
      return NextResponse.json(
        { success: false, error: "이미 사용되었거나 만료된 부적입니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/amulets/use] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 사용 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
