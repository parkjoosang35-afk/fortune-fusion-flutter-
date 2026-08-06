import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import MatchingProfileRow from "@/components/MatchingProfileRow";

// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 1차 소단위(도메인 M 1단계): 매칭 프로필 모니터링
// 04A M-1 matching_profiles 조회 + 부적절 프로필 강제 비활성화.
// [범위 결정] 원칙⑤(소단위 개발): 이번 소단위는 matching_profiles 1개 화면만
//   다룬다. 나머지 5개 화면(매칭 성사 이력/친구·팔로우 모니터링/채팅 모니터링/
//   궁합 요소 가중치 설정/궁합 요청·결과 통계)은 04A 도메인 M의 M-2~M-7, 도메인
//   F의 F-1~F-3에 대응하며 이후 소단위로 순차 진행 예정.
// [RBAC] 05§5.2: "매칭/궁합 관리 | super_admin:RWD, operator:RW, cs:R(신고대응시만
//   채팅열람), content_manager:R" — rbac.ts에 matching 메뉴 코드가 이미 등록되어
//   있음(matching: RWD/RW/R/R). cs의 "신고대응시만 채팅열람" 예외는 4차 소단위
//   (채팅 모니터링)에서 별도 처리 예정이며, 이번 소단위(프로필 모니터링)에는
//   해당 예외가 적용되지 않는다(단순 read 권한 그대로 적용).
export const dynamic = "force-dynamic";

// preferences(JSON 문자열)를 목록에 표시할 요약 텍스트로 변환(애플리케이션 레벨 처리)
function summarizePreferences(raw: string | null): string {
  if (!raw) return "";
  try {
    const obj = JSON.parse(raw) as Record<string, unknown>;
    return Object.entries(obj)
      .map(([k, v]) => `${k}:${Array.isArray(v) ? v.join("~") : String(v)}`)
      .join(", ");
  } catch {
    return raw;
  }
}

export default async function MatchingProfilesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "matching")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.matching[session.roleCode as keyof typeof RBAC_MATRIX.matching]?.write;

  const profiles = await prisma.matchingProfile.findMany({
    where: { deletedAt: null },
    orderBy: { createdAt: "desc" },
  });

  // 폴리모픽은 아니지만 userId → User 배치조회로 닉네임 조합(N+1 방지)
  const userIds = [...new Set(profiles.map((p) => p.userId))];
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, nickname: true },
  });
  const userMap = new Map(users.map((u) => [u.id, u.nickname]));

  const activeCount = profiles.filter((p) => p.status === "active").length;
  const deactivatedCount = profiles.filter((p) => p.status === "deactivated_by_admin").length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">매칭/궁합 관리 — 매칭 프로필 모니터링</h1>
        <p className="mt-1 text-sm text-slate-500">
          회원이 등록한 매칭 프로필을 조회하고, 부적절한 프로필을 강제 비활성화할 수 있습니다.
          공개 여부(is_public)는 회원이 직접 설정하는 값이며 관리자 조치와는 별개입니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">매칭 프로필</span>
          <Link href="/matching/likes-pairs" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            매칭 성사 이력
          </Link>
          <Link href="/matching/friends-follows" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            친구/팔로우
          </Link>
          <Link href="/matching/chats" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            채팅 모니터링
          </Link>
          <Link href="/matching/compatibility-weights" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            궁합 요소 가중치
          </Link>
          <Link href="/matching/compatibility-stats" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            궁합 통계
          </Link>
        </nav>
      </div>

      <div className="mb-4 flex gap-4 text-sm text-slate-500">
        <span>
          전체 <span className="text-slate-900">{profiles.length}</span>건
        </span>
        <span>
          노출중 <span className="text-emerald-700">{activeCount}</span>건
        </span>
        <span>
          관리자 비활성화 <span className="text-rose-700">{deactivatedCount}</span>건
        </span>
      </div>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">회원</th>
              <th className="px-4 py-3">공개여부</th>
              <th className="px-4 py-3">소개글</th>
              <th className="px-4 py-3">이상형 조건</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">등록일</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {profiles.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  등록된 매칭 프로필이 없습니다.
                </td>
              </tr>
            )}
            {profiles.map((p) => (
              <MatchingProfileRow
                key={p.id}
                profile={{
                  id: p.id,
                  userNickname: userMap.get(p.userId) ?? `회원#${p.userId}`,
                  isPublic: p.isPublic,
                  preferencesSummary: summarizePreferences(p.preferences),
                  introText: p.introText,
                  status: p.status,
                  createdAt: p.createdAt,
                }}
                canWrite={canWrite}
              />
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-xs text-slate-500">
        04A M-1 명시: matching_profiles는 회원당 1개(UQ user_id)만 존재합니다.
      </p>
    </div>
  );
}
