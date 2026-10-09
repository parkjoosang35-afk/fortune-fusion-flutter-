"use server";

// [신통방통 관리자 통합 간소화 실행 지시서 task 6] 소원방(WishRoom) 운영 Server Actions
//
// 이번 task에서 전수조사 중 발견한 2가지 구조적 결함을 해결한다:
//   1) 신고 처리함(actions/reports.ts의 actionReport)에 wish_room/wish_room_comment/
//      wish_room_review 3개 targetType에 대한 조치(deleted/suspended) 로직은 이미
//      추가되었으나, 담당자배정/반려는 기존 assignReportToMe/rejectReport가 폴리모픽
//      중립적으로 이미 지원한다(수정 불필요) — 이 파일에서는 추가 작업이 필요 없다.
//   2) 어뷰징 의심 후기(WishRoomReview.status === "review")를 승인(보상 지급 +
//      visible 전환)하거나 반려(hidden_by_report 전환)할 관리자 기능이 전혀 없어
//      영구 보류 상태였다. 이 파일의 approveReview/rejectReview가 그 기능을 담당한다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";
import { grantReviewReward } from "@/lib/wishroom-engine";

export interface WishroomActionState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/wishroom/reviews";

const ReviewIdSchema = z.object({
  id: z.coerce.number().int().positive(),
});

// ══════════════════════════════════════════════════════════
// 승인 — status:"review"(어뷰징 의심, 보상 보류) → 보상 지급 + status:"visible"
// wishroom-engine.ts의 grantReviewReward()를 그대로 호출한다([id]/review/route.ts의
// status==="visible" 분기 보상 로직(base 30 + 사진 20)과 완전히 동일한 수치·경로).
// ══════════════════════════════════════════════════════════
export async function approveReview(
  _prevState: WishroomActionState,
  formData: FormData
): Promise<WishroomActionState> {
  const session = await verifyAdminSession();
  if (!canWriteMenu(session.roleCode, "wishroom")) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ReviewIdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.wishRoomReview.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 후기입니다." };
  }
  if (before.status !== "review") {
    return { error: "검토 대기(review) 상태의 후기만 승인할 수 있습니다." };
  }
  if (before.rewardGranted) {
    // 이중 지급 방지(grantReviewReward 내부에서도 status 체크를 하지만, 한 번 더
    // 방어적으로 막아 상태 불일치 시에도 실수로 재지급되지 않도록 한다.
    return { error: "이미 보상이 지급된 후기입니다." };
  }

  const reward = await prisma.$transaction((tx) =>
    grantReviewReward(tx, {
      id: before.id,
      roomId: before.roomId,
      userId: before.userId,
      photoUrl: before.photoUrl,
    })
  );

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "wish_room_review",
      targetId: id,
      before: JSON.stringify({ status: before.status, flagsJson: before.flagsJson }),
      after: JSON.stringify({ status: "visible", rewardGranted: true, reward }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 반려 — status:"review" → status:"hidden_by_report"(보상 미지급, 목록/피드 비노출)
// 신고 3회 누적 시 쓰이는 기존 상태값을 그대로 재사용한다(신규 상태값 추가 없음 —
// WishRoomReview.status 주석에 이미 정의된 4가지 상태 안에서 처리).
// ══════════════════════════════════════════════════════════
export async function rejectReview(
  _prevState: WishroomActionState,
  formData: FormData
): Promise<WishroomActionState> {
  const session = await verifyAdminSession();
  if (!canWriteMenu(session.roleCode, "wishroom")) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ReviewIdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.wishRoomReview.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 후기입니다." };
  }
  if (before.status !== "review") {
    return { error: "검토 대기(review) 상태의 후기만 반려할 수 있습니다." };
  }

  await prisma.wishRoomReview.update({
    where: { id },
    data: { status: "hidden_by_report" },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "wish_room_review",
      targetId: id,
      before: JSON.stringify({ status: before.status, flagsJson: before.flagsJson }),
      after: JSON.stringify({ status: "hidden_by_report" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
