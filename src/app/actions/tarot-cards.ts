"use server";

// 타로카드 마스터 관리 Server Actions
// 05_Admin_System_Design.md §3.2 "타로카드 마스터 관리" — 04A E-5 tarot_cards CRUD
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";

function canWriteAiContent(roleCode: string): boolean {
  if (!canAccessMenu(roleCode, "ai_content")) return false;
  return !!RBAC_MATRIX.ai_content[roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;
}

const TarotCardSchema = z.object({
  name: z.string().min(1, "카드 이름을 입력해주세요."),
  arcanaType: z.enum(["major", "minor"]),
  uprightMeaning: z.string().min(1, "정방향 의미를 입력해주세요."),
  reversedMeaning: z.string().min(1, "역방향 의미를 입력해주세요."),
  sortOrder: z.coerce.number().int().min(0),
  imageUrl: z.string().optional(),
});

export interface TarotCardFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
export async function createTarotCard(
  _prevState: TarotCardFormState,
  formData: FormData
): Promise<TarotCardFormState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = TarotCardSchema.safeParse({
    name: formData.get("name"),
    arcanaType: formData.get("arcanaType"),
    uprightMeaning: formData.get("uprightMeaning"),
    reversedMeaning: formData.get("reversedMeaning"),
    sortOrder: formData.get("sortOrder") || 0,
    imageUrl: formData.get("imageUrl") ?? undefined,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const existing = await prisma.tarotCard.findUnique({ where: { name: parsed.data.name } });
  if (existing) {
    return { error: "이미 동일한 이름의 카드가 존재합니다." };
  }

  const created = await prisma.tarotCard.create({
    data: {
      ...parsed.data,
      imageUrl: parsed.data.imageUrl || null,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "tarot_card",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ name: created.name, arcanaType: created.arcanaType }),
    },
  });

  revalidatePath("/ai-content/tarot-cards");
  return { success: true };
}

// ── 수정 ──
const UpdateTarotCardSchema = TarotCardSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateTarotCard(
  _prevState: TarotCardFormState,
  formData: FormData
): Promise<TarotCardFormState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateTarotCardSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    arcanaType: formData.get("arcanaType"),
    uprightMeaning: formData.get("uprightMeaning"),
    reversedMeaning: formData.get("reversedMeaning"),
    sortOrder: formData.get("sortOrder") || 0,
    imageUrl: formData.get("imageUrl") ?? undefined,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.tarotCard.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 카드입니다." };
  }

  const after = await prisma.tarotCard.update({
    where: { id },
    data: { ...data, imageUrl: data.imageUrl || null, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "tarot_card",
      targetId: id,
      before: JSON.stringify({
        name: before.name,
        uprightMeaning: before.uprightMeaning,
        reversedMeaning: before.reversedMeaning,
      }),
      after: JSON.stringify({
        name: after.name,
        uprightMeaning: after.uprightMeaning,
        reversedMeaning: after.reversedMeaning,
      }),
    },
  });

  revalidatePath("/ai-content/tarot-cards");
  return { success: true };
}

// ── 삭제 (soft delete: deletedAt 기록) ──
const DeleteTarotCardSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function deleteTarotCard(
  _prevState: TarotCardFormState,
  formData: FormData
): Promise<TarotCardFormState> {
  const session = await verifyAdminSession();

  // 삭제는 write 권한만으로는 부족 — RBAC 매트릭스상 ai_content는 content_manager가 RW(삭제 불가), super_admin만 D 보유
  if (!canAccessMenu(session.roleCode, "ai_content") || session.roleCode !== "super_admin") {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteTarotCardSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.tarotCard.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 카드입니다." };
  }

  await prisma.tarotCard.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "tarot_card",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name, status: before.status }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/ai-content/tarot-cards");
  return { success: true };
}
