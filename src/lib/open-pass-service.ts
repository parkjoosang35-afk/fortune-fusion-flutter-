// ══════════════════════════════════════════════════════════════════
// OpenPassService — 열림패스 지급/광고보상 공용 로직의 단일 소스.
//
// [배경] admin-simulation.ts(관리자 테스트랩의 "광고 성공 시뮬레이션")와
// /api/public/open-pass/reward-complete(Flutter 앱의 실제 광고 시청 성공 콜백)는
// "열림패스를 지급한다"는 동일한 비즈니스 로직을 수행해야 한다. 이 로직을 두 곳에
// 각각 구현하면 시간이 지나며 동작이 갈라질 위험이 있으므로(§15 금지 원칙: 관리자/앱
// 정책 불일치 금지), 이 파일 하나에만 구현하고 양쪽 모두 이 파일을 import해서 쓴다.
//
// "use server" 지시어를 사용하지 않는 일반 lib 모듈이다(Server Action이 아니라
// Server Action/Route Handler 양쪽에서 호출되는 공용 헬퍼이기 때문).
// ══════════════════════════════════════════════════════════════════
import { prisma } from "@/lib/db";
import { isMockAdSourceType } from "@/lib/open-pass-constants";

export class OpenPassServiceError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

/**
 * 특정 사용자의 열림패스(프리패스)가 현재 활성 상태인지 확인한다.
 *
 * [배경 - 프리패스 무료이용 버그 수정] /api/public/pass/status가 Flutter
 * PassProvider/AccessChecker에게 알려주는 "활성 여부" 판정 기준(만료시각만 확인)을
 * 그대로 재사용한다. 각 AI 운세 API(tarot/daily/saju/name)가 포인트 차감 여부를
 * 판단하는 데 이 함수를 단일 소스로 사용해야 한다(§15 "관리자/앱 정책 불일치 금지"와
 * 동일한 이유로, 활성 판정 로직을 라우트마다 다시 구현하면 안 된다).
 *
 * pass-policies.ts의 DEFAULT_AD_GUIDE_TEXT("프리패스 이용시간 동안 모든 콘텐츠를
 * 무료로 이용할 수 있어요")가 명시하는 설계 의도를 실제로 구현하는 지점이다 —
 * 이 함수가 true를 반환하면 호출측은 포인트 차감(및 잔액부족 실패)을 완전히
 * 건너뛰어야 한다.
 */
export async function isOpenPassActive(userId: number): Promise<boolean> {
  const now = new Date();
  const activePass = await prisma.userPass.findFirst({
    where: { userId, expiresAt: { gt: now } },
  });
  return !!activePass;
}

/**
 * 현재 활성 상태인 UserPass(+정책)를 조회한다. isOpenPassActive()와 동일한
 * "만료시각만 확인" 기준을 재사용하되, 카테고리 이용횟수 검증/증가 등 정책 정보가
 * 함께 필요한 호출자(예: 아래 checkAndConsumeCategoryUsage, pass/status route)를
 * 위해 레코드 자체를 반환한다. 단일 판정 소스 원칙(§15)에 따라 이 함수가 반환하는
 * "활성 패스 없음(null)"이 곧 isOpenPassActive() === false와 항상 일치해야 한다.
 */
export async function getActiveUserPass(userId: number) {
  const now = new Date();
  return prisma.userPass.findFirst({
    where: { userId, expiresAt: { gt: now } },
    orderBy: { expiresAt: "desc" },
    include: { policy: true },
  });
}

export interface CategoryUsageCheckResult {
  allowed: boolean;
  reason?: "NO_ACTIVE_PASS" | "CATEGORY_LIMIT_REACHED";
  usageCount: number;
  maxUsage: number | null;
  userPassId: number | null;
}

/**
 * [어뷰징 방지 개편, 2026-08] KST(UTC+9) 기준 "오늘"의 날짜키("YYYY-MM-DD")를 반환한다.
 * pass_category_usages.dateKey와 아래 checkDailyAbsoluteLimit()의 fortuneRequest 조회 범위
 * 계산에 공통으로 사용한다 — daily route의 todayRangeUtcKST()/luck-pouch-engine.ts의
 * todayRangeKst()와 동일한 KST 절단 규칙을 재사용해야 한다(§15 판정 기준 불일치 금지).
 */
