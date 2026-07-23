"use server";

// 결제/구독 관리 — 구독 플랜 관리 Server Actions
// 05_Admin_System_Design.md §3.7 "구독 플랜 관리" — 04A K-3 subscription_plans CRUD.
// 스펙: "구독 플랜 관리 | subscription_plans CRUD(가격/기간/혜택)"
// [RBAC] RBAC_MATRIX.payments가 이미 {super_admin: RWD, operator: R, cs: R,
//   content_manager: X}로 설정되어 있으므로(K-1 커밋에서 확인), K-2처럼
//   별도 예외 헬퍼를 두지 않고 표준 canWriteMenu/canDeleteMenu(payments)를
//   그대로 사용한다(설계충돌 없음 — operator는 CRUD 시도 시 canWriteMenu가
//   자동으로 false 반환).
// [period 화이트리스트] 04A 명시 2종: monthly/yearly.
// [benefits] JSONB → SQLite String 매핑(attendance-rules.ts 등 기존 JSON
//   문자열 처리 전례와 동일). 폼에서는 줄바꿈으로 구분된 텍스트를 배열로
//   변환하여 JSON.stringify한다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWritePayments(roleCode: string): boolean {
  return canWriteMenu(roleCode, "payments");
}

function canDeletePayments(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "payments");
}

export interface PlanFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/payments/plans";

const PERIOD_WHITELIST = ["monthly", "yearly"] as const;

const PlanSchema = z.object({
  name: z.string().min(1, "플랜명은 필수 입력입니다."),
  price: z.coerce.number().int().min(0, "가격은 0 이상이어야 합니다."),
  period: z.enum(PERIOD_WHITELIST, { message: "기간은 monthly 또는 yearly여야 합니다." }),
  benefitsText: z.string().min(1, "혜택은 최소 1개 이상 입력해주세요."),
  isActive: z.coerce.boolean(),
});

function benefitsTextToJson(text: string): string {
  const lines = text
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
  return JSON.stringify(lines);
}

// ── 생성 ──
export async function createSubscriptionPlan(
  _prevState: PlanFormState,
  formData: FormData
): Promise<PlanFormState> {
  const session = await verifyAdminSession();
  if (!canWritePayments(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = PlanSchema.safeParse({
    name: formData.get("name"),
    price: formData.get("price"),
    period: formData.get("period"),
    benefitsText: formData.get("benefitsText"),
    isActive: formData.get("isActive") === "on",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { name, price, period, benefitsText, isActive } = parsed.data;
  const benefits = benefitsTextToJson(benefitsText);

  const created = await prisma.subscriptionPlan.create({
    data: { name, price, period, benefits, isActive, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "subscription_plan",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ name, price, period, benefits, isActive }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ── 수정 ──
const UpdatePlanSchema = PlanSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateSubscriptionPlan(
  _prevState: PlanFormState,
  formData: FormData
): Promise<PlanFormState> {
  const session = await verifyAdminSession();
  if (!canWritePayments(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdatePlanSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    price: formData.get("price"),
    period: formData.get("period"),
    benefitsText: formData.get("benefitsText"),
    isActive: formData.get("isActive") === "on",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, name, price, period, benefitsText, isActive } = parsed.data;
  const benefits = benefitsTextToJson(benefitsText);

  const before = await prisma.subscriptionPlan.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 플랜입니다." };
  }

  await prisma.subscriptionPlan.update({
    where: { id },
    data: { name, price, period, benefits, isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "subscription_plan",
      targetId: id,
      before: JSON.stringify({
        name: before.name,
        price: before.price,
        period: before.period,
        benefits: before.benefits,
        isActive: before.isActive,
      }),
      after: JSON.stringify({ name, price, period, benefits, isActive }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ── 삭제 (soft delete, super_admin 전용 — canDeleteMenu) ──
const DeletePlanSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteSubscriptionPlan(
  _prevState: PlanFormState,
  formData: FormData
): Promise<PlanFormState> {
  const session = await verifyAdminSession();
  if (!canDeletePayments(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeletePlanSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.subscriptionPlan.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 플랜입니다." };
  }

  await prisma.subscriptionPlan.update({
    where: { id },
    data: { deletedAt: new Date(), isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "subscription_plan",
      targetId: id,
      before: JSON.stringify({ name: before.name, isActive: before.isActive }),
      after: JSON.stringify({ isActive: false, deleted: true }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
