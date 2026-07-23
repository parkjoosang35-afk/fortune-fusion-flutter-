"use server";

// 커뮤니티 관리 — 신고 처리함 Server Actions
// 05_Admin_System_Design.md §3.5 "신고 처리함" — 04A L-6 reports(폴리모픽).
// 스펙: "신고 처리함 | reports(폴리모픽 전체 대상: 게시글/댓글/부적거래 등)
//       통합 처리 워크플로우 — 승인(조치)/반려"
// §4.1 워크플로우: 신고접수 → 담당자배정(선택) → 검토 → 조치선택(삭제/경고/
//   계정정지/반려) → operation_logs 자동기록 → 알림(선택, 이번 스코프 제외) →
//   reports.status 전이
// [범위 결정] prisma/schema.prisma의 Report 모델 주석(설계 결정 1~3)에 기술된
//   내용을 그대로 따른다:
//   - status: pending/reviewed/actioned/rejected 4단계
//   - target_type 화이트리스트: post/comment/wish/user (fortune_result 제외)
//   - action(조치): deleted(콘텐츠 대상, community.ts/comments.ts의 상태변경
//     로직 재사용)/suspended(사용자 대상, users.status 변경)/warned(로그만
//     기록, 실제 알림·경고카운트 연동은 알림 도메인 미구현으로 제외)
// [RBAC] 05§5.2: "커뮤니티 관리 | cs: RW(신고처리)" — 1차/2차 소단위
//   (community.ts/comments.ts)의 canWriteCommunity/canDeleteCommunity와 반대로,
//   신고 처리함에서는 cs 역할도 write(담당자배정/조치/반려) 가능해야 한다.
//   따라서 community.ts의 canWriteMenu 기반 헬퍼를 그대로 쓰지 않고, 이 파일
//   전용의 canWriteReports를 신설한다(super_admin/operator/cs 허용,
//   content_manager는 05§5.2상 community=R이므로 제외).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

function canWriteReports(roleCode: string): boolean {
  if (!canAccessMenu(roleCode, "community")) return false;
  // 05§5.2: 신고처리는 super_admin(RWD)/operator(RW)/cs(RW, 신고처리 한정)까지
  // write 가능. content_manager는 community=R이므로 제외.
  return roleCode === "super_admin" || roleCode === "operator" || roleCode === "cs";
}

export interface ReportFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/community/reports";

// ══════════════════════════════════════════════════════════
// 담당자 배정 — 05§6 요구사항, reports.assigned_admin_id
// ══════════════════════════════════════════════════════════
const AssignSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function assignReportToMe(
  _prevState: ReportFormState,
  formData: FormData
): Promise<ReportFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReports(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = AssignSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.report.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 신고입니다." };
  }
  if (before.status !== "pending") {
    return { error: "접수(pending) 상태의 신고만 담당자를 배정할 수 있습니다." };
  }

  await prisma.report.update({
    where: { id },
    data: {
      assignedAdminId: session.adminUserId,
      status: "reviewed",
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "report",
      targetId: id,
      before: JSON.stringify({ status: before.status, assignedAdminId: before.assignedAdminId }),
      after: JSON.stringify({ status: "reviewed", assignedAdminId: session.adminUserId }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 조치 실행 — action: deleted/suspended/warned, status → actioned
// [연동 조치 범위] schema.prisma 설계결정 3 참조:
//   - deleted: target_type이 post/comment/wish인 경우, 대상 레코드의 status를
//     "deleted_by_admin"으로 실제 변경(user 대상은 선택 불가).
//   - suspended: 대상 사용자(target_type=user면 target_id, 그 외 콘텐츠 타입이면
//     해당 콘텐츠 작성자)의 users.status를 "suspended"로 변경.
//   - warned: operation_logs에만 기록(알림 연동은 미구현 도메인이라 제외).
// ══════════════════════════════════════════════════════════
const ActionSchema = z.object({
  id: z.coerce.number().int().positive(),
  action: z.enum(["deleted", "suspended", "warned"]),
});

export async function actionReport(
  _prevState: ReportFormState,
  formData: FormData
): Promise<ReportFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReports(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ActionSchema.safeParse({
    id: formData.get("id"),
    action: formData.get("action"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, action } = parsed.data;

  const before = await prisma.report.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 신고입니다." };
  }
  if (before.status === "actioned" || before.status === "rejected") {
    return { error: "이미 처리 완료된 신고입니다." };
  }

  if (action === "deleted" && before.targetType === "user") {
    return { error: "회원 신고에는 '삭제' 조치를 선택할 수 없습니다. 경고 또는 계정정지를 사용하세요." };
  }

  // 실제 연동 조치 실행
  if (action === "deleted") {
    if (before.targetType === "post") {
      await prisma.communityPost.update({
        where: { id: before.targetId },
        data: { status: "deleted_by_admin", deletedAt: new Date(), updatedBy: session.email },
      });
    } else if (before.targetType === "comment") {
      await prisma.comment.update({
        where: { id: before.targetId },
        data: { status: "deleted_by_admin", deletedAt: new Date(), updatedBy: session.email },
      });
    } else if (before.targetType === "wish") {
      await prisma.wish.update({
        where: { id: before.targetId },
        data: { status: "deleted_by_admin", deletedAt: new Date(), updatedBy: session.email },
      });
    }
  } else if (action === "suspended") {
    let targetUserId: number | null = null;
    if (before.targetType === "user") {
      targetUserId = before.targetId;
    } else if (before.targetType === "post") {
      const post = await prisma.communityPost.findUnique({ where: { id: before.targetId } });
      targetUserId = post?.userId ?? null;
    } else if (before.targetType === "comment") {
      const comment = await prisma.comment.findUnique({ where: { id: before.targetId } });
      targetUserId = comment?.userId ?? null;
    } else if (before.targetType === "wish") {
      const wish = await prisma.wish.findUnique({ where: { id: before.targetId } });
      targetUserId = wish?.userId ?? null;
    }
    if (targetUserId) {
      await prisma.user.update({
        where: { id: targetUserId },
        data: { status: "suspended", updatedBy: session.email },
      });
    }
  }
  // action === "warned"인 경우 콘텐츠/사용자 상태 변경 없이 로그만 기록.

  await prisma.report.update({
    where: { id },
    data: {
      action,
      status: "actioned",
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "report",
      targetId: id,
      before: JSON.stringify({ status: before.status, action: before.action }),
      after: JSON.stringify({ status: "actioned", action }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 반려 — status → rejected, action=null(대상에 어떤 변경도 가하지 않음)
// ══════════════════════════════════════════════════════════
const RejectSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function rejectReport(
  _prevState: ReportFormState,
  formData: FormData
): Promise<ReportFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReports(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = RejectSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.report.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 신고입니다." };
  }
  if (before.status === "actioned" || before.status === "rejected") {
    return { error: "이미 처리 완료된 신고입니다." };
  }

  await prisma.report.update({
    where: { id },
    data: {
      status: "rejected",
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "report",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "rejected" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
