// 공개(비인증) AI 생성형 부적 생성 API — Flutter AmuletRepository.generate() 대응.
// isAiGenerated=true인 부적 상품에 대해서만 허용. 실제 LLM/이미지생성 인프라가 아직
// 없으므로(ai_prompt_templates는 템플릿 정의만 존재), 기존 base 상품을 그대로 지급하고
// ai_request_logs에 domain="amulet"으로 생성 이력을 남긴다(추후 실제 AI 연동 시 이
// 라우트 내부만 교체).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseItemId(raw: unknown): number | null {
  const s = String(raw ?? "");
  const m = s.match(/^am_(\d+)$/) ?? s.match(/^(\d+)$/);
  if (!m) return null;
  return Number(m[1]);
}

export async function POST(request: NextRequest) {
  let body: { userId?: number; baseItemId?: string | number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;
  const baseItemId = parseItemId(body.baseItemId);
  if (baseItemId == null) {
    return NextResponse.json(
      { success: false, error: "baseItemId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const outcome = await prisma.$transaction(async (tx) => {
      const base = await tx.amuletItem.findFirst({
        where: { id: baseItemId, status: "active", deletedAt: null },
      });
      if (!base) throw new Error("NOT_FOUND");
      if (!base.isAiGenerated) throw new Error("NOT_AI_GENERATED");
      // [경제 감사 2026-10-12 M-5] 유료 카탈로그 상품(pricePoint > 0)을
      // 대가 없이 무료 발급하던 경제 누수 차단 — 유료 상품은 반드시
      // amulets/purchase(지갑 차감) 경로를 사용하도록 강제한다.
      if (base.pricePoint > 0) throw new Error("PAID_ITEM");

      const userAmulet = await tx.userAmulet.create({
        data: {
          userId,
          amuletItemId: base.id,
          sourceType: "purchase",
          status: "held",
        },
      });

      await tx.aiRequestLog.create({
        data: {
          domain: "amulet",
          requestRefId: userAmulet.id,
          aiModel: "rule-based-v1",
          status: "success",
        },
      });

      return { userAmulet, base };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `ua_${outcome.userAmulet.id}`,
          itemId: `am_${outcome.base.id}`,
          itemName: outcome.base.name,
          status: outcome.userAmulet.status,
          acquiredAt: outcome.userAmulet.acquiredAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 상품입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "NOT_AI_GENERATED") {
      return NextResponse.json(
        { success: false, error: "AI 생성 가능한 상품이 아닙니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    if (message === "PAID_ITEM") {
      return NextResponse.json(
        { success: false, error: "구매가 필요한 부적입니다. 상점에서 구매해 주세요." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    // [경제 감사 2026-10-12 M-5] 항목당 1회 유니크 제약(@@unique) 충돌을
    // 명시적으로 409로 매핑한다 — 기존에는 catch-all 500으로 새어나갔다.
    if (typeof e === "object" && e !== null && (e as { code?: string }).code === "P2002") {
      return NextResponse.json(
        { success: false, error: "이미 보유한 부적입니다." },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/amulets/generate] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 생성 처리 중 오류가 발생했습니다." },
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
