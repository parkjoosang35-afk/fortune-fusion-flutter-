"use server";

// 소원성(Wish Castle) 성취 후기 - 명예의 전당 수동 선정(isFeatured) 토글 Server Action.
// community RBAC 매트릭스를 그대로 재사용(신규 권한 항목 없음).
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

export async function toggleWishReviewFeatured(reviewId: number, isFeatured: boolean) {
  const session = await verifyAdminSession();
  if (!canWriteMenu(session.roleCode, "community") || session.roleCode === "cs") {
    throw new Error("이 작업을 수행할 권한이 없습니다.");
  }

  await prisma.wishReview.update({
    where: { id: reviewId },
    data: { isFeatured },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "wish_review_feature_toggle",
      targetType: "wish_review",
      targetId: reviewId,
      before: JSON.stringify({ isFeatured: !isFeatured }),
      after: JSON.stringify({ isFeatured }),
    },
  });

  revalidatePath("/community/wish-castle");
}
