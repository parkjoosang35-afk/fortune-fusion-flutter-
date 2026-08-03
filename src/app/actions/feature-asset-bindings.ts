"use server";

// 기능-자산 매핑(FeatureAssetBinding) 관리 Server Actions
// [열림패스/행복머니/복주머니 통합정책] §5-4/§9-4
// scope(예: fortune_today/wish_room/community 등)는 신규 생성하지 않고
// "제한된 범위"에서만 수정 가능하게 한다(§금지 원칙: 3대 자산 간 스코프 침범 방지).
// 즉 accessType/secondaryAssets/notes/isActive만 수정 허용, scope/featureGroup/primaryAsset은
// 화면에서 읽기 전용으로 노출(구조적 변경은 코드 배포를 통해서만 가능하도록 강제).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}

const ACCESS_TYPES = ["free", "open_pass", "happy_money", "luck_pouch", "mixed_limited"] as const;

const UpdateBindingSchema = z.object({
  id: z.coerce.number().int().positive(),
  accessType: z.enum(ACCESS_TYPES, { message: "accessType 값이 올바르지 않습니다." }),
  secondaryAssets: z.string().optional().nullable(),
  notes: z.string().optional().nullable(),
  isActive: z.coerce.boolean().optional().default(true),
});

export interface FeatureAssetBindingFormState {
  error?: string;
  success?: boolean;
}

export async function updateFeatureAssetBinding(
  _prevState: FeatureAssetBindingFormState,
  formData: FormData
): Promise<FeatureAssetBindingFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const secondaryRaw = formData.get("secondaryAssets");
  const notesRaw = formData.get("notes");
  const parsed = UpdateBindingSchema.safeParse({
    id: formData.get("id"),
    accessType: formData.get("accessType"),
    secondaryAssets: secondaryRaw === "" ? null : secondaryRaw,
    notes: notesRaw === "" ? null : notesRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.featureAssetBinding.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 매핑입니다." };
  }
  if (!before.editableByAdmin) {
    return { error: "이 매핑은 관리자 수정이 제한되어 있습니다(코드 배포로만 변경 가능)." };
  }

  const after = await prisma.featureAssetBinding.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "feature_asset_binding",
      targetId: id,
      before: JSON.stringify(before),
      after: JSON.stringify(after),
    },
  });

  revalidatePath("/reward/feature-bindings");
  return { success: true };
}
