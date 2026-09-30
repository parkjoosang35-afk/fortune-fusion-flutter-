// ══════════════════════════════════════════════════════════════════
// ResultAccessService — [결과보기 통합 권한 시스템 v1.0, 2026-09-28] §8 공통
// 결과보기 서비스의 단일 소스.
//
// 정통사주 69종 · 타로 65종 · 운세 콘텐츠 전체가 "결과보기" 버튼을 누르는 시점에
// 오직 이 파일의 함수들만 호출해야 한다(§8.1 "콘텐츠별 결제 로직 중복 구현 금지").
// 개별 콘텐츠 API(saju/tarot/name/face/palm/daily route.ts)는 이 서비스가 반환한
// 결과만 신뢰하고, 잔액 계산/차감 로직을 스스로 구현해서는 안 된다.
//
// [설계 요약 — 지시서 대응표]
//   §8.2 판단 항목      → getResultAccessQuote()
//   §8.3 서버 재검증     → beginResultAccess() 내부에서 payment_method별로 항상
//                          서버 DB를 다시 조회/차감한다(클라이언트 선언은 참고용).
//   §8.4 멱등성          → transactionId(ResultAccessTransaction.transactionId
//                          @unique)로 중복 요청을 차단한다.
//   §8.5 결제 확정 후 AI 생성 → beginResultAccess()가 "차감 확정"까지만 담당하고,
//                          호출부(각 콘텐츠 route.ts)가 그 다음에 AI 생성을 수행한
//                          뒤 completeResultAccess()/failAndRefundResultAccess()를
//                          호출해 트랜잭션을 종결시키는 2단계 구조다.
//   §8.6 실패 시 환불     → failAndRefundResultAccess()가 transactionId 기준으로
//                          정확히 1회만 복구한다(status가 이미 pending이 아니면
//                          아무 것도 하지 않아 중복 복구를 막는다).
//
// [프리패스 신구 체계 공존] schema.prisma의 UserPass 주석과 동일한 원칙:
//   - remainingCount != null (신규 횟수제) → 원자적으로 -1씩 소비한다.
//   - remainingCount == null (레거시 시간제, expiresAt만 있음) → 활성 상태이면
//     차감 없이 그대로 승인한다(기존 회원 데이터를 즉시 깨뜨리지 않기 위한 하위호환,
//     §9.2 "기존 회원 데이터가 손실되면 안 된다"). 레거시 패스는 결과보기 횟수
//     표시(§6 "N회 남음")에는 포함하지 않고, "보유 중" 여부만 별도로 알린다.
// ══════════════════════════════════════════════════════════════════
import { prisma } from "@/lib/db";
import type { Prisma } from "@/generated/prisma/client";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";

type Tx = Prisma.TransactionClient;

export class ResultAccessError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

export type ResultAccessPaymentMethod = "FREEPASS" | "POUCH" | "AD";

export type ResultAccessTransactionStatus = "pending" | "success" | "failed" | "refunded";

/** §4 결과보기 기본 복주머니 가격(전역 기본값). 관리자 예외가격(§4 예외 가격)은
 * Phase5에서 콘텐츠별 예외 테이블/설정을 추가할 때 이 함수 내부만 확장하면 되고,
 * 호출부(각 route.ts)는 변경할 필요가 없다(§8.1 공통화 원칙). */
const DEFAULT_POUCH_PRICE = 100;
const POUCH_PRICE_CONFIG_KEY = "result_access_pouch_price_default";

/** [어뷰징 방지, §3.3] KST(UTC+9) 기준 "오늘"의 날짜키("YYYY-MM-DD"). open-pass-service.ts/
 * luck-pouch-engine.ts와 동일한 절단 규칙(§15 "판정 기준 불일치 금지")을 재사용한다. */
