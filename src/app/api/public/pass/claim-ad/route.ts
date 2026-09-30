// 공개(비인증) 광고 시청 프리패스 발급 API — Flutter PassRepository.claimAd() 대응.
// 광고 시청 완료 콜백 시 호출: passType="ad" 정책을 조회해 UserPass를 발급한다.
// [재화 구조 정리] 프리패스는 순수 시간제 이용권이므로 지급 시 상시 복주머니 적립을
// 붙이지 않는다(과거 policy.bonusPoint 자동 지급 블록 제거).
//
// [결과보기 통합 권한 시스템 v1.0, 2026-09-28] §3 쿠팡 프리패스 횟수제 전환.
// 조회된 정책이 grantCount != null(횟수제, 현재는 쿠팡 정책 id=11)이면
// claimCoupangDailyPass()(§3.4 원자적 "하루 1회 획득" 로직)로 위임하고,
// grantCount == null(그 외 기존 레거시 시간제 ad 정책)이면 아래 기존 로직을
// 그대로 유지한다 — 기존에 정상 동작하던 것을 재작성하지 않는다는 원칙(§0)에
// 따라 레거시 분기의 코드는 건드리지 않았다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { claimCoupangDailyPass, OpenPassServiceError } from "@/lib/open-pass-service";
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

    // [결과보기 통합 권한 시스템 v1.0, 2026-09-28] §3 횟수제 정책 분기.
    // 이 정책이 신규 횟수제(grantCount != null, 현재는 쿠팡 id=11)라면 시간제
    // 로직(멱등윈도우/dailyLimit/durationMin 기반 expiresAt)을 전혀 거치지 않고
    // 원자적 하루1회 지급 함수로 바로 위임한다. 응답 형태(userPassId/policyId/
    // policyName/expiresAt)는 기존 계약과 동일하게 유지해 Flutter
    // PassRepository._claim()의 파싱 로직을 변경하지 않아도 되게 한다.
    if (policy.grantCount != null) {
      try {
        const claimResult = await claimCoupangDailyPass({ userId, policyId: policy.id });
        if (!claimResult.claimed) {
          // §3.3: 오늘 이미 획득함 — 지급 없음. 409로 명확히 구분해 클라이언트가
          // "이미 오늘 받으셨어요" 안내를 띄울 수 있게 한다(§6.4 받기버튼 노출규칙).
          return NextResponse.json(
            {
              success: false,
              error: "오늘의 쿠팡 프리패스를 이미 받으셨어요. 내일 다시 시도해주세요.",
              code: "ALREADY_CLAIMED_TODAY",
            },
            { status: 409, headers: CORS_HEADERS }
          );
        }
        const userPass = claimResult.userPass!;
        return NextResponse.json(
          {
            success: true,
            data: {
              userPassId: userPass.id,
              policyId: policy.id,
              policyName: policy.name,
              expiresAt: userPass.expiresAt.toISOString(),
              idempotent: false,
              // [§3 신규] 횟수제 잔여 정보 — 하위호환을 위해 기존 필드에 덧붙이는
              // 형태로만 추가한다(기존 필드 제거/이름변경 없음).
              grantedCount: claimResult.grantedCount,
              remainingCount: userPass.remainingCount,
            },
          },
          { headers: CORS_HEADERS }
        );
      } catch (e) {
        if (e instanceof OpenPassServiceError) {
          const status = e.code === "POLICY_NOT_FOUND" ? 404 : 400;
          return NextResponse.json(
            { success: false, error: e.message, code: e.code },
            { status, headers: CORS_HEADERS }
          );
        }
        throw e;
      }
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
