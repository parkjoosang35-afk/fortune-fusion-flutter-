// ══════════════════════════════════════════════════════════════════
// LuckPouchEngine — 복주머니(재화 구조 정리) 공용 적립 보조 로직의 단일 소스.
//
// [배경] 재화 구조 정리 작업에서 "복주머니 적립 구간표"는 여러 진입점
// (출석/커뮤니티/운세/부적/상담/응원 등)에서 발생하지만, 아래 두 가지
// "총량 규칙"은 모든 진입점에 공통으로 적용되어야 한다.
//   1) 일일 총 적립 상한(일반 80 / 이벤트 활성 시 120, 운영자 수동지급은 제외)
//   2) 활동 점수 구간 보너스(3/5/8/12점 달성 시 +3/+5/+8/+12, 1일 1회씩)
// 이 파일 하나에만 구현하고, 각 적립 발생 지점(wallet/earn, fortune/daily 등)은
// 이 모듈의 applyDailyCapAndEarn()/maybeGrantActivityTierBonus()만 호출한다
// (§ 정책 원칙: 관리자/앱 정책 불일치 금지 — 동일 로직 여러 곳에 복붙 금지).
//
// prisma.$transaction 콜백 안에서 사용하는 것을 전제로, 모든 함수는 tx(트랜잭션
// 클라이언트)를 첫 인자로 받는다.
// ══════════════════════════════════════════════════════════════════
import type { Prisma } from "@/generated/prisma/client";

type Tx = Prisma.TransactionClient;

/**
 * 운영자 수동 지급/차감은 일일 상한 계산에서 항상 제외한다.
 * [인트로 전면 개편] "signup_reward"(회원가입 보상)도 여기 포함시킨다 — 가입 직후
 * 다른 적립(출석 등)과 같은 날 겹쳐도 관리자가 설정한 보상 수량(기본 100개)이
 * 일일 상한(80/120)에 걸려 일부만 지급되는 일이 없도록 하기 위함이다. 어차피
 * PointPolicy.dailyLimit=1(1회 한정)로 중복 지급 자체가 막혀 있어 남용 위험은 없다.
 */
const CAP_EXEMPT_SOURCE_TYPES = new Set(["admin_adjust", "admin_grant", "manual", "signup_reward"]);

/**
 * [복주머니 적립 구간표 §활동 점수] 액션별 활동 점수 가중치.
 * sourceType(=PointHistory.sourceType)을 기준으로 오늘 하루 누적된 "활동 점수"를
 * 계산하는 데 사용한다. 목록에 없는 sourceType은 활동 점수에 반영하지 않는다.
 */
export const ACTIVITY_SCORE_WEIGHTS: Record<string, number> = {
  attendance: 1,
  fortune_first_view: 1,
  fortune_category_first_use: 1,
  community_post: 3,
  community_comment: 1,
  cheer_send: 1,
  talisman_make: 2,
  consultation_register: 2,
};

/** [복주머니 적립 구간표 §활동 점수 구간 보너스] 점수 도달 시 지급(1일 1회씩). */
export const ACTIVITY_SCORE_TIERS: Array<{ score: number; bonus: number }> = [
  { score: 3, bonus: 3 },
  { score: 5, bonus: 5 },
  { score: 8, bonus: 8 },
  { score: 12, bonus: 12 },
];

const ACTIVITY_TIER_BONUS_SOURCE_TYPE = "activity_tier_bonus";

function todayRangeKst(): { start: Date; end: Date } {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  const startKst = new Date(Date.UTC(y, m, d, 0, 0, 0));
  const endKst = new Date(Date.UTC(y, m, d + 1, 0, 0, 0));
  return {
    start: new Date(startKst.getTime() - 9 * 60 * 60 * 1000),
    end: new Date(endKst.getTime() - 9 * 60 * 60 * 1000),
  };
}

