"use server";

// 결제/구독 관리 — 환불 처리 Server Actions
// 05_Admin_System_Design.md §3.7 "환불 처리" — 04A K-2 payment_refunds.
// 스펙: "환불 처리 | payment_refunds 신규 생성 워크플로우(원본 payments는
//       상태만 변경)"
// 04A 절대원칙3("결제/포인트는 관리자 화면에서도 직접 수정 절대 금지 — 조회
//   전용 + '조정 요청'은 반드시 별도 이력 레코드 생성 방식으로만 허용")에
//   따라 payments.amount/pg_tx_id 등 핵심 필드는 절대 직접 수정하지 않고,
//   ① payment_refunds에 새 이력 레코드 생성 ② 원본 payments.status만 변경
//   하는 2단계 방식으로만 반영한다(schema.prisma PaymentRefund 모델 주석과
//   동일 근거).
// [RBAC 2단계 승인 구조] 05§5.2: "결제/구독 관리 | operator: R(+환불요청,
//   최종승인은 super_admin)". RBAC_MATRIX.payments만으로는 이 "예외적 부분
//   write 권한"을 표현할 수 없으므로, reports.ts의 canWriteReports 전용
//   헬퍼 패턴을 재사용하여 이 파일 전용의 2개 헬퍼를 신설한다:
//   - canRequestRefund: super_admin/operator 허용(요청 생성=pending)
//   - canApproveRefund: super_admin만 허용(최종 승인/거부)
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

function canRequestRefund(roleCode: string): boolean {
  if (!canAccessMenu(roleCode, "payments")) return false;
  // 05§5.2: operator는 "R(+환불요청)" — 환불 요청 생성(pending)까지만 허용.
  // cs는 payments=R뿐이라 제외, content_manager는 payments=X.
  return roleCode === "super_admin" || roleCode === "operator";
}

function canApproveRefund(roleCode: string): boolean {
  // 05§5.2: "최종승인은 super_admin" — 승인/거부(완료 처리)는 super_admin 전용.
  return roleCode === "super_admin";
}

export interface RefundFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/payments/refunds";

// ══════════════════════════════════════════════════════════
// 환불 요청 생성 — payment_refunds INSERT(status=pending)
// 원본 payments는 이 단계에서 변경하지 않음(승인 시점에만 변경)
// ══════════════════════════════════════════════════════════
const RequestSchema = z.object({
  paymentId: z.coerce.number().int().positive(),
  amount: z.coerce.number().int().positive("환불 금액은 1 이상이어야 합니다."),
  reason: z.string().min(1, "환불 사유는 필수 입력입니다."),
});

export async function requestRefund(
  _prevState: RefundFormState,
  formData: FormData
): Promise<RefundFormState> {
  const session = await verifyAdminSession();
  if (!canRequestRefund(session.roleCode)) {
    return { error: "환불 요청 권한이 없습니다." };
  }

  const parsed = RequestSchema.safeParse({
    paymentId: formData.get("paymentId"),
    amount: formData.get("amount"),
    reason: formData.get("reason"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { paymentId, amount, reason } = parsed.data;

  const payment = await prisma.payment.findUnique({ where: { id: paymentId } });
  if (!payment) {
    return { error: "존재하지 않는 결제 내역입니다." };
  }
  if (payment.status === "cancelled") {
    return { error: "이미 취소된 결제입니다." };
  }
  if (amount > payment.amount) {
    return { error: `환불 금액은 원 결제 금액(${payment.amount.toLocaleString()}원)을 초과할 수 없습니다.` };
  }

  const existingPending = await prisma.paymentRefund.findFirst({
    where: { paymentId, status: "pending" },
  });
  if (existingPending) {
    return { error: "이미 처리 대기 중인 환불 요청이 존재합니다." };
  }

  const refund = await prisma.paymentRefund.create({
    data: {
      paymentId,
      amount,
      reason,
      status: "pending",
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "payment_refund",
      targetId: refund.id,
      before: null,
      after: JSON.stringify({ paymentId, amount, reason, status: "pending" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 환불 승인 — status: pending → completed
// 원본 payments.status만 함께 cancelled로 변경(직접 amount 수정 없음)
// super_admin 전용(05§5.2 "최종승인은 super_admin")
// ══════════════════════════════════════════════════════════
const DecisionSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function approveRefund(
  _prevState: RefundFormState,
  formData: FormData
): Promise<RefundFormState> {
  const session = await verifyAdminSession();
  if (!canApproveRefund(session.roleCode)) {
    return { error: "환불 최종 승인은 super_admin만 가능합니다." };
  }

  const parsed = DecisionSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const refund = await prisma.paymentRefund.findUnique({ where: { id } });
  if (!refund) {
    return { error: "존재하지 않는 환불 요청입니다." };
  }
  if (refund.status !== "pending") {
    return { error: "대기(pending) 상태의 환불 요청만 승인할 수 있습니다." };
  }

  const payment = await prisma.payment.findUnique({ where: { id: refund.paymentId } });
  if (!payment) {
    return { error: "원본 결제 내역을 찾을 수 없습니다." };
  }

  // 원자적 처리: payment_refunds.status 변경 + payments.status만 변경(다른 필드는 절대 수정하지 않음)
  await prisma.$transaction([
    prisma.paymentRefund.update({
      where: { id },
      data: { status: "completed", processedAt: new Date(), updatedBy: session.email },
    }),
    prisma.payment.update({
      where: { id: payment.id },
      data: { status: "cancelled", updatedBy: session.email },
    }),
  ]);

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "payment_refund",
      targetId: id,
      before: JSON.stringify({ status: "pending", paymentStatus: payment.status }),
      after: JSON.stringify({ status: "completed", paymentStatus: "cancelled" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  revalidatePath("/payments/list");
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 환불 거부 — status: pending → failed (원본 payments는 변경하지 않음)
// super_admin 전용
// ══════════════════════════════════════════════════════════
export async function rejectRefund(
  _prevState: RefundFormState,
  formData: FormData
): Promise<RefundFormState> {
  const session = await verifyAdminSession();
  if (!canApproveRefund(session.roleCode)) {
    return { error: "환불 거부 결정은 super_admin만 가능합니다." };
  }

  const parsed = DecisionSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const refund = await prisma.paymentRefund.findUnique({ where: { id } });
  if (!refund) {
    return { error: "존재하지 않는 환불 요청입니다." };
  }
  if (refund.status !== "pending") {
    return { error: "대기(pending) 상태의 환불 요청만 거부할 수 있습니다." };
  }

  await prisma.paymentRefund.update({
    where: { id },
    data: { status: "failed", processedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "payment_refund",
      targetId: id,
      before: JSON.stringify({ status: "pending" }),
      after: JSON.stringify({ status: "failed" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
