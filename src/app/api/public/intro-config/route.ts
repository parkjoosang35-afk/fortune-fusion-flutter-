// 공개(비인증) 인트로 설정 조회 API — Flutter IntroConfigRepository 대응.
//
// [인트로 전면 개편] IntroConfig는 싱글턴 row(id=1)이며, 관리자가 최소 항목
// (on/off, 첫실행노출, 스킵버튼, 카피, 이미지, 가입보상 문구/수량)만 수정할 수 있다.
// row가 아직 없으면(seed 누락 등) 클라이언트가 하드코딩 기본값으로 폴백할 수 있도록
// success:false + 404를 반환한다(HomeConfigCacheStore와 동일한 폴백 패턴).
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  try {
    const config = await prisma.introConfig.findUnique({ where: { id: 1 } });
    if (!config) {
      return NextResponse.json(
        { success: false, error: "인트로 설정이 아직 초기화되지 않았습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          isEnabled: config.isEnabled,
          showOnlyFirstLaunch: config.showOnlyFirstLaunch,
          showSkipButton: config.showSkipButton,
          showGuestHint: config.showGuestHint,
          splashTitle: config.splashTitle,
          splashSubtitle: config.splashSubtitle,
          card1Title: config.card1Title,
          card1Description: config.card1Description,
          card1ImageUrl: config.card1ImageUrl,
          card2Title: config.card2Title,
          card2Description: config.card2Description,
          card2ImageUrl: config.card2ImageUrl,
          ctaTitle: config.ctaTitle,
          ctaSubtitle: config.ctaSubtitle,
          signupRewardText: config.signupRewardText,
          signupRewardAmount: config.signupRewardAmount,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e: unknown) {
    console.error("[GET /api/public/intro-config] 실패:", e);
    return NextResponse.json(
      { success: false, error: "인트로 설정 조회 중 오류가 발생했습니다." },
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
