// ══════════════════════════════════════════════════════════════════
// PouchBoxService — 행운상자(복주머니 탭 신규 기능)의 공용 자격검증/보상결정
// 로직의 단일 소스.
//
// [배경] handoff 패키지(dev-spec.md) 명세: 신통방통 하단바 "복주머니" 탭을
// 누르면 즉시 3x3 상자 그리드가 열리고, "광고보고 상자 열기" CTA → 5초 광고
// 시청 → 상자 shake → 폭발 애니메이션 → 결과(획득 복주머니 개수) 흐름으로
// 진행한다. fortune-ad-service.ts의 검증된 패턴(자격판정을 API 라우트와
// 분리한 단일 소스)을 그대로 재사용하되, 특정 광고 콘텐츠(FortuneAd)에
// 결부되지 않고 "하루 5회"라는 순수 카운트 한도만 있다는 점이 다르다.
//
// [절대 원칙] 보상은 반드시 서버가 결정한다(dev-spec.md §0-3, §4).
// 클라이언트에서 난수 추첨을 하면 어뷰징(변조된 클라이언트가 항상 잭팟을
// 주장)에 취약하므로, rollReward()는 이 파일에만 존재하고 클라이언트에는
// 절대 전달하지 않는다.
// ══════════════════════════════════════════════════════════════════
import { prisma } from "@/lib/db";
import { todayRangeKst } from "@/lib/luck-pouch-engine";

/** dev-spec.md §7 결정 항목 #4 — 하루 한도는 5회로 고정(관리자 확장 없음). */
export const POUCH_BOX_DAILY_LIMIT = 5;

/** dev-spec.md §4 보상 분배 — 가중 확률(합계 1.0). */
const REWARD_TIERS: Array<{
  tier: "common" | "uncommon" | "rare" | "jackpot";
  chance: number;
  min: number;
  max: number;
}> = [
  { tier: "common", chance: 0.55, min: 50, max: 150 },
  { tier: "uncommon", chance: 0.3, min: 150, max: 250 },
  { tier: "rare", chance: 0.13, min: 200, max: 280 },
  { tier: "jackpot", chance: 0.02, min: 300, max: 300 },
];

/**
 * [핵심 원칙] 오직 서버에서만 호출한다. 가중 확률 표(REWARD_TIERS)를 순서대로
 * 누적해 난수 하나로 등급을 결정하고, 등급 구간 내에서 다시 균등 난수로
 * 최종 지급량을 뽑는다. min===max(jackpot)인 경우 그대로 min을 반환한다.
 */
export function rollPouchBoxReward(): {
  amount: number;
  tier: "common" | "uncommon" | "rare" | "jackpot";
} {
  const r = Math.random();
  let cumulative = 0;
  for (const t of REWARD_TIERS) {
    cumulative += t.chance;
    if (r < cumulative) {
      const amount =
        t.min === t.max ? t.min : t.min + Math.floor(Math.random() * (t.max - t.min + 1));
      return { amount, tier: t.tier };
    }
  }
  // 부동소수 누적 오차로 마지막 구간을 못 벗어난 경우를 위한 안전 폴백(jackpot과 동일 처리).
  const last = REWARD_TIERS[REWARD_TIERS.length - 1];
  return { amount: last.max, tier: last.tier };
}

export type PouchBoxEligibilityReason = "DAILY_LIMIT_REACHED";

export interface PouchBoxEligibilityResult {
  eligible: boolean;
  reason?: PouchBoxEligibilityReason;
  todayOpenedCount: number;
  dailyLimit: number;
  dailyLeft: number;
}

/**
 * 오늘(KST) 이 유저가 이미 몇 번 행운상자를 "완료"(COMPLETED)했는지 확인해
 * 하루 5회 한도를 넘었는지 판정한다. PENDING(시청 중 이탈) 세션은 카운트에
 * 넣지 않는다 — 중간 이탈로 소진되지 않도록(dev-spec.md는 "시청 완료"만을
 * 1회로 규정).
 */
export async function checkPouchBoxEligibility(
  userId: number
): Promise<PouchBoxEligibilityResult> {
  const { start, end } = todayRangeKst();
  const todayOpenedCount = await prisma.pouchBoxOpenLog.count({
    where: { userId, rewardStatus: "COMPLETED", createdAt: { gte: start, lt: end } },
  });
  const dailyLeft = Math.max(0, POUCH_BOX_DAILY_LIMIT - todayOpenedCount);
  if (todayOpenedCount >= POUCH_BOX_DAILY_LIMIT) {
    return {
      eligible: false,
      reason: "DAILY_LIMIT_REACHED",
      todayOpenedCount,
      dailyLimit: POUCH_BOX_DAILY_LIMIT,
      dailyLeft: 0,
    };
  }
  return {
    eligible: true,
    todayOpenedCount,
    dailyLimit: POUCH_BOX_DAILY_LIMIT,
    dailyLeft,
  };
}

export const POUCH_BOX_REASON_LABELS: Record<PouchBoxEligibilityReason, string> = {
  DAILY_LIMIT_REACHED: "오늘 남은 행운상자를 모두 확인했어요. 내일 다시 만나요.",
};