async function getEconomyConfigValue(tx: Tx, key: string, fallback: number): Promise<number> {
  const row = await tx.economyConfig.findUnique({ where: { key } });
  return row?.value ?? fallback;
}

/** 오늘 하루의 일반 적립 총 상한을 반환한다(이벤트 활성 여부 반영). */
export async function getDailyEarnCap(tx: Tx): Promise<number> {
  const eventActive = (await getEconomyConfigValue(tx, "event_bonus_active", 0)) > 0;
  const key = eventActive ? "daily_earn_cap_event" : "daily_earn_cap_normal";
  const fallback = eventActive ? 120 : 80;
  return getEconomyConfigValue(tx, key, fallback);
}

/**
 * [재화 구조 정리 - 재연결] 지갑이 없는 경우 새로 생성하기 전에 반드시 해당
 * userId의 User 레코드가 실존하는지 먼저 확인한다. 확인 없이 바로
 * tx.wallet.create()를 호출하면 존재하지 않는 userId에 대해 Prisma가
 * P2003(ForeignKeyConstraintViolation)을 던지고, 이는 각 API 라우트의
 * catch 블록에서 구분되지 않아 "복주머니 부족"이 아닌 의도치 않은 500
 * 응답으로 이어진다(2026-08 테스트 중 cheer/empathize/highlight/expose_boost
 * 신규 엔드포인트 검증 과정에서 발견). 존재하지 않는 사용자는 명시적으로
 * USER_NOT_FOUND를 던져, 호출부(spendLuckPouch/applyDailyCapAndEarn 등)를
 * 거쳐 각 라우트가 404로 매핑할 수 있게 한다. 실제 앱 흐름에서는 userId가
 * 항상 인증된 사용자로부터 오므로 이 경로는 사실상 도달하지 않지만, 방어적으로
 * 처리해 "알 수 없는 500"이 발생하지 않도록 한다.
 */
async function getWalletOrCreate(tx: Tx, userId: number) {
  let wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
  if (!wallet) {
    const userExists = await tx.user.findUnique({ where: { id: userId }, select: { id: true } });
    if (!userExists) {
      throw new Error("USER_NOT_FOUND");
    }
    wallet = await tx.wallet.create({ data: { userId, currencyType: "POINT", balance: 0 } });
  }
  return wallet;
}

/**
 * [복주머니 적립 구간표 §일일 총 적립 상한]
 * 오늘 하루 이미 적립된 총량(운영자 지급 제외)에 requestedAmount를 더했을 때
 * 상한을 넘는다면, 상한까지만 잘라서 적립하고 나머지는 버린다(0으로 클리핑).
 * 반환값 grantedAmount가 0이면 이미 상한 도달 상태이므로 지갑 갱신을 하지 않아야 한다.
 */
export async function clipToDailyCap(
  tx: Tx,
  userId: number,
  requestedAmount: number,
  sourceType: string
): Promise<{ grantedAmount: number; cap: number; todayTotal: number }> {
  if (CAP_EXEMPT_SOURCE_TYPES.has(sourceType) || requestedAmount <= 0) {
    return { grantedAmount: requestedAmount, cap: Infinity, todayTotal: 0 };
  }
  const cap = await getDailyEarnCap(tx);
  const { start, end } = todayRangeKst();
  const todayEarns = await tx.pointHistory.findMany({
    where: {
      userId,
      type: "earn",
      createdAt: { gte: start, lt: end },
      sourceType: { notIn: Array.from(CAP_EXEMPT_SOURCE_TYPES) },
    },
    select: { amount: true },
  });
  const todayTotal = todayEarns.reduce((sum, h) => sum + h.amount, 0);
  const remaining = Math.max(0, cap - todayTotal);
  const grantedAmount = Math.min(requestedAmount, remaining);
  return { grantedAmount, cap, todayTotal };
}

/**
 * 복주머니(Wallet/POINT) 적립을 "일일 상한 클리핑"까지 적용해서 실행한다.
 * grantedAmount가 0이면 지갑/이력을 만들지 않고 그대로 반환한다(상한 도달).
 */