function todayKstKey(): string {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  return `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** KST 기준 "오늘" 하루의 시작/끝을 UTC Date로 반환한다(fortuneRequest.createdAt 범위 조회용). */
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

/** 유저별 절대 일일 AI 호출 상한(프리패스 보유 여부와 무관하게 항상 적용). */
export const DAILY_ABSOLUTE_AI_CALL_LIMIT = 5;

export interface DailyAbsoluteLimitResult {
  allowed: boolean;
  usageCount: number;
  maxUsage: number;
}

/**
 * [어뷰징 방지 개편, 2026-08 — §신규 ①] 유저별 "오늘 하루 AI 운세 호출 총합"의 절대 상한을
 * 검사한다. 프리패스의 카테고리별 이용횟수 제한(checkCategoryUsage, 패스 1건당 카테고리당
 * 기본 2회)과는 완전히 독립적인 2중 방어선이다 — 프리패스를 아무리 자주 재발급받아도
 * (광고 재시청 쿨다운 30초 + 일일 5회 한도로 재발급 자체는 가능했음) 이 절대 상한은
 * userId 기준으로 하루 전체를 통틀어 딱 DAILY_ABSOLUTE_AI_CALL_LIMIT(5)회로 못박는다.
 *
 * [집계 기준] fortuneRequest 테이블에서 오늘(KST) 생성된 status="success" 레코드 수를
 * 그대로 센다. saju는 다중 주제를 한 번에 요청해도 fortuneRequest 레코드는 1건만 생성되므로
 * (Promise.allSettled로 LLM은 여러 번 호출되지만 "1회 이용"으로 집계되는 기존 동작을
 * 그대로 유지) 이 카운트도 "라우트 호출 1회 = 1"로 집계된다. daily route처럼
 * checkCategoryUsage를 쓰지 않는 라우트도 이 절대 상한 검사는 동일하게 받아야 한다.
 */
export async function checkDailyAbsoluteLimit(userId: number): Promise<DailyAbsoluteLimitResult> {
  const { start, end } = todayRangeKst();
  const usageCount = await prisma.fortuneRequest.count({
    where: {
      userId,
      status: "success",
      deletedAt: null,
      createdAt: { gte: start, lt: end },
    },
  });
  return {
    allowed: usageCount < DAILY_ABSOLUTE_AI_CALL_LIMIT,
    usageCount,
    maxUsage: DAILY_ABSOLUTE_AI_CALL_LIMIT,
  };
}

/**
 * [신통방통 기존시스템유지+프리패스 카테고리별 이용횟수 제한] §6/§7/§24/§27
 *
 * 현재 활성 프리패스가 있는지 먼저 확인하고(없으면 즉시 차단), 있으면 이 카테고리
 * (categoryKey)의 "userId + 오늘(KST) 날짜" 기준 누적 이용횟수를 조회해
 * policy.categoryMaxUsage(기본 2회, null=무제한)를 초과했는지 판정한다.
 *
 * [어뷰징 방지 개편, 2026-08] 과거에는 userPassId 기준으로 카운트해서 패스를
 * 재발급받으면(광고 재시청) 카운터가 0으로 리셋되는 구멍이 있었다. 이제는 userId +
 * categoryKey + dateKey(오늘 KST 날짜) 기준으로 카운트하므로, 패스가 몇 번
 * 재발급되더라도 같은 날에는 카운트가 누적되어 절대 리셋되지 않는다. 활성 패스가
 * 있어야 이용 자체는 가능하지만(NO_ACTIVE_PASS 판정은 그대로 유지), 카운트 자체는
 * 패스 인스턴스가 아니라 유저+날짜에 귀속된다.
 *
 * 이 함수는 "검사만" 하고 카운트를 증가시키지 않는다(consume=false 상태 미리보기용).
 * 실제 이용 처리(카운트 +1)는 consumeCategoryUsage()가 담당한다 — 두 단계로 나눈
 * 이유는 pass/consume route가 "검사 실패 시 즉시 403, 성공해야만 +1"을 트랜잭션
 * 없이도 명확히 표현할 수 있게 하기 위함이다.
 */
export async function checkCategoryUsage(
  userId: number,
  categoryKey: string
): Promise<CategoryUsageCheckResult> {
  const activePass = await getActiveUserPass(userId);
  if (!activePass) {
    return { allowed: false, reason: "NO_ACTIVE_PASS", usageCount: 0, maxUsage: null, userPassId: null };
  }

  const maxUsage = activePass.policy.categoryMaxUsage ?? null;
  const dateKey = todayKstKey();
  const usage = await prisma.passCategoryUsage.findUnique({
    where: { userId_categoryKey_dateKey: { userId, categoryKey, dateKey } },
  });
  const usageCount = usage?.usageCount ?? 0;

  if (maxUsage != null && usageCount >= maxUsage) {
    return { allowed: false, reason: "CATEGORY_LIMIT_REACHED", usageCount, maxUsage, userPassId: activePass.id };
  }
  return { allowed: true, usageCount, maxUsage, userPassId: activePass.id };
}

/**
 * checkCategoryUsage()로 허용된 경우에만 호출해 실제 이용횟수를 +1 한다(upsert).
 * [어뷰징 방지 개편, 2026-08] upsert 키를 userId+categoryKey+dateKey(오늘 KST 날짜)로
 * 변경했다 — userPassId는 "가장 최근에 이 카운트를 소비한 패스"를 남겨두는 참고값으로만
 * 갱신한다(카운트 판정에는 사용하지 않음, 관리자 화면 감사용).
 * 동시성 상황에서 정확한 카운트가 필요하면 트랜잭션 내에서 checkCategoryUsage +
 * consumeCategoryUsage를 함께 호출해야 한다(pass/consume route가 이 패턴을 따른다).
 */
export async function consumeCategoryUsage(userPassId: number, userId: number, categoryKey: string) {
  const dateKey = todayKstKey();
  return prisma.passCategoryUsage.upsert({
    where: { userId_categoryKey_dateKey: { userId, categoryKey, dateKey } },
    create: { userPassId, userId, categoryKey, dateKey, usageCount: 1 },
    update: { usageCount: { increment: 1 }, userPassId },
  });
}

/**
 * 관리자 회원 상세 화면(§12/STEP12)에서 "카테고리별 N/2" 형태로 보여줄 수 있도록,
 * 오늘(KST) 하루의 전체 카테고리 이용현황을 한 번에 조회한다. 활성 패스가 없으면
 * null을 반환한다(화면은 "현재 이용 중인 프리패스 없음"으로 표시해야 함).
 *
 * [어뷰징 방지 개편, 2026-08] 조회 기준이 userPassId → userId+dateKey(오늘)로 바뀌었다 —
 * 오늘 하루 동안 패스가 여러 번 재발급되었어도 카운트는 유저+날짜 단위로 이미 합산되어
 * 있으므로, 이 함수는 activePass.id로 필터링하지 않고 오늘 날짜의 userId 레코드를 그대로 반환한다.
 */
export async function getCategoryUsageSummary(userId: number) {
  const activePass = await getActiveUserPass(userId);
  if (!activePass) return null;
  const dateKey = todayKstKey();
  const usages = await prisma.passCategoryUsage.findMany({
    where: { userId, dateKey },
  });
  return {
    userPass: activePass,
    maxUsage: activePass.policy.categoryMaxUsage ?? null,
    usages: usages.map((u) => ({ categoryKey: u.categoryKey, usageCount: u.usageCount })),
  };
}

// [재화 구조 정리 - 재연결, 2026-08] 아래 두 함수는 더 이상 어디서도 호출되지 않는다.
// LuckPouchWallet은 실제 앱의 어떤 화면도 읽지 않는 죽은 테이블로 확인되어
// admin-simulation.ts의 §4 "복주머니 테스트"가 실제 원장(Wallet/POINT)을 쓰도록
// 재연결되었고, /api/public/luck-pouch/* 3개 라우트(호출자 없음)도 삭제했다.
// 이 함수들은 스키마 마이그레이션 없이 즉시 삭제 가능한 최소 위험 잔재이므로
// export만 유지하고, 새 코드에서는 절대 사용하지 말 것(Wallet/POINT + luck-pouch-engine.ts를
// 사용해야 한다). 다음 스키마 정리 세션에서 LuckPouchWallet/LuckPouchHistory 모델 자체
// 삭제와 함께 정리 권장.
export async function findOrCreateLuckPouchWallet(userId: number) {
  let wallet = await prisma.luckPouchWallet.findUnique({ where: { userId } });
  if (!wallet) {
    wallet = await prisma.luckPouchWallet.create({ data: { userId, balance: 0 } });
  }
  return wallet;
}

// [주의] 이름과 달리 이 함수가 다루는 Wallet(POINT)이 현재는 "행복머니"가 아니라
// 실질적인 "복주머니" 원장이다(재화 구조 통합 이후). 새 코드는 이 함수 대신
// luck-pouch-engine.ts의 getWalletOrCreate 계열(비공개) 또는 earnLuckPouch/
// spendLuckPouch를 통해서만 Wallet(POINT)에 접근해야 한다.
export async function findOrCreateHappyMoneyWallet(userId: number) {
  let wallet = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
  if (!wallet) {
    wallet = await prisma.wallet.create({ data: { userId, currencyType: "POINT", balance: 0 } });
  }
  return wallet;
}

/**
 * 열림패스(UserPass) 지급의 단일 진입점.
 * 관리자 수동지급/테스트 시뮬레이션/실제 광고보상 콜백이 모두 이 함수를 통해서만
 * UserPass를 생성한다.
 */
export async function grantOpenPass(params: {
  userId: number;
  policyId: number;
  sourceType: string; // ad/partner/subscription/event/manual/test_mode
  durationOverrideMin?: number;
  scopeOverride?: string;
  grantedByAdminId?: number;
}) {
  const policy = await prisma.passPolicy.findUnique({ where: { id: params.policyId } });
  if (!policy || policy.deletedAt) throw new OpenPassServiceError("POLICY_NOT_FOUND", "존재하지 않는 열림패스 정책입니다.");

  const durationMin = params.durationOverrideMin ?? policy.durationMin;
  const now = new Date();

  // ── [프리패스 테스트 인프라] §7 "이미 활성 상태일 때 추가 지급" 누적 정책 ──
  // 기본 추천안(§7): 남은 시간이 있는 상태에서 추가 지급되면 "이어붙이기"로 합산한다.
  // 예: 남은 20분 상태에서 30분 지급 → 총 50분. 정책(policyId)과 무관하게 해당 유저의
  // "현재 시각 이후에 만료되는 active 패스" 중 가장 늦은 만료시각을 기준시각으로 삼아
  // 그 위에 새 duration을 더한다(먼저 만료되는 패스가 있어도, 가장 오래 남은 것 기준).
  // 이렇게 하면 /api/public/pass/status가 그대로 사용하는
  // "orderBy: { expiresAt: 'desc' }" 조회 로직을 전혀 건드리지 않고도, 새로 만들어지는
  // UserPass 행의 expiresAt 자체가 이미 누적된 값이 되어 자동으로 상태 API에 반영된다.
  const activePass = await prisma.userPass.findFirst({
    where: { userId: params.userId, status: "active", expiresAt: { gt: now } },
    orderBy: { expiresAt: "desc" },
  });
  const baseTime = activePass ? activePass.expiresAt : now;
  const expiresAt = new Date(baseTime.getTime() + durationMin * 60_000);

  const created = await prisma.userPass.create({
    data: {
      userId: params.userId,
      policyId: params.policyId,
      activatedAt: now,
      expiresAt,
      sourceType: params.sourceType,
      status: "active",
      scope: params.scopeOverride ?? null,
      grantedByAdminId: params.grantedByAdminId ?? null,
    },
  });

  // [재화 구조 정리 - 프리패스 상시 적립 제거]
  // 과거에는 policy.bonusPoint > 0 이면 "패스 지급 = 항상 복주머니(구 행복머니) 적립"이
  // 자동으로 붙었다. 프리패스는 순수 "시간제 이용권"이며 상시 적립/할인/전환 정책을
  // 가질 수 없다는 최종 정책에 따라 이 자동 적립 블록은 완전히 제거한다.
  // policy.bonusPoint 필드 자체는 스키마 마이그레이션 리스크를 피하기 위해 남겨두되,
  // 더 이상 어떤 코드에서도 읽지 않는다(값이 있어도 무시). 이벤트성 보너스가 필요하면
  // 운영자가 /reward/luck-pouch-rules 에서 ruleType="earn", actionType="event"로
  // 별도 수동 지급하거나, admin-simulation.ts의 "이벤트 보상" 액션을 사용해야 한다.

  return { userPass: created, policy };
}

/**
 * 특정 유저가 특정 광고소스로 리워드를 받을 자격이 있는지 확인한다.
 * cooldownSeconds(마지막 성공 시점 기준)와 dailyLimit(당일 성공 횟수)을 함께 체크한다.
 * OpenPassAdRewardLog가 유일한 판단 근거 원장이다(§13 QA: 일일 제한/중복지급 방지).
 */
export async function checkAdRewardEligibility(userId: number, adSourceId: number) {
  const adSource = await prisma.openPassAdSource.findUnique({ where: { id: adSourceId } });
  if (!adSource || adSource.deletedAt) {
    return { eligible: false, reason: "AD_SOURCE_NOT_FOUND" as const, adSource: null };
  }
  if (!adSource.isActive) {
    return { eligible: false, reason: "AD_SOURCE_INACTIVE" as const, adSource };
  }
  const now = new Date();
  if (adSource.startAt && now < adSource.startAt) {
    return { eligible: false, reason: "AD_SOURCE_NOT_STARTED" as const, adSource };
  }
  if (adSource.endAt && now > adSource.endAt) {
    return { eligible: false, reason: "AD_SOURCE_ENDED" as const, adSource };
  }

  if (adSource.cooldownSeconds > 0) {
    const lastSuccess = await prisma.openPassAdRewardLog.findFirst({
      where: { userId, adSourceId, result: "success" },
      orderBy: { createdAt: "desc" },
    });
    if (lastSuccess) {
      const elapsedSec = (now.getTime() - lastSuccess.createdAt.getTime()) / 1000;
      if (elapsedSec < adSource.cooldownSeconds) {
        return {
          eligible: false,
          reason: "COOLDOWN" as const,
          adSource,
          cooldownRemainingSec: Math.ceil(adSource.cooldownSeconds - elapsedSec),
        };
      }
    }
  }

  if (adSource.dailyLimit != null) {
    const todayStart = new Date(now);
    todayStart.setHours(0, 0, 0, 0);
    const todayCount = await prisma.openPassAdRewardLog.count({
      where: { userId, adSourceId, result: "success", createdAt: { gte: todayStart } },
    });
    if (todayCount >= adSource.dailyLimit) {
      return { eligible: false, reason: "DAILY_LIMIT_REACHED" as const, adSource, todayCount };
    }
  }

  return { eligible: true as const, adSource };
}

/**
 * 광고소스 또는 상품에 연결된 fallback 첨부파일을 우선순위대로 조회한다.
 * 1) 해당 광고소스의 fallbackAttachmentId
 * 2) 상품(PassPolicy)의 fallbackAttachmentId
 * 3) 둘 다 없으면 null(앱은 기본 안내 문구를 표시해야 함 — §13 "fallback attachment 미설정 시 기본 안내 처리")
 */
export async function resolveFallbackAttachment(adSourceId: number | null, policyId: number | null) {
  if (adSourceId) {
    const adSource = await prisma.openPassAdSource.findUnique({ where: { id: adSourceId } });
    if (adSource?.fallbackAttachmentId) {
      const attachment = await prisma.openPassAttachment.findUnique({ where: { id: adSource.fallbackAttachmentId } });
      if (attachment && attachment.isActive && !attachment.deletedAt) return attachment;
    }
  }
  if (policyId) {
    const policy = await prisma.passPolicy.findUnique({ where: { id: policyId } });
    if (policy?.fallbackAttachmentId) {
      const attachment = await prisma.openPassAttachment.findUnique({ where: { id: policy.fallbackAttachmentId } });
      if (attachment && attachment.isActive && !attachment.deletedAt) return attachment;
    }
  }
  return null;
}

// ── 첨부파일 직렬화(공개 API 응답 공통 포맷) ──
type AttachmentRecord = {
  id: number;
  fileName: string;
  fileType: string;
  purpose: string;
  fileUrl: string | null;
  thumbnailUrl: string | null;
  mimeType: string | null;
  fileSize: number | null;
  htmlContent: string | null;
};

export function serializeAttachment(a: AttachmentRecord | null | undefined) {
  if (!a) return null;
  return {
    id: a.id,
    fileName: a.fileName,
    fileType: a.fileType,
    purpose: a.purpose,
    fileUrl: a.fileUrl,
    thumbnailUrl: a.thumbnailUrl,
    mimeType: a.mimeType,
    fileSize: a.fileSize,
    htmlContent: a.htmlContent,
  };
}

/**
 * 특정 열림패스 상품의 노출 구성(대표 배너/광고유도 배너/공통 fallback + usageType별
 * 첨부파일 묶음)을 조회한다. 관리자 "상품연결" 화면에서 지정한 값을 그대로 반영하며,
 * 앱은 이 함수의 결과만 신뢰하고 파일 목적을 임의로 추정하지 않는다(§15).
 */
export async function resolveProductDisplayConfig(policyId: number) {
  const policy = await prisma.passPolicy.findUnique({ where: { id: policyId } });
  if (!policy || policy.deletedAt) return null;

  const [heroAttachment, promoAttachment, fallbackAttachment, bindings] = await Promise.all([
    policy.heroAttachmentId ? prisma.openPassAttachment.findUnique({ where: { id: policy.heroAttachmentId } }) : null,
    policy.promoAttachmentId ? prisma.openPassAttachment.findUnique({ where: { id: policy.promoAttachmentId } }) : null,
    policy.fallbackAttachmentId
      ? prisma.openPassAttachment.findUnique({ where: { id: policy.fallbackAttachmentId } })
      : null,
    prisma.openPassProductAttachment.findMany({
      where: { passPolicyId: policyId, isActive: true },
      include: { attachment: true },
      orderBy: [{ usageType: "asc" }, { isPrimary: "desc" }, { displayOrder: "asc" }],
    }),
  ]);

  const byUsageType: Record<string, ReturnType<typeof serializeAttachment>[]> = {};
  for (const b of bindings) {
    if (!b.attachment.isActive || b.attachment.deletedAt) continue;
    if (!byUsageType[b.usageType]) byUsageType[b.usageType] = [];
    byUsageType[b.usageType].push(serializeAttachment(b.attachment));
  }

  return {
    hero: serializeAttachment(heroAttachment ?? undefined),
    promo: serializeAttachment(promoAttachment ?? undefined),
    fallback: serializeAttachment(fallbackAttachment ?? undefined),
    byUsageType,
  };
}

/**
 * 특정 열림패스 상품에 연결된(플랫폼별) 광고소스를 우선순위대로 조회한다.
 * userId가 주어지면 각 광고소스별로 checkAdRewardEligibility를 함께 실행해
 * "지금 이 유저가 이 광고소스로 보상을 받을 수 있는지"까지 반영한다.
 */
export async function resolveProductAdConfig(policyId: number, platform: string = "all", userId?: number) {
  const bindings = await prisma.openPassProductAdSource.findMany({
    where: { passPolicyId: policyId, isActive: true, OR: [{ platform }, { platform: "all" }] },
    include: { adSource: true },
    orderBy: [{ isPrimary: "desc" }, { priority: "asc" }],
  });

  const result = [];
  for (const b of bindings) {
    if (!b.adSource.isActive || b.adSource.deletedAt) continue;
    const eligibility = userId ? await checkAdRewardEligibility(userId, b.adSourceId) : null;
    result.push({
      bindingId: b.id,
      adSourceId: b.adSourceId,
      sourceName: b.adSource.sourceName,
      sourceType: b.adSource.sourceType,
      networkName: b.adSource.networkName,
      adUnitId: b.adSource.adUnitId,
      placementId: b.adSource.placementId,
      rewardType: b.adSource.rewardType,
      rewardValue: b.adSource.rewardValue,
      cooldownSeconds: b.adSource.cooldownSeconds,
      dailyLimit: b.adSource.dailyLimit,
      testModeEnabled: b.adSource.testModeEnabled,
      priority: b.priority,
      isPrimary: b.isPrimary,
      platform: b.platform,
      eligible: eligibility ? eligibility.eligible : null,
      eligibilityReason: eligibility && !eligibility.eligible ? eligibility.reason : null,
      // ── [프리패스 테스트 인프라] §4 앱이 mock 광고 화면을 결정적으로 그릴 수 있도록
      // 가짜 시청시간/실패사유를 함꾼 노출한다. 실광고 소스는 둘 다 null.
      isMock: isMockAdSourceType(b.adSource.sourceType),
      simulatedDurationSeconds: b.adSource.simulatedDurationSeconds,
      failMode: b.adSource.failMode,
    });
  }
  return result;
}

/** OpenPassAdRewardLog 기록(성공/실패/no_fill 공통) */
export async function recordAdRewardLog(params: {
  userId: number;
  adSourceId: number;
  passPolicyId?: number | null;
  result: "success" | "fail" | "no_fill" | "cancel" | "timeout";
  rewardGranted: boolean;
  userPassId?: number | null;
  idempotencyKey?: string | null;
}) {
  return prisma.openPassAdRewardLog.create({
    data: {
      userId: params.userId,
      adSourceId: params.adSourceId,
      passPolicyId: params.passPolicyId ?? null,
      result: params.result,
      rewardGranted: params.rewardGranted,
      userPassId: params.userPassId ?? null,
      idempotencyKey: params.idempotencyKey ?? null,
    },
  });
}
