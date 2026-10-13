// 공개(비인증) 파트너 제휴 알림패스 발급 API — Flutter PassRepository.claimPartner() 대응.
// 제휴 랜딩(linkUrl) 방문 완료 콜백 시 호출. claim-ad와 동일한 발급 로직이나
// passType="partner" 정책을 사용한다(문서3 정책표: 3시간, 1일 1회, 보너스 10P).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { countPassGrantFields, OpenPassServiceError } from "@/lib/open-pass-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; policyId?: number };
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

  try {
    const policy = body.policyId
      ? await prisma.passPolicy.findFirst({
          where: {
            id: Number(body.policyId),
            passType: "partner",
            isActive: true,
            deletedAt: null,
          },
        })
      : await prisma.passPolicy.findFirst({
          where: { passType: "partner", isActive: true, deletedAt: null },
          orderBy: { id: "asc" },
        });

    if (!policy) {
      return NextResponse.json(
        { success: false, error: "활성화된 파트너 프리패스 정책이 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // [경제 감사 2026-10-12 M-4] 일일 한도 체크를 트랜잭션 밖에서 읽던 기존
    // 구조는 병렬 요청이 모두 count=0을 읽고 각각 발급받는 경합이 있었다.
    // 체크를 발급과 같은 트랜잭션 안으로 이동한다(SQLite 단일 쓰기 직렬화와
    // 결합해 체크-생성이 원자적으로 처리된다).
    const result = await prisma.$transaction(async (tx) => {
      if (policy.dailyLimit != null) {
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayCount = await tx.userPass.count({
          where: { userId, policyId: policy.id, createdAt: { gte: todayStart } },
        });
        if (todayCount >= policy.dailyLimit) {
          throw new Error("DAILY_LIMIT_EXCEEDED");
        }
      }
      const now = new Date();
      const grantFields = countPassGrantFields(policy, now);
      const expiresAt = grantFields.expiresAt;

      const userPass = await tx.userPass.create({
        data: {
          userId,
          policyId: policy.id,
          activatedAt: now,
          ...grantFields,
          sourceType: "partner",
        },
      });

      // [재화 구조 정리] 프리패스 지급 시 상시 복주머니 적립은 붙이지 않는다(제거됨).
      await tx.operationLog.create({
        data: {
          actorType: "user",
          actorId: userId,
          action: "claim_partner_pass",
          targetType: "user_pass",
          targetId: userPass.id,
          before: null,
          after: JSON.stringify({ policyId: policy.id, expiresAt: expiresAt.toISOString() }),
        },
      });

      return { userPass, expiresAt };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          userPassId: result.userPass.id,
          grantedCount: result.userPass.grantedCount,
          remainingCount: result.userPass.remainingCount,
          policyId: policy.id,
          policyName: policy.name,
          expiresAt: result.expiresAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (e instanceof OpenPassServiceError) {
      return NextResponse.json({ success: false, error: e.message, code: e.code }, { status: 409, headers: CORS_HEADERS });
    }
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "DAILY_LIMIT_EXCEEDED") {
      return NextResponse.json(
        { success: false, error: "오늘의 파트너 프리패스 발급 한도를 초과했습니다." },
        { status: 429, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/pass/claim-partner] 실패:", e);
    return NextResponse.json(
      { success: false, error: "파트너 프리패스 발급 중 오류가 발생했습니다." },
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
