// 공개(인증 필요) "결과보기 완료 확정" API — §8.5/§8.6 순서에서 서버 API를
// 전혀 호출하지 않는 콘텐츠(예: 정통사주 69종 — 클라이언트 로컬
// JeontongReportCache.getOrBuild()로 즉시 결과를 생성)를 위한 얇은 래퍼다.
//
// [범위] saju/tarot/name/face/palm처럼 자체 fortune/{type}/route.ts가 있는
// 콘텐츠는 그 라우트 내부에서 completeResultAccess()를 직접 호출하므로 이
// API를 쓰지 않는다 — 이 API는 서버 AI 생성 단계 자체가 없는 콘텐츠 전용이다.
// fortuneRequestId는 항상 null로 넘긴다(FortuneRequest 레코드가 없음).
import { NextRequest, NextResponse } from "next/server";
import { completeResultAccess, findResultAccessTransaction } from "@/lib/result-access-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { transactionId?: string };
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

  const transactionId = body.transactionId?.trim();
  if (!transactionId) {
    return NextResponse.json(
      { success: false, error: "transactionId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const txn = await findResultAccessTransaction(transactionId);
    if (!txn) {
      return NextResponse.json(
        { success: false, error: "결과보기 거래를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (txn.userId !== userId) {
      return NextResponse.json(
        { success: false, error: "잘못된 요청입니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    await completeResultAccess(transactionId, null);
    return NextResponse.json({ success: true }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/result-access/complete] 실패:", e);
    return NextResponse.json(
      { success: false, error: "결과보기 완료 처리 중 오류가 발생했습니다." },
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
