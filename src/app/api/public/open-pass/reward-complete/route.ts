// 공개(비인증) 열림패스 광고 보상 완료 콜백 — Flutter OpenPassRewardController.onAdRewardSuccess() 대응.
// [사용자 요청] §7/§9/§16 완료기준 "광고 성공 시 실제로 열림패스가 지급되어야 한다"
// admin-simulation.ts의 adminSimulateAdRewardSuccess와 완전히 동일한 그랜트 로직
// (open-pass-service.ts의 grantOpenPass/checkAdRewardEligibility/recordAdRewardLog)을
// 그대로 재사용한다 — 관리자 테스트와 실제 앱 동작이 갈라지지 않는다(§15).
// idempotencyKey로 중복 지급을 방지한다(§13 QA "중복 보상 지급 방지").
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  grantOpenPass,
  checkAdRewardEligibility,
  recordAdRewardLog,
  OpenPassServiceError,
} from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

interface RewardCompleteBody {
  userId?: number;
  policyId?: number;
  adSourceId?: number;
  idempotencyKey?: string;
}

export async function POST(request: NextRequest) {
  let body: RewardCompleteBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다." }, { status: 400, headers: CORS_HEADERS });
  }

  const userId = Number(body.userId ?? 0);
  const policyId = Number(body.policyId ?? 0);
  const adSourceId = Number(body.adSourceId ?? 0);
  const idempotencyKey = body.idempotencyKey || null;

  if (!userId || !policyId || !adSourceId) {
    return NextResponse.json(
      { success: false, error: "userId, policyId, adSourceId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 1) idempotency 체크 — 동일 키로 이미 처리된 요청이면 중복 지급 없이 기존 결과를 그대로 반환.
    if (idempotencyKey) {
      const existing = await prisma.openPassAdRewardLog.findUnique({ where: { idempotencyKey } });
      if (existing) {
        if (existing.rewardGranted && existing.userPassId) {
          const userPass = await prisma.userPass.findUnique({ where: { id: existing.userPassId }, include: { policy: true } });
          if (userPass) {
            return NextResponse.json(
              {
                success: true,
                idempotent: true,
                data: {
                  userPassId: userPass.id,
                  policyId: userPass.policyId,
                  policyName: userPass.policy.name,
                  expiresAt: userPass.expiresAt.toISOString(),
                  remainingSec: Math.max(0, Math.floor((userPass.expiresAt.getTime() - Date.now()) / 1000)),
                },
              },
              { headers: CORS_HEADERS }
            );
          }
        }
        return NextResponse.json(
          { success: false, idempotent: true, error: "이미 처리된 요청입니다(보상 미지급 상태로 종료됨)." },
          { status: 409, headers: CORS_HEADERS }
        );
      }
    }

    // 2) 자격 확인(활성/기간/쿨다운/일일제한) — 관리자 테스트랩과 동일한 판단 로직.
    const eligibility = await checkAdRewardEligibility(userId, adSourceId);
    if (!eligibility.eligible) {
      const reasonLabel: Record<string, string> = {
        AD_SOURCE_NOT_FOUND: "존재하지 않는 광고소스입니다.",
        AD_SOURCE_INACTIVE: "현재 비활성화된 광고소스입니다.",
        AD_SOURCE_NOT_STARTED: "아직 노출 시작 전인 광고소스입니다.",
        AD_SOURCE_ENDED: "노출 기간이 종료된 광고소스입니다.",
        COOLDOWN: "쿨다운 시간이 남아있습니다.",
        DAILY_LIMIT_REACHED: "오늘의 시청 가능 횟수를 모두 사용했습니다.",
      };
      return NextResponse.json(
        {
          success: false,
          error: reasonLabel[eligibility.reason] ?? "지금은 보상을 받을 수 없습니다.",
          reason: eligibility.reason,
          ...("cooldownRemainingSec" in eligibility ? { cooldownRemainingSec: eligibility.cooldownRemainingSec } : {}),
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    // 3) 실제 지급 + 원장 기록(하나의 흐름 — 관리자 시뮬레이션과 동일).
    const { userPass, policy } = await grantOpenPass({ userId, policyId, sourceType: "ad" });
    await recordAdRewardLog({
      userId,
      adSourceId,
      passPolicyId: policyId,
      result: "success",
      rewardGranted: true,
      userPassId: userPass.id,
      idempotencyKey,
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          userPassId: userPass.id,
          policyId: policy.id,
          policyName: policy.name,
          expiresAt: userPass.expiresAt.toISOString(),
          remainingSec: Math.max(0, Math.floor((userPass.expiresAt.getTime() - Date.now()) / 1000)),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (e instanceof OpenPassServiceError) {
      return NextResponse.json({ success: false, error: e.message, code: e.code }, { status: 404, headers: CORS_HEADERS });
    }
    console.error("[POST /api/public/open-pass/reward-complete] 실패:", e);
    return NextResponse.json(
      { success: false, error: "보상 지급 처리 중 오류가 발생했습니다." },
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
