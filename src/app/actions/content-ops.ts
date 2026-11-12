"use server";

// [2026-11-11 기획_01_콘텐츠운영_화면설계 — 탭④ 노출제어] ContentOpsConfig
// Server Actions. 9개 라이브 콘텐츠 + 신규 2개의 "노출 상태(visible/hidden/
// maintenance)"만 다룬다 — 기획서가 강조한 유일한 신규 쓰기 기능.
//
// [Q1 확정 — 편집 권한] 기존 ai_content RBAC 코드를 그대로 재사용한다(별도
// 역할 분리 안 함). ai-prompts.ts/premium-saju.ts와 동일한 canWriteMenu 패턴.
// [Q2 확정 — 점검중 전환 시 자동환불] 하지 않는다. 필요한 경우 운영자가
// 기존 /reward/policies 포인트조정 화면에서 수동 처리한다(새 메커니즘 발명 안 함).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";
import { CONTENT_OPS_ITEMS } from "@/lib/content-ops-meta";

function canWriteContentOps(roleCode: string): boolean {
  return canWriteMenu(roleCode, "ai_content");
}

const VALID_KEYS = CONTENT_OPS_ITEMS.map((i) => i.contentKey) as [string, ...string[]];
const LIST_PATH = "/ai-content/overview";

export interface ContentOpsFormState {
  error?: string;
  success?: boolean;
}

const UpdateExposureSchema = z.object({
  contentKey: z.enum(VALID_KEYS),
  exposureStatus: z.enum(["visible", "hidden", "maintenance"]),
  maintenanceNote: z.string().trim().max(500).optional().default(""),
});

export async function updateContentExposure(
  _prevState: ContentOpsFormState,
  formData: FormData
): Promise<ContentOpsFormState> {
  const session = await verifyAdminSession();
  if (!canWriteContentOps(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateExposureSchema.safeParse({
    contentKey: formData.get("contentKey"),
    exposureStatus: formData.get("exposureStatus"),
    maintenanceNote: formData.get("maintenanceNote") ?? "",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { contentKey, exposureStatus, maintenanceNote } = parsed.data;

  if (exposureStatus === "maintenance" && maintenanceNote.length === 0) {
    return { error: "점검중으로 전환하려면 안내문을 입력해주세요." };
  }

  const before = await prisma.contentOpsConfig.findUnique({ where: { contentKey } });

  const updated = await prisma.contentOpsConfig.upsert({
    where: { contentKey },
    create: {
      contentKey,
      exposureStatus,
      maintenanceNote: exposureStatus === "maintenance" ? maintenanceNote : null,
      updatedBy: session.email,
    },
    update: {
      exposureStatus,
      maintenanceNote: exposureStatus === "maintenance" ? maintenanceNote : null,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "content_ops_config",
      targetId: updated.id,
      before: JSON.stringify({
        exposureStatus: before?.exposureStatus ?? "visible",
        maintenanceNote: before?.maintenanceNote ?? null,
      }),
      after: JSON.stringify({ exposureStatus, maintenanceNote: updated.maintenanceNote }),
    },
  });

  revalidatePath(LIST_PATH);
  revalidatePath(`${LIST_PATH}/${contentKey}`);
  return { success: true };
}
