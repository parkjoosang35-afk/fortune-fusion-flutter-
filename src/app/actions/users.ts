"use server";

// 회원 관리 Server Actions
// 05_Admin_System_Design.md §3.1 "상태 변경: 정상/정지/탈퇴 처리 — 정지 시 사유 입력 필수, operation_logs 기록"
// §1 원칙2: "모든 CUD 작업은 예외 없이 operation_logs 기록"
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

const StatusChangeSchema = z.object({
  userId: z.coerce.number().int().positive(),
  newStatus: z.enum(["active", "suspended", "withdrawn"]),
  reason: z.string().optional(),
});

export interface StatusChangeFormState {
  error?: string;
  success?: boolean;
}

export async function changeUserStatus(
  _prevState: StatusChangeFormState,
  formData: FormData
): Promise<StatusChangeFormState> {
  const session = await verifyAdminSession();

  // 05§5.2 RBAC: users 메뉴는 super_admin/operator/cs가 write 권한 보유, content_manager는 R만 가능
  if (!canAccessMenu(session.roleCode, "users") || session.roleCode === "content_manager") {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = StatusChangeSchema.safeParse({
    userId: formData.get("userId"),
    newStatus: formData.get("newStatus"),
    reason: formData.get("reason") ?? undefined,
  });

  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const { userId, newStatus, reason } = parsed.data;

  // 정지 처리 시 사유 입력 필수 (05§3.1)
  if (newStatus === "suspended" && !reason?.trim()) {
    return { error: "정지 처리 시 사유 입력이 필수입니다." };
  }
  if (newStatus === "withdrawn" && !reason?.trim()) {
    return { error: "탈퇴 처리 시 사유 입력이 필수입니다." };
  }

  const before = await prisma.user.findUnique({ where: { id: userId } });
  if (!before) {
    return { error: "존재하지 않는 회원입니다." };
  }

  const now = new Date();

  const after = await prisma.user.update({
    where: { id: userId },
    data: {
      status: newStatus,
      withdrawalReason: newStatus === "withdrawn" ? reason : before.withdrawalReason,
      updatedBy: session.email,
    },
  });

  // 탈퇴 처리 시 04A A-11 user_withdrawal_logs 기록 (개인정보 파기 예정일: 30일 후, 04A 정책 기준)
  if (newStatus === "withdrawn") {
    const purgeScheduledAt = new Date(now);
    purgeScheduledAt.setDate(purgeScheduledAt.getDate() + 30);
    await prisma.userWithdrawalLog.create({
      data: {
        userId,
        reason,
        requestedAt: now,
        dataPurgeScheduledAt: purgeScheduledAt,
      },
    });
  }

  // 04A O-2 operation_logs: 모든 CUD 작업 예외 없이 기록 (05§1 원칙2)
  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "status_change",
      targetType: "user",
      targetId: userId,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: after.status, reason: reason ?? null }),
    },
  });

  revalidatePath(`/users/${userId}`);
  revalidatePath("/users");

  return { success: true };
}
