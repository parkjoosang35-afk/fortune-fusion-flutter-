"use server";

// [관리자 2.0 전면 재설계 - Task 12a] 도완녀상담 Server Actions.
//
// [RBAC] rbac.ts 주석(신규 리프 화면의 RBAC 코드 재사용 결정)에 따라 "ai_content"
// 코드를 재사용한다. RBAC_MATRIX.ai_content = { super_admin: RWD, operator: R,
// cs: R, content_manager: RW }.
//
// [1차 범위 — schema.prisma DowanyeoConsultationRequest 모델 주석 참고]
// 자동매칭/선착순 정책 없이 "관리자가 신청 건을 보고 수동으로 카운슬러를
// 배정"하는 가장 단순한 경로만 제공한다. 실시간 채팅/예약 슬롯 검증/정산은
// 이번 범위에서 제외(인프라 부재 확정 — 보고서③/④).
//
// [결제] point-adjust.ts의 WalletService 트랜잭션 패턴을 그대로 재사용한다:
// point_histories INSERT(source_type=dowanyeo_consultation, type=spend) +
// wallets.balance 원자적 갱신을 하나의 $transaction으로 처리하고, 생성된
// PointHistory.id를 DowanyeoConsultationRequest.pointHistoryId에 연결한다.
// 신청 자체를 "복주머니 결제가 선결된 상태"로만 생성 가능하게 해 과거
// 사주/소원방과 동일하게 "복주머니 = 유일 재화" 원칙을 지킨다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteDowanyeo(roleCode: string): boolean {
  return canWriteMenu(roleCode, "ai_content");
}

export interface DowanyeoFormState {
  error?: string;
  success?: boolean;
}

const LIST_PATH = "/ai-content/dowanyeo";

// ══════════════════════════════════════════════════════════
// 카운슬러 마스터 CRUD (tarot-cards.ts 패턴 재사용)
// ══════════════════════════════════════════════════════════
const CounselorSchema = z.object({
  name: z.string().trim().min(1, "이름을 입력해주세요.").max(100),
  specialty: z.string().trim().max(200).optional(),
  introBody: z.string().trim().max(2000).optional(),
});

