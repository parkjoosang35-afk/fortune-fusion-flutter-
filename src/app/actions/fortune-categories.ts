"use server";

// [운세 카테고리 확장] FortuneCategory / FortuneCategoryGroup 관리 Server Actions
// 기존 ai-prompts.ts(버전 관리) Server Actions 패턴을 그대로 재사용한다:
// zod 검증 → RBAC(ai_content) 쓰기 권한 확인 → prisma 갱신 → operationLog 기록
// → revalidatePath. 카테고리 마스터는 "전체보기 노출 메타"만 다루며, 실제
// AI 프롬프트 버전 관리(ai_prompt_templates)는 건드리지 않는다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";

function canWriteAiContent(roleCode: string): boolean {
  if (!canAccessMenu(roleCode, "ai_content")) return false;
  return !!RBAC_MATRIX.ai_content[roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;
}

export interface CategoryActionState {
  error?: string;
  success?: boolean;
}

// ── 카테고리 노출/정렬 토글(목록에서 즉시 클릭) ──
const ToggleSchema = z.object({
  categoryKey: z.string().min(1),
  field: z.enum(["isActive", "isVisible", "isFeatured"]),
});

export async function toggleFortuneCategoryFlag(
  _prevState: CategoryActionState,
  formData: FormData
): Promise<CategoryActionState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleSchema.safeParse({
    categoryKey: formData.get("categoryKey"),
    field: formData.get("field"),
  });
  if (!parsed.success) return { error: "입력값이 올바르지 않습니다." };

  const { categoryKey, field } = parsed.data;
  const target = await prisma.fortuneCategory.findUnique({ where: { categoryKey } });
  if (!target) return { error: "대상 카테고리를 찾을 수 없습니다." };

  const nextValue = !target[field];
  await prisma.fortuneCategory.update({
    where: { categoryKey },
    data: { [field]: nextValue, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "fortune_category",
      targetId: target.id,
      before: JSON.stringify({ [field]: target[field] }),
      after: JSON.stringify({ [field]: nextValue }),
    },
  });

  revalidatePath("/ai-content/categories");
  return { success: true };
}

// ── 카테고리 정렬 순서 변경(그룹 내 위/아래 이동) ──
const ReorderSchema = z.object({
  categoryKey: z.string().min(1),
  direction: z.enum(["up", "down"]),
});

export async function reorderFortuneCategory(
  _prevState: CategoryActionState,
  formData: FormData
): Promise<CategoryActionState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ReorderSchema.safeParse({
    categoryKey: formData.get("categoryKey"),
    direction: formData.get("direction"),
  });
  if (!parsed.success) return { error: "입력값이 올바르지 않습니다." };

  const { categoryKey, direction } = parsed.data;
  const target = await prisma.fortuneCategory.findUnique({ where: { categoryKey } });
  if (!target) return { error: "대상 카테고리를 찾을 수 없습니다." };

  const sibling = await prisma.fortuneCategory.findFirst({
    where: {
      groupId: target.groupId,
      deletedAt: null,
      displayOrder: direction === "up" ? { lt: target.displayOrder } : { gt: target.displayOrder },
    },
    orderBy: { displayOrder: direction === "up" ? "desc" : "asc" },
  });
  if (!sibling) return { error: "더 이상 이동할 수 없습니다." };

  await prisma.$transaction([
    prisma.fortuneCategory.update({
      where: { id: target.id },
      data: { displayOrder: sibling.displayOrder, updatedBy: session.email },
    }),
    prisma.fortuneCategory.update({
      where: { id: sibling.id },
      data: { displayOrder: target.displayOrder, updatedBy: session.email },
    }),
  ]);

  revalidatePath("/ai-content/categories");
  return { success: true };
}

