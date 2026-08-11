// ══════════════════════════════════════════════════════════════════
// WishRoomService — 소원방(Wish Room) 도메인 공용 로직의 단일 소스.
//
// [원칙] 모든 wish-room API 라우트는 이 파일의 함수만 사용한다. 정책 숫자
// (하루 힘주기 횟수, 감쇠량, 최대 소원 개수 등)를 라우트에 하드코딩하지 않고
// 항상 getWishRoomConfigNumber/Bool()로 읽는다(관리자 설정 즉시 반영 원칙).
// prisma.$transaction 콜백 안에서 쓰는 함수는 tx를 인자로 받는다.
// ══════════════════════════════════════════════════════════════════
import type { Prisma } from "@/generated/prisma/client";
import { prisma } from "@/lib/db";

type Tx = Prisma.TransactionClient;

// ── 설정값 조회(WishRoomConfig, key-value) ──────────────────────────
export async function getWishRoomConfigNumber(
  key: string,
  fallback: number,
  tx: Tx | typeof prisma = prisma
): Promise<number> {
  const row = await tx.wishRoomConfig.findUnique({ where: { key } });
  if (!row) return fallback;
  const n = Number(row.value);
  return Number.isFinite(n) ? n : fallback;
}

export async function getWishRoomConfigBool(
  key: string,
  fallback: boolean,
  tx: Tx | typeof prisma = prisma
): Promise<boolean> {
  const row = await tx.wishRoomConfig.findUnique({ where: { key } });
  if (!row) return fallback;
  return row.value === "true";
}

// ── 소원방 프로필 획득/생성 ───────────────────────────────────────
export async function getOrCreateWishRoomProfile(tx: Tx, userId: number) {
  let profile = await tx.wishRoomProfile.findUnique({ where: { userId } });
  if (!profile) {
    const userExists = await tx.user.findUnique({ where: { id: userId }, select: { id: true } });
    if (!userExists) throw new Error("USER_NOT_FOUND");
    profile = await tx.wishRoomProfile.create({ data: { userId } });
  }
  return profile;
}

// ── KST 기준 "오늘" 범위(luck-pouch-engine.ts의 todayRangeKst()와 동일 규칙) ──
export function todayRangeKst(): { start: Date; end: Date } {
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

/** KST 기준 "오늘" 날짜 문자열(YYYY-MM-DD) — lastCaredAt 등을 날짜 단위로 비교할 때 사용. */
export function kstDateString(d: Date): string {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10);
}

export function daysBetweenKst(from: Date, to: Date): number {
  const fromKst = new Date(from.getTime() + 9 * 60 * 60 * 1000);
  const toKst = new Date(to.getTime() + 9 * 60 * 60 * 1000);
  const fromDay = Date.UTC(fromKst.getUTCFullYear(), fromKst.getUTCMonth(), fromKst.getUTCDate());
  const toDay = Date.UTC(toKst.getUTCFullYear(), toKst.getUTCMonth(), toKst.getUTCDate());
  return Math.floor((toDay - fromDay) / (24 * 60 * 60 * 1000));
}

/**
 * [미접속 감쇠 규칙] 마지막 돌봄(lastCaredAt) 이후 경과일수에 따라 감쇠할 총량을 계산한다.
 * 1일: day1 / 2일: day1+day2 / 3일 이상: day1+day2+day3 / 7일 이상: +day7Plus(1회만 추가)
 * 감쇠는 누적(경과일이 늘어날수록 더 감소)이 아니라 "현재 경과일에 도달했는지"의 단계합이다.
 */
