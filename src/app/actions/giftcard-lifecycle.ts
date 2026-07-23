"use server";

// 상점 관리 — 상품권 환불/재발급 처리 Server Actions
// 05_Admin_System_Design.md §3.4 "상점 관리" — 04A J-2/J-4/J-5/J-6.
// 스펙: "상품권 환불/재발급 처리 | 2단계 확인 필수, 환불 시 포인트 복원 로직은
//        시스템이 자동 처리(수동 balance 수정 없음)"
// [범위 결정] 원칙⑤(소단위 개발): 이번 소단위는 "issued" 상태의 발급 건에 대해
//   (1) 환불 처리: giftcard_cancels + giftcard_refunds 레코드 생성 + point_histories
//       INSERT(source_type=refund) + wallets.balance 원자적 갱신(트랜잭션, point-adjust.ts
//       WalletService 패턴 재사용) + issue.status를 cancelled로 전환.
//   (2) 재발급 처리: 신규 giftcard_issues 레코드 생성(point_spent=0) + giftcard_reissues
//       연결 레코드 생성. 원본 issue.status는 변경하지 않는다(취소가 아니므로).
//   2단계 확인(2단계 확인 필수)은 클라이언트 컴포넌트(GiftcardIssueActionRow)에서
//   "처리 요청 → 확인 패널 노출 → 최종 확인 클릭 시 submit" 흐름으로 구현하며,
//   이 Server Action 자체는 최종 확인 이후 1회 호출되는 단일 처리 단계이다.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

function canWriteShop(roleCode: string): boolean {
  return canWriteMenu(roleCode, "shop");
}

export interface GiftcardLifecycleFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/shop/giftcards";

// ══════════════════════════════════════════════════════════
// 상품권 환불 처리 (04A J-4 giftcard_cancels + J-5 giftcard_refunds)
// ══════════════════════════════════════════════════════════
const RefundSchema = z.object({
  issueId: z.coerce.number().int().positive(),
  reason: z.string().min(1, "환불 사유를 입력해주세요."),
});

