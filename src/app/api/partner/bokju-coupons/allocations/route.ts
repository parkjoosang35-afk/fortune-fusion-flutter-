// [복주머니 마케팅 쿠폰] GET /api/partner/bokju-coupons/allocations
// 로그인한 업체 본인에게 배정된 건만 조회(partnerId는 세션에서만 결정 — 클라이언트 입력 불신).
import { NextResponse } from "next/server";
import { requirePartnerOrResponse, isPartnerSession } from "@/lib/partner-session";
import { listMyAllocations, type PartnerScope } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  const session = await requirePartnerOrResponse();
  if (!isPartnerSession(session)) return session;

  const scope: PartnerScope = { partnerId: session.partnerId, accountId: session.accountId, role: session.role };

  try {
    const allocations = await listMyAllocations(scope);
    return NextResponse.json(
      {
        success: true,
        data: {
          allocations: allocations.map((a) => ({
            ...a,
            deliveredAt: a.deliveredAt ? a.deliveredAt.toISOString() : null,
            acknowledgedAt: a.acknowledgedAt ? a.acknowledgedAt.toISOString() : null,
            distributeDeadline: a.distributeDeadline ? a.distributeDeadline.toISOString() : null,
          })),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/partner/bokju-coupons/allocations] 실패:", e);
    return NextResponse.json(
      { success: false, error: "배정 목록 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}
