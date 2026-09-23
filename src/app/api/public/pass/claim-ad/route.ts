// 공개(비인증) 광고 시청 프리패스 발급 API — Flutter PassRepository.claimAd() 대응.
// 광고 시청 완료 콜백 시 호출: passType="ad" 정책을 조회해 UserPass를 발급한다.
// [재화 구조 정리] 프리패스는 순수 시간제 이용권이므로 지급 시 상시 복주머니 적립을
// 붙이지 않는다(과거 policy.bonusPoint 자동 지급 블록 제거).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
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
          where: { id: Number(body.policyId), passType: "ad", isActive: true, deletedAt: null },
        })
      : await prisma.passPolicy.findFirst({
          where: { passType: "ad", isActive: true, deletedAt: null },
          orderBy: { id: "asc" },
        });

    if (!policy) {
      return NextResponse.json(
        { success: false, error: "활성화된 광고 프리패스 정책이 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // [프리패스 "시간이 안 들어가요" 버그 수정 — 2026-09-23]
    // 기존 코드는 "이미 유효한(만료되지 않은) 프리패스가 있으면 무조건
    // 새로 발급하지 않고 기존 만료시각을 그대로 반환"했다. 이 안전장치는
    // 원래 "앱 라이프사이클 이벤트가 짧은 시간 안에 중복 발생해 claim-ad가
    // 두 번 연속 호출되는 것"만 막으려던 것이었는데, 조건이 너무 넓어서
    // "몇 시간 전에 광고를 보고 받은 패스가 아직 남아있는 상태에서, 사용자가
    // 광고를 한 번 더 보고 프리패스를 충전하려는" 정상적인 재시청까지
    // 전부 막아버렸다. 그 결과 Flutter 앱은 "지급 완료" 화면을 보여주지만
    // 실제 만료시각은 1초도 늘어나지 않는 버그가 발생했다(사용자 리포트:
    // "프리패스 시간이 안 들어가잖아").
    //
    // 이제는 "몇 초 안의 진짜 중복 호출"만 멱등 처리하도록 범위를 크게
    // 좁힌다: 같은 정책으로 방금(idempotencyWindow 이내) 발급된 UserPass가
    // 있을 때만 그 건을 그대로 반환하고, 그 외(=정상적인 재시청 충전
    // 요청)에는 항상 새로 발급해 만료시각이 뒤로 늘어나게 한다.
    const now0 = new Date();
    const idempotencyWindowMs = 5000; // 5초 — 중복 클릭/생명주기 중복 이벤트 방어용
    const recentDuplicate = await prisma.userPass.findFirst({
      where: {
        userId,
        policyId: policy.id,
        createdAt: { gte: new Date(now0.getTime() - idempotencyWindowMs) },
      },
      orderBy: { id: "desc" },
    });
    if (recentDuplicate) {
      return NextResponse.json(
        {
          success: true,
          data: {
            userPassId: recentDuplicate.id,
            policyId: recentDuplicate.policyId,
            policyName: policy.name,
            expiresAt: recentDuplicate.expiresAt.toISOString(),
            idempotent: true,
          },
        },
        { headers: CORS_HEADERS }
      );
    }

    // 1일 발급 한도 체크(dailyLimit이 있는 경우)
    if (policy.dailyLimit != null) {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayCount = await prisma.userPass.count({
        where: { userId, policyId: policy.id, createdAt: { gte: todayStart } },
      });
      if (todayCount >= policy.dailyLimit) {
        return NextResponse.json(
          { success: false, error: "오늘의 광고 프리패스 발급 한도를 초과했습니다." },
          { status: 429, headers: CORS_HEADERS }
        );
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      const now = new Date();
      const expiresAt = new Date(now.getTime() + policy.durationMin * 60 * 1000);

      const userPass = await tx.userPass.create({
        data: {
          userId,
          policyId: policy.id,
          activatedAt: now,
          expiresAt,
          sourceType: "ad",
        },
      });

      await tx.operationLog.create({
        data: {
          actorType: "user",
          actorId: userId,
          action: "claim_ad_pass",
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
          policyId: policy.id,
          policyName: policy.name,
          expiresAt: result.expiresAt.toISOString(),
          idempotent: false,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/pass/claim-ad] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 프리패스 발급 중 오류가 발생했습니다." },
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