export async function createCounselor(
  _prevState: DowanyeoFormState,
  formData: FormData
): Promise<DowanyeoFormState> {
  const session = await verifyAdminSession();
  if (!canWriteDowanyeo(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = CounselorSchema.safeParse({
    name: formData.get("name"),
    specialty: formData.get("specialty") || undefined,
    introBody: formData.get("introBody") || undefined,
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.dowanyeoCounselor.create({
    data: {
      ...parsed.data,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "dowanyeo_counselor",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ name: created.name }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}

const UpdateCounselorStatusSchema = z.object({
  id: z.coerce.number().int().positive(),
  status: z.enum(["active", "inactive"]),
});

export async function updateCounselorStatus(
  _prevState: DowanyeoFormState,
  formData: FormData
): Promise<DowanyeoFormState> {
  const session = await verifyAdminSession();
  if (!canWriteDowanyeo(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateCounselorStatusSchema.safeParse({
    id: formData.get("id"),
    status: formData.get("status"),
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id, status } = parsed.data;

  const before = await prisma.dowanyeoCounselor.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 카운슬러입니다." };
  }

  await prisma.dowanyeoCounselor.update({
    where: { id },
    data: { status, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "dowanyeo_counselor",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 배정 — status: requested → assigned, counselorId 지정
// ══════════════════════════════════════════════════════════
const AssignSchema = z.object({
  id: z.coerce.number().int().positive(),
  counselorId: z.coerce.number().int().positive("카운슬러를 선택해주세요."),
});

export async function assignCounselor(
  _prevState: DowanyeoFormState,
  formData: FormData
): Promise<DowanyeoFormState> {
  const session = await verifyAdminSession();
  if (!canWriteDowanyeo(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = AssignSchema.safeParse({
    id: formData.get("id"),
    counselorId: formData.get("counselorId"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, counselorId } = parsed.data;

  const before = await prisma.dowanyeoConsultationRequest.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 신청입니다." };
  }
  if (before.status !== "requested") {
    return { error: "배정 대기(신청) 상태의 건만 배정할 수 있습니다." };
  }

  const counselor = await prisma.dowanyeoCounselor.findUnique({ where: { id: counselorId } });
  if (!counselor || counselor.status !== "active") {
    return { error: "활성 상태인 카운슬러만 배정할 수 있습니다." };
  }

  await prisma.dowanyeoConsultationRequest.update({
    where: { id },
    data: {
      counselorId,
      status: "assigned",
      assignedAdminId: session.adminUserId,
      assignedAt: new Date(),
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "dowanyeo_consultation_request",
      targetId: id,
      before: JSON.stringify({ status: before.status, counselorId: before.counselorId }),
      after: JSON.stringify({ status: "assigned", counselorId }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 진행중 전환 — status: assigned → in_progress
// ══════════════════════════════════════════════════════════
const IdSchema = z.object({ id: z.coerce.number().int().positive() });

export async function startConsultation(
  _prevState: DowanyeoFormState,
  formData: FormData
): Promise<DowanyeoFormState> {
  const session = await verifyAdminSession();
  if (!canWriteDowanyeo(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.dowanyeoConsultationRequest.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 신청입니다." };
  }
  if (before.status !== "assigned") {
    return { error: "배정 완료 상태의 건만 진행중으로 전환할 수 있습니다." };
  }

  await prisma.dowanyeoConsultationRequest.update({
    where: { id },
    data: { status: "in_progress", startedAt: new Date() },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "dowanyeo_consultation_request",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "in_progress" }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 완료 처리 — status: in_progress → completed
// ══════════════════════════════════════════════════════════
export async function completeConsultation(
  _prevState: DowanyeoFormState,
  formData: FormData
): Promise<DowanyeoFormState> {
  const session = await verifyAdminSession();
  if (!canWriteDowanyeo(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.dowanyeoConsultationRequest.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 신청입니다." };
  }
  if (before.status !== "in_progress") {
    return { error: "진행중 상태의 건만 완료 처리할 수 있습니다." };
  }

  await prisma.dowanyeoConsultationRequest.update({
    where: { id },
    data: { status: "completed", completedAt: new Date() },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "dowanyeo_consultation_request",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "completed" }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 취소(환불 포함) — status: requested/assigned → cancelled.
// point-adjust.ts/giftcard-lifecycle.ts의 WalletService 패턴 재사용:
// point_histories INSERT(source_type=dowanyeo_consultation_refund, type=earn)
// + wallets.balance 원자적 갱신을 하나의 트랜잭션으로 처리한다. in_progress
// 이후(실제 상담이 이미 시작된 건)는 환불 분쟁 소지가 있어 1차 범위에서는
// 취소 자체를 막는다(요청/배정 단계에서만 취소 가능).
// ══════════════════════════════════════════════════════════
export async function cancelRequest(
  _prevState: DowanyeoFormState,
  formData: FormData
): Promise<DowanyeoFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteMenu(session.roleCode, "ai_content") && !canWriteDowanyeo(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.dowanyeoConsultationRequest.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 신청입니다." };
  }
  if (before.status !== "requested" && before.status !== "assigned") {
    return { error: "신청/배정 단계의 건만 취소할 수 있습니다(진행중 이후는 취소 불가)." };
  }

  // 복주머니 결제 내역이 연결되어 있으면 환불 트랜잭션을 함께 처리한다.
  if (before.pointHistoryId) {
    const originalHistory = await prisma.pointHistory.findUnique({
      where: { id: before.pointHistoryId },
    });
    if (originalHistory) {
      const wallet = await prisma.wallet.findUnique({ where: { id: originalHistory.walletId } });
      if (wallet) {
        const refundAmount = Math.abs(originalHistory.amount);
        const newBalance = wallet.balance + refundAmount;

        await prisma.$transaction([
          prisma.pointHistory.create({
            data: {
              walletId: wallet.id,
              userId: originalHistory.userId,
              amount: refundAmount,
              type: "earn",
              sourceType: "dowanyeo_consultation_refund",
              sourceId: id,
              balanceAfter: newBalance,
              memo: "도완녀상담 신청 취소 환불",
            },
          }),
          prisma.wallet.update({
            where: { id: wallet.id },
            data: { balance: newBalance, balanceSyncedAt: new Date(), updatedBy: session.email },
          }),
        ]);
      }
    }
  }

  await prisma.dowanyeoConsultationRequest.update({
    where: { id },
    data: { status: "cancelled", cancelledAt: new Date() },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "cancel",
      targetType: "dowanyeo_consultation_request",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "cancelled" }),
    },
  });

  revalidatePath(LIST_PATH);
  return { success: true };
}
