// 공개(인증 필요) "결과보기 권한 확정" API — §8.5 "결제 확정 후 AI 생성" 순서의
// 첫 단계. Flutter가 3택 UI에서 결제수단을 선택하면 AI 생성을 시작하기 "전에" 이
// API를 호출해 서버가 실제로 차감(FREEPASS -1 / POUCH -100)까지 완료한다.
//
// [범위] 이 API는 ResultAccessService.beginResultAccess()만 호출하는 얇은 래퍼다.
// 콘텐츠별 전용 로직(saju/tarot/name/...)은 여기서 다루지 않는다 — 각 콘텐츠
// route.ts가 자신의 AI 생성 로직 "앞"에서 이 API와 동등한 서버 함수
// (beginResultAccess)를 직접 호출하는 것이 최종 통합 형태이며, 이 공개 API는
// Flutter가 결제수단 선택 화면에서 사전 확정을 원할 때(또는 서버-서버 통합 전
// 단계 검증용으로) 사용할 수 있는 동일 기능의 공개 엔드포인트다.
import { NextRequest, NextResponse } from "next/server";
import {
  beginResultAccess,
  ResultAccessError,
  type ResultAccessPaymentMethod,
} from "@/lib/result-access-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const VALID_METHODS: ResultAccessPaymentMethod[] = ["FREEPASS", "POUCH", "AD"];

const ERROR_STATUS: Record<string, number> = {
  NO_FREEPASS_BALANCE: 403,
  INSUFFICIENT_POUCH_BALANCE: 409,
  INVALID_PAYMENT_METHOD: 400,
  TRANSACTION_OWNER_MISMATCH: 400,
  AD_SESSION_REQUIRED: 400,
  AD_SESSION_NOT_FOUND: 404,
  AD_SESSION_NOT_COMPLETED: 409,
  AD_SESSION_ALREADY_USED: 409,
};

const ERROR_MESSAGE: Record<string, string> = {
  NO_FREEPASS_BALANCE: "사용 가능한 프리패스가 없습니다.",
  INSUFFICIENT_POUCH_BALANCE: "보유한 복주머니가 부족합니다.",
  INVALID_PAYMENT_METHOD: "잘못된 결제수단입니다.",
  TRANSACTION_OWNER_MISMATCH: "잘못된 요청입니다.",
  AD_SESSION_REQUIRED: "광고 시청 세션 정보가 없습니다.",
  AD_SESSION_NOT_FOUND: "광고 시청 세션을 찾을 수 없습니다.",
  AD_SESSION_NOT_COMPLETED: "광고 시청이 완료되지 않았습니다.",
  AD_SESSION_ALREADY_USED: "이미 사용된 광고 시청 세션입니다.",
};

export async function POST(request: NextRequest) {
  let body: {
    transactionId?: string;
    contentType?: string;
    contentId?: string;
    categoryKey?: string;
    paymentMethod?: string;
    adSessionId?: string;
  };
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
  const contentType = body.contentType?.trim();
  const paymentMethod = body.paymentMethod as ResultAccessPaymentMethod | undefined;

  if (!transactionId) {
    return NextResponse.json(
      { success: false, error: "transactionId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!contentType) {
    return NextResponse.json(
      { success: false, error: "contentType은 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!paymentMethod || !VALID_METHODS.includes(paymentMethod)) {
    return NextResponse.json(
      { success: false, error: "paymentMethod는 FREEPASS/POUCH/AD 중 하나여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await beginResultAccess({
      userId,
      transactionId,
      contentType,
      contentId: body.contentId ?? null,
      categoryKey: body.categoryKey ?? null,
      paymentMethod,
      adSessionId: body.adSessionId ?? null,
    });
    return NextResponse.json({ success: true, data: result }, { headers: CORS_HEADERS });
  } catch (e) {
    if (e instanceof ResultAccessError) {
      return NextResponse.json(
        { success: false, error: ERROR_MESSAGE[e.code] ?? e.message, reason: e.code },
        { status: ERROR_STATUS[e.code] ?? 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/result-access/begin] 실패:", e);
    return NextResponse.json(
      { success: false, error: "결과보기 권한 확인 중 오류가 발생했습니다." },
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