function todayKstKey(): string {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  return `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** §4 결과보기 1건당 복주머니 가격. 예외가격 설정이 없으면 전역 기본값(100)을 반환한다. */
export async function getResultAccessPrice(
  _contentType: string,
  _categoryKey?: string | null
): Promise<number> {
  // [Phase5 예정] 콘텐츠별 예외가격 테이블/설정이 추가되면 categoryKey로 조회해
  // 있으면 그 값을, 없으면 전역 기본값을 반환하도록 이 함수만 확장한다.
  const row = await prisma.economyConfig.findUnique({ where: { key: POUCH_PRICE_CONFIG_KEY } });
  return row ? Math.round(row.value) : DEFAULT_POUCH_PRICE;
}

export interface FreePassSummary {
  /** 신규 횟수제 프리패스의 잔여 횟수 합계(§6 "N회 남음" 표시에 사용). */
  remainingCount: number;
  /** 레거시 시간제 프리패스가 현재 활성 상태로 남아있는지(하위호환 전용, 신규 UX에는 노출 안 함). */
  hasLegacyUnlimited: boolean;
  /** 이 값이 true면 사용자가 지금 FREEPASS로 결과보기를 진행할 수 있다. */
  hasAny: boolean;
}

/** 사용자의 현재 프리패스 보유 현황을 조회한다(§8.2 "프리패스 잔액"). */
export async function getFreePassSummary(userId: number): Promise<FreePassSummary> {
  const now = new Date();
  const passes = await prisma.userPass.findMany({
    where: { userId, status: "active", expiresAt: { gt: now } },
    select: { remainingCount: true },
  });
  let remainingCount = 0;
  let hasLegacyUnlimited = false;
  for (const p of passes) {
    if (p.remainingCount != null) {
      remainingCount += p.remainingCount;
    } else {
      hasLegacyUnlimited = true;
    }
  }
  return { remainingCount, hasLegacyUnlimited, hasAny: remainingCount > 0 || hasLegacyUnlimited };
}

/** 사용자의 현재 복주머니(Wallet/POINT) 잔액을 조회한다(§8.2 "복주머니 잔액"). */
export async function getPouchBalance(userId: number): Promise<number> {
  const wallet = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
  return wallet?.balance ?? 0;
}

/** §3.6/§6.4 오늘(KST) 쿠팡 프리패스를 이미 획득했는지 여부(있으면 획득한 날짜키 반환). */
export async function getCoupangClaimedTodayKey(userId: number): Promise<string | null> {
  const dateKey = todayKstKey();
  const log = await prisma.coupangPassClaimLog.findFirst({
    where: { userId, claimDateKey: dateKey },
    select: { id: true },
  });
  return log ? dateKey : null;
}

export interface ResultAccessQuote {
  freePassRemaining: number;
  freePassHasLegacyUnlimited: boolean;
  freePassAvailable: boolean;
  pouchBalance: number;
  pouchPrice: number;
  pouchAvailable: boolean;
  adAvailable: boolean;
  coupangClaimedTodayKey: string | null;
  /** [§6.4] 오늘(KST) 쿠팡 프리패스를 이미 획득했는지 boolean 편의 필드.
   * coupangClaimedTodayKey(문자열/null)와 동일한 정보를 boolean으로 노출한다 —
   * Flutter의 "오늘의 프리패스 2회 받기" 버튼 노출 조건(freePassRemaining===0
   * && !todayClaimed)을 문자열 null 체크 없이 바로 판단할 수 있게 한다. */
  todayClaimed: boolean;
}

/**
 * §6/§8.2 — 결과보기 권한 선택 화면(3택 UI)이 필요로 하는 모든 상태를 한 번에 조회한다.
 * [Phase5 예정] freePassEnabled/pouchEnabled/adEnabled 관리자 ON/OFF 설정이 추가되면
 * 이 함수 안에서 EconomyConfig 등을 조회해 pouchAvailable/adAvailable에 반영한다.
 */
export async function getResultAccessQuote(
  userId: number,
  contentType: string,
  categoryKey?: string | null
): Promise<ResultAccessQuote> {
  const [freePass, pouchBalance, price, coupangClaimedTodayKey] = await Promise.all([
    getFreePassSummary(userId),
    getPouchBalance(userId),
    getResultAccessPrice(contentType, categoryKey),
    getCoupangClaimedTodayKey(userId),
  ]);
  return {
    freePassRemaining: freePass.remainingCount,
    freePassHasLegacyUnlimited: freePass.hasLegacyUnlimited,
    freePassAvailable: freePass.hasAny,
    pouchBalance,
    pouchPrice: price,
    pouchAvailable: true,
    adAvailable: true,
    coupangClaimedTodayKey,
    todayClaimed: coupangClaimedTodayKey != null,
  };
}

/** transactionId로 기존 거래를 조회한다(§8.4 멱등성 판단의 기준). */
export async function findResultAccessTransaction(transactionId: string) {
  return prisma.resultAccessTransaction.findUnique({ where: { transactionId } });
}

/**
 * [원자적 소비] 신규 횟수제 프리패스 1회를 소비한다. 여러 활성 패스가 있으면 만료가
 * 가장 가까운 것부터 소비한다(먼저 만료될 것을 먼저 쓰는 것이 사용자에게 유리).
 * 레거시 시간제(remainingCount == null) 활성 패스가 있으면 그것을 차감 없이
 * "그대로 승인"한다(§9.2 기존 회원 데이터 보존 — 시간제 패스는 원래도 시간 동안
 * 무제한이었으므로 횟수를 깎지 않는다).
 *
 * updateMany(where remainingCount > 0)의 count로 동시성 충돌을 감지해 재시도하는
 * 패턴은 fortune-ad-service.ts의 PENDING→COMPLETED 원자적 전환과 동일하다.
 */
async function consumeFreePassOnce(
  tx: Tx,
  userId: number
): Promise<{ ok: boolean; userPassId: number | null; remainingAfter?: number }> {
  const now = new Date();

  const legacy = await tx.userPass.findFirst({
    where: { userId, status: "active", expiresAt: { gt: now }, remainingCount: null },
    orderBy: { expiresAt: "asc" },
  });
  if (legacy) {
    return { ok: true, userPassId: legacy.id };
  }

  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = await tx.userPass.findFirst({
      where: { userId, status: "active", expiresAt: { gt: now }, remainingCount: { gt: 0 } },
      orderBy: { expiresAt: "asc" },
    });
    if (!candidate) return { ok: false, userPassId: null };

    const updated = await tx.userPass.updateMany({
      where: { id: candidate.id, remainingCount: { gt: 0 } },
      data: { remainingCount: { decrement: 1 } },
    });
    if (updated.count === 1) {
      const fresh = await tx.userPass.findUnique({
        where: { id: candidate.id },
        select: { remainingCount: true },
      });
      return { ok: true, userPassId: candidate.id, remainingAfter: fresh?.remainingCount ?? 0 };
    }
    // count === 0: 동시 요청이 먼저 이 행을 가져갔다 — 다음 루프에서 다른 후보를 다시 탐색.
  }
  return { ok: false, userPassId: null };
}

export interface BeginResultAccessParams {
  userId: number;
  /** 클라이언트가 발급한 고유 요청 식별자(§8.4 멱등키). 같은 값으로 재호출하면
   * 차감을 다시 하지 않고 기존 결과를 그대로 반환한다. */
  transactionId: string;
  /** FortuneRequest.fortuneType과 동일한 값(saju/tarot/daily/name/face/palm 등). */
  contentType: string;
  contentId?: string | null;
  /** fortune_categories.category_key(예: saju_wealth, tarot 등). */
  categoryKey?: string | null;
  paymentMethod: ResultAccessPaymentMethod;
  /** [Phase4 §8.3 광고 서버 재검증] paymentMethod가 "AD"일 때 필수 — 클라이언트가
   * /result-access/ad-session/start로 발급받고, AdMob 리워드 콜백 이후
   * /ad-session/complete까지 마친 세션의 sessionId. 이 세션이 실제로 completed
   * 상태인지 여기서 다시 조회해 확인하기 전에는 절대 승인하지 않는다(§8.3
   * "클라이언트 선언은 참고용" 원칙 — paymentMethod=AD라는 선언만으로는 통과 불가). */
  adSessionId?: string | null;
}

export interface BeginResultAccessResult {
  transactionId: string;
  paymentMethod: ResultAccessPaymentMethod;
  /** "pending"만 반환된다 — 이 시점에는 아직 AI 생성 전이므로 success/failed일 수 없다.
   * 단, 멱등 재호출로 과거에 이미 success/failed/refunded까지 간 거래를 다시 조회한
   * 경우에는 그 실제 상태를 그대로 반환한다(클라이언트가 상태를 오인하지 않도록). */
  status: ResultAccessTransactionStatus;
  amount: number;
  freePassRemaining?: number;
  pouchBalance?: number;
  userPassId?: number | null;
  /** 이미 존재하던 transactionId를 재사용한 응답인지(§8.4 중복 클릭 방지 확인용). */
  idempotent: boolean;
}

/**
 * §8.3~§8.5 — 결과보기 권한을 확정한다(AI 생성 "전"에 반드시 먼저 호출해야 한다).
 * FREEPASS/POUCH는 이 함수 안에서 원자적으로 차감까지 완료하고 status="pending"인
 * ResultAccessTransaction을 남긴다. AD는 차감할 자산이 없으므로 즉시 status="pending"
 * 트랜잭션만 생성한다(광고 시청 완료 확인은 호출부가 Phase4 UX 순서로 보장한다 —
 * 광고 SDK의 완료 콜백 "이후"에만 이 함수를 호출하도록 강제).
 *
 * 실패(잔액부족 등)면 ResultAccessTransaction 행을 만들지 않고 ResultAccessError를 던진다
 * (§12 금지사항: "임의 차감 금지" — 실패 시 아무 것도 남기지 않아야 재시도가 안전하다).
 */
export async function beginResultAccess(
  params: BeginResultAccessParams
): Promise<BeginResultAccessResult> {
  const { userId, transactionId, contentType, contentId, categoryKey, paymentMethod, adSessionId } =
    params;

  // ── §8.4 멱등성: 같은 transactionId로 이미 처리된 요청이면 새로 차감하지 않는다. ──
  const existing = await findResultAccessTransaction(transactionId);
  if (existing) {
    if (existing.userId !== userId) {
      throw new ResultAccessError("TRANSACTION_OWNER_MISMATCH", "잘못된 요청입니다.");
    }
    return {
      transactionId: existing.transactionId,
      paymentMethod: existing.paymentMethod as ResultAccessPaymentMethod,
      status: existing.status as ResultAccessTransactionStatus,
      amount: existing.amount,
      idempotent: true,
    };
  }

  if (paymentMethod === "AD") {
    // ── [Phase4 §8.3 서버 재검증] 광고 완료 여부를 클라이언트 선언이 아니라
    // ResultAccessAdSession의 실제 DB 상태로 확인한다. sessionId가 없거나,
    // 존재하지 않거나, 다른 사용자의 세션이거나, 아직 completed가 아니면
    // (중도 종료/콜백 미도달 등) 무조건 거부한다 — §5 "중도 종료 시 권한
    // 승인하지 않음"을 서버 레벨에서 강제하는 지점이다. ──
    if (!adSessionId) {
      throw new ResultAccessError("AD_SESSION_REQUIRED", "광고 시청 세션 정보가 없습니다.");
    }
    const adSession = await prisma.resultAccessAdSession.findUnique({
      where: { sessionId: adSessionId },
    });
    if (!adSession || adSession.userId !== userId) {
      throw new ResultAccessError("AD_SESSION_NOT_FOUND", "광고 시청 세션을 찾을 수 없습니다.");
    }
    if (adSession.status !== "completed") {
      throw new ResultAccessError(
        "AD_SESSION_NOT_COMPLETED",
        "광고 시청이 완료되지 않았습니다. 광고를 끝까지 시청해주세요."
      );
    }

    return prisma.$transaction(async (tx) => {
      // 같은 광고 세션이 다른 트랜잭션에 재사용되지 않도록 consumed로 원자적 전환.
      // (동시 두 요청이 같은 세션으로 begin을 시도해도 하나만 성공한다.)
      const claim = await tx.resultAccessAdSession.updateMany({
        where: { id: adSession.id, status: "completed" },
        data: { status: "consumed" },
      });
      if (claim.count === 0) {
        throw new ResultAccessError(
          "AD_SESSION_ALREADY_USED",
          "이미 사용된 광고 시청 세션입니다."
        );
      }
      const created = await tx.resultAccessTransaction.create({
        data: {
          userId,
          transactionId,
          contentType,
          contentId: contentId ?? null,
          categoryKey: categoryKey ?? null,
          paymentMethod: "AD",
          amount: 0,
          status: "pending",
        },
      });
      return {
        transactionId: created.transactionId,
        paymentMethod: "AD" as const,
        status: "pending" as const,
        amount: 0,
        idempotent: false,
      };
    });
  }

  if (paymentMethod === "FREEPASS") {
    return prisma.$transaction(async (tx) => {
      const consumed = await consumeFreePassOnce(tx, userId);
      if (!consumed.ok) {
        throw new ResultAccessError("NO_FREEPASS_BALANCE", "사용 가능한 프리패스가 없습니다.");
      }
      const created = await tx.resultAccessTransaction.create({
        data: {
          userId,
          transactionId,
          contentType,
          contentId: contentId ?? null,
          categoryKey: categoryKey ?? null,
          paymentMethod: "FREEPASS",
          amount: 1,
          userPassId: consumed.userPassId,
          status: "pending",
        },
      });
      return {
        transactionId: created.transactionId,
        paymentMethod: "FREEPASS" as const,
        status: "pending" as const,
        amount: 1,
        freePassRemaining: consumed.remainingAfter,
        userPassId: consumed.userPassId,
        idempotent: false,
      };
    });
  }

  if (paymentMethod === "POUCH") {
    const price = await getResultAccessPrice(contentType, categoryKey);
    return prisma.$transaction(async (tx) => {
      const spend = await spendLuckPouch(tx, {
        userId,
        amount: price,
        sourceType: "result_access",
        memo: `결과보기 이용(${contentType}${categoryKey ? `/${categoryKey}` : ""})`,
      });
      if (!spend.ok) {
        throw new ResultAccessError("INSUFFICIENT_POUCH_BALANCE", "보유한 복주머니가 부족합니다.");
      }
      const created = await tx.resultAccessTransaction.create({
        data: {
          userId,
          transactionId,
          contentType,
          contentId: contentId ?? null,
          categoryKey: categoryKey ?? null,
          paymentMethod: "POUCH",
          amount: price,
          status: "pending",
        },
      });
      return {
        transactionId: created.transactionId,
        paymentMethod: "POUCH" as const,
        status: "pending" as const,
        amount: price,
        pouchBalance: spend.balanceAfter ?? undefined,
        idempotent: false,
      };
    });
  }

  throw new ResultAccessError("INVALID_PAYMENT_METHOD", "잘못된 결제수단입니다.");
}

/** §8.5 — AI 결과 생성이 성공한 뒤 거래를 최종 확정한다. */
export async function completeResultAccess(
  transactionId: string,
  fortuneRequestId: number | null
): Promise<void> {
  await prisma.resultAccessTransaction.updateMany({
    where: { transactionId, status: "pending" },
    data: { status: "success", fortuneRequestId },
  });
}

/**
 * §8.6 — AI 결과 생성이 실패했을 때 차감분을 복구(환불)한다.
 * transaction_id 기준으로 status가 여전히 "pending"인 경우에만 복구를 수행하고,
 * 이미 success/failed/refunded로 종결된 거래는 그대로 둔다(중복 복구 방지, §14.8).
 */
export async function failAndRefundResultAccess(transactionId: string): Promise<void> {
  await prisma.$transaction(async (tx) => {
    const txn = await tx.resultAccessTransaction.findUnique({ where: { transactionId } });
    if (!txn || txn.status !== "pending") return;

    if (txn.paymentMethod === "FREEPASS" && txn.userPassId != null) {
      // 레거시 시간제 소비(userPassId는 있지만 remainingCount가 null인 케이스)는
      // 원래 차감 자체가 없었으므로 increment해도 무해하다(null 필드는 increment 대상이
      // 아니라 원래 값 그대로 유지되는 컬럼이 아니라, remainingCount가 null인 행에는
      // increment 자체가 적용되지 않고 null로 유지된다 — Prisma가 null 필드에 대한
      // increment를 그대로 null로 반환하므로 안전하다).
      await tx.userPass.update({
        where: { id: txn.userPassId },
        data: { remainingCount: { increment: txn.amount } },
      });
    } else if (txn.paymentMethod === "POUCH") {
      // spendLuckPouch의 역연산 — 일일 상한 클리핑은 "적립"에만 적용되는 규칙이므로
      // 환불(원상복구)에는 관여하지 않는다. earnLuckPouch를 그대로 쓰면 클리핑이
      // 걸릴 수 있어(원래 차감된 만큼 정확히 되돌려야 하므로) 직접 처리한다.
      const wallet = await tx.wallet.findFirst({
        where: { userId: txn.userId, currencyType: "POINT", deletedAt: null },
      });
      if (wallet) {
        const balanceAfter = wallet.balance + txn.amount;
        await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance: balanceAfter, balanceSyncedAt: new Date() },
        });
        await tx.pointHistory.create({
          data: {
            walletId: wallet.id,
            userId: txn.userId,
            amount: txn.amount,
            type: "earn",
            sourceType: "result_access_refund",
            sourceId: txn.id,
            balanceAfter,
            memo: `결과보기 실패 환불(${txn.contentType})`,
          },
        });
      }
    }
    // AD는 차감한 자산이 없으므로 복구할 것이 없다 — 상태만 종결시킨다.

    await tx.resultAccessTransaction.update({
      where: { transactionId },
      data: { status: "refunded", refundedAt: new Date() },
    });
  });
}
