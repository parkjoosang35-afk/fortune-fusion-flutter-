"use server";

// 커뮤니티 관리 — 댓글 관리 Server Actions
// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 04A L-4 comments(폴리모픽).
// 스펙: "댓글 관리 | comments(폴리모픽) 목록/삭제"
// [범위 결정] 원칙⑤(소단위 개발): 화면 스펙이 "목록/삭제"만 명시하므로(숨김 기능
//   없음), community.ts(L-2/L-3)의 setPostStatus/setWishStatus와 달리 상태값은
//   active/deleted_by_admin 2단계만 다룬다. 댓글 "작성"도 회원 앱 기능이므로
//   관리자 화면에서는 제공하지 않는다(community.ts와 동일 원칙).
// [RBAC] 05§5.2: cs 역할은 "신고처리"에만 write 권한이 있으므로, 댓글 관리는
//   community.ts와 동일하게 super_admin/operator만 접근 가능하도록 canDeleteMenu
//   기준으로 판단한다(댓글 삭제/복원은 삭제 권한 체계를 그대로 사용 — 별도의
//   "노출/숨김" 중간 상태가 없어 write와 delete를 구분할 필요가 없기 때문).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canDeleteMenu } from "@/lib/rbac";

export interface CommentFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/community/comments";

// 04A L-4 명시: target_type은 post/wish 화이트리스트 검증 대상.
const CommentStatusSchema = z.object({
  id: z.coerce.number().int().positive(),
  status: z.enum(["active", "deleted_by_admin"]),
});

export async function setCommentStatus(
  _prevState: CommentFormState,
  formData: FormData
): Promise<CommentFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteMenu(session.roleCode, "community")) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = CommentStatusSchema.safeParse({
    id: formData.get("id"),
    status: formData.get("status"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, status } = parsed.data;

  const before = await prisma.comment.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 댓글입니다." };
  }

  await prisma.comment.update({
    where: { id },
    data: {
      status,
      deletedAt: status === "deleted_by_admin" ? new Date() : null,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: status === "deleted_by_admin" ? "delete" : "update",
      targetType: "comment",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
