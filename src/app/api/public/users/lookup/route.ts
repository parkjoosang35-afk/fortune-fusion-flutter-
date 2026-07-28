// 공개(비인증) "닉네임 -> userId" 조회 API — Flutter 앱의 "복 나누기(송금)" 대상 선택에 사용.
//
// [Phase22-3 - 커뮤니티 화면에 "복 나누기" 출구버튼 삽입] 소원게시판/부적 선물 화면은
// 작성자를 닉네임(문자열)으로만 표시하고 있어, wallet/send API가 요구하는 정수 userId를
// 직접 알 수 없다. 이 API는 닉네임으로 활성 유저의 id/nickname만 조회해 클라이언트가
// sendBok() 호출 전에 toUserId를 확보할 수 있게 한다.
//
// [범위 제한] status가 'active'인 유저만 반환한다(탈퇴/정지 계정으로는 송금 불가).
// 자기 자신(userId=1, 방법A 고정 테스트유저)을 조회하면 SELF 에러를 별도로 구분해
// 클라이언트가 "본인에게는 보낼 수 없다"는 메시지를 바로 보여줄 수 있게 한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate",
  "Access-Control-Allow-Origin": "*",
};

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const nickname = searchParams.get("nickname")?.trim();

  if (!nickname) {
    return NextResponse.json(
      { success: false, error: "nickname 파라미터가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const user = await prisma.user.findUnique({
      where: { nickname },
      select: { id: true, nickname: true, status: true },
    });

    if (!user || user.status !== "active") {
      return NextResponse.json(
        { success: false, error: "해당 닉네임의 활동 중인 유저를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      { success: true, data: { userId: user.id, nickname: user.nickname } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/users/lookup] 실패:", e);
    return NextResponse.json(
      { success: false, error: "유저 조회 중 오류가 발생했습니다." },
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
