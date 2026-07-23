"use server";

// 커뮤니티 관리 — 파일/업로드 관리 Server Actions
// 05_Admin_System_Design.md §3.5 "파일/업로드 관리" — 04A L-7 files(폴리모픽 공용).
// 스펙: "파일/업로드 관리 | files(폴리모픽 공용) 조회, 문제 이미지 삭제"
// [범위 결정] 05§3.5 스펙이 "조회, 문제 이미지 삭제"만 명시하므로(생성/수정 없음
// — 업로드는 회원 앱 기능), comments.ts(L-4)와 동일하게 상태값 2단계
// (active/deleted_by_admin)만 다루는 단일 Server Action(setFileStatus)만 구현한다.
// [RBAC] 05§5.2 "커뮤니티 관리 | cs: RW(신고처리)" — cs의 write 권한은 신고처리
// 워크플로우에만 한정되므로, comments.ts와 동일하게 파일 삭제도
// canDeleteMenu(super_admin만) 기준으로 판단한다(community.ts/comments.ts와
// 동일 원칙: 별도의 "노출/숨김" 중간 상태가 없어 write/delete 구분 불필요).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canDeleteMenu } from "@/lib/rbac";

export interface FileFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/community/files";

const FileStatusSchema = z.object({
  id: z.coerce.number().int().positive(),
  status: z.enum(["active", "deleted_by_admin"]),
});

export async function setFileStatus(
  _prevState: FileFormState,
  formData: FormData
): Promise<FileFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteMenu(session.roleCode, "community")) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = FileStatusSchema.safeParse({
    id: formData.get("id"),
    status: formData.get("status"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, status } = parsed.data;

  const before = await prisma.file.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 파일입니다." };
  }

  await prisma.file.update({
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
      targetType: "file",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
