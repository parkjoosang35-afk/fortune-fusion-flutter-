// 궁합지도(Gunghap Map) 상세 보고서 잠금해제 API — 100 복주머니 고정 차감.
// [신통방통 궁합지도 개발 지시서 §1-4, §2 "상세 보고서 잠금해제", 개발 승인(API 단계)]
//
// [100P 고정] 지시서 원문 "상세 보고서 비용은 100 복주머니입니다"를 그대로
// 고정값으로 둔다(귀인지도 `guinji_unlock_special`처럼 PointPolicy로 관리자
// 조정 가능하게 하는 설계도 고려했으나, 지시서가 "100 복주머니로 확정"을
// 명시했고 "관리자 화면 개발"은 이번 단계 금지사항이므로, 관리자가 바꿀
// 수단이 아직 없는 상태에서 PointPolicy 테이블을 노출하는 것은 오히려
// 혼란을 준다 — 금액은 상수 GUNGHAP_UNLOCK_AMOUNT=100으로 고정하고, 차후
// 관리자 화면 개발 단계에서 PointPolicy 연동으로 확장한다).
//
// [멱등 — 동일 사용자 동일 보고서 재열람 시 중복 차감 금지]
// `GunghapUnlockRecord.@@unique([userId, resultId])`로 스키마 수준 보장.
// 귀인지도 `unlocks/route.ts`와 동일하게, 트랜잭션 내에서 **차감 전에
// 먼저** 기존 해금 기록을 조회해 있으면 차감 없이 그대로 unlocked:true를
// 반환한다.
//
// [동시 요청에도 중복 차감 금지] 두 경로로 이중 방어한다:
//   1) SQLite + Prisma `$transaction`은 단일 writer로 직렬화되므로, 두
//      동시 요청이 "선검사 → 차감 → insert"를 각각 수행해도 실제로는
//      순차 실행된다 — 먼저 커밋된 트랜잭션이 unlock record를 만들면,
//      나중 트랜잭션은 (a) 선검사 시점에 레코드가 이미 생겼다면 멱등
//      반환, 또는 (b) 선검사 통과 후 insert 시점에 unique 제약(P2002)에
//      걸리면 즉시 재조회해 멱등 반환한다.
//   2) `spendLuckPouch()` 자체도 tx 내에서 Wallet.balance를 읽고 쓰므로
//      같은 트랜잭션 직렬화 보장을 받는다(이중 차감 불가).
//
// [잔액 부족 시] 차감하지 않고 안내한다 — `spendLuckPouch()`가 차감 전에
// 잔액을 확인해 부족하면 아무것도 쓰지 않고 `{ok:false}`를 반환하므로,
// 이 라우트는 그 경우 트랜잭션을 롤백(에러 throw)하고 400 INSUFFICIENT_
// BALANCE로 응답한다.
//
// [권한] 상세 보고서는 "내가 만든 궁합"의 결과이므로 invite.ownerId ===
// 요청자여야 한다(타인 결과 잠금해제 시도는 FORBIDDEN).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import type { GunghapCategoryId } from "@/lib/gunghap/gunghap-category-rules";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGunghapResultDbId,
  requireUser,
  unauthorizedResponse,
} from "../../../_shared";

export const dynamic = "force-dynamic";

const GUNGHAP_UNLOCK_AMOUNT = 100;

interface StoredCategoryResult {
  categoryId: GunghapCategoryId;
  grade: string;
  gradeCode: string;
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  improvement: string;
}

