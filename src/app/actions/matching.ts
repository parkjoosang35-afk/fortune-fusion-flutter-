"use server";

// 매칭/궁합 관리 — 매칭 프로필 모니터링 Server Actions
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 04A M-1 matching_profiles.
// 스펙: "매칭 프로필 모니터링 | matching_profiles 조회, 부적절 프로필 강제 비활성화"
// [범위 결정] 원칙⑤(소단위 개발): 화면 스펙이 "조회, 강제 비활성화"만 명시하므로
//   (생성/수정 없음 — 매칭 프로필 등록은 회원 앱 전용 기능), status를
//   active/deactivated_by_admin 2단계로 전환하는 Server Action 1개만 구현한다
//   (comments.ts/files.ts와 동일 원칙).
// [RBAC] 05§5.2: "매칭/궁합 관리 | super_admin:RWD, operator:RW, cs:R(신고대응시만
//   채팅열람), content_manager:R". 매칭 프로필 비활성화는 write 권한 판단
//   대상이므로 canWriteMenu 기준(super_admin/operator)으로 판단한다(files.ts의
//   canDeleteMenu와 달리, 04A M-1에는 "강제 비활성화"만 있고 별도 "완전삭제" 개념이
//   없으므로 write 권한으로 충분 — reports.ts의 canWriteReports와 유사하게
//   전용 헬퍼를 두되 cs는 제외한다).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

export interface MatchingProfileFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/matching/profiles";

function canWriteMatching(roleCode: string): boolean {
  // 05§5.2: cs는 매칭/궁합 관리에서 "신고 대응 시만 채팅 열람"이라는 제한적 read
  //   예외만 있을 뿐, RBAC_MATRIX상 matching.cs.write는 false이므로
  //   canWriteMenu 기준 그대로 사용해도 cs는 자동으로 배제된다.
  return canWriteMenu(roleCode, "matching");
}

const MatchingProfileStatusSchema = z.object({
  id: z.coerce.number().int().positive(),
  status: z.enum(["active", "deactivated_by_admin"]),
});

export async function setMatchingProfileStatus(
  _prevState: MatchingProfileFormState,
  formData: FormData
): Promise<MatchingProfileFormState> {
  const session = await verifyAdminSession();
  if (!canWriteMatching(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = MatchingProfileStatusSchema.safeParse({
    id: formData.get("id"),
    status: formData.get("status"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, status } = parsed.data;

  const before = await prisma.matchingProfile.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 매칭 프로필입니다." };
  }

  await prisma.matchingProfile.update({
    where: { id },
    data: {
      status,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: status === "deactivated_by_admin" ? "status_change" : "update",
      targetType: "matching_profile",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
