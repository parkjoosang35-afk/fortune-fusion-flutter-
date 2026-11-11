"use server";

// [관리자 2.0 전면 재설계 - Task 9c] 1:1 고객문의 Server Actions.
//
// [RBAC] rbac.ts 주석(신규 리프 화면의 RBAC 코드 재사용 결정)에 따라 "users" 코드를
// 재사용한다. RBAC_MATRIX.users = { super_admin: RWD, operator: RW, cs: RW,
// content_manager: R }. 즉 super_admin/operator/cs는 답변·종료·재오픈 가능,
// content_manager는 조회만 가능.
//
// [status 전이] open(접수) → in_progress(운영자 첫 답변 시 자동 전이) →
// closed(운영자가 명시적으로 종료 처리) → (재문의 시) reopened 아님 — 동일
// Inquiry 레코드를 open으로 되돌리는 reopenInquiry로 재오픈한다(신규 레코드
// 생성 없음 — 스레드 연속성 유지).
//
// [담당자 배정] 별도의 "담당자 배정" 버튼 액션을 두지 않고, 운영자가 최초로
// 답변(sendInquiryReply)할 때 assignedAdminId가 비어있으면 자동으로 본인을
// 배정한다(1인 운영 가정 — Report처럼 수동 배정 단계를 분리할 실익이 적음).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

function canWriteInquiries(roleCode: string): boolean {
  if (!canAccessMenu(roleCode, "users")) return false;
  return roleCode === "super_admin" || roleCode === "operator" || roleCode === "cs";
}

export interface InquiryFormState {
  error?: string;
  success?: boolean;
}

const LIST_PATH = "/member-ops/inquiries";
function detailPath(id: number): string {
  return `/member-ops/inquiries/${id}`;
}

// ══════════════════════════════════════════════════════════
// 답변 전송 — InquiryMessage(senderType=admin) 생성 + 필요 시 담당자 자동배정 +
// status: open → in_progress(이미 in_progress/closed면 상태는 유지, closed인
// 경우 먼저 reopenInquiry로 재오픈해야 함 — 종료된 문의에 바로 답변 불가)
// ══════════════════════════════════════════════════════════
const ReplySchema = z.object({
  id: z.coerce.number().int().positive(),
  body: z.string().trim().min(1, "답변 내용을 입력하세요.").max(4000),
});

export async function sendInquiryReply(
  _prevState: InquiryFormState,
  formData: FormData
): Promise<InquiryFormState> {
  const session = await verifyAdminSession();
  if (!canWriteInquiries(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ReplySchema.safeParse({
    id: formData.get("id"),
    body: formData.get("body"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, body } = parsed.data;

  const before = await prisma.inquiry.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 문의입니다." };
  }
  if (before.status === "closed") {
    return { error: "종료된 문의입니다. 먼저 '재오픈'을 눌러주세요." };
  }

  await prisma.inquiryMessage.create({
    data: {
      inquiryId: id,
      senderType: "admin",
      senderAdminId: session.adminUserId,
      body,
    },
  });

  const nextStatus = before.status === "open" ? "in_progress" : before.status;
  await prisma.inquiry.update({
    where: { id },
    data: {
      status: nextStatus,
      assignedAdminId: before.assignedAdminId ?? session.adminUserId,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "inquiry",
      targetId: id,
      before: JSON.stringify({ status: before.status, assignedAdminId: before.assignedAdminId }),
      after: JSON.stringify({ status: nextStatus, assignedAdminId: before.assignedAdminId ?? session.adminUserId }),
    },
  });

  revalidatePath(LIST_PATH);
  revalidatePath(detailPath(id));
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 종료 처리 — status → closed, closed_at 기록
// ══════════════════════════════════════════════════════════
const IdSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function closeInquiry(
  _prevState: InquiryFormState,
  formData: FormData
): Promise<InquiryFormState> {
  const session = await verifyAdminSession();
  if (!canWriteInquiries(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.inquiry.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 문의입니다." };
  }
  if (before.status === "closed") {
    return { error: "이미 종료된 문의입니다." };
  }

  await prisma.inquiry.update({
    where: { id },
    data: { status: "closed", closedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "inquiry",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "closed" }),
    },
  });

  revalidatePath(LIST_PATH);
  revalidatePath(detailPath(id));
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 재오픈 — 종료된 문의에 회원이 추가 문의를 남긴 경우(또는 운영자 재검토 필요
// 판단 시) status: closed → open, closed_at 초기화(신규 Inquiry를 만들지 않고
// 동일 스레드를 재사용 — InquiryMessage 이력은 전부 보존됨)
// ══════════════════════════════════════════════════════════
export async function reopenInquiry(
  _prevState: InquiryFormState,
  formData: FormData
): Promise<InquiryFormState> {
  const session = await verifyAdminSession();
  if (!canWriteInquiries(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.inquiry.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 문의입니다." };
  }
  if (before.status !== "closed") {
    return { error: "종료된 문의만 재오픈할 수 있습니다." };
  }

  await prisma.inquiry.update({
    where: { id },
    data: { status: "open", closedAt: null, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "inquiry",
      targetId: id,
      before: JSON.stringify({ status: "closed" }),
      after: JSON.stringify({ status: "open" }),
    },
  });

  revalidatePath(LIST_PATH);
  revalidatePath(detailPath(id));
  return { success: true };
}
