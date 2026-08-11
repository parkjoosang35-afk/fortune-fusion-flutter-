"use server";

// 알림패스(AlarmPass) 정책 관리 Server Actions
// [문서7/문서8 승인 반영] Fortune Fusion 3대 재화 중 ①알림패스(시간제 콘텐츠 열람권)의
// 관리자 CRUD. point-policies.ts(key-value형 point_policies) 패턴을 그대로 복제하되,
// pass_policies는 완전 CRUD 대상 테이블이므로 sourceType unique 대신 일반 id 기반 CRUD로 구성.
// RBAC menuCode는 "reward"(리워드관리)를 재사용한다(신규 메뉴 미도입, 문서6 결정 반영).
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";
import { SCOPE_PRESETS, type ScopePresetKey } from "@/lib/open-pass-constants";

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}

function canDeleteReward(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "reward");
}

const PASS_TYPES = ["ad", "partner", "subscription", "event"] as const;
const SCOPE_PRESET_KEYS = Object.keys(SCOPE_PRESETS) as [ScopePresetKey, ...ScopePresetKey[]];

// [프리패스 테스트 인프라 §3] 관리자 CRUD 필드를 확장한다. 기존 name/passType/durationMin/
// dailyLimit/ctaText/bannerImageUrl/linkUrl/bonusPoint/isActive는 그대로 유지하고,
// 스키마에는 이미 있었지만 이 액션에서는 노출되지 않았던 description/scope/happyMoneyPrice/
// adRewardEnabled/isFeatured/displayPriority + 신규 컬럼 startAt/endAt/testModeAllowed,
// 그리고 uiCopy(JSON)에 담을 lockCopy/acquireCopy/expireCopy를 추가로 받는다.
const PassPolicySchema = z.object({
  name: z.string().min(1, "정책명을 입력해주세요."),
  passType: z.enum(PASS_TYPES, {
    message: "passType은 ad/partner/subscription/event 중 하나여야 합니다.",
  }),
  durationMin: z.coerce.number().int().positive("지속시간(분)은 1 이상이어야 합니다."),
  dailyLimit: z.coerce.number().int().min(0).optional().nullable(),
  ctaText: z.string().optional().nullable(),
  bannerImageUrl: z.string().optional().nullable(),
  linkUrl: z.string().optional().nullable(),
  bonusPoint: z.coerce.number().int().min(0).optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
  // ── §3 확장 필드 ──
  description: z.string().optional().nullable(),
  scopePreset: z.enum(SCOPE_PRESET_KEYS).optional().default("all_fortune"),
  happyMoneyPrice: z.coerce.number().int().min(0).optional().nullable(),
  adRewardEnabled: z.coerce.boolean().optional().default(true),
  isFeatured: z.coerce.boolean().optional().default(false),
  displayPriority: z.coerce.number().int().optional().default(0),
  startAt: z.string().optional().nullable(),
  endAt: z.string().optional().nullable(),
  testModeAllowed: z.coerce.boolean().optional().default(true),
  lockCopy: z.string().optional().nullable(),
  acquireCopy: z.string().optional().nullable(),
  expireCopy: z.string().optional().nullable(),
});

// scopePreset(관리자 UI 전용 선택값) → 실제 DB 컬럼(scope CSV) + uiCopy(JSON) 변환.
// Prisma create/update data에는 scopePreset이 아니라 scope/uiCopy 컬럼이 들어가야 하므로
// 항상 이 헬퍼를 거쳐서 payload를 만든다(§15 앱-관리자 데이터 불일치 금지 원칙과 동일한 이유로,
// 이 변환 로직도 여기 한 곳에만 둔다).
type PolicyParsedData<T extends { scopePreset: ScopePresetKey; startAt?: string | null; endAt?: string | null; lockCopy?: string | null; acquireCopy?: string | null; expireCopy?: string | null }> = T;

function toPolicyWriteData<
  T extends {
    scopePreset: ScopePresetKey;
    startAt?: string | null;
    endAt?: string | null;
    lockCopy?: string | null;
    acquireCopy?: string | null;
    expireCopy?: string | null;
  }
