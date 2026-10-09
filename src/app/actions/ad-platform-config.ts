"use server";

// [신통방통 관리자 통합 간소화 실행 지시서 - task 4 "광고관리 통합메뉴"]
// AdMob/AdSense 광고 플랫폼 설정 Server Actions.
// system-settings.ts 패턴(zod 검증 + operationLog 기록 + revalidatePath)을 재사용한다.
//
// [설계 원칙 재확인]
// - admob 행: isEnabled(노출 킬스위치)만 이 화면에서 수정 가능. 실제 Ad Unit ID
//   전환은 여전히 Flutter --dart-define=ADMOB_USE_REAL_IDS 빌드타임 플래그로만
//   허용된다(무효 트래픽→계정정지 위험 재도입 방지). publisherId/surface/format
//   필드는 admob 행에서는 사용하지 않는다(항상 null로 유지).
// - adsense 행: publisherId + surfaceConfigJson + formatConfigJson 전부 이
//   화면에서 수정 가능(완전 원격 제어). 저장 즉시 /api/public/ad-config를 통해
//   Flutter에 반영된다(재배포 불필요).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

function canWriteAdManagement(roleCode: string): boolean {
  return canWriteMenu(roleCode, "ad_management");
}

export interface AdPlatformConfigFormState {
  error?: string;
  success?: boolean;
}

// ── AdMob: isEnabled만 토글 ──
const UpdateAdmobSchema = z.object({
  isEnabled: z.coerce.boolean(),
});

export async function updateAdmobConfig(
  _prevState: AdPlatformConfigFormState,
  formData: FormData
): Promise<AdPlatformConfigFormState> {
  const session = await verifyAdminSession();
  if (!canWriteAdManagement(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateAdmobSchema.safeParse({
    isEnabled: formData.get("isEnabled") === "on" || formData.get("isEnabled") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.adPlatformConfig.findUnique({ where: { platform: "admob" } });
  if (!before) {
    return { error: "admob 설정 행이 존재하지 않습니다. 시드 스크립트를 먼저 실행해주세요." };
  }

  const after = await prisma.adPlatformConfig.update({
    where: { platform: "admob" },
    data: {
      isEnabled: parsed.data.isEnabled,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "ad_platform_config",
      targetId: after.id,
      before: JSON.stringify({ isEnabled: before.isEnabled }),
      after: JSON.stringify({ isEnabled: after.isEnabled }),
    },
  });

  revalidatePath("/reward/fortune-ads");
  return { success: true };
}

// ── AdSense: publisherId + 서비스별/포맷별 노출 전부 수정 ──
const SURFACE_KEYS = ["home", "sajuRenewal", "tarot", "wishRoom", "guinji", "face", "palm"] as const;
const FORMAT_KEYS = ["banner", "inPage", "anchor", "vignette"] as const;

const UpdateAdsenseSchema = z.object({
  isEnabled: z.coerce.boolean(),
  publisherId: z
    .string()
    .trim()
    .regex(/^(ca-pub-\d{16})?$/, "퍼블리셔 ID는 'ca-pub-'로 시작하는 16자리 숫자여야 합니다.")
    .optional()
    .nullable(),
  showPlaceholderWhenDisabled: z.coerce.boolean(),
});

export async function updateAdsenseConfig(
  _prevState: AdPlatformConfigFormState,
  formData: FormData
): Promise<AdPlatformConfigFormState> {
  const session = await verifyAdminSession();
  if (!canWriteAdManagement(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const publisherIdRaw = formData.get("publisherId");
  const parsed = UpdateAdsenseSchema.safeParse({
    isEnabled: formData.get("isEnabled") === "on" || formData.get("isEnabled") === "true",
    publisherId: publisherIdRaw === "" ? null : publisherIdRaw,
    showPlaceholderWhenDisabled:
      formData.get("showPlaceholderWhenDisabled") === "on" ||
      formData.get("showPlaceholderWhenDisabled") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const surfaceConfig: Record<string, boolean> = {};
  for (const key of SURFACE_KEYS) {
    surfaceConfig[key] = formData.get(`surface_${key}`) === "on";
  }
  const formatConfig: Record<string, boolean> = {};
  for (const key of FORMAT_KEYS) {
    formatConfig[key] = formData.get(`format_${key}`) === "on";
  }

  const before = await prisma.adPlatformConfig.findUnique({ where: { platform: "adsense" } });
  if (!before) {
    return { error: "adsense 설정 행이 존재하지 않습니다. 시드 스크립트를 먼저 실행해주세요." };
  }

  const after = await prisma.adPlatformConfig.update({
    where: { platform: "adsense" },
    data: {
      isEnabled: parsed.data.isEnabled,
      publisherId: parsed.data.publisherId || null,
      showPlaceholderWhenDisabled: parsed.data.showPlaceholderWhenDisabled,
      surfaceConfigJson: JSON.stringify(surfaceConfig),
      formatConfigJson: JSON.stringify(formatConfig),
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "ad_platform_config",
      targetId: after.id,
      before: JSON.stringify({
        isEnabled: before.isEnabled,
        publisherId: before.publisherId,
        surfaceConfigJson: before.surfaceConfigJson,
        formatConfigJson: before.formatConfigJson,
      }),
      after: JSON.stringify({
        isEnabled: after.isEnabled,
        publisherId: after.publisherId,
        surfaceConfigJson: after.surfaceConfigJson,
        formatConfigJson: after.formatConfigJson,
      }),
    },
  });

  revalidatePath("/reward/fortune-ads");
  return { success: true };
}
