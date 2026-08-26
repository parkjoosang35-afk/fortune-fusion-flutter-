// 공개(비인증) 상담 완료 후기 작성 API — 복주머니 정책표 §3 "상담 완료 후기 작성: 5개,
// 상담 1건당 1회" 대응.
//
// [설계] consultation_reviews.session_id를 UNIQUE로 강제해 "상담 1건당 1회"를 DB 레벨에서
// 보장한다(중복 작성 시도는 P2002로 감지해 409 응답). 추가로 checkPolicyEligibility()의
// sourceId=sessionId 체크로 PointHistory 레벨에서도 이중 방어한다(둘 중 하나가 실패해도
// 나머지가 막아준다 — 방어적 이중화).
//
// [인증 임시 방편] 아직 로그인 세션 미들웨어가 없으므로 userId를 바디로 받는다(기본값 1).
import { NextRequest, NextResponse } from "next/server";
import { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db";
import { earnLuckPouch, checkPolicyEligibility } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; sessionId?: number; content?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const sessionId = Number(body.sessionId);
  const content = body.content?.trim();

  if (!Number.isInteger(sessionId) || sessionId <= 0) {
    return NextResponse.json(
      { success: false, error: "sessionId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!content) {
    return NextResponse.json(
      { success: false, error: "후기 내용을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const session = await prisma.consultationSession.findUnique({
      where: { id: sessionId },
    });
    if (!session || session.userId !== userId) {
      return NextResponse.json(
        { success: false, error: "상담 세션을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const result = await prisma.$transaction(async (tx) => {
      // 1) 후기 레코드 생성 (session_id UNIQUE 제약으로 중복 작성 자체를 DB가 차단)
      const review = await tx.consultationReview.create({
        data: { sessionId, userId, content },
      });

      // 2) 정책 가드: sourceId=sessionId로 이미 review_reward가 지급됐는지 재확인(이중 방어)
      const elig = await checkPolicyEligibility(tx, userId, "review_reward", {
        scope: "lifetime",
        sourceId: sessionId,
      });

      if (!elig.eligible) {
        return { review, rewardGranted: false, balanceAfter: null as number | null, amount: 0 };
      }

      const policy = await tx.pointPolicy.findUnique({ where: { sourceType: "review_reward" } });
      const amount = policy?.isActive === false ? 0 : policy?.amount ?? 5;
      if (amount <= 0) {
        return { review, rewardGranted: false, balanceAfter: null as number | null, amount: 0 };
      }

      const earnOutcome = await earnLuckPouch(tx, {
        userId,
        amount,
        sourceType: "review_reward",
        sourceId: sessionId,
        memo: `상담 완료 후기 작성 보상 +${amount} 복주머니`,
      });

      await tx.consultationReview.update({
        where: { id: review.id },
        data: { rewardGranted: true },
      });

      return { review, rewardGranted: true, balanceAfter: earnOutcome.balanceAfter, amount };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          reviewId: result.review.id,
          rewardGranted: result.rewardGranted,
          rewardAmount: result.amount,
          balanceAfter: result.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e: unknown) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      return NextResponse.json(
        { success: false, error: "이미 이 상담에 대한 후기를 작성했습니다.", code: "ALREADY_REVIEWED" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/consultation/review] 실패:", e);
    return NextResponse.json(
      { success: false, error: "후기 등록 중 오류가 발생했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
