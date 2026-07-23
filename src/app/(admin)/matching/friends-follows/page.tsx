import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 3차 소단위(도메인 M 3단계): 친구/팔로우 모니터링
// 04A M-4 friends, M-5 follows 조회.
// [범위 결정] 05§3.6 화면 스펙: "친구/팔로우 모니터링 | friends, follows
//   (선택, 조회 전용)" — "조회 전용"으로 명시(CUD 없음). matching_likes/
//   matching_pairs(2차 소단위)와 동일하게 Server Action 없이 순수 읽기 전용
//   페이지만 구현한다.
// [status 의미 차이] M-4 friends의 status(requested/accepted/blocked)는
//   04A에 이미 실제 애플리케이션 레벨 친구관계 상태값으로 명시되어 있어
//   matching_profiles(1차 소단위)의 "관리자 액션용 status 재정의" 패턴과는
//   다르다(원칙② 설계충돌 방지 — 원본 의미 그대로 노출).
export const dynamic = "force-dynamic";

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function MatchingFriendsFollowsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "matching")) {
    redirect("/dashboard");
  }

  const [friends, follows] = await Promise.all([
    prisma.friend.findMany({ where: { deletedAt: null }, orderBy: { createdAt: "desc" } }),
    prisma.follow.findMany({ where: { deletedAt: null }, orderBy: { createdAt: "desc" } }),
  ]);

  // 회원 닉네임 배치조회(N+1 방지)
  const userIds = [
    ...new Set([
      ...friends.map((f) => f.userId),
      ...friends.map((f) => f.friendUserId),
      ...follows.map((fo) => fo.followerId),
      ...follows.map((fo) => fo.followingId),
    ]),
  ];
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, nickname: true },
  });
  const userMap = new Map(users.map((u) => [u.id, u.nickname]));
  const nick = (id: number) => userMap.get(id) ?? `회원#${id}`;

  const requestedCount = friends.filter((f) => f.status === "requested").length;
  const acceptedCount = friends.filter((f) => f.status === "accepted").length;
  const blockedCount = friends.filter((f) => f.status === "blocked").length;

  // 팔로워 수 집계(인기 회원 파악용 — 어뷰징 판단은 아니며 단순 참고 지표)
  const followingCountMap = new Map<number, number>();
  for (const fo of follows) {
    followingCountMap.set(fo.followingId, (followingCountMap.get(fo.followingId) ?? 0) + 1);
  }

  const statusBadge = (status: string) => {
    if (status === "accepted") {
      return (
        <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">
          친구 성사
        </span>
      );
    }
    if (status === "blocked") {
      return (
        <span className="rounded-full bg-rose-950/60 px-2 py-0.5 text-xs text-rose-400">
          차단
        </span>
      );
    }
    return (
      <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">
        요청 대기
      </span>
    );
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">매칭/궁합 관리 — 친구/팔로우 모니터링</h1>
        <p className="mt-1 text-sm text-slate-400">
          회원 간 친구 관계(friends)와 팔로우 관계(follows)를 조회합니다(조회 전용). 친구
          관계의 요청/성사/차단 상태를 확인할 수 있습니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/matching/profiles" className="px-3 py-2 text-slate-400 hover:text-white">
            매칭 프로필
          </Link>
          <Link href="/matching/likes-pairs" className="px-3 py-2 text-slate-400 hover:text-white">
            매칭 성사 이력
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">친구/팔로우</span>
          <Link href="/matching/chats" className="px-3 py-2 text-slate-400 hover:text-white">
            채팅 모니터링
          </Link>
          <Link href="/matching/compatibility-weights" className="px-3 py-2 text-slate-400 hover:text-white">
            궁합 요소 가중치
          </Link>
          <Link href="/matching/compatibility-stats" className="px-3 py-2 text-slate-400 hover:text-white">
            궁합 통계
          </Link>
        </nav>
      </div>

      <section className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">친구 요청 대기</p>
          <p className="mt-1 text-2xl font-bold text-slate-300">{requestedCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">친구 성사(accepted)</p>
          <p className="mt-1 text-2xl font-bold text-emerald-400">{acceptedCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">차단(blocked)</p>
          <p className="mt-1 text-2xl font-bold text-rose-400">{blockedCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">전체 팔로우 관계</p>
          <p className="mt-1 text-2xl font-bold text-white">{follows.length.toLocaleString()}</p>
        </div>
      </section>

      <section className="mb-6">
        <h2 className="mb-2 text-sm font-semibold text-slate-300">친구 관계 (friends)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">요청자</th>
                <th className="px-4 py-3">대상자</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">등록일</th>
              </tr>
            </thead>
            <tbody>
              {friends.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    등록된 친구 관계가 없습니다.
                  </td>
                </tr>
              )}
              {friends.map((f) => (
                <tr key={f.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">{nick(f.userId)}</td>
                  <td className="px-4 py-3 text-slate-200">{nick(f.friendUserId)}</td>
                  <td className="px-4 py-3">{statusBadge(f.status)}</td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(f.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-300">팔로우 관계 (follows)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">팔로워</th>
                <th className="px-4 py-3">팔로잉 대상</th>
                <th className="px-4 py-3">대상자 총 팔로워수</th>
                <th className="px-4 py-3">등록일</th>
              </tr>
            </thead>
            <tbody>
              {follows.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    등록된 팔로우 관계가 없습니다.
                  </td>
                </tr>
              )}
              {follows.map((fo) => (
                <tr key={fo.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">{nick(fo.followerId)}</td>
                  <td className="px-4 py-3 text-slate-200">{nick(fo.followingId)}</td>
                  <td className="px-4 py-3 text-slate-400">
                    {followingCountMap.get(fo.followingId) ?? 0}명
                  </td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(fo.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <p className="mt-2 text-xs text-slate-500">
        04A M-4/M-5 명시: friends는 UQ(user_id,friend_user_id), follows는
        UQ(follower_id,following_id) 제약을 가집니다.
      </p>
    </div>
  );
}
