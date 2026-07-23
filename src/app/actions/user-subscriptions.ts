"use server";

// 결제/구독 관리 — 구독 현황 조회 Server Actions
// 05_Admin_System_Design.md §3.7 "구독 현황 조회" — 04A K-4 user_subscriptions.
// 스펙: "구독 현황 조회 | user_subscriptions 조회, 강제 해지(사유 필수)"
// [범위 결정] K-3(완전CRUD)와 달리 이 화면은 "조회 + 제한적 write 1건
//   (강제해지)"만 명시되어 있다. 강제해지는 04A 절대원칙3의 "직접 수정 절대
//   금지" 대상(결제/포인트)에는 해당하지 않으나(구독은 결제 그 자체가 아닌
//   구독 상태), 05§3.7 문구가 "강제 해지"라는 단일 액션만 허용하므로 그
//   범위를 벗어나는 다른 필드 수정(플랜변경, 기간연장 등)은 이 소단위에서
//   제공하지 않는다(설계충돌 방지 — 스펙에 명시된 것만 구현).
// [RBAC] 05§5.2 "결제/구독 관리 | operator: R(+환불요청, 최종승인은
//   super_admin)"는 payment_refunds 전용 문구이고, user_subscriptions
//   강제해지에 대해서는 별도 명시가 없다. RBAC_MATRIX.payments 표준
//   {super_admin:RWD, operator:R, cs:R, content_manager:X}를 그대로
//   적용하여 표준 canWriteMenu(payments) 헬퍼로 강제해지 write 권한을
//   판단한다(K-2처럼 명시적 예외 문구가 없으므로 표준 헬퍼 사용 — 04A/05
//   문서 간 애매성 없음).
// [사유 필수] 04A user_subscriptions에는 취소사유 전용 컬럼이 없으므로,
//   기존 K-1~K-3 전례와 동일하게 operationLog.after에 사유를 포함하여
//   기록한다(스키마 변경 없이 05 요구사항 충족).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

function canForceCancelSubscription(roleCode: string): boolean {
  return canWriteMenu(roleCode, "payments");
}

export interface ForceCancelFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/payments/subscriptions";

// 04A K-4 명시 4종 화이트리스트. 강제해지는 active/past_due 상태에서만 허용
// (이미 cancelled/expired인 구독을 다시 cancelled로 만드는 것은 무의미).
const CANCELLABLE_STATUS = ["active", "past_due"] as const;

const ForceCancelSchema = z.object({
  id: z.coerce.number().int().positive(),
  reason: z.string().trim().min(1, "해지 사유는 필수 입력입니다."),
});

export async function forceCancelSubscription(
  _prevState: ForceCancelFormState,
  formData: FormData
): Promise<ForceCancelFormState> {
  const session = await verifyAdminSession();
  if (!canForceCancelSubscription(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ForceCancelSchema.safeParse({
    id: formData.get("id"),
    reason: formData.get("reason"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, reason } = parsed.data;

  const before = await prisma.userSubscription.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 구독입니다." };
  }
  if (!(CANCELLABLE_STATUS as readonly string[]).includes(before.status)) {
    return { error: `현재 상태(${before.status})는 강제 해지할 수 없습니다.` };
  }

  await prisma.userSubscription.update({
    where: { id },
    data: { status: "cancelled", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "force_cancel",
      targetType: "user_subscription",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "cancelled", reason }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
