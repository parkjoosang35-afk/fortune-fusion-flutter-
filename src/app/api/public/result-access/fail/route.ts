// 공개(인증 필요) "결과보기 실패 환불" API — §8.6과 동일한 원칙을, 서버 AI
// 생성 단계 자체가 없는 콘텐츠(예: 정통사주 69종의 클라이언트 로컬 계산)에도
// 적용하기 위한 얇은 래퍼다. transaction_id 기준으로 status가 여전히
// "pending"인 경우에만 복구를 수행하고, 이미 종결된 거래는 그대로 둔다
// (failAndRefundResultAccess 내부에서 이미 보장 — 중복 복구 방지, §14.8).
import { NextRequest, NextResponse } from "next/server";
import { failAndRefundResultAccess, findResultAccessTransaction } from "@/lib/result-access-service";
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

    await failAndRefundResultAccess(transactionId);
    return NextResponse.json({ success: true }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/result-access/fail] 실패:", e);
    return NextResponse.json(
      { success: false, error: "결과보기 실패 처리 중 오류가 발생했습니다." },
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