>(parsed: PolicyParsedData<T>) {
  const { scopePreset, startAt, endAt, lockCopy, acquireCopy, expireCopy, ...rest } = parsed;
  const uiCopy = JSON.stringify({
    lockCopy: lockCopy ?? null,
    acquireCopy: acquireCopy ?? null,
    expireCopy: expireCopy ?? null,
  });
  return {
    ...rest,
    scope: SCOPE_PRESETS[scopePreset],
    startAt: startAt ? new Date(startAt) : null,
    endAt: endAt ? new Date(endAt) : null,
    uiCopy,
  };
}

export interface PassPolicyFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
export async function createPassPolicy(
  _prevState: PassPolicyFormState,
  formData: FormData
): Promise<PassPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const happyMoneyPriceRaw = formData.get("happyMoneyPrice");
  const parsed = PassPolicySchema.safeParse({
    name: formData.get("name"),
    passType: formData.get("passType"),
    durationMin: formData.get("durationMin"),
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    ctaText: formData.get("ctaText") || null,
    bannerImageUrl: formData.get("bannerImageUrl") || null,
    linkUrl: formData.get("linkUrl") || null,
    bonusPoint: formData.get("bonusPoint") ?? 0,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    description: formData.get("description") || null,
    scopePreset: formData.get("scopePreset") || "all_fortune",
    happyMoneyPrice: happyMoneyPriceRaw === "" ? null : happyMoneyPriceRaw,
    adRewardEnabled: formData.get("adRewardEnabled") === "on" || formData.get("adRewardEnabled") === "true",
    isFeatured: formData.get("isFeatured") === "on" || formData.get("isFeatured") === "true",
    displayPriority: formData.get("displayPriority") ?? 0,
    startAt: formData.get("startAt") || null,
    endAt: formData.get("endAt") || null,
    testModeAllowed: formData.get("testModeAllowed") === "on" || formData.get("testModeAllowed") === "true",
    lockCopy: formData.get("lockCopy") || null,
    acquireCopy: formData.get("acquireCopy") || null,
    expireCopy: formData.get("expireCopy") || null,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.passPolicy.create({
    data: {
      ...toPolicyWriteData(parsed.data),
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "pass_policy",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/pass-policies");
  return { success: true };
}

// ── 수정 ──
const UpdatePassPolicySchema = PassPolicySchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updatePassPolicy(
  _prevState: PassPolicyFormState,
  formData: FormData
): Promise<PassPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const happyMoneyPriceRaw = formData.get("happyMoneyPrice");
  const parsed = UpdatePassPolicySchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    passType: formData.get("passType"),
    durationMin: formData.get("durationMin"),
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    ctaText: formData.get("ctaText") || null,
    bannerImageUrl: formData.get("bannerImageUrl") || null,
    linkUrl: formData.get("linkUrl") || null,
    bonusPoint: formData.get("bonusPoint") ?? 0,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    description: formData.get("description") || null,
    scopePreset: formData.get("scopePreset") || "all_fortune",
    happyMoneyPrice: happyMoneyPriceRaw === "" ? null : happyMoneyPriceRaw,
    adRewardEnabled: formData.get("adRewardEnabled") === "on" || formData.get("adRewardEnabled") === "true",
    isFeatured: formData.get("isFeatured") === "on" || formData.get("isFeatured") === "true",
    displayPriority: formData.get("displayPriority") ?? 0,
    startAt: formData.get("startAt") || null,
    endAt: formData.get("endAt") || null,
    testModeAllowed: formData.get("testModeAllowed") === "on" || formData.get("testModeAllowed") === "true",
    lockCopy: formData.get("lockCopy") || null,
    acquireCopy: formData.get("acquireCopy") || null,
    expireCopy: formData.get("expireCopy") || null,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.passPolicy.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 정책입니다." };
  }

  const after = await prisma.passPolicy.update({
    where: { id },
    data: { ...toPolicyWriteData(data), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "pass_policy",
      targetId: id,
      before: JSON.stringify({
        name: before.name,
        passType: before.passType,
        durationMin: before.durationMin,
        dailyLimit: before.dailyLimit,
        bonusPoint: before.bonusPoint,
        isActive: before.isActive,
      }),
      after: JSON.stringify({
        name: after.name,
        passType: after.passType,
        durationMin: after.durationMin,
        dailyLimit: after.dailyLimit,
        bonusPoint: after.bonusPoint,
        isActive: after.isActive,
      }),
    },
  });

  revalidatePath("/reward/pass-policies");
  return { success: true };
}

// ── 삭제 (soft delete) — RBAC상 reward는 operator까지 RW, D는 super_admin 전용 ──
const DeletePassPolicySchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function deletePassPolicy(
  _prevState: PassPolicyFormState,
  formData: FormData
): Promise<PassPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeletePassPolicySchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.passPolicy.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 정책입니다." };
  }

  await prisma.passPolicy.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "pass_policy",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/pass-policies");
  return { success: true };
}

