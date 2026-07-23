"use server";

// 포인트 조정(수동 지급/회수) Server Action
// 05_Admin_System_Design.md §3.3 "포인트 조정(수동 지급)":
//   "직접 balance 수정 금지 — '포인트 지급/회수' 액션이 곧 point_histories 신규 레코드
//    생성(사유 필수 입력)"
// 04_Database_Master_Design.md 핵심원칙10 + §6.1 WalletService 패턴 준수:
//   wallets.balance를 직접 UPDATE하는 코드는 이 흐름(트랜잭션) 내부에만 존재해야 하며,
//   point_histories INSERT(source_type=admin_adjust, balance_after 계산) 후
//   같은 트랜잭션 내에서 wallets.balance를 원자적으로 갱신한다.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}

const AdjustSchema = z.object({
  userId: z.coerce.number().int().positive("회원을 선택해주세요."),
  direction: z.enum(["grant", "revoke"]),
  amount: z.coerce.number().int().positive("1 이상의 값을 입력해주세요."),
  memo: z.string().min(1, "사유(메모)는 필수 입력입니다."),
});

export interface AdjustFormState {
  error?: string;
  success?: boolean;
}

export async function adjustUserPoint(
  _prevState: AdjustFormState,
  formData: FormData
): Promise<AdjustFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = AdjustSchema.safeParse({
    userId: formData.get("userId"),
    direction: formData.get("direction"),
    amount: formData.get("amount"),
    memo: formData.get("memo"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { userId, direction, amount, memo } = parsed.data;

  // 회원의 POINT 지갑 조회(없으면 생성 — 신규가입 후 아직 지갑이 없는 예외적 케이스 대비)
  let wallet = await prisma.wallet.findUnique({
    where: { userId_currencyType: { userId, currencyType: "POINT" } },
  });
  if (!wallet) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return { error: "존재하지 않는 회원입니다." };
    }
    wallet = await prisma.wallet.create({
      data: { userId, currencyType: "POINT", balance: 0, createdBy: session.email, updatedBy: session.email },
    });
  }

  const signedAmount = direction === "grant" ? amount : -amount;

  if (direction === "revoke" && wallet.balance + signedAmount < 0) {
    return { error: `잔액 부족: 현재 잔액(${wallet.balance}P)보다 큰 금액을 회수할 수 없습니다.` };
  }

  const newBalance = wallet.balance + signedAmount;

  // ── WalletService 패턴: point_histories INSERT + wallets.balance UPDATE를 하나의 트랜잭션으로 ──
  const [history] = await prisma.$transaction([
    prisma.pointHistory.create({
      data: {
        walletId: wallet.id,
        userId,
        amount: signedAmount,
        type: direction === "grant" ? "earn" : "spend",
        sourceType: "admin_adjust",
        balanceAfter: newBalance,
        memo,
      },
    }),
    prisma.wallet.update({
      where: { id: wallet.id },
      data: { balance: newBalance, balanceSyncedAt: new Date(), updatedBy: session.email },
    }),
  ]);

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: direction === "grant" ? "point_grant" : "point_revoke",
      targetType: "point_history",
      targetId: history.id,
      before: JSON.stringify({ userId, balanceBefore: wallet.balance }),
      after: JSON.stringify({ userId, balanceAfter: newBalance, amount: signedAmount, memo }),
    },
  });

  revalidatePath("/reward/policies");
  return { success: true };
}
