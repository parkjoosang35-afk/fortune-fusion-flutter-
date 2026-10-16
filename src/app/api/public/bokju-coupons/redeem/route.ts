// [복주머니 마케팅 쿠폰] POST /api/public/bokju-coupons/redeem — 심장부.
//
// QR/링크로 받은 redeemToken을 실제로 "등록"해 복주머니를 적립받는 유일한 엔드포인트.
// 바디: { token: string, idempotencyKey?: string }
// 헤더: Idempotency-Key(선택) — 바디의 idempotencyKey와 둘 다 지원하되 헤더를 우선한다
// (네트워크 재시도 시 클라이언트가 동일 키로 재전송하면 재지급 없이 최초 결과를 반환).
// idempotencyKey를 아예 안 보내면 서버가 즉석 발급한다(순수 偶发 네트워크 재시도까지는
// 못 막지만, 쿠폰 자체의 상태 전이(rowVersion 조건부 UPDATE)가 이중 적립의 최종
// 방어선이므로 안전하다 — bokju-coupon-service.ts의 낙관적 락 설계 참고).
import { randomUUID } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse, CORS_HEADERS } from "../../wishes/_shared";
import { redeemCoupon, BokjuCouponError } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

const NEW_MEMBER_WINDOW_DAYS = 7;
function isNewMember(createdAt: Date): boolean {
  const diffMs = Date.now() - createdAt.getTime();
  return diffMs <= NEW_MEMBER_WINDOW_DAYS * 24 * 60 * 60 * 1000;
}

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { token?: string; idempotencyKey?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const token = typeof body.token === "string" ? body.token.trim() : "";
  if (!token) {
    return NextResponse.json({ success: false, error: "token은 필수입니다." }, { status: 400, headers: CORS_HEADERS });
  }

  // 헤더 우선, 없으면 바디, 그것도 없으면 서버가 즉석 발급(이 경우 "이 요청 1건" 범위에서만
  // 멱등 — 애초에 클라이언트가 재시도 안전성을 원하면 반드시 키를 보내야 한다).
  const idempotencyKey =
    request.headers.get("Idempotency-Key") || body.idempotencyKey || randomUUID();

  try {
    const user = await prisma.user.findUnique({ where: { id: auth.userId }, select: { createdAt: true } });
    const newMember = user ? isNewMember(user.createdAt) : false;

    const result = await redeemCoupon({
      userId: auth.userId,
      token,
      idempotencyKey,
      isNewMember: newMember,
    });

    if (!result.ok) {
      // 비즈니스 실패(이미 사용됨/만료/대상 아님 등)는 200이 아닌 409/400으로 구분해
      // 클라이언트가 "네트워크 에러"와 "쿠폰 자체가 유효하지 않음"을 분리 처리할 수 있게 한다.
      const status = ["ALREADY_USED", "DUPLICATE"].includes(result.code)
        ? 409
        : result.code === "NOT_TARGET" || result.code === "LIMIT_EXCEEDED"
          ? 403
          : result.code === "RATE_LIMITED"
            ? 429
            : 400;
      return NextResponse.json(
        { success: false, code: result.code, error: result.message },
        { status, headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          grantedAmount: result.grantedAmount,
          balanceAfter: result.balanceAfter,
          couponNoMasked: result.couponNoMasked,
          redeemedAt: result.redeemedAt,
          replayed: result.replayed,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (e instanceof BokjuCouponError) {
      const status = e.code === "WALLET_DAILY_CAP_REACHED" || e.code === "RATE_LIMITED" ? 429 : 400;
      return NextResponse.json(
        { success: false, code: e.code, error: e.message },
        { status, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/bokju-coupons/redeem] 실패:", e);
    return NextResponse.json(
      { success: false, error: "쿠폰 등록 처리 중 오류가 발생했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization, Idempotency-Key",
    },
  });
}
