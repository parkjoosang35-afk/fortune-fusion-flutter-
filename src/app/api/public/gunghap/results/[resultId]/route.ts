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
import { filterStoredByMajorId } from "@/lib/gunghap/gunghap-compute-helper";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGunghapResultDbId,
  requireUser,
  resolveGunghapResultOwnerId,
  toGunghapResultPublicId,
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
    // [타인의 결과 접근 차단 — Phase 2/3: invite가 null인 DIRECT 결과는
    // ownerUserId로 판별한다. 기존 INVITE 결과는 invite.ownerId 판별
    // 로직이 100% 동일하게 유지된다(resolveGunghapResultOwnerId 참고).
    const resolvedOwnerId = resolveGunghapResultOwnerId(result);
    if (resolvedOwnerId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "내가 만든 궁합 결과만 볼 수 있어요.", code: "FORBIDDEN" },
        { status: 403, headers: CORS_HEADERS },
      );
    }

    const fact = JSON.parse(result.factTrace) as GunghapFactResult;
    const stored = JSON.parse(result.categoryResults) as StoredCategoryResult[];
    // [2026-11 궁합 주제 반영 지시서 — Section 2] 선택된 주제가 있으면 1개
    // 분야만, 없으면(레거시) 8개 전체를 노출한다.
    const visibleStored = filterStoredByMajorId(stored, result.majorId);

    const unlocked = await prisma.gunghapUnlockRecord.findUnique({
      where: { userId_resultId: { userId: auth.userId, resultId: result.id } },
    });

    // [Section 4 — LLM 캐시] 잠금해제된 경우, 캐시된 LLM 상세 해석이 있으면
    // 그것을 반환하고, 아직 없으면(과거 unlock 레코드는 있는데 LLM 캐시가
    // 비어있는 과도기 데이터) 결정론적 템플릿 서술로 안전하게 폴백한다
    // (상세 화면이 빈 값으로 깨지는 것을 방지 — unlock 호출 시 캐시가
    // 항상 채워지므로 정상 흐름에서는 이 폴백이 사실상 발생하지 않는다).
    let detail: unknown = null;
    let refunded = false;
    if (unlocked) {
      if (result.llmDetailJson) {
        try {
          detail = JSON.parse(result.llmDetailJson);
        } catch {
          detail = null;
        }
      }
      if (!detail) {
        detail = visibleStored.map((c) => ({
          categoryId: c.categoryId,
          grade: c.grade,
          relationshipFeature: c.relationshipFeature,
          strength: c.strength,
          conflictRisk: c.conflictRisk,
          improvement: c.improvement,
        }));
      }
      // [2026-11 추가 검수 지시 — LLM 실패 시 환불 정책] unlock(POST)이 아닌
      // 이 GET으로 재열람할 때도(예: 궁합스토리에서 다시 들어온 경우) "이
      // 보고서는 LLM 생성 실패로 환불됐다"는 사실을 동일하게 보여줘야 한다
      // — unlock/route.ts와 동일한 조회 조건(sourceType/sourceId)을 그대로
      // 재사용한다(새 플래그 컬럼을 추가하지 않고 기존 PointHistory 감사
      // 로그만으로 판별 — 스키마 변경 없음).
      const refundRecord = await prisma.pointHistory.findFirst({
        where: { sourceType: "gunghap_detail_unlock_refund", sourceId: result.id },
        select: { id: true },
      });
      refunded = refundRecord != null;
    }

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
          majorId: result.majorId ?? null,
          subName: result.subName ?? null,
          categories: visibleStored.map((c) => ({
            categoryId: c.categoryId,
            grade: c.grade,
            gradeCode: c.gradeCode,
          })),
          unlocked: unlocked != null,
          unlockCost: 100,
          // [유료 — 해금된 경우에만 상세 해석 포함]
          ...(unlocked ? { detail, llmSource: result.llmSource ?? "template", refunded } : {}),
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

// [Phase 3 — 궁합스토리 삭제] 소유자 본인만 삭제 가능. 실제 row를 지우지
// 않고 `deletedAt`만 채우는 soft-delete를 사용한다(귀인지도 guinji_map
// 삭제 패턴과 동일 원칙 — 복구/감사 추적 여지를 남긴다). 삭제 후에는
// GET/my-results/unlock 모든 경로에서 `deletedAt != null` 조건으로
// 제외되므로 사용자 눈에는 즉시 사라진다.
export async function DELETE(
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

    // [타인의 결과 삭제 차단 — GET/unlock과 동일한 소유자 판별 재사용]
    const resolvedOwnerId = resolveGunghapResultOwnerId(result);
    if (resolvedOwnerId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "내가 만든 궁합 결과만 삭제할 수 있어요.", code: "FORBIDDEN" },
        { status: 403, headers: CORS_HEADERS },
      );
    }

    await prisma.gunghapPairResult.update({
      where: { id: dbId },
      data: { deletedAt: new Date() },
    });

    return NextResponse.json(
      { success: true, data: { resultId: toGunghapResultPublicId(dbId), deleted: true } },
      { headers: CORS_HEADERS },
    );
  } catch (e) {
    console.error("[DELETE /api/public/gunghap/results/[resultId]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "삭제 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
