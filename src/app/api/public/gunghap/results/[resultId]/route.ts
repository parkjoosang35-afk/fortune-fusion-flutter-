// 궁합지도(Gunghap Map) 무료 결과 조회 API — 초대 소유자가 자신이 만든
// 궁합 결과를 다시 확인할 때 사용한다.
// [신통방통 궁합지도 개발 지시서 §1-3 "궁합 결과 생성 및 조회", 개발 승인(API 단계)]
//
// [권한 검증 — 결과 조회는 초대 소유자만 가능] 게스트(joinedUserId)는
// 항상 null로 저장되므로(개인정보 최소화·익명 참여 설계), 로그인 기반
// "내 결과 조회"는 초대 소유자(owner)만 대상으로 한다 — 게스트 본인은
// `g/[token]/join` 응답에서 결과를 1회성으로 이미 전달받았으므로(해당
// 라우트가 곧 게스트의 "조회" 경로), 이 GET은 **소유자 전용**이다.
// 소유자가 아닌 로그인 사용자가 다른 사람의 resultId로 조회를 시도하면
// 403 FORBIDDEN으로 차단한다("다른 사용자의 결과 접근 차단" — 지시서 §3).
//
// [무료/유료 분리] 이 응답은 분야별 "등급(grade)"만 포함한다(점수/서술
// 비노출). 상세 4요소 서술은 잠금해제(unlock) 후에만 제공된다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import type { GunghapFactResult } from "@/lib/gunghap/gunghap-relation-fact";
import type { GunghapCategoryId } from "@/lib/gunghap/gunghap-category-rules";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGunghapResultDbId,
  requireUser,
  unauthorizedResponse,
} from "../../_shared";

export const dynamic = "force-dynamic";

interface StoredCategoryResult {
  categoryId: GunghapCategoryId;
  grade: string;
  gradeCode: string;
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  improvement: string;
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ resultId: string }> },
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { resultId } = await params;
  const dbId = parseGunghapResultDbId(resultId);
  if (dbId === null) {
    return NextResponse.json(
      { success: false, error: "resultId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  try {
    const result = await prisma.gunghapPairResult.findUnique({
      where: { id: dbId },
      include: { invite: { select: { ownerId: true, ownerName: true } } },
    });

    if (!result || result.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "결과를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS },
      );
    }
    // [타인의 결과 접근 차단 — Phase 2: invite가 null인 DIRECT 결과는
    // ownerUserId로 판별한다(Phase 3에서 DIRECT 생성 API가 ownerUserId를
    // 채운다). 기존 INVITE 결과는 invite.ownerId 판별 로직이 100% 동일하게
    // 유지된다 — 이 분기가 없으면 DIRECT 결과 조회 시 invite가 null이라
    // 타입 에러 및 런타임 크래시가 발생한다.]
    const resolvedOwnerId = result.invite?.ownerId ?? result.ownerUserId;
    if (resolvedOwnerId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "내가 만든 궁합 결과만 볼 수 있어요.", code: "FORBIDDEN" },
        { status: 403, headers: CORS_HEADERS },
      );
    }

    const fact = JSON.parse(result.factTrace) as GunghapFactResult;
    const stored = JSON.parse(result.categoryResults) as StoredCategoryResult[];

    const unlocked = await prisma.gunghapUnlockRecord.findUnique({
      where: { userId_resultId: { userId: auth.userId, resultId: result.id } },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          resultId: `gr_${result.id}`,
          ownerName: result.invite?.ownerName ?? null,
          guestName: result.guestName,
          relationType: fact.base.relationType,
          relationTypeLabel: fact.base.relationTypeLabel,
          relationTypeDesc: fact.base.relationTypeDesc,
          chemistryScore: fact.base.chemistryScore,
          grade: fact.base.grade,
          gradeCode: fact.base.gradeCode,
          categories: stored.map((c) => ({
            categoryId: c.categoryId,
            grade: c.grade,
            gradeCode: c.gradeCode,
          })),
          unlocked: unlocked != null,
          unlockCost: 100,
          // [유료 — 해금된 경우에만 4요소 서술 포함]
          ...(unlocked
            ? {
                detail: stored.map((c) => ({
                  categoryId: c.categoryId,
                  grade: c.grade,
                  relationshipFeature: c.relationshipFeature,
                  strength: c.strength,
                  conflictRisk: c.conflictRisk,
                  improvement: c.improvement,
                })),
              }
            : {}),
        },
      },
      { headers: CORS_HEADERS },
    );
  } catch (e) {
    console.error("[GET /api/public/gunghap/results/[resultId]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "결과 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