export async function POST(
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
    const outcome = await prisma.$transaction(async (tx) => {
      const result = await tx.gunghapPairResult.findUnique({
        where: { id: dbId },
        include: { invite: { select: { ownerId: true } } },
      });
      if (!result || result.deletedAt != null) {
        throw new Error("RESULT_NOT_FOUND");
      }
      if (result.invite.ownerId !== auth.userId) {
        throw new Error("FORBIDDEN");
      }

      // [멱등 — 차감 전 선확인] 이미 해금했다면 재과금 없이 그대로 반환.
      const existing = await tx.gunghapUnlockRecord.findUnique({
        where: { userId_resultId: { userId: auth.userId, resultId: result.id } },
      });
      if (existing) {
        return { result, alreadyUnlocked: true, amount: existing.amount };
      }

      // [100P 차감 — Wallet 잔액 기준] 부족하면 차감 없이 예외.
      const spendResult = await spendLuckPouch(tx, {
        userId: auth.userId,
        amount: GUNGHAP_UNLOCK_AMOUNT,
        sourceType: "gunghap_detail_unlock",
        sourceId: result.id,
        memo: `궁합지도 상세 보고서 해금 (${result.guestName})`,
      });
      if (!spendResult.ok) {
        throw new Error("INSUFFICIENT_BALANCE");
      }

      try {
        await tx.gunghapUnlockRecord.create({
          data: { userId: auth.userId, resultId: result.id, amount: GUNGHAP_UNLOCK_AMOUNT },
        });
      } catch (e) {
        const code = (e as { code?: string }).code;
        // [동시 요청 극단 케이스] 차감까지 끝낸 뒤 insert에서 P2002가
        // 난다는 것은, 선확인 이후 아주 짧은 창(이론상 SQLite 단일 writer
        // 직렬화에서는 발생하지 않아야 하나, 방어적으로 처리) 사이에 다른
        // 트랜잭션이 끼어들었다는 뜻이다. 이 경우 이미 차감된 포인트는
        // 되돌리지 않고(트랜잭션 전체가 커밋되지 않으므로 자동 롤백됨)
        // 예외를 다시 던져 바깥 catch에서 일반 오류로 처리한다 — 실제로는
        // Prisma $transaction이 실패 시 전체 롤백하므로 포인트 차감도
        // 함께 롤백되어 "차감+잠금해제 기록은 하나의 트랜잭션" 원칙이
        // 보장된다.
        if (code !== "P2002") throw e;
        throw new Error("CONCURRENT_UNLOCK_CONFLICT");
      }

      return { result, alreadyUnlocked: false, amount: GUNGHAP_UNLOCK_AMOUNT, balanceAfter: spendResult.balanceAfter };
    });

    const stored = JSON.parse(outcome.result.categoryResults) as StoredCategoryResult[];

    return NextResponse.json(
      {
        success: true,
        data: {
          unlocked: true,
          alreadyUnlocked: outcome.alreadyUnlocked,
          amountCharged: outcome.alreadyUnlocked ? 0 : outcome.amount,
          balanceAfter: "balanceAfter" in outcome ? outcome.balanceAfter : undefined,
          detail: stored.map((c) => ({
            categoryId: c.categoryId,
            grade: c.grade,
            relationshipFeature: c.relationshipFeature,
            strength: c.strength,
            conflictRisk: c.conflictRisk,
            improvement: c.improvement,
          })),
        },
      },
      { headers: CORS_HEADERS },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    const errorMap: Record<string, { status: number; error: string }> = {
      RESULT_NOT_FOUND: { status: 404, error: "결과를 찾을 수 없어요." },
      FORBIDDEN: { status: 403, error: "내가 만든 궁합 결과만 해금할 수 있어요." },
      INSUFFICIENT_BALANCE: { status: 400, error: "복주머니가 부족해요." },
      CONCURRENT_UNLOCK_CONFLICT: { status: 409, error: "처리 중 충돌이 발생했어요. 다시 시도해 주세요." },
    };
    const mapped = errorMap[message];
    if (mapped) {
      return NextResponse.json(
        { success: false, error: mapped.error, code: message },
        { status: mapped.status, headers: CORS_HEADERS },
      );
    }
    console.error("[POST /api/public/gunghap/results/[resultId]/unlock] 실패:", e);
    return NextResponse.json(
      { success: false, error: "잠금해제 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
