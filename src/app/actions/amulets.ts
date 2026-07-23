"use server";

// 상점 관리 — 디지털부적 상품 관리 Server Actions
// 05_Admin_System_Design.md §3.4 "상점 관리" — 04A H-1 amulet_items + H-2 amulet_grades CRUD
// [스코프 결정] 1단계는 등급 마스터 + 부적 상품 마스터 CRUD까지만 다룬다.
//   user_amulets 등 지급/보유 이력(H-3~H-6)은 회원 활동 결과 데이터이므로 조회 전용 화면으로
//   별도 소단위에서 추가할 예정(missions 화면의 user_missions 패턴과 동일).
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteShop(roleCode: string): boolean {
  return canWriteMenu(roleCode, "shop");
}

function canDeleteShop(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "shop");
}

export interface AmuletFormState {
  error?: string;
  success?: boolean;
}

// ── 04A H-2 amulet_grades (마스터) ──
const AmuletGradeSchema = z.object({
  code: z.string().min(1, "등급 코드를 입력해주세요."),
  name: z.string().min(1, "등급명을 입력해주세요."),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
});

export async function createAmuletGrade(
  _prevState: AmuletFormState,
  formData: FormData
): Promise<AmuletFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = AmuletGradeSchema.safeParse({
    code: formData.get("code"),
    name: formData.get("name"),
    sortOrder: formData.get("sortOrder"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const existing = await prisma.amuletGrade.findUnique({ where: { code: parsed.data.code } });
  if (existing) {
    return { error: "이미 동일한 등급 코드가 존재합니다." };
  }

  const created = await prisma.amuletGrade.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "amulet_grade",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/shop/amulets");
  return { success: true };
}

const UpdateAmuletGradeSchema = AmuletGradeSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateAmuletGrade(
  _prevState: AmuletFormState,
  formData: FormData
): Promise<AmuletFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateAmuletGradeSchema.safeParse({
    id: formData.get("id"),
    code: formData.get("code"),
    name: formData.get("name"),
    sortOrder: formData.get("sortOrder"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;
  const before = await prisma.amuletGrade.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 등급입니다." };
  }

  const after = await prisma.amuletGrade.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "amulet_grade",
      targetId: id,
      before: JSON.stringify({ code: before.code, name: before.name }),
      after: JSON.stringify({ code: after.code, name: after.name }),
    },
  });

  revalidatePath("/shop/amulets");
  return { success: true };
}

// ── 04A H-1 amulet_items ──
const AmuletItemSchema = z.object({
  name: z.string().min(1, "부적 이름을 입력해주세요."),
  gradeId: z.coerce.number().int().positive("등급을 선택해주세요."),
  effectDescription: z.string().min(1, "효과 설명을 입력해주세요."),
  imageUrl: z.string().optional().nullable(),
  isAiGenerated: z.coerce.boolean().optional().default(false),
  pricePoint: z.coerce.number().int().min(0).optional().default(0),
  isLimited: z.coerce.boolean().optional().default(false),
});

export async function createAmuletItem(
  _prevState: AmuletFormState,
  formData: FormData
): Promise<AmuletFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const parsed = AmuletItemSchema.safeParse({
    name: formData.get("name"),
    gradeId: formData.get("gradeId"),
    effectDescription: formData.get("effectDescription"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    isAiGenerated: formData.get("isAiGenerated") === "on" || formData.get("isAiGenerated") === "true",
    pricePoint: formData.get("pricePoint"),
    isLimited: formData.get("isLimited") === "on" || formData.get("isLimited") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const grade = await prisma.amuletGrade.findUnique({ where: { id: parsed.data.gradeId } });
  if (!grade) {
    return { error: "존재하지 않는 등급입니다." };
  }

  const created = await prisma.amuletItem.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "amulet_item",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ name: created.name, gradeId: created.gradeId }),
    },
  });

  revalidatePath("/shop/amulets");
  return { success: true };
}

const UpdateAmuletItemSchema = AmuletItemSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateAmuletItem(
  _prevState: AmuletFormState,
  formData: FormData
): Promise<AmuletFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const parsed = UpdateAmuletItemSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    gradeId: formData.get("gradeId"),
    effectDescription: formData.get("effectDescription"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    isAiGenerated: formData.get("isAiGenerated") === "on" || formData.get("isAiGenerated") === "true",
    pricePoint: formData.get("pricePoint"),
    isLimited: formData.get("isLimited") === "on" || formData.get("isLimited") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;
  const before = await prisma.amuletItem.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 부적 상품입니다." };
  }

  const grade = await prisma.amuletGrade.findUnique({ where: { id: data.gradeId } });
  if (!grade) {
    return { error: "존재하지 않는 등급입니다." };
  }

  const after = await prisma.amuletItem.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "amulet_item",
      targetId: id,
      before: JSON.stringify({
        name: before.name,
        gradeId: before.gradeId,
        pricePoint: before.pricePoint,
      }),
      after: JSON.stringify({
        name: after.name,
        gradeId: after.gradeId,
        pricePoint: after.pricePoint,
      }),
    },
  });

  revalidatePath("/shop/amulets");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteAmuletItemSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteAmuletItem(
  _prevState: AmuletFormState,
  formData: FormData
): Promise<AmuletFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteShop(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteAmuletItemSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.amuletItem.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 부적 상품입니다." };
  }

  await prisma.amuletItem.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "amulet_item",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/shop/amulets");
  return { success: true };
}