export async function applyDailyCapAndEarn(
  tx: Tx,
  params: { userId: number; amount: number; sourceType: string; sourceId?: number; memo: string }
): Promise<{ grantedAmount: number; balanceAfter: number | null; capped: boolean }> {
  const { grantedAmount, cap } = await clipToDailyCap(tx, params.userId, params.amount, params.sourceType);
  if (grantedAmount <= 0) {
    const wallet = await tx.wallet.findFirst({ where: { userId: params.userId, currencyType: "POINT", deletedAt: null } });
    return { grantedAmount: 0, balanceAfter: wallet?.balance ?? null, capped: cap !== Infinity };
  }

  const wallet = await getWalletOrCreate(tx, params.userId);
  const balanceAfter = wallet.balance + grantedAmount;
  await tx.wallet.update({ where: { id: wallet.id }, data: { balance: balanceAfter, balanceSyncedAt: new Date() } });
  await tx.pointHistory.create({
    data: {
      walletId: wallet.id,
      userId: params.userId,
      amount: grantedAmount,
      type: "earn",
      sourceType: params.sourceType,
      sourceId: params.sourceId ?? null,
      balanceAfter,
      memo: params.memo,
    },
  });

  return { grantedAmount, balanceAfter, capped: grantedAmount < params.amount };
}

/**
 * [복주머니 적립 구간표 §활동 점수 구간 보너스]
 * 오늘 누적 활동 점수를 계산하고, 아직 지급되지 않은 새 구간(3/5/8/12)이 있으면
 * 가장 낮은 미지급 구간부터 순서대로 지급한다(중복 지급 방지는 sourceId=score로 판단).
 * 일일 총 상한과는 무관하게 지급한다(구간 보너스는 상한 계산의 대상이 아님 — 활동
 * 자체에 대한 별도 보상이므로 상한 클리핑을 적용하지 않는다. 다만 상한 남용을 막기
 * 위해 CAP_EXEMPT 목록에 넣지 않고 그대로 적립 API를 거치므로, 최종 지갑 반영은
 * applyDailyCapAndEarn을 쓰지 않고 직접 처리한다).
 */
export async function maybeGrantActivityTierBonus(
  tx: Tx,
  userId: number
): Promise<{ newlyGrantedTiers: number[]; todayScore: number }> {
  const { start, end } = todayRangeKst();
  const todayEarns = await tx.pointHistory.findMany({
    where: { userId, type: "earn", createdAt: { gte: start, lt: end } },
    select: { sourceType: true },
  });
  const todayScore = todayEarns.reduce((sum, h) => sum + (ACTIVITY_SCORE_WEIGHTS[h.sourceType] ?? 0), 0);

  const alreadyGranted = await tx.pointHistory.findMany({
    where: { userId, sourceType: ACTIVITY_TIER_BONUS_SOURCE_TYPE, createdAt: { gte: start, lt: end } },
    select: { sourceId: true },
  });
  const grantedScores = new Set(alreadyGranted.map((h) => h.sourceId));

  const newlyGrantedTiers: number[] = [];
  for (const tier of ACTIVITY_SCORE_TIERS) {
    if (todayScore >= tier.score && !grantedScores.has(tier.score)) {
      const wallet = await getWalletOrCreate(tx, userId);
      const balanceAfter = wallet.balance + tier.bonus;
      await tx.wallet.update({ where: { id: wallet.id }, data: { balance: balanceAfter, balanceSyncedAt: new Date() } });
      await tx.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId,
          amount: tier.bonus,
          type: "earn",
          sourceType: ACTIVITY_TIER_BONUS_SOURCE_TYPE,
          sourceId: tier.score,
          balanceAfter,
          memo: `활동 점수 ${tier.score}점 달성 보너스`,
        },
      });
      newlyGrantedTiers.push(tier.score);
    }
  }

  return { newlyGrantedTiers, todayScore };
}

