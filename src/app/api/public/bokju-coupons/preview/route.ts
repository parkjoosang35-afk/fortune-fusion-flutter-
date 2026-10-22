// [2026-10-22, 쿠폰 링크 미리보기 노출 수정 — 사용자 명시 지적]
// "카카오톡을 보냈는데 쿠폰이 보여야지, 이 사람들이 들어와서 무슨 내용인지
// 알아야 회원가입을 해서 쿠폰등록을 할 것 아니야" — 기존 `/coupon/{token}`
// 랜딩페이지는 마운트 즉시 Flutter 앱으로 강제 리다이렉트했고, 앱도 로그인
// 여부부터 확인해 비로그인 상태면 쿠폰 내용을 전혀 보여주지 않고 바로 로그인
// 화면으로 보냈다 — 받은 사람이 "이게 뭔지" 전혀 모른 채 회원가입부터
// 강요당하는 구조였다(`/g/[token]` 귀인지도 랜딩이 2026-09에 동일한 문제를
// 겪고 "콘텐츠가 먼저 보여야 한다" 원칙으로 수정된 선례와 정확히 같은 버그).
//
// 기존 `GET /api/public/bokju-coupons/resolve`는 `requireUser()`로 로그인을
// 강제하므로(Flutter 앱의 실제 등록 전 조회용 — 신규/기존회원 판정과 본인
// 배정 여부까지 확인), 이 공개 랜딩페이지에서 재사용할 수 없다. 그 엔드포인트
// 자체는 건드리지 않고(앱이 이미 쓰고 있음), 익명 방문자도 "무엇을 받았는지"
// 수준의 정보만 가볍게 확인할 수 있는 새 공개(비인증) 엔드포인트를 신설한다.
//
// [정보 노출 원칙] 캠페인명/지급액/안내문구/유효기간/일반 상태만 보여준다.
// 이 토큰 보유자가 "본인에게 배정된 쿠폰인지", "신규/기존회원 대상인지" 같은
// 사용자별 최종 판정은 여전히 로그인 후 앱의 resolve/redeem에서만 이뤄진다
// (이 라우트는 최종 등록 가능 여부를 보증하지 않는다 — "미리보기"일 뿐).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { findCouponByIdentifier } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get("token");
  if (!token) {
    return NextResponse.json(
      { success: false, error: "token은 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const coupon = await findCouponByIdentifier(prisma, token);
    if (!coupon) {
      return NextResponse.json(
        { success: false, error: "존재하지 않거나 사용할 수 없는 쿠폰입니다.", code: "COUPON_NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const now = new Date();
    // [일반 상태만 판정 — 사용자별 판정은 로그인 후로 미룬다]
    let generalStatus: "available" | "redeemed" | "unavailable" = "available";
    let statusMessage: string | null = null;
    if (coupon.campaign.status === "PAUSED" || coupon.campaign.status === "CLOSED") {
      generalStatus = "unavailable";
      statusMessage = "지금은 진행하지 않는 이벤트예요.";
    } else if (coupon.status === "REDEEMED") {
      generalStatus = "redeemed";
      statusMessage = "이미 등록이 완료된 쿠폰이에요.";
    } else if (["REVOKED", "RECALLED"].includes(coupon.status)) {
      generalStatus = "unavailable";
      statusMessage = "사용이 중지된 쿠폰이에요.";
    } else if (coupon.status === "EXPIRED" || coupon.expiresAt <= now) {
      generalStatus = "unavailable";
      statusMessage = "사용 기간이 지난 쿠폰이에요.";
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          campaignTitle: coupon.campaign.title,
          grantAmount: coupon.campaign.grantAmount,
          guideText: coupon.campaign.guideText,
          validTo: coupon.campaign.validTo.toISOString(),
          generalStatus,
          statusMessage,
          // [2026-10-22, 디자인 핸드오프 반영] 실제 쿠폰 번호 노출.
          // 이 라우트는 `token`(redeemToken) 하나만 알아도 조회되므로
          // 토큰 소유자는 이미 이 쿠폰을 "실질적으로 보유"한 상태다
          // (관리자 쿠폰 목록 API가 couponNo를 마스킹하는 것과는 다른
          // 맥락 — 거기는 "누가 봐도 되는지" 모르는 불특정 열람이지만,
          // 여기는 카카오 공유로 "이 쿠폰을 전달받은 바로 그 사람"만
          // 아는 토큰이 있어야 도달한다). 디자인 목업의 가짜 시리얼
          // "SAMPLE-0000-0000" 자리를 이 실제 값으로 교체한다.
          couponNo: coupon.couponNo,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/bokju-coupons/preview] 실패:", e);
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
