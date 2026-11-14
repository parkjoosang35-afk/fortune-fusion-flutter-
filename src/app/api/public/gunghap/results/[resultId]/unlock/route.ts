// 궁합지도(Gunghap Map) 상세 보고서 잠금해제 API — 100 복주머니 고정 차감
// + 실제 LLM 유료 해석 생성/캐시.
// [신통방통 궁합지도 개발 지시서 §1-4, §2 "상세 보고서 잠금해제", 개발 승인(API 단계)]
// [2026-11 궁합 주제 반영 지시서 — Section 4/6] "유료 상세 해석은 기존
// 템플릿을 단순 반환하지 말고 실제 LLM 호출(claude-haiku-4-5)로 생성해야
// 한다" / "LLM 결과는 저장/캐시해 재열람 시 재생성(추가 LLM 비용)·중복
// 과금이 없어야 한다" 요구사항의 구현체.
//
// [100P 고정] 지시서 원문 "상세 보고서 비용은 100 복주머니입니다"를 그대로
// 고정값으로 둔다(이전 단계와 동일 — Section 4 작업은 "무엇을 보여줄지"만
// 바꾸고 "얼마를 받을지"는 건드리지 않는다).
//
// [멱등 — 동일 사용자 동일 보고서 재열람 시 중복 차감 금지] 기존과 동일:
// `GunghapUnlockRecord.@@unique([userId, resultId])`로 스키마 수준 보장.
// 차감 전에 먼저 기존 해금 기록을 조회해 있으면 차감 없이 그대로
// unlocked:true를 반환한다 — **이번 변경으로 추가된 것**은, 이미 해금한
// 경우 LLM을 다시 호출하지 않고 `GunghapPairResult.llmDetailJson`에 저장된
// 캐시를 그대로 반환한다는 점이다(LLM 재호출 비용 방지, "생성"의 멱등).
//
// [LLM 호출 시점 — 트랜잭션 밖] Anthropic API 호출은 최대 35초×2회
// 걸릴 수 있어(gunghap-interpret-service.ts), DB 트랜잭션(SQLite 단일
// writer) 안에서 호출하면 그 시간만큼 다른 모든 쓰기 요청이 block된다.
// 따라서 순서를 다음과 같이 분리한다:
//   1) 1차 트랜잭션: 멱등 확인 + 100P 차감 + UnlockRecord 생성(기존과 동일,
//      단 LLM 결과는 아직 없음 — 캐시가 비어 있으면 "차감은 됐지만 아직
//      해석이 없는" 중간 상태가 이론상 가능하나, 아래 3)에서 즉시 채운다).
//   2) 트랜잭션 밖에서 LLM 호출(generateGunghapInterpret).
//   3) 2차 업데이트: llmDetailJson/llmSource/llmModel/llmGeneratedAt을
//      GunghapPairResult에 저장(최초 1회만 — 이미 캐시가 있으면 이 단계
//      자체를 건너뛴다).
//
// [2026-11 추가 검수 지시 — "LLM 실패 시 100P 차감 정책 재검토"] 기존에는
// LLM이 전부 실패해 fallback(무료 템플릿 재포장)으로 귀결돼도 이미 차감한
// 100P를 그대로 두었다 — "사용자가 유료로 기대한 개인화 해석을 받지 못했는데
// 과금만 유지되는" 문제가 있었다. 이를 해결하기 위해 saju-renewal/fortune
// 도메인에 이미 있는 환불 패턴(`result-access-service.ts`의
// `failAndRefundResultAccess` POUCH 분기: Wallet 복구 + PointHistory
// type:"earn" 기록)과 동일한 원칙을 그대로 재사용해 자동 환불을 수행한다
// (새 메커니즘을 발명하지 않는다 — 다만 궁합지도 unlock은
// ResultAccessTransaction 모델을 쓰지 않는 독립 플로우이므로, 아래
// `refundGunghapUnlockIfLlmFailed()`가 Wallet/PointHistory를 직접
// 조작하는 축소판을 별도로 둔다).
//   - 환불 대상: "주제가 선택된(majorId 있음) 결과"에서 실제로 LLM을
//     호출했지만 MAX_LLM_ATTEMPTS(2)회 모두 실패해 fallback으로
//     귀결된 경우만(`interpretOutcome.source === "template"` **그리고**
//     애초에 LLM을 시도한 케이스 — 아래 레거시(majorId 없음) 분기는
//     처음부터 LLM을 시도조차 하지 않는 기존 정상 동작이므로 환불 대상이
//     아니다. 둘 다 llmSource="template"가 되지만 의미가 다르다).
//   - 사용자 경험: 환불되어도 fallback 텍스트(무료 템플릿 재포장)는 그대로
//     보여준다(§6 요구사항 "LLM 실패 시 fallback 결과 저장 및 재열람 처리"
//     유지) — "돈은 돌려주되 완전히 빈 결과를 보여주지는 않는다"는 절충.
//   - 멱등: 캐시(llmDetailJson)가 한 번 채워지면 이후 재열람은 캐시
//     히트 경로로 바로 빠지므로(아래 `if (outcome.result.llmDetailJson)`)
//     `generateAndCacheDetail()`/환불 로직 자체가 다시 실행되지 않는다 —
//     즉 환불도 생성과 마찬가지로 정확히 1회만 일어난다.
//
// [동시 요청에도 중복 차감 금지] 1차 트랜잭션은 기존과 동일한 이중 방어
// (SQLite 직렬화 + unique 제약 P2002 캐치)를 그대로 유지한다.
//
// [권한] 상세 보고서는 "내가 만든 궁합"의 결과이므로 invite.ownerId ===
// 요청자여야 한다(타인 결과 잠금해제 시도는 FORBIDDEN).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import type { GunghapCategoryId } from "@/lib/gunghap/gunghap-category-rules";
import { gradeCategory } from "@/lib/gunghap/gunghap-category-rules";
import type { GunghapFactResult } from "@/lib/gunghap/gunghap-relation-fact";
import { categoryLabel } from "@/lib/gunghap/gunghap-narrative";
import { buildFreeNarrative7 } from "@/lib/gunghap/gunghap-sub-narrative";
import {
  generateGunghapInterpret,
  GUNGHAP_INTERPRET_MODEL,
} from "@/lib/gunghap/gunghap-interpret-service";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGunghapResultDbId,
  requireUser,
  resolveGunghapResultOwnerId,
  unauthorizedResponse,
} from "../../../_shared";