/**
 * 적립류 액션의 "일일 상한 클리핑 + 활동 점수 보너스" 두 단계를 한 번에 처리하는
 * 헬퍼. 대부분의 적립 진입점(커뮤니티/운세/부적/상담 등)은 이 함수 하나만 호출하면
 * 충분하다(출석은 자체 스트릭 로직이 있어 applyDailyCapAndEarn만 개별 사용).
 */
export async function earnLuckPouch(
  tx: Tx,
  params: { userId: number; amount: number; sourceType: string; sourceId?: number; memo: string }
) {
  const earnResult = await applyDailyCapAndEarn(tx, params);
  const tierResult = await maybeGrantActivityTierBonus(tx, params.userId);
  return { ...earnResult, ...tierResult };
}

/**
 * [복주머니 사용 구간표] 복주머니(Wallet/POINT) 차감 전용 헬퍼.
 * earnLuckPouch류와 대칭되는 지출 헬퍼로, 잔액이 부족하면 예외를 던지지 않고
 * { ok: false } 를 반환한다(호출부에서 사용자 친화적 안내 메시지로 변환하기 쉽도록).
 * 잔액이 충분하면 지갑 balance를 amount만큼 차감하고 PointHistory(type: "spend")를
 * 기록한다. 일일 상한(clipToDailyCap)은 "적립"에만 적용되는 규칙이므로 사용(차감)에는
 * 관여하지 않는다.
 */
export async function spendLuckPouch(
  tx: Tx,
  params: { userId: number; amount: number; sourceType: string; sourceId?: number; memo: string }
): Promise<{ ok: boolean; balanceAfter: number | null; reason?: "INSUFFICIENT_BALANCE" }> {
  if (params.amount <= 0) {
    const wallet = await tx.wallet.findFirst({ where: { userId: params.userId, currencyType: "POINT", deletedAt: null } });
    return { ok: true, balanceAfter: wallet?.balance ?? 0 };
  }

  const wallet = await getWalletOrCreate(tx, params.userId);
  if (wallet.balance < params.amount) {
    return { ok: false, balanceAfter: wallet.balance, reason: "INSUFFICIENT_BALANCE" };
  }

  const balanceAfter = wallet.balance - params.amount;
  await tx.wallet.update({ where: { id: wallet.id }, data: { balance: balanceAfter, balanceSyncedAt: new Date() } });
  await tx.pointHistory.create({
    data: {
      walletId: wallet.id,
      userId: params.userId,
      amount: -params.amount,
      type: "spend",
      sourceType: params.sourceType,
      sourceId: params.sourceId ?? null,
      balanceAfter,
      memo: params.memo,
    },
  });

  return { ok: true, balanceAfter };
}

/**
 * [재화 구조 정리 - 재연결] LuckPouchRule(ruleType="spend")에서 actionType에 해당하는
 * 현재 금액을 읽어온다. 관리자가 "복주머니관리" 화면에서 언제든 값을 바꿀 수 있도록,
 * 응원(cheer)/공감(empathize)/글강조(highlight)/노출강화(expose_boost) 등 신규 유료
 * 액션의 금액은 반드시 이 함수를 통해서만 읽어야 한다(엔드포인트에 하드코딩 금지 —
 * "관리자는 값만 조정, 구조는 고정" 원칙). 규칙이 없거나 비활성화된 경우에만 fallback을
 * 사용한다(seed 삭제/오류로 인한 기능 정지 방지용 안전장치).
 */
export async function getSpendRuleAmount(tx: Tx, actionType: string, fallback: number): Promise<number> {
  const rule = await tx.luckPouchRule.findFirst({
    where: { ruleType: "spend", actionType, isActive: true, deletedAt: null },
    orderBy: { displayPriority: "asc" },
  });
  return rule && rule.amount > 0 ? rule.amount : fallback;
}