// ── 카테고리 메타 편집(제목/설명/아이콘/배지/라우트/관련카테고리) ──
const UpdateMetaSchema = z.object({
  categoryKey: z.string().min(1),
  title: z.string().min(1, "제목을 입력해주세요."),
  shortDescription: z.string().optional(),
  icon: z.string().optional(),
  badgeLabel: z.string().optional(),
  route: z.string().optional(),
  resultLengthHint: z.string().optional(),
  groupId: z.coerce.number().int().optional(),
});

export async function updateFortuneCategoryMeta(
  _prevState: CategoryActionState,
  formData: FormData
): Promise<CategoryActionState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const raw = {
    categoryKey: formData.get("categoryKey"),
    title: formData.get("title"),
    shortDescription: formData.get("shortDescription") || undefined,
    icon: formData.get("icon") || undefined,
    badgeLabel: formData.get("badgeLabel") || undefined,
    route: formData.get("route") || undefined,
    resultLengthHint: formData.get("resultLengthHint") || undefined,
    groupId: formData.get("groupId") || undefined,
  };
  const parsed = UpdateMetaSchema.safeParse(raw);
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { categoryKey, ...rest } = parsed.data;
  const target = await prisma.fortuneCategory.findUnique({ where: { categoryKey } });
  if (!target) return { error: "대상 카테고리를 찾을 수 없습니다." };

  await prisma.fortuneCategory.update({
    where: { categoryKey },
    data: {
      title: rest.title,
      shortDescription: rest.shortDescription ?? null,
      icon: rest.icon ?? null,
      badgeLabel: rest.badgeLabel ?? null,
      route: rest.route ?? null,
      resultLengthHint: rest.resultLengthHint ?? null,
      groupId: rest.groupId ?? target.groupId,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "fortune_category",
      targetId: target.id,
      before: JSON.stringify(target),
      after: JSON.stringify(rest),
    },
  });

  revalidatePath("/ai-content/categories");
  revalidatePath(`/ai-content/categories/${categoryKey}`);
  return { success: true };
}

// ── 그룹 메타 편집(라벨/설명/순서/노출) ──
const UpdateGroupSchema = z.object({
  code: z.string().min(1),
  label: z.string().min(1, "그룹명을 입력해주세요."),
  description: z.string().optional(),
  displayOrder: z.coerce.number().int(),
});

export async function updateFortuneCategoryGroup(
  _prevState: CategoryActionState,
  formData: FormData
): Promise<CategoryActionState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateGroupSchema.safeParse({
    code: formData.get("code"),
    label: formData.get("label"),
    description: formData.get("description") || undefined,
    displayOrder: formData.get("displayOrder"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { code, label, description, displayOrder } = parsed.data;
  const target = await prisma.fortuneCategoryGroup.findUnique({ where: { code } });
  if (!target) return { error: "대상 그룹을 찾을 수 없습니다." };

  await prisma.fortuneCategoryGroup.update({
    where: { code },
    data: { label, description: description ?? null, displayOrder, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "fortune_category_group",
      targetId: target.id,
      before: JSON.stringify(target),
      after: JSON.stringify({ label, description, displayOrder }),
    },
  });

  revalidatePath("/ai-content/categories/groups");
  revalidatePath("/ai-content/categories");
  return { success: true };
}

// ── 그룹 노출 토글 ──
const ToggleGroupSchema = z.object({ code: z.string().min(1) });

export async function toggleFortuneCategoryGroupVisible(
  _prevState: CategoryActionState,
  formData: FormData
): Promise<CategoryActionState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleGroupSchema.safeParse({ code: formData.get("code") });
  if (!parsed.success) return { error: "입력값이 올바르지 않습니다." };

  const target = await prisma.fortuneCategoryGroup.findUnique({ where: { code: parsed.data.code } });
  if (!target) return { error: "대상 그룹을 찾을 수 없습니다." };

  await prisma.fortuneCategoryGroup.update({
    where: { code: parsed.data.code },
    data: { isVisible: !target.isVisible, updatedBy: session.email },
  });

  revalidatePath("/ai-content/categories/groups");
  revalidatePath("/ai-content/categories");
  return { success: true };
}