export const dynamic = "force-dynamic";

const GUNGHAP_UNLOCK_AMOUNT = 100;

// [2026-11 유료 보고서 7단계 확대] 기존 4필드(레거시, majorId=null
// 8개 분야 전체)는 그대로 유지되고, 주제 선택(majorId 있음) 경로만 새
// 3개 필드(communicationStyle/growthPotential/cautionPoint)가 채워진다 —
// 선택적 필드로 두어 레거시 데이터(이 3필드 없음)와 타입 호환성을 유지한다.
interface StoredCategoryResult {
  categoryId: GunghapCategoryId;
  grade: string;
  gradeCode: string;
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  communicationStyle?: string;
  growthPotential?: string;
  cautionPoint?: string;
  improvement: string;
}

const ALLOWED_CATEGORY_IDS: GunghapCategoryId[] = [
  "love", "marriage", "intimacy", "persona", "wealth", "business", "friend", "family",
];

function isKnownCategoryId(majorId: string | null): majorId is GunghapCategoryId {
  return majorId != null && (ALLOWED_CATEGORY_IDS as string[]).includes(majorId);
}

/**
 * [동시 요청 시 중복 LLM 호출 방지 - 프로세스 내 in-flight 중복 제거]
 * 1차 트랜잭션(멱등 차감)은 resultId별로 거의 동시에 여러 요청이 들어와도
 * "차감은 1번만"을 보장하지만(unique 제약), 그 이후 LLM 생성은 트랜잭션
 * 밖에서 실행되므로, 차감이 끝난 뒤 아직 llmDetailJson 캐시가 채워지기 전
 * 짧은 시간에 동시 요청 여러 개가 각자 "캐시 없음"을 보고 중복으로 LLM을
 * 호출할 수 있다(실측: 5건 동시 요청 시 AiRequestLog 5건 생성 확인됨).
 * 이를 막기 위해 같은 resultId에 대한 생성 작업을 프로세스 내 Map으로 공유해,
 * 나중에 도착한 요청은 새로 생성하지 않고 먼저 시작된 생성 작업의 결과를
 * 그대로 기다렸다가 재사용한다(Next.js dev 서버처럼 단일 Node 프로세스로
 * 동작하는 배포 형태를 전제 - 다중 서버 인스턴스 환경에서는 추가로 분산 락이
 * 필요하나, 이번 승인 범위는 이 수준의 동시성 방지로 충분하다).
 */