export async function calcDecayAmount(elapsedDays: number, tx: Tx | typeof prisma = prisma): Promise<number> {
  if (elapsedDays <= 0) return 0;
  const day1 = await getWishRoomConfigNumber("wish_room_decay_day1_amount", 5, tx);
  const day2 = await getWishRoomConfigNumber("wish_room_decay_day2_amount", 10, tx);
  const day3 = await getWishRoomConfigNumber("wish_room_decay_day3_amount", 15, tx);
  const day7Plus = await getWishRoomConfigNumber("wish_room_decay_day7_plus_amount", 25, tx);

  let amount = 0;
  if (elapsedDays >= 1) amount += day1;
  if (elapsedDays >= 2) amount += day2;
  if (elapsedDays >= 3) amount += day3;
  if (elapsedDays >= 7) amount += day7Plus;
  return amount;
}

/**
 * [미접속 감쇠 적용] 소원 하나에 대해 경과일 기준 감쇠를 계산해 energy에 적용하고
 * decayAppliedAt을 갱신한다. 이미 오늘 감쇠를 적용했다면 다시 적용하지 않는다
 * (decayAppliedAt이 오늘과 같은 KST 날짜면 스킵).
 */
export async function applyDecayIfNeeded(
  tx: Tx,
  wish: { id: number; energy: number; lastCaredAt: Date | null; decayAppliedAt: Date | null; createdAt: Date }
): Promise<{ energyAfter: number; decayApplied: number }> {
  const now = new Date();
  const baseline = wish.lastCaredAt ?? wish.createdAt;
  const alreadyToday = wish.decayAppliedAt && kstDateString(wish.decayAppliedAt) === kstDateString(now);
  if (alreadyToday) {
    return { energyAfter: wish.energy, decayApplied: 0 };
  }
  const elapsed = daysBetweenKst(baseline, now);
  if (elapsed <= 0) {
    return { energyAfter: wish.energy, decayApplied: 0 };
  }
  const decay = await calcDecayAmount(elapsed, tx);
  const energyAfter = Math.max(0, wish.energy - decay);
  if (decay > 0) {
    await tx.wishRoomWish.update({
      where: { id: wish.id },
      data: { energy: energyAfter, decayAppliedAt: now },
    });
  }
  return { energyAfter, decayApplied: decay };
}

// ── 소원방 프로필 방문 카운트 갱신(입장 시 호출) ────────────────────
export async function touchVisit(tx: Tx, userId: number) {
  const profile = await getOrCreateWishRoomProfile(tx, userId);
  const now = new Date();
  const lastEntered = profile.lastEnteredAt;
  let consecutive = profile.consecutiveVisitDays;
  if (lastEntered) {
    const elapsed = daysBetweenKst(lastEntered, now);
    if (elapsed === 1) {
      consecutive += 1;
    } else if (elapsed > 1) {
      consecutive = 1;
    }
    // elapsed === 0(오늘 이미 방문)이면 스트릭 변경 없음.
  } else {
    consecutive = 1;
  }
  return tx.wishRoomProfile.update({
    where: { userId },
    data: {
      totalVisitCount: { increment: 1 },
      consecutiveVisitDays: consecutive,
      lastEnteredAt: now,
    },
  });
}

// ── 레벨/경험치 ───────────────────────────────────────────────────
/** 방 레벨업에 필요한 경험치 곡선(레벨 n -> n+1). 간단한 선형 증가(레벨*50+50). */
export function expThresholdForLevel(level: number): number {
  return level * 50 + 50;
}

export function applyExpGain(currentLevel: number, currentExp: number, gain: number): { level: number; exp: number; leveledUp: boolean } {
  let level = currentLevel;
  let exp = currentExp + gain;
  let leveledUp = false;
  while (exp >= expThresholdForLevel(level)) {
    exp -= expThresholdForLevel(level);
    level += 1;
    leveledUp = true;
  }
  return { level, exp, leveledUp };
}

// ── 게시판 연동(기존 Wish 소원성 테이블 재사용) ─────────────────────
/**
 * [소원방 <-> 소원게시판 연동] WishRoomWish를 공개(publish)할 때, 기존 "소원성"
 * Wish 테이블에 파생 게시물을 생성하고 publicWishId로 연결한다. 이미 연결된
 * 경우(publicWishId 존재)는 재생성하지 않고 그대로 반환한다(중복 게시 방지).
 */