// ────────────────────────────────────────────────────────────────
// [프리패스 단순화 - 쿠팡파트너스 전용] §1/§10
// 기존 pass_policies는 ad/partner/subscription/event 4종 + 20여개 확장
// 필드를 갖춘 범용 CRUD 테이블이었으나, "프리패스는 쿠팡 파트너스 광고
// 전용 기능으로만 운영"하기로 결정함에 따라 관리자가 만지는 값은 단 2개
// (프리패스 이용시간 durationMin, 광고 확인 대기시간 adWaitSeconds)로
// 줄인다. 광고 이미지/쿠팡 광고 소스는 이 액션이 아니라 CMS 배너
// (positionCode='open_pass')에서 등록하므로 여기서는 다루지 않는다.
//
// 기존 다건(N) 정책 테이블 구조를 그대로 유지한 채(스키마 변경/데이터
// 손실 없이), passType='ad'인 정책 중 가장 오래된 1건을 "단일 프리패스
// 정책"으로 취급한다(없으면 자동 생성). 이렇게 하면 기존 UserPass 이력/
// operationLog 등 참조 무결성을 깨지 않고, 화면만 단순화할 수 있다.
// ────────────────────────────────────────────────────────────────

const OPEN_PASS_DURATION_OPTIONS = [30, 60, 120, 180, 1440] as const;
const OPEN_PASS_WAIT_SECONDS_OPTIONS = [4, 5, 10] as const;

// [신통방통 기존시스템유지+프리패스 카테고리별 이용횟수 제한] §6/§27
// 관리자가 설정하는 "카테고리별 최대 이용횟수"(기본 2회) 선택 옵션. null(무제한)도
// 허용해 운영 중 필요 시 제한을 완전히 끌 수 있게 한다.
const CATEGORY_MAX_USAGE_OPTIONS = [1, 2, 3, 5, 10] as const;

export interface OpenPassSettings {
  id: number;
  durationMin: number;
  adWaitSeconds: number;
  isActive: boolean;
  adHelpMessage: string;
  adGuideTitle: string;
  adGuideText: string;
  categoryMaxUsage: number | null;
}

// [프리패스 UI 문구 관리자 연동] 관리자가 아직 값을 입력하지 않았을 때 사용할
// 기본 문구(기존 하드코딩 값과 동일하게 유지해 첫 배포 시 UI가 비어보이지 않게 함).
const DEFAULT_AD_HELP_MESSAGE =
  "쿠팡 파트너스 활동을 통해 일정 수수료를 지급받는 제휴 광고예요.\n쿠팡 방문 후 앱으로 돌아오면 잠시 후 자동으로 프리패스가 지급됩니다.";
const DEFAULT_AD_GUIDE_TITLE = "프리패스가 필요해요";
const DEFAULT_AD_GUIDE_TEXT = "쿠팡 파트너스 광고를 확인하면 프리패스 이용시간 동안\n모든 콘텐츠를 무료로 이용할 수 있어요.";

