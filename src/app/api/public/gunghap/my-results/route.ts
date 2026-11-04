// 궁합지도(Gunghap Map) 궁합스토리 목록 조회 API — 로그인 사용자가 만든
// 모든 궁합 결과(DIRECT + INVITE 통합)를 최신순으로 반환한다.
// [신통방통 궁합지도 통합 최종 개발 지시서 Phase 3 — "궁합스토리" 마이페이지]
//
// [궁합스토리 정의] 실제로 저장된 궁합 결과를 재분석/재과금 없이 다시
// 열람하는 기능이다(목업/하드코딩 데이터 아님 — 반드시 실 DB 조회).
//
// [DIRECT + INVITE 통합 조회 — Prisma 관계 OR 쿼리 한계 대응]
// "내가 만든 결과"는 두 가지 경로로 소유될 수 있다(resolveGunghapResultOwnerId
// 참고): (a) DIRECT 결과 — ownerUserId = 내 id, (b) INVITE 결과 —
// invite.ownerId = 내 id(ownerUserId는 항상 null). Prisma는 "관계를 건너
// 뛴 OR 조건"(예: ownerUserId=X OR invite.ownerId=X)을 단일 쿼리로 깔끔하게
// 표현하기 어렵다(where에 OR로 relation 필터를 섞으면 join이 불필요하게
// 복잡해지고, 인덱스 활용도 예측하기 어려움) — 따라서 두 번의 단순 쿼리로
// 나눠 각각 실행한 뒤 애플리케이션 레벨에서 병합·정렬한다. 두 쿼리 모두
// 단순 `where` 조건(인덱스 가능)이므로 Firestore 가이드와 동일한 원칙
// ("복합 쿼리 대신 단순 쿼리 + 메모리 정렬")을 SQL에도 동일하게 적용한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import type { GunghapFactResult } from "@/lib/gunghap/gunghap-relation-fact";
import type { StoredCategoryResult } from "@/lib/gunghap/gunghap-compute-helper";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  requireUser,
  toGunghapResultPublicId,
  unauthorizedResponse,
} from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    // (a) DIRECT 결과 — ownerUserId로 직접 식별.
    const directResults = await prisma.gunghapPairResult.findMany({
      where: { ownerUserId: auth.userId, deletedAt: null, resultType: "DIRECT" },
    });

    // (b) INVITE 결과 — invite.ownerId로 식별(기존 invite 기반 결과).
    const inviteResults = await prisma.gunghapPairResult.findMany({
      where: {
        deletedAt: null,
        resultType: "INVITE",
        invite: { ownerId: auth.userId, deletedAt: null },
      },
      include: { invite: { select: { ownerName: true } } },
    });

    type Row = (typeof directResults)[number] & {
      invite?: { ownerName: string | null } | null;
    };
    const merged: Row[] = [...directResults, ...inviteResults];

    // [메모리 정렬 — 복합 인덱스/orderBy 불필요] 두 쿼리 결과를 합친 뒤
    // createdAt 기준 최신순으로 정렬한다(Firestore 가이드와 동일 원칙,
        // SQLite에도 동일 적용 — 단순 쿼리 + 메모리 정렬로 인덱스 설계 비용 회피).
    merged.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    const items = merged.map((r) => {
      const fact = JSON.parse(r.factTrace) as GunghapFactResult;
      const stored = JSON.parse(r.categoryResults) as StoredCategoryResult[];
      return {
        resultId: toGunghapResultPublicId(r.id),
        resultType: r.resultType,
        ownerName: r.invite?.ownerName ?? null,
        guestName: r.guestName,
        relationTypeLabel: fact.base.relationTypeLabel,
        grade: fact.base.grade,
        gradeCode: fact.base.gradeCode,
        categoryCount: stored.length,
        createdAt: r.createdAt.toISOString(),
      };
    });

    return NextResponse.json(
      { success: true, data: { items, total: items.length } },
      { headers: CORS_HEADERS },
    );
  } catch (e) {
    console.error("[GET /api/public/gunghap/my-results] 실패:", e);
    return NextResponse.json(
      { success: false, error: "목록 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
