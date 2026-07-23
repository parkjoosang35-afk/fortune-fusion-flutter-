"use server";

// 커뮤니티 관리 — 게시판 관리 + 게시글/소원 관리 Server Actions
// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 04A L-1(community_boards)/
// L-2(community_posts)/L-3(wishes).
// 스펙: "게시판 관리 | community_boards CRUD(게시판 종류/공개설정)"
//       "게시글/소원 관리 | community_posts, wishes 목록/숨김/삭제(Soft Delete)"
// [범위 결정] 원칙⑤(소단위 개발): 게시판 CRUD + 게시글/소원 숨김·삭제까지 이번
//   소단위에서 다룬다. 게시글/소원 "작성"은 회원 앱 기능이므로 관리자 화면에서는
//   제공하지 않는다(giftcard_issues/coupon_issues와 달리 "발급" 개념이 없는 순수
//   조회+상태변경 대상 — attendances/user_missions 조회전용 패턴과 유사하나, 04A
//   L-2/L-3 status(visible/blinded/deleted_by_admin)는 관리자가 직접 변경하는
//   필드이므로 상품권 J-2 상태변경 액션과 동일하게 Server Action으로 구현한다).
// giftcards.ts(J-1) 패턴과 동일한 zod 검증 + RBAC + operation_logs 컨벤션을 따른다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

// 05§5.2 RBAC 상세: "커뮤니티 관리 | cs: RW(신고처리)" — cs 역할의 write 권한은
// 신고 처리 워크플로우(05§3.5 "신고 처리함", 다음 소단위에서 구현)에만 한정된다.
// rbac.ts의 RBAC_MATRIX.community는 메뉴 단위 요약(RW)만 표현하므로, 게시판/게시글/
// 소원 관리(이번 소단위)에서는 users.ts의 content_manager 제외 패턴과 동일하게
// cs를 write 대상에서 명시적으로 제외한다(super_admin/operator만 write 가능).
function canWriteCommunity(roleCode: string): boolean {
  if (!canWriteMenu(roleCode, "community")) return false;
  return roleCode !== "cs";
}

function canDeleteCommunity(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "community");
}

export interface CommunityFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/community/boards";

// ══════════════════════════════════════════════════════════
// 04A L-1 community_boards
// ══════════════════════════════════════════════════════════
const BoardSchema = z.object({
  code: z.string().min(1, "게시판 코드를 입력해주세요.").max(30, "게시판 코드는 30자 이내여야 합니다."),
  name: z.string().min(1, "게시판 이름을 입력해주세요.").max(50, "게시판 이름은 50자 이내여야 합니다."),
  description: z.string().max(200, "설명은 200자 이내여야 합니다.").optional().nullable(),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
  isPublic: z.coerce.boolean().optional().default(true),
});

