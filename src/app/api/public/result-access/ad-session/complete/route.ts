// 공개(인증 필요) "결과보기 광고 시청 세션 완료" API.
// [결과보기 통합 권한 시스템 v1.0, Phase4] 클라이언트는 AdMob RewardedAd의
// onUserEarnedReward 콜백이 실제로 호출된 뒤에만(즉 광고를 끝까지 시청했다는
// AdMob SDK의 공식 완료 신호를 받은 뒤에만) 이 API를 호출해야 한다. 중도
// 종료/닫기/오류 시에는 절대 호출하지 않는다(§5 "중도 종료 시 권한 승인하지
// 않음"). 이 API를 호출하지 않으면 세션은 pending 상태로 남아 beginResultAccess가
// 영원히 거부한다 — 별도의 "타임아웃 실패 처리"가 없어도 안전하다(미완료 세션은
// 그냥 소비되지 않을 뿐이다).
//
// PENDING → COMPLETED 원자적 전환(updateMany where status=PENDING)으로,
// 동시에 두 번 호출되어도 한 번만 완료 처리된다(§8.4 멱등성과 동일한 원자적 패턴,
// fortune-ad-service.ts의 /complete와 동일 기법).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;

  let body: { sessionId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const sessionId = body.sessionId?.trim();
  if (!sessionId) {
    return NextResponse.json(
      { success: false, error: "sessionId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const session = await prisma.resultAccessAdSession.findUnique({ where: { sessionId } });
    if (!session || session.userId !== userId) {
      return NextResponse.json(
        { success: false, error: "광고 세션을 찾을 수 없습니다. 처음부터 다시 시도해주세요." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    if (session.status === "pending") {
      await prisma.resultAccessAdSession.updateMany({
        where: { id: session.id, status: "pending" },
        data: { status: "completed", completedAt: new Date() },
      });
    }
    // 이미 completed/consumed였어도 그대로 성공 응답(idempotent) — 재호출로
    // 상태가 역행하지 않는다.

    return NextResponse.json({ success: true, data: { sessionId } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/result-access/ad-session/complete] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 세션 완료 처리 중 오류가 발생했습니다." },
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