export async function publishToWishBoard(
  tx: Tx,
  wishRoomWish: { id: number; userId: number; categoryCode: string; content: string; publicWishId: number | null }
) {
  if (wishRoomWish.publicWishId) {
    const existing = await tx.wish.findUnique({ where: { id: wishRoomWish.publicWishId } });
    if (existing) return existing;
  }
  const created = await tx.wish.create({
    data: {
      userId: wishRoomWish.userId,
      content: wishRoomWish.content,
      category: wishRoomWish.categoryCode,
      isAnonymous: false,
      status: "visible",
    },
  });
  await tx.wishRoomWish.update({
    where: { id: wishRoomWish.id },
    data: { publicWishId: created.id, isPublic: true },
  });
  return created;
}

// ── 카테고리 마스터 헬퍼 ────────────────────────────────────────────
export async function listActiveCategories(tx: Tx | typeof prisma = prisma) {
  return tx.wishRoomCategory.findMany({
    where: { isActive: true, deletedAt: null },
    orderBy: { displayOrder: "asc" },
  });
}

export function serializeWish(w: {
  id: number; categoryCode: string; content: string; isPublic: boolean; isRepresentative: boolean;
  energy: number; maxEnergy: number; careCount: number; cheerCount: number; publicWishId: number | null;
  lastCaredAt: Date | null; status: string; createdAt: Date;
}) {
  return {
    id: `wrw_${w.id}`,
    categoryCode: w.categoryCode,
    content: w.content,
    isPublic: w.isPublic,
    isRepresentative: w.isRepresentative,
    energy: w.energy,
    maxEnergy: w.maxEnergy,
    careCount: w.careCount,
    cheerCount: w.cheerCount,
    publicWishId: w.publicWishId,
    lastCaredAt: w.lastCaredAt ? w.lastCaredAt.toISOString() : null,
    status: w.status,
    createdAt: w.createdAt.toISOString(),
  };
}

export function serializeProfile(p: {
  level: number; exp: number; currentThemeId: number | null; representativeWishId: number | null;
  totalVisitCount: number; totalCareCount: number; consecutiveVisitDays: number; roomState: string;
  hasSeenGuide: boolean; lastEnteredAt: Date | null; lastCaredAt: Date | null;
}) {
  return {
    level: p.level,
    exp: p.exp,
    expToNextLevel: expThresholdForLevel(p.level),
    currentThemeId: p.currentThemeId,
    representativeWishId: p.representativeWishId,
    totalVisitCount: p.totalVisitCount,
    totalCareCount: p.totalCareCount,
    consecutiveVisitDays: p.consecutiveVisitDays,
    roomState: p.roomState,
    hasSeenGuide: p.hasSeenGuide,
    lastEnteredAt: p.lastEnteredAt ? p.lastEnteredAt.toISOString() : null,
    lastCaredAt: p.lastCaredAt ? p.lastCaredAt.toISOString() : null,
  };
}

export function parseWishRoomWishId(idParam: string): number | null {
  const match = /^wrw_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

/**
 * [재화 구조 정리 - 재연결] LuckPouchRule(ruleType="earn")에서 actionType에 해당하는
 * 현재 지급량을 읽어온다. luck-pouch-engine.ts의 getSpendRuleAmount()와 대칭되는
 * earn 전용 조회 헬퍼 — spend 함수를 earn 조회에 억지로 재사용하지 않기 위해 분리한다.
 */
export async function getEarnRuleAmount(tx: Tx | typeof prisma, actionType: string, fallback: number): Promise<number> {
  const rule = await tx.luckPouchRule.findFirst({
    where: { ruleType: "earn", actionType, isActive: true, deletedAt: null },
    orderBy: { displayPriority: "asc" },
  });
  return rule && rule.amount > 0 ? rule.amount : fallback;
}

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Cache-Control": "no-store, no-cache, must-revalidate",
};

export function corsOptionsResponse(methods: string) {
  return new Response(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": `${methods}, OPTIONS`,
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
