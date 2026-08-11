// ══════════════════════════════════════════════════════════════════
// FortuneAdService — 복주머니 광고 적립 시스템의 공용 자격검증/조회 로직.
//
// open-pass-service.ts의 checkAdRewardEligibility() 패턴을 그대로 재사용하되,
// 지급 대상이 UserPass가 아니라 Wallet(POINT)이라는 점만 다르다. 노출목록
// (/api/ads/fortune), 시청시작(start), 시청완료(complete), 오늘현황(today-status)
// 4개 API가 모두 이 파일의 checkFortuneAdEligibility()를 단일 소스로 사용해
// "관리자 설정과 실제 판정 로직이 갈라지지 않도록" 한다.
// ══════════════════════════════════════════════════════════════════
import { prisma } from "@/lib/db";
import { todayRangeKst } from "@/lib/luck-pouch-engine";

export type FortuneAdEligibilityReason =
  | "AD_NOT_FOUND"
  | "AD_INACTIVE"
  | "AD_NOT_STARTED"
  | "AD_ENDED"
  | "PER_USER_DAILY_LIMIT_REACHED"
  | "DAILY_REWARD_LIMIT_REACHED";

export interface FortuneAdEligibilityResult {
  eligible: boolean;
  reason?: FortuneAdEligibilityReason;
  todayUserCount: number;
  todayTotalReward: number;
}

/**
 * 특정 광고가 "지금, 이 유저"에게 노출/시청 가능한 상태인지 판정한다.
 * 1) 광고 자체 활성/기간(노출 설정) 2) 회원당 하루 시청 횟수(perUserDailyLimit)
 * 3) 광고 1건당 하루 최대 지급 총량(dailyLimitReward, 전체 유저 합산)을 순서대로 검사한다.
 */
export async function checkFortuneAdEligibility(
  adId: number,
  userId: number
): Promise<FortuneAdEligibilityResult> {
  const ad = await prisma.fortuneAd.findUnique({ where: { id: adId } });
  if (!ad || ad.deletedAt || ad.status === "deleted") {
    return { eligible: false, reason: "AD_NOT_FOUND", todayUserCount: 0, todayTotalReward: 0 };
  }
  if (!ad.isActive || ad.status !== "active") {
    return { eligible: false, reason: "AD_INACTIVE", todayUserCount: 0, todayTotalReward: 0 };
  }
  const now = new Date();
  if (ad.startAt && now < ad.startAt) {
    return { eligible: false, reason: "AD_NOT_STARTED", todayUserCount: 0, todayTotalReward: 0 };
  }
  if (ad.endAt && now > ad.endAt) {
    return { eligible: false, reason: "AD_ENDED", todayUserCount: 0, todayTotalReward: 0 };
  }

  const { start, end } = todayRangeKst();

  const todayUserCount = await prisma.fortuneAdWatchLog.count({
    where: { adId, userId, rewardStatus: "COMPLETED", createdAt: { gte: start, lt: end } },
  });
  if (todayUserCount >= ad.perUserDailyLimit) {
    return { eligible: false, reason: "PER_USER_DAILY_LIMIT_REACHED", todayUserCount, todayTotalReward: 0 };
  }

  let todayTotalReward = 0;
  if (ad.dailyLimitReward != null) {
    const todayLogs = await prisma.fortuneAdWatchLog.findMany({
      where: { adId, rewardStatus: "COMPLETED", createdAt: { gte: start, lt: end } },
      select: { rewardAmount: true },
    });
    todayTotalReward = todayLogs.reduce((sum, l) => sum + l.rewardAmount, 0);
    if (todayTotalReward >= ad.dailyLimitReward) {
      return { eligible: false, reason: "DAILY_REWARD_LIMIT_REACHED", todayUserCount, todayTotalReward };
    }
  }

  return { eligible: true, todayUserCount, todayTotalReward };
}

export const FORTUNE_AD_REASON_LABELS: Record<FortuneAdEligibilityReason, string> = {
  AD_NOT_FOUND: "존재하지 않는 광고입니다.",
  AD_INACTIVE: "현재 노출되지 않는 광고입니다.",
  AD_NOT_STARTED: "아직 노출 시작 전인 광고입니다.",
  AD_ENDED: "노출 기간이 종료된 광고입니다.",
  PER_USER_DAILY_LIMIT_REACHED: "오늘의 시청 가능 횟수를 모두 사용했습니다.",
  DAILY_REWARD_LIMIT_REACHED: "오늘 이 광고의 지급 한도가 모두 소진되었습니다.",
};

/** 목록 API(/api/ads/fortune)에서 광고 1건을 클라이언트 응답 포맷으로 직렬화한다. */
export function serializeFortuneAdSummary(ad: {
  id: number;
  title: string;
  description: string | null;
  adType: string;
  imageUrl: string | null;
  videoUrl: string | null;
  externalUrl: string | null;
  adSourceHtml: string | null;
  rewardAmount: number;
  watchSeconds: number;
  priority: number;
  perUserDailyLimit: number;
  dailyLimitReward: number | null;
}) {
  return {
    id: ad.id,
    title: ad.title,
    description: ad.description,
    adType: ad.adType,
    imageUrl: ad.imageUrl,
    videoUrl: ad.videoUrl,
    externalUrl: ad.externalUrl,
    adSourceHtml: ad.adSourceHtml,
    rewardAmount: ad.rewardAmount,
    watchSeconds: ad.watchSeconds,
    priority: ad.priority,
    perUserDailyLimit: ad.perUserDailyLimit,
    dailyLimitReward: ad.dailyLimitReward,
  };
}
