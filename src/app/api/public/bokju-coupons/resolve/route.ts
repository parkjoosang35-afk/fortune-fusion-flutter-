// [복주머니 마케팅 쿠폰] GET /api/public/bokju-coupons/resolve?token=...
// QR 스캔/딥링크 직후, 실제 등록(redeem) 전에 쿠폰 정보를 미리 보여주기 위한
// 비파괴 조회(쿠폰 상태를 변경하지 않음). Flutter 앱이 "등록하기" 버튼을 보여주기
// 전에 캠페인명/지급액/안내문구/현재 사용 가능 여부를 먼저 확인하는 용도.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse, CORS_HEADERS } from "../../wishes/_shared";
import { findCouponByIdentifier } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

/** [신규회원 판정 기준] 이 프로젝트 전역에 "신규회원" 공식 정의가 없어(가입 축하 쿠폰
 * 대상 판정 용도로) 가입 후 7일 이내를 신규로 간주한다. 추후 공식 기준이 생기면
 * 이 상수만 교체하면 된다(다른 곳에 복붙 없이 이 라우트 + redeem/route.ts 2곳만 참조). */
const NEW_MEMBER_WINDOW_DAYS = 7;

function isNewMember(createdAt: Date): boolean {
  const diffMs = Date.now() - createdAt.getTime();
  return diffMs <= NEW_MEMBER_WINDOW_DAYS * 24 * 60 * 60 * 1000;
}

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const token = request.nextUrl.searchParams.get("token");
  if (!token) {
    return NextResponse.json({ success: false, error: "token은 필수입니다." }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    // [쿠폰번호 간소화 — 구조적 버그 수정] QR의 redeemToken뿐 아니라 쿠폰
    // 이미지에 인쇄된 couponNo(수동 입력)로도 동일하게 조회되도록 공용
    // 헬퍼를 사용한다 — bokju-coupon-service.ts의 findCouponByIdentifier
    // 문서 주석 참고.
    const coupon = await findCouponByIdentifier(prisma, token);
    if (!coupon) {
      return NextResponse.json(
        { success: false, error: "존재하지 않거나 사용할 수 없는 쿠폰입니다.", code: "COUPON_NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const user = await prisma.user.findUnique({ where: { id: auth.userId }, select: { createdAt: true } });
    const newMember = user ? isNewMember(user.createdAt) : false;

    const now = new Date();
    let redeemable = true;
    let reasonIfNot: string | null = null;
    if (coupon.campaign.status === "PAUSED" || coupon.campaign.status === "CLOSED") {
      redeemable = false;
      reasonIfNot = "중지된 이벤트의 쿠폰입니다.";
    } else if (coupon.status === "REDEEMED") {
      redeemable = false;
      reasonIfNot = "이미 등록된 쿠폰입니다.";
    } else if (["REVOKED", "RECALLED"].includes(coupon.status)) {
      redeemable = false;
      reasonIfNot = "사용이 중지되었거나 회수된 쿠폰입니다.";
    } else if (coupon.status === "EXPIRED" || coupon.expiresAt <= now) {
      redeemable = false;
      reasonIfNot = "사용 기간이 만료된 쿠폰입니다.";
    } else if (!["ISSUED", "ALLOCATED", "DELIVERED", "ASSIGNED"].includes(coupon.status)) {
      redeemable = false;
      reasonIfNot = "아직 등록할 수 없는 쿠폰입니다.";
    } else if (coupon.assignedUserId && coupon.assignedUserId !== auth.userId) {
      redeemable = false;
      reasonIfNot = "본인에게 배정된 쿠폰이 아닙니다.";
    } else if (coupon.campaign.targetAudience === "NEW" && !newMember) {
      redeemable = false;
      reasonIfNot = "신규 회원 전용 쿠폰입니다.";
    } else if (coupon.campaign.targetAudience === "EXISTING" && newMember) {
      redeemable = false;
      reasonIfNot = "기존 회원 전용 쿠폰입니다.";
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          campaignTitle: coupon.campaign.title,
          grantAmount: coupon.campaign.grantAmount,
          guideText: coupon.campaign.guideText,
          issueType: coupon.campaign.issueType,
          validTo: coupon.campaign.validTo.toISOString(),
          redeemable,
          reasonIfNot,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/bokju-coupons/resolve] 실패:", e);
    return NextResponse.json(
      { success: false, error: "쿠폰 조회 중 오류가 발생했습니다." },
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