/** 단일 프리패스(쿠팡파트너스) 정책을 조회하고, 없으면 기본값으로 생성한다. */
export async function getOrCreateOpenPassSettings(): Promise<OpenPassSettings> {
  const existing = await prisma.passPolicy.findFirst({
    where: { passType: "ad", deletedAt: null },
    orderBy: { id: "asc" },
  });
  if (existing) {
    return {
      id: existing.id,
      durationMin: existing.durationMin,
      adWaitSeconds: existing.adWaitSeconds,
      isActive: existing.isActive,
      adHelpMessage: existing.adHelpMessage ?? DEFAULT_AD_HELP_MESSAGE,
      adGuideTitle: existing.adGuideTitle ?? DEFAULT_AD_GUIDE_TITLE,
      adGuideText: existing.adGuideText ?? DEFAULT_AD_GUIDE_TEXT,
      categoryMaxUsage: existing.categoryMaxUsage ?? null,
    };
  }

  const created = await prisma.passPolicy.create({
    data: {
      name: "프리패스 (쿠팡 파트너스)",
      passType: "ad",
      durationMin: 60,
      adWaitSeconds: 5,
      isActive: true,
      ctaText: "쿠팡 방문하기",
      description: "쿠팡 파트너스 광고를 확인하면 지급되는 프리패스",
      adHelpMessage: DEFAULT_AD_HELP_MESSAGE,
      adGuideTitle: DEFAULT_AD_GUIDE_TITLE,
      adGuideText: DEFAULT_AD_GUIDE_TEXT,
    },
  });
  return {
    id: created.id,
    durationMin: created.durationMin,
    adWaitSeconds: created.adWaitSeconds,
    isActive: created.isActive,
    adHelpMessage: created.adHelpMessage ?? DEFAULT_AD_HELP_MESSAGE,
    adGuideTitle: created.adGuideTitle ?? DEFAULT_AD_GUIDE_TITLE,
    adGuideText: created.adGuideText ?? DEFAULT_AD_GUIDE_TEXT,
    categoryMaxUsage: created.categoryMaxUsage ?? null,
  };
}

const OpenPassSettingsSchema = z.object({
  durationMin: z.coerce
    .number()
    .int()
    .refine((v) => (OPEN_PASS_DURATION_OPTIONS as readonly number[]).includes(v), {
      message: "이용시간은 30/60/120/180/1440분 중 하나여야 합니다.",
    }),
  adWaitSeconds: z.coerce
    .number()
    .int()
    .refine((v) => (OPEN_PASS_WAIT_SECONDS_OPTIONS as readonly number[]).includes(v), {
      message: "대기시간은 4/5/10초 중 하나여야 합니다.",
    }),
  isActive: z.coerce.boolean().optional().default(true),
  adHelpMessage: z.string().min(1, "도움말 안내 문구를 입력해주세요."),
  adGuideTitle: z.string().min(1, "안내 제목을 입력해주세요."),
  adGuideText: z.string().min(1, "안내 문구를 입력해주세요."),
  // categoryMaxUsage: "무제한"(빈 값)이면 null, 아니면 옵션 중 하나여야 함.
  categoryMaxUsage: z
    .union([z.coerce.number().int(), z.null()])
    .optional()
    .refine(
      (v) => v == null || (CATEGORY_MAX_USAGE_OPTIONS as readonly number[]).includes(v),
      { message: "카테고리별 최대 이용횟수는 1/2/3/5/10회 또는 무제한 중 하나여야 합니다." }
    ),
});

export interface OpenPassSettingsFormState {
  error?: string;
  success?: boolean;
}

export async function updateOpenPassSettings(
  _prevState: OpenPassSettingsFormState,
  formData: FormData
): Promise<OpenPassSettingsFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const categoryMaxUsageRaw = formData.get("categoryMaxUsage");
  const parsed = OpenPassSettingsSchema.safeParse({
    durationMin: formData.get("durationMin"),
    adWaitSeconds: formData.get("adWaitSeconds"),
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    adHelpMessage: formData.get("adHelpMessage"),
    adGuideTitle: formData.get("adGuideTitle"),
    adGuideText: formData.get("adGuideText"),
    categoryMaxUsage: categoryMaxUsageRaw === "" || categoryMaxUsageRaw == null ? null : categoryMaxUsageRaw,
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const settings = await getOrCreateOpenPassSettings();

  const before = {
    durationMin: settings.durationMin,
    adWaitSeconds: settings.adWaitSeconds,
    categoryMaxUsage: settings.categoryMaxUsage,
  };
  await prisma.passPolicy.update({
    where: { id: settings.id },
    data: {
      durationMin: parsed.data.durationMin,
      adWaitSeconds: parsed.data.adWaitSeconds,
      isActive: parsed.data.isActive,
      adHelpMessage: parsed.data.adHelpMessage,
      adGuideTitle: parsed.data.adGuideTitle,
      adGuideText: parsed.data.adGuideText,
      categoryMaxUsage: parsed.data.categoryMaxUsage ?? null,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "pass_policy",
      targetId: settings.id,
      before: JSON.stringify(before),
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/pass-policies");
  return { success: true };
}
