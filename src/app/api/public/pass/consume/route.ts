// 공개(비인증) 알림패스 소진(게이트 체크) API — Flutter PassRepository.consume() 대응.
// 시간제 콘텐츠(운세 상세 등) 열람 직전 호출: 현재 유효한 UserPass가 있는지 검증하고,
// 유효하면 열람 로그(operation_logs)를 남긴 뒤 통과시킨다. 알림패스 자체는 시간 기반이라
// 열람 1회당 잔여시간을 차감하지 않고, "이 열람이 패스로 커버되었다"는 이력만 남긴다.
//
// [신통방통 기존시스템유지+프리패스 카테고리별 이용횟수 제한] §6/§7/§24/§27
// categoryKey(예: daily/saju/face/palm — fortune_categories.category_key와 동일 값)가
// 함께 전달되면, 활성 패스 검증 통과 후 "이 패스로 이 카테고리를 몇 번째 이용하는지"를
// 추가로 검사한다. policy.categoryMaxUsage(기본 2회, null=무제한)를 이미 채웠으면
// 403으로 차단하고(기존 "패스 없음" 403과 동일한 에러 포맷, reason으로만 구분),
// 통과 시에만 PassCategoryUsage.usageCount를 +1 한다. categoryKey가 없으면(기존
// 호출자 하위호환) 카테고리 검증을 완전히 건너뛰고 기존 동작 그대로 유지한다.
//
// [STEP8 - Flutter categoryKey 연동, 이중 차감 방지] 이 API는 "화면 진입 게이트체크"
// (Flutter navigateWithPassGate)용이며, 실제 이용횟수 소진은 각 운세 API(saju/tarot/
// name/face/palm/compatibility route.ts)가 AI 분석 완료 후에만 수행한다. 만약 이
// 게이트에서도 categoryKey로 consumeCategoryUsage()를 호출해버리면 "게이트 진입 1회 +
// 실제 API 호출 1회 = 2회 소진"이 되어 카테고리당 2회 제한이 실질적으로 1회로 줄어드는
// 이중 차감 버그가 발생한다. 따라서 checkOnly=true(Flutter 게이트체크의 기본값)이면
// checkCategoryUsage()로 "확인"만 하고 consumeCategoryUsage()는 절대 호출하지 않는다.
// checkOnly가 없거나 false인 과거 호출자(하위호환)는 기존과 동일하게 체크+증가를 모두 수행한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { checkCategoryUsage, consumeCategoryUsage } from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    contentType?: string;
    contentId?: number | string;
    categoryKey?: string;
    checkOnly?: boolean;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const contentType = body.contentType ?? "unknown";
  const categoryKey = body.categoryKey && body.categoryKey.trim() ? body.categoryKey.trim() : null;
  // [STEP8 - 이중 차감 방지] 기본값 true: 화면 진입 게이트체크는 "확인만" 하고,
  // 실제 소진은 이후 호출되는 개별 운세 API가 담당한다.
  const checkOnly = body.checkOnly !== false;

  try {
    const now = new Date();
    const activePass = await prisma.userPass.findFirst({
      where: { userId, expiresAt: { gt: now } },
      orderBy: { expiresAt: "desc" },
      include: { policy: true },
    });

    if (!activePass) {
      return NextResponse.json(
        {
          success: false,
          error: "유효한 프리패스가 없습니다. 광고 시청, 파트너 방문 또는 구독으로 프리패스를 받아보세요.",
          reason: "NO_ACTIVE_PASS",
        },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // ── 카테고리별 이용횟수 검증(categoryKey가 전달된 경우에만) ──
    let categoryUsageInfo: { usageCount: number; maxUsage: number | null } | null = null;
    if (categoryKey) {
      const usageCheck = await checkCategoryUsage(userId, categoryKey);
      if (!usageCheck.allowed) {
        return NextResponse.json(
          {
            success: false,
            error:
              usageCheck.reason === "CATEGORY_LIMIT_REACHED"
                ? `오늘 이 프리패스로 이용할 수 있는 횟수(${usageCheck.maxUsage}회)를 모두 사용했습니다.`
                : "유효한 프리패스가 없습니다. 광고 시청, 파트너 방문 또는 구독으로 프리패스를 받아보세요.",
            reason: usageCheck.reason,
            usageCount: usageCheck.usageCount,
            maxUsage: usageCheck.maxUsage,
          },
          { status: 403, headers: CORS_HEADERS }
        );
      }
      if (checkOnly) {
        // [STEP8 - 이중 차감 방지] 확인만 하고 증가시키지 않는다. 실제 소진은 이
        // 게이트를 통과한 뒤 호출되는 개별 운세 API(saju/tarot/... route.ts)가 수행한다.
        categoryUsageInfo = { usageCount: usageCheck.usageCount, maxUsage: usageCheck.maxUsage };
      } else {
        const updated = await consumeCategoryUsage(activePass.id, userId, categoryKey);
        categoryUsageInfo = { usageCount: updated.usageCount, maxUsage: usageCheck.maxUsage };
      }
    }

    await prisma.operationLog.create({
      data: {
        actorType: "user",
        actorId: userId,
        action: "consume_pass",
        targetType: "user_pass",
        targetId: activePass.id,
        before: null,
        after: JSON.stringify({
          contentType,
          contentId: body.contentId ?? null,
          categoryKey,
          categoryUsageCount: categoryUsageInfo?.usageCount ?? null,
        }),
      },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          userPassId: activePass.id,
          policyId: activePass.policyId,
          policyName: activePass.policy.name,
          remainingSec: Math.max(
            0,
            Math.floor((activePass.expiresAt.getTime() - now.getTime()) / 1000)
          ),
          categoryUsage: categoryUsageInfo,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/pass/consume] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프리패스 검증 중 오류가 발생했습니다." },
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
