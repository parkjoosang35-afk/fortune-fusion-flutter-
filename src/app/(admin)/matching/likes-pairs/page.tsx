import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 2차 소단위(도메인 M 2단계): 매칭 성사 이력
// 04A M-2 matching_likes, M-3 matching_pairs 조회(어뷰징/신고 연계).
// [범위 결정] 05§3.6 화면 스펙: "매칭 성사 이력 | matching_likes, matching_pairs
//   조회(어뷰징/신고 연계)" — "조회"만 명시(CUD 없음). matching_profiles(1차
//   소단위)와 마찬가지로 매칭 좋아요 발송/취소는 회원 앱 전용 기능이므로, 이번
//   소단위는 community/likes(4차 소단위)와 동일하게 Server Action 없이 순수
//   읽기 전용 페이지만 구현한다.
// [어뷰징 탐지] 발신 좋아요 수가 많은 회원을 상단에 노출하여(threshold 기준)
//   어뷰징 패턴 탐지에 활용한다(community/likes의 ABUSE_THRESHOLD 패턴 재사용).
export const dynamic = "force-dynamic";

const ABUSE_THRESHOLD = 4; // 임의 기준치: 특정 회원이 보낸 좋아요 수가 이 값 이상이면 "주의" 표시

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function MatchingLikesPairsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "matching")) {
    redirect("/dashboard");
  }

  const [likes, pairs] = await Promise.all([
    prisma.matchingLike.findMany({ where: { deletedAt: null }, orderBy: { createdAt: "desc" } }),
    prisma.matchingPair.findMany({ where: { deletedAt: null }, orderBy: { matchedAt: "desc" } }),
  ]);

  // 회원 닉네임 배치조회(폴리모픽은 아니지만 두 개의 FK 컬럼 조합이므로 동일 원칙 적용)
  const userIds = [
    ...new Set([
      ...likes.map((l) => l.fromUserId),
      ...likes.map((l) => l.toUserId),
      ...pairs.map((p) => p.userAId),
      ...pairs.map((p) => p.userBId),
    ]),
  ];
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, nickname: true },
  });
  const userMap = new Map(users.map((u) => [u.id, u.nickname]));
  const nick = (id: number) => userMap.get(id) ?? `회원#${id}`;

  // 발신 좋아요 수 집계(어뷰징 탐지용)
  const sentCountMap = new Map<number, number>();
  for (const l of likes) {
    sentCountMap.set(l.fromUserId, (sentCountMap.get(l.fromUserId) ?? 0) + 1);
  }
  const abuseSenderIds = new Set(
    [...sentCountMap.entries()].filter(([, count]) => count >= ABUSE_THRESHOLD).map(([id]) => id)
  );

  const activePairCount = pairs.filter((p) => p.status === "active").length;
  const unmatchedPairCount = pairs.filter((p) => p.status === "unmatched").length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">매칭/궁합 관리 — 매칭 성사 이력</h1>
        <p className="mt-1 text-sm text-slate-500">
          회원 간 매칭 좋아요(matching_likes)와 상호 성사된 매칭 쌍(matching_pairs)을
          조회합니다(조회 전용). 발신 좋아요가 비정상적으로 많은 회원은 어뷰징 의심으로
          표시됩니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/matching/profiles" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            매칭 프로필
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">매칭 성사 이력</span>
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

      <section className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">전체 좋아요 발신</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{likes.length.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">성사(active) 매칭 쌍</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{activePairCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">해제(unmatched) 매칭 쌍</p>
          <p className="mt-1 text-2xl font-bold text-slate-500">{unmatchedPairCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">어뷰징 의심 발신자(≥{ABUSE_THRESHOLD}건)</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">{abuseSenderIds.size.toLocaleString()}</p>
        </div>
      </section>

      <section className="mb-6">
        <h2 className="mb-2 text-sm font-semibold text-slate-600">매칭 좋아요 (matching_likes)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">발신자</th>
                <th className="px-4 py-3">수신자</th>
                <th className="px-4 py-3">유형</th>
                <th className="px-4 py-3">발신일</th>
                <th className="px-4 py-3">비고</th>
              </tr>
            </thead>
            <tbody>
              {likes.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    등록된 매칭 좋아요가 없습니다.
                  </td>
                </tr>
              )}
              {likes.map((l) => {
                const isAbuse = abuseSenderIds.has(l.fromUserId);
                return (
                  <tr
                    key={l.id}
                    className={`border-b border-slate-200/60 hover:bg-slate-100/40 ${
                      isAbuse ? "bg-amber-100" : ""
                    }`}
                  >
                    <td className="px-4 py-3 text-slate-700">{nick(l.fromUserId)}</td>
                    <td className="px-4 py-3 text-slate-700">{nick(l.toUserId)}</td>
                    <td className="px-4 py-3">
                      {l.type === "super" ? (
                        <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs text-indigo-700">
                          슈퍼 좋아요
                        </span>
                      ) : (
                        <span className="text-xs text-slate-500">일반</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(l.createdAt)}</td>
                    <td className="px-4 py-3">
                      {isAbuse ? (
                        <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
                          어뷰징 의심(발신 {sentCountMap.get(l.fromUserId)}건)
                        </span>
                      ) : (
                        <span className="text-xs text-slate-600">정상</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-600">매칭 성사 쌍 (matching_pairs)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원 A</th>
                <th className="px-4 py-3">회원 B</th>
                <th className="px-4 py-3">성사일</th>
                <th className="px-4 py-3">상태</th>
              </tr>
            </thead>
            <tbody>
              {pairs.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    성사된 매칭 쌍이 없습니다.
                  </td>
                </tr>
              )}
              {pairs.map((p) => (
                <tr key={p.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-700">{nick(p.userAId)}</td>
                  <td className="px-4 py-3 text-slate-700">{nick(p.userBId)}</td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(p.matchedAt)}</td>
                  <td className="px-4 py-3">
                    {p.status === "active" ? (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                        성사중
                      </span>
                    ) : (
                      <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
                        해제됨
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <p className="mt-2 text-xs text-slate-500">
        04A M-2/M-3 명시: matching_likes는 UQ(from_user_id,to_user_id), matching_pairs는
        UQ(user_a_id,user_b_id) 제약을 가집니다.
      </p>
    </div>
  );
}