export async function createBoard(
  _prevState: CommunityFormState,
  formData: FormData
): Promise<CommunityFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCommunity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const descRaw = formData.get("description");
  const parsed = BoardSchema.safeParse({
    code: formData.get("code"),
    name: formData.get("name"),
    description: descRaw === "" ? null : descRaw,
    sortOrder: formData.get("sortOrder"),
    isPublic: formData.get("isPublic") === "on" || formData.get("isPublic") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { code, name, description, sortOrder, isPublic } = parsed.data;

  const dup = await prisma.communityBoard.findUnique({ where: { code } });
  if (dup) {
    return { error: "이미 존재하는 게시판 코드입니다." };
  }

  const created = await prisma.communityBoard.create({
    data: {
      code,
      name,
      description: description ?? null,
      sortOrder,
      isPublic,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "community_board",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ code: created.code, name, isPublic }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const UpdateBoardSchema = z.object({
  id: z.coerce.number().int().positive(),
  name: z.string().min(1, "게시판 이름을 입력해주세요.").max(50, "게시판 이름은 50자 이내여야 합니다."),
  description: z.string().max(200, "설명은 200자 이내여야 합니다.").optional().nullable(),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
  isPublic: z.coerce.boolean().optional().default(true),
});

export async function updateBoard(
  _prevState: CommunityFormState,
  formData: FormData
): Promise<CommunityFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCommunity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const descRaw = formData.get("description");
  const parsed = UpdateBoardSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    description: descRaw === "" ? null : descRaw,
    sortOrder: formData.get("sortOrder"),
    isPublic: formData.get("isPublic") === "on" || formData.get("isPublic") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, name, description, sortOrder, isPublic } = parsed.data;

  const before = await prisma.communityBoard.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 게시판입니다." };
  }

  // 04A L-1 명시: code는 UQ이며, 이미 게시글이 등록된 게시판의 코드 변경 시 정합성
  // 문제가 발생할 수 있어 coupons(J-8)와 동일하게 code를 수정 불가 필드로 스코프를 정한다.
  const after = await prisma.communityBoard.update({
    where: { id },
    data: {
      name,
      description: description ?? null,
      sortOrder,
      isPublic,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "community_board",
      targetId: id,
      before: JSON.stringify({ name: before.name, isPublic: before.isPublic, sortOrder: before.sortOrder }),
      after: JSON.stringify({ name: after.name, isPublic: after.isPublic, sortOrder: after.sortOrder }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const DeleteBoardSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteBoard(
  _prevState: CommunityFormState,
  formData: FormData
): Promise<CommunityFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCommunity(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteBoardSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.communityBoard.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 게시판입니다." };
  }

  const postCount = await prisma.communityPost.count({
    where: { boardId: parsed.data.id, deletedAt: null },
  });
  if (postCount > 0) {
    return { error: `게시글이 ${postCount}건 존재하는 게시판은 삭제할 수 없습니다.` };
  }

  await prisma.communityBoard.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "community_board",
      targetId: parsed.data.id,
      before: JSON.stringify({ code: before.code }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 04A L-2 community_posts — 숨김/삭제(Soft Delete)
// status(Base) 사용값: visible/blinded/deleted_by_admin
// ══════════════════════════════════════════════════════════
const PostStatusSchema = z.object({
  id: z.coerce.number().int().positive(),
  status: z.enum(["visible", "blinded", "deleted_by_admin"]),
});

export async function setPostStatus(
  _prevState: CommunityFormState,
  formData: FormData
): Promise<CommunityFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCommunity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = PostStatusSchema.safeParse({
    id: formData.get("id"),
    status: formData.get("status"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, status } = parsed.data;

  // "삭제(deleted_by_admin)"는 04A 원칙상 Soft Delete이므로 deletedAt도 함께 기록한다.
  if (status === "deleted_by_admin" && !canDeleteCommunity(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const before = await prisma.communityPost.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 게시글입니다." };
  }

  await prisma.communityPost.update({
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
      targetType: "community_post",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status }),
    },
  });

  revalidatePath("/community/posts");
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 04A L-3 wishes — 숨김/삭제(Soft Delete)
// [설계 결정] 04A L-3 스펙에는 status 사용값이 별도 명시되어 있지 않으나, 05§3.5
//   "게시글/소원 관리" 화면이 community_posts와 wishes를 동일 기능(목록/숨김/삭제)으로
//   함께 다루므로, 화면 일관성을 위해 community_posts(L-2)와 동일한 3단계 status
//   값(visible/blinded/deleted_by_admin)을 wishes에도 적용한다(원칙② 설계충돌 없음:
//   Base status 컬럼의 "도메인별 상이" 허용 범위 내).
// ══════════════════════════════════════════════════════════
const WishStatusSchema = z.object({
  id: z.coerce.number().int().positive(),
  status: z.enum(["visible", "blinded", "deleted_by_admin"]),
});

export async function setWishStatus(
  _prevState: CommunityFormState,
  formData: FormData
): Promise<CommunityFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCommunity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = WishStatusSchema.safeParse({
    id: formData.get("id"),
    status: formData.get("status"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, status } = parsed.data;

  if (status === "deleted_by_admin" && !canDeleteCommunity(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const before = await prisma.wish.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 소원입니다." };
  }

  await prisma.wish.update({
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
      targetType: "wish",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status }),
    },
  });

  revalidatePath("/community/posts");
  return { success: true };
}
