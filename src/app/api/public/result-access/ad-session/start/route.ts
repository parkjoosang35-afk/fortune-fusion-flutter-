// 공개(인증 필요) "결과보기 광고 시청 세션 시작" API.
// [결과보기 통합 권한 시스템 v1.0, Phase4] §8.3 "광고면 광고 완료 상태를 서버
// 기준으로 확인한다"를 만족시키기 위한 신규 API. fortune-ad-service.ts의
// /api/ads/[adId]/start와 동일한 패턴(PENDING 세션 발급 → 클라이언트가 실제로
// 광고를 끝까지 본 뒤에만 /complete 호출)이나, 이 세션은 "결과보기 무료 이용권"
// 자격 증명 전용이라 FortuneAdWatchLog(복주머니 적립용)와는 별도 테이블을 쓴다.
//
// [범위] 여기서는 어떤 자산도 지급/차감하지 않는다 — 오직 "이 사용자가 방금
// 광고 시청을 시작했다"는 PENDING 세션만 발급한다. 실제 결과보기 승인은
// beginResultAccess(paymentMethod=AD, adSessionId)가 이 세션의 최종 상태를
// 다시 조회해서 판단한다.
import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;

  try {
    const sessionId = randomUUID();
    const session = await prisma.resultAccessAdSession.create({
      data: { userId, sessionId, status: "pending" },
    });
    return NextResponse.json(
      { success: true, data: { sessionId: session.sessionId } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/result-access/ad-session/start] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 세션을 시작하지 못했습니다." },
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