const inFlightLlmGeneration = new Map<
  number,
  Promise<{
    llmDetailList: StoredCategoryResult[];
    llmSource: "llm" | "template";
    refunded: boolean;
  }>
>();

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
    // ── 1차 트랜잭션: 소유권 확인 + 멱등 확인 + 100P 차감 ──
    const outcome = await prisma.$transaction(async (tx) => {
      const result = await tx.gunghapPairResult.findUnique({
        where: { id: dbId },
        include: { invite: { select: { ownerId: true, ownerName: true } } },
      });
      if (!result || result.deletedAt != null) {
        throw new Error("RESULT_NOT_FOUND");
      }
      // [Phase 2/3: DIRECT 결과(invite=null)는 ownerUserId로 판별 — 위
      // results/[resultId]/route.ts와 동일 원칙, 기존 INVITE 로직 불변]
      const resolvedOwnerId = resolveGunghapResultOwnerId(result);
      if (resolvedOwnerId !== auth.userId) {
        throw new Error("FORBIDDEN");
      }

      // [멱등 — 차감 전 선확인] 이미 해금했다면 재과금 없이 그대로 반환.
      const existing = await tx.gunghapUnlockRecord.findUnique({
        where: { userId_resultId: { userId: auth.userId, resultId: result.id } },
      });
      if (existing) {
        return { result, resolvedOwnerId, alreadyUnlocked: true, amount: existing.amount };
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
        // 예외를 다시 던져 바깥 catch에서 일반 오류로 처리한다.
        if (code !== "P2002") throw e;
        throw new Error("CONCURRENT_UNLOCK_CONFLICT");
      }

      return {
        result,
        resolvedOwnerId,
        alreadyUnlocked: false,
        amount: GUNGHAP_UNLOCK_AMOUNT,
        balanceAfter: spendResult.balanceAfter,
      };
    });

    // ── [Section 4 — LLM 캐시 우선] 이미 llmDetailJson이 있으면 LLM을
    // 다시 호출하지 않고 그대로 반환한다(재열람 시 재생성/재과금 방지).
    let llmDetailList: StoredCategoryResult[] | null = null;
    let llmSourceForResponse: "llm" | "template" = "template";

    if (outcome.result.llmDetailJson) {
      try {
        const parsed = JSON.parse(outcome.result.llmDetailJson);
        llmDetailList = Array.isArray(parsed) ? parsed : [parsed];
        llmSourceForResponse = (outcome.result.llmSource as "llm" | "template") ?? "template";
      } catch {
        llmDetailList = null;
      }
    }

    // [LLM 실패 환불 여부 — 응답에 항상 포함] 이번 호출에서 새로 환불이
    // 발생했는지(refundedJustNow), 과거에 이미 환불된 적이 있는지(캐시
    // 재열람 시에도 사용자에게 "이 보고서는 환불됐다"는 사실을 계속 보여줘야
    // 하므로) 둘 다 확인한다. 환불 기록은 PointHistory(sourceType:
    // "gunghap_detail_unlock_refund", sourceId: result.id)로 남기므로 스키마
    // 변경 없이 기존 인덱스(@@index([sourceType, sourceId]))로 조회 가능하다.
    let refundedJustNow = false;

    if (!llmDetailList) {
      // [동시 요청 시 중복 LLM 호출 방지] 같은 resultId에 대해 이미 생성
      // 작업이 진행 중이면(동시 요청 레이스), 새로 시작하지 않고 그 작업의
      // 완료를 기다렸다가 결과를 재사용한다. 생성이 끝나면(성공이든 실패든)
      // 맵에서 제거해 다음 번 "캐시 없음" 상태의 정상 요청이 다시 시도할 수
      // 있게 한다.
      let generation = inFlightLlmGeneration.get(outcome.result.id);
      if (!generation) {
        generation = (async () => {
          try {
            return await generateAndCacheDetail(outcome.result, outcome.resolvedOwnerId);
          } finally {
            inFlightLlmGeneration.delete(outcome.result.id);
          }
        })();
        inFlightLlmGeneration.set(outcome.result.id, generation);
      }
      const generated = await generation;
      llmDetailList = generated.llmDetailList;
      llmSourceForResponse = generated.llmSource;
      refundedJustNow = generated.refunded;
    }

    // [과거 환불 이력 조회 — 재열람 시에도 refunded:true를 계속 보여주기 위함]
    const refundRecord = refundedJustNow
      ? null // 방금 환불했으면 또 조회할 필요 없음(바로 true로 확정).
      : await prisma.pointHistory.findFirst({
          where: { sourceType: "gunghap_detail_unlock_refund", sourceId: outcome.result.id },
          select: { id: true },
        });
    const refunded = refundedJustNow || refundRecord != null;

    return NextResponse.json(
      {
        success: true,
        data: {
          unlocked: true,
          alreadyUnlocked: outcome.alreadyUnlocked,
          amountCharged: outcome.alreadyUnlocked ? 0 : outcome.amount,
          balanceAfter: "balanceAfter" in outcome ? outcome.balanceAfter : undefined,
          llmSource: llmSourceForResponse,
          // [LLM 실패 환불] true면 "실제 LLM 호출이 모두 실패해 100P를
          // 환불했고, 대신 무료 템플릿 기반 결과를 보여주는 중"이라는 뜻.
          // Flutter 쪽에서 이 플래그로 "일부 환불 안내" 배너를 띄울 수 있다
          // (이번 승인 범위에서는 서버 플래그 제공까지만 — Flutter UI 반영은
          // 별도 작업으로 분리).
          refunded,
          detail: llmDetailList.map((c) => ({
            categoryId: c.categoryId,
            grade: c.grade,
            relationshipFeature: c.relationshipFeature,
            strength: c.strength,
            conflictRisk: c.conflictRisk,
            // [2026-11 7단계 확장] 레거시(majorId=null) 결과는 이 3필드가
            // 없으므로(undefined) 응답에서 자연스럽게 생략된다(JSON.stringify
            // undefined 필드 생략 동작) — Flutter는 null체크로 해당 섹션을
            // 그냥 렌더링하지 않으므로 레거시 화면은 그대로 유지된다.
            communicationStyle: c.communicationStyle,
            growthPotential: c.growthPotential,
            cautionPoint: c.cautionPoint,
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

type GunghapPairResultWithInvite = NonNullable<
  Awaited<ReturnType<typeof prisma.gunghapPairResult.findUnique>>
> & { invite?: { ownerId: number; ownerName: string | null } | null };

/**
 * [LLM 생성 + 캐시 저장 — in-flight 중복 제거 대상 본체]
 * unlock/route.ts의 1차 트랜잭션(멱등 차감) 완료 이후, "아직 LLM 캐시가
 * 없는 결과"에 대해 실제 생성을 수행한다. inFlightLlmGeneration 맵을 통해
 * 같은 resultId에 대해 동시에 이 함수가 두 번 이상 실행되지 않도록 보장된다
 * (호출부 참고). 이 함수 자체는 멱등을 스스로 보장하지 않으므로 — 반드시
 * inFlightLlmGeneration을 통해서만 호출해야 한다.
 */
async function generateAndCacheDetail(
  result: GunghapPairResultWithInvite,
  resolvedOwnerId: number | null,
): Promise<{ llmDetailList: StoredCategoryResult[]; llmSource: "llm" | "template"; refunded: boolean }> {
  const fact = JSON.parse(result.factTrace) as GunghapFactResult;
  const stored = JSON.parse(result.categoryResults) as StoredCategoryResult[];

  // [2026-11 궁합 주제 반영 지시서 — Section 4] 사용자가 1개 주제를 선택한
  // 결과(majorId 있음)만 실제 LLM 해석을 생성한다. majorId가 없는 레거시
  // 결과(Section 1 적용 이전 생성분, 16건 중 다수)는 애초에 "선택된 주제"가
  // 없으므로 LLM에 "어떤 주제에 특화해 생성하라"고 지시할 근거 자체가 없다
  // — 이 경우 기존 동작(8분야 전체 결정론적 템플릿 그대로 반환)을 100%
  // 유지한다(하위 호환, 기존 서비스 기능을 임의로 변경하지 않는다는 원칙).
  // [환불 대상 아님] 이 분기는 애초에 LLM을 시도조차 하지 않으므로(지시서
  // 적용 이전 레거시 데이터 호환용), "LLM 실패"가 아니다 — 환불하지 않는다.
  if (!isKnownCategoryId(result.majorId)) {
    const llmDetailList = stored;
    await prisma.gunghapPairResult.update({
      where: { id: result.id },
      data: {
        llmDetailJson: JSON.stringify(llmDetailList),
        llmSource: "template",
        llmModel: null,
        llmGeneratedAt: new Date(),
      },
    });
    return { llmDetailList, llmSource: "template", refunded: false };
  }

  // ── 실제 LLM 호출(트랜잭션 밖) — Section 4/5/6 핵심 ──
  const targetCategoryId = result.majorId as GunghapCategoryId;
  const targetStored = stored.find((c) => c.categoryId === targetCategoryId) ?? stored[0];

  // [등급 재계산 — evidence 확보] StoredCategoryResult에는 evidence가
  // 없으므로(저장 시 4문장 서술만 남김, FACT 트레이스는 factTrace에
  // 별도 보관), gradeCategory()를 다시 호출해 evidence를 복원한다.
  // 이 재계산은 "같은 fact로 같은 결과를 다시 도출"하는 결정론적
  // 연산일 뿐이므로 §절대원칙(점수/등급 산정 로직 변경 금지)을 전혀
  // 건드리지 않는다(gradeCategory 자체는 1바이트도 수정하지 않음).
  const gradeResult = gradeCategory(fact, targetCategoryId);

  // [owner/guest 성별] guest는 GunghapPairResult.guestGender(필수
  // 컬럼)에 이미 있다. owner는 User.gender를 조회한다(스키마에
  // 서술했듯, 초대/직접생성 경로 모두 owner는 로그인 사용자이므로
  // User 테이블에서 직접 조회하는 것이 유일한 신뢰 가능한 소스 —
  // 클라이언트가 보낸 값을 신뢰하지 않는 기존 B안 원칙과 동일).
  const ownerUser = await prisma.user.findUnique({
    where: { id: resolvedOwnerId! },
    select: { gender: true, nickname: true },
  });
  const ownerName = result.invite?.ownerName ?? ownerUser?.nickname ?? "나";
  const ownerGender =
    ownerUser?.gender === "male" || ownerUser?.gender === "female" ? ownerUser.gender : null;
  const guestGenderRaw = (result as unknown as { guestGender?: string }).guestGender;
  const guestGender = guestGenderRaw === "male" || guestGenderRaw === "female" ? guestGenderRaw : null;

  // [2026-11 궁합 세부주제 반영 — 대표 신고 "성격/대화/감정 궁합을 따로 다
  // 봤는데 다 또같다" 버그 수정] LLM에게 넘길 "기준 무료 요약"을
  // 기존 4필드(major 수준, subName 무시)가 아니라 54개 세부 카테고리
  // 전용 7단계 서술(gunghap-sub-narrative.ts)로 교체한다 — 같은 majorId
  // 안에서도 subName마다 서로 다른 근거/초점을 LLM에게 먼저 제공해,
  // 실제 LLM 출력도 주제별로 달라지게 유도한다(fallback으로 그대로
  // 반환되어도 이미 subName별로 다른 결정론적 문장이므로 체감 버그가
  // 사라진다).
  const freeNarrative7 = buildFreeNarrative7(
    targetCategoryId,
    result.subName ?? null,
    gradeResult.evidence,
    {
      relationshipFeature: targetStored.relationshipFeature,
      strength: targetStored.strength,
      conflictRisk: targetStored.conflictRisk,
      improvement: targetStored.improvement,
    },
  );

  const interpretOutcome = await generateGunghapInterpret({
    topic: {
      categoryId: targetCategoryId,
      categoryLabel: categoryLabel(targetCategoryId),
      subName: result.subName ?? null,
    },
    evidence: gradeResult.evidence,
    grade: gradeResult.grade,
    freeNarrative: freeNarrative7,
    owner: { name: ownerName, gender: ownerGender },
    guest: { name: result.guestName, gender: guestGender },
    relationTypeLabel: fact.base.relationTypeLabel,
  });

  const llmDetailEntry: StoredCategoryResult = {
    categoryId: targetCategoryId,
    grade: gradeResult.grade,
    gradeCode: gradeResult.gradeCode,
    relationshipFeature: interpretOutcome.detail.relationshipFeature,
    strength: interpretOutcome.detail.strength,
    conflictRisk: interpretOutcome.detail.conflictRisk,
    communicationStyle: interpretOutcome.detail.communicationStyle,
    growthPotential: interpretOutcome.detail.growthPotential,
    cautionPoint: interpretOutcome.detail.cautionPoint,
    improvement: interpretOutcome.detail.improvement,
  };
  const llmDetailList = [llmDetailEntry];

  // [감사 로그 — AiRequestLog] LLM 호출 성공/폴백 여부와 무관하게 "이
  // 결과에 대해 해석 생성이 시도됐다"는 사실을 기록한다(domain 구분으로
  // 기존 saju/face/palm/compatibility 집계와 섞이지 않음).
  await prisma.aiRequestLog
    .create({
      data: {
        domain: "gunghap",
        requestRefId: result.id,
        aiModel: GUNGHAP_INTERPRET_MODEL,
        status: interpretOutcome.source === "llm" ? "success" : "failed",
      },
    })
    .catch((e) => console.error("[gunghap/unlock] AiRequestLog 적재 실패:", e));

  // [캐시 저장 — 최초 1회] 다음 재열람부터는 호출부의 llmDetailJson 선확인
  // 분기를 거쳐 이 함수 자체를 건너뛰고 캐시를 그대로 반환한다(재생성/
  // 재과금 없음).
  await prisma.gunghapPairResult.update({
    where: { id: result.id },
    data: {
      llmDetailJson: JSON.stringify(llmDetailList),
      llmSource: interpretOutcome.source,
      llmModel: GUNGHAP_INTERPRET_MODEL,
      llmGeneratedAt: new Date(),
    },
  });

  // [2026-11 추가 검수 지시 — LLM 실패 시 과금 정책] 실제로 LLM을 시도했으나
  // (이 분기까지 왔다는 것 자체가 시도했다는 뜻) 2회 모두 실패해 fallback으로
  // 귀결된 경우에만 100P를 자동 환불한다. `result-access-service.ts`의
  // `failAndRefundResultAccess` POUCH 분기와 동일한 방식(Wallet.balance
  // 복구 + PointHistory type:"earn" 기록)을 직접 수행한다 — 궁합지도 unlock은
  // ResultAccessTransaction을 쓰지 않는 독립 플로우라 그 함수를 그대로
  // 호출할 수는 없지만, "무엇을 할지"는 완전히 동일하다(새 환불 메커니즘을
  // 발명하지 않음). 환불은 자체 트랜잭션으로 수행해 생성 결과 캐시 저장과는
  // 분리한다 — 환불이 실패해도 이미 생성된 해석 결과는 정상적으로 반환돼야
  // 하므로(사용자가 받는 콘텐츠 자체가 끊기면 안 됨), catch로 감싸 로그만
  // 남기고 메인 흐름은 계속 진행한다.
  let refunded = false;
  if (interpretOutcome.source === "template") {
    try {
      refunded = await refundGunghapUnlockAmount(result.id, GUNGHAP_UNLOCK_AMOUNT);
    } catch (e) {
      console.error(
        `[gunghap/unlock] LLM 실패 환불 처리 실패 resultId=gr_${result.id}:`,
        e,
      );
    }
  }

  console.log(
    `[gunghap/unlock] LLM 해석 생성 완료 resultId=gr_${result.id} category=${targetCategoryId} ` +
      `source=${interpretOutcome.source} refunded=${refunded} attemptLog=${JSON.stringify(interpretOutcome.attemptLog)}`,
  );

  return { llmDetailList, llmSource: interpretOutcome.source, refunded };
}

/**
 * [LLM 실패 환불 — 단건, 멱등] `GunghapUnlockRecord`로 이미 "차감됐다"는
 * 사실이 보장되는 resultId에 대해, 정확히 1회만 100P를 되돌린다.
 * `PointHistory(sourceType: "gunghap_detail_unlock_refund", sourceId: resultId)`
 * 행의 존재 여부로 멱등을 보장한다(스키마 변경 없이 기존
 * `@@index([sourceType, sourceId])`로 조회 가능) — 동시 요청이 겹쳐도
 * `inFlightLlmGeneration` in-flight dedup이 애초에 이 함수가 같은 resultId에
 * 대해 동시에 두 번 실행되는 것 자체를 막아주므로, 이 조회는 "같은 보고서를
 * 나중에 재열람(캐시 미스가 재발하지 않는 한 사실상 재호출되지 않음)"하는
 * 극단적 레이스에 대비한 2중 방어다.
 */
async function refundGunghapUnlockAmount(resultId: number, amount: number): Promise<boolean> {
  return prisma.$transaction(async (tx) => {
    const already = await tx.pointHistory.findFirst({
      where: { sourceType: "gunghap_detail_unlock_refund", sourceId: resultId },
      select: { id: true },
    });
    if (already) return false;

    const unlockRecord = await tx.gunghapUnlockRecord.findFirst({ where: { resultId } });
    if (!unlockRecord) return false; // 차감 기록 자체가 없으면(이론상 불가) 환불할 것도 없음.

    const wallet = await tx.wallet.findFirst({
      where: { userId: unlockRecord.userId, currencyType: "POINT", deletedAt: null },
    });
    if (!wallet) return false;

    const balanceAfter = wallet.balance + amount;
    await tx.wallet.update({
      where: { id: wallet.id },
      data: { balance: balanceAfter, balanceSyncedAt: new Date() },
    });
    await tx.pointHistory.create({
      data: {
        walletId: wallet.id,
        userId: unlockRecord.userId,
        amount,
        type: "earn",
        sourceType: "gunghap_detail_unlock_refund",
        sourceId: resultId,
        balanceAfter,
        memo: "궁합지도 상세 해석 생성 실패로 인한 자동 환불(무료 템플릿으로 대체 제공)",
      },
    });
    return true;
  });
}