export async function refundGiftcardIssue(
  _prevState: GiftcardLifecycleFormState,
  formData: FormData
): Promise<GiftcardLifecycleFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = RefundSchema.safeParse({
    issueId: formData.get("issueId"),
    reason: formData.get("reason"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { issueId, reason } = parsed.data;

  const issue = await prisma.giftcardIssue.findUnique({
    where: { id: issueId },
    include: { usage: true },
  });
  if (!issue || issue.deletedAt) {
    return { error: "존재하지 않는 발급 건입니다." };
  }
  // 04A J-2 status(Base): requested/issued/failed/cancelled/expired만 허용.
  // 환불 가능 대상은 "issued" 상태이며, 이미 사용된 건(giftcard_usages 존재)은 환불 불가.
  if (issue.status !== "issued") {
    return { error: `현재 상태(${issue.status})는 환불 대상이 아닙니다. 발급완료 상태만 환불 가능합니다.` };
  }
  if (issue.usage) {
    return { error: "이미 사용된 상품권은 환불할 수 없습니다." };
  }

  // 회원의 POINT 지갑 조회 (point-adjust.ts와 동일 패턴)
  const wallet = await prisma.wallet.findUnique({
    where: { userId_currencyType: { userId: issue.userId, currencyType: "POINT" } },
  });
  if (!wallet) {
    return { error: "회원의 포인트 지갑을 찾을 수 없습니다." };
  }

  const refundAmount = issue.pointSpent;
  const newBalance = wallet.balance + refundAmount;

  // ── WalletService 패턴: giftcard_cancels + point_histories INSERT + wallets.balance
  //    UPDATE + giftcard_refunds + giftcard_issues.status 전환을 하나의 트랜잭션으로 처리.
  //    "환불 시 포인트 복원 로직은 시스템이 자동 처리(수동 balance 수정 없음)"(05§3.4)
  //    giftcard_refunds가 cancel.id/history.id를 참조하므로 인터랙티브 트랜잭션(tx)을
  //    사용해 순서 의존 관계를 하나의 원자적 단위로 보장한다.
  const { cancel, history } = await prisma.$transaction(async (tx) => {
    const cancel = await tx.giftcardCancel.create({
      data: {
        issueId,
        reason,
        refundedPoint: refundAmount,
        createdBy: session.email,
        updatedBy: session.email,
      },
    });
    const history = await tx.pointHistory.create({
      data: {
        walletId: wallet.id,
        userId: issue.userId,
        amount: refundAmount,
        type: "earn",
        sourceType: "refund",
        sourceId: issueId,
        balanceAfter: newBalance,
        memo: `상품권 환불: ${reason}`,
      },
    });
    await tx.wallet.update({
      where: { id: wallet.id },
      data: { balance: newBalance, balanceSyncedAt: new Date(), updatedBy: session.email },
    });
    await tx.giftcardIssue.update({
      where: { id: issueId },
      data: { status: "cancelled", updatedBy: session.email },
    });
    await tx.giftcardRefund.create({
      data: {
        cancelId: cancel.id,
        refundPointHistoryId: history.id,
        status: "completed",
        createdBy: session.email,
        updatedBy: session.email,
      },
    });
    return { cancel, history };
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "giftcard_refund",
      targetType: "giftcard_issue",
      targetId: issueId,
      before: JSON.stringify({ status: "issued", walletBalance: wallet.balance }),
      after: JSON.stringify({
        status: "cancelled",
        refundedPoint: refundAmount,
        walletBalance: newBalance,
        reason,
        cancelId: cancel.id,
        refundPointHistoryId: history.id,
      }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 상품권 재발급 처리 (04A J-6 giftcard_reissues)
// ══════════════════════════════════════════════════════════
const ReissueSchema = z.object({
  issueId: z.coerce.number().int().positive(),
  reason: z.string().min(1, "재발급 사유를 입력해주세요."),
});

export async function reissueGiftcardIssue(
  _prevState: GiftcardLifecycleFormState,
  formData: FormData
): Promise<GiftcardLifecycleFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ReissueSchema.safeParse({
    issueId: formData.get("issueId"),
    reason: formData.get("reason"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { issueId, reason } = parsed.data;

  const original = await prisma.giftcardIssue.findUnique({
    where: { id: issueId },
    include: { usage: true },
  });
  if (!original || original.deletedAt) {
    return { error: "존재하지 않는 발급 건입니다." };
  }
  // 재발급은 "코드 유실" 등의 사유로 발급완료 상태에서 새 코드를 재발급하는 것이므로
  // 사용/취소/만료/실패 건은 재발급 대상이 아니다.
  if (original.status !== "issued") {
    return { error: `현재 상태(${original.status})는 재발급 대상이 아닙니다. 발급완료 상태만 재발급 가능합니다.` };
  }
  if (original.usage) {
    return { error: "이미 사용된 상품권은 재발급할 수 없습니다." };
  }

  const now = new Date();
  const validMs =
    original.expiresAt && original.issuedAt
      ? original.expiresAt.getTime() - original.issuedAt.getTime()
      : 365 * 24 * 60 * 60 * 1000;
  const newExpiresAt = new Date(now.getTime() + validMs);
  const newIssuedCode = `RE-${issueId}-${now.getTime().toString(36).toUpperCase()}`;

  // ── 원본 발급 건은 상태를 변경하지 않고(취소가 아님), 신규 발급 건 생성 +
  //    giftcard_reissues 연결 레코드 생성을 하나의 트랜잭션으로 처리.
  //    포인트 재차감 없음(재발급은 무상 처리, point_spent=0).
  //    giftcard_reissues.newIssueId가 신규 생성 id를 참조하므로 인터랙티브
  //    트랜잭션(tx)을 사용해 순서 의존 관계를 원자적으로 보장한다.
  const newIssue = await prisma.$transaction(async (tx) => {
    const newIssue = await tx.giftcardIssue.create({
      data: {
        userId: original.userId,
        productId: original.productId,
        pointSpent: 0,
        issuedCode: newIssuedCode,
        issuedAt: now,
        expiresAt: newExpiresAt,
        status: "issued",
        createdBy: session.email,
        updatedBy: session.email,
      },
    });
    await tx.giftcardReissue.create({
      data: {
        originalIssueId: issueId,
        newIssueId: newIssue.id,
        reason,
        createdBy: session.email,
        updatedBy: session.email,
      },
    });
    return newIssue;
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "giftcard_reissue",
      targetType: "giftcard_issue",
      targetId: issueId,
      before: JSON.stringify({ issuedCode: original.issuedCode }),
      after: JSON.stringify({ newIssueId: newIssue.id, newIssuedCode, reason }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
