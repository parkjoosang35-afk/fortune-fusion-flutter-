import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 6차(마지막) 소단위:
//   F-1/F-2 궁합 요청/결과 통계 (04A F도메인)
// [범위 결정] 05§3.6 화면 스펙: "궁합 요청/결과 통계 | compatibility_requests,
//   compatibility_results 집계" — "집계"만 명시(CUD 없음). 궁합 요청 생성/
//   AI 결과 산출 자체는 회원 앱 + AI 엔진 전용 기능이므로(matching_likes/
//   matching_pairs, friends/follows와 동일 원칙), Server Action 없이 순수
//   집계/조회 페이지만 구현한다. 이것으로 §3.6 매칭/궁합 관리 전체 6개
//   화면이 모두 완료된다.
// [집계 로직] where 단순화 후 메모리 집계 원칙(ai-content/logs 패턴 재사용):
//   - type별(love/friend/business/family) 요청 건수
//   - 상대방 유형별(회원 대상 target_user_id 존재 / 비회원 대상 target_input) 비율
//   - score 분포(구간별: 0-40/40-60/60-80/80-100)
//   - 결과 미생성 건수(요청은 있으나 result가 없는 케이스 — AI 처리 대기/실패 추정)
// [JSON 문자열 파싱] target_input, detail 컬럼은 04A 원본 JSONB를 SQLite
//   네이티브 미지원으로 String(JSON 문자열)에 매핑했으므로(schema.prisma
//   CompatibilityRequest/CompatibilityResult 모델 주석과 동일 근거),
//   화면에서 JSON.parse로 역직렬화하여 표시한다.
export const dynamic = "force-dynamic";

const TYPE_LABEL: Record<string, string> = {
  love: "연애",
  friend: "친구",
  business: "사업",
  family: "가족",
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

function scoreBand(score: number): string {
  if (score >= 80) return "80-100";
  if (score >= 60) return "60-79";
  if (score >= 40) return "40-59";
  return "0-39";
}

export default async function MatchingCompatibilityStatsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "matching")) {
    redirect("/dashboard");
  }

  const [requests, results] = await Promise.all([
    prisma.compatibilityRequest.findMany({
      where: { deletedAt: null },
      orderBy: { createdAt: "desc" },
    }),
    prisma.compatibilityResult.findMany({ where: { deletedAt: null } }),
  ]);

  const resultByRequestId = new Map(results.map((r) => [r.requestId, r]));

  // ── type별 집계 ──
  const typeMap = new Map<string, number>();
  for (const r of requests) {
    typeMap.set(r.type, (typeMap.get(r.type) ?? 0) + 1);
  }
  const typeStats = Array.from(typeMap.entries()).sort((a, b) => b[1] - a[1]);

  // ── 상대방 유형 집계 ──
  const memberTargetCount = requests.filter((r) => r.targetUserId != null).length;
  const nonMemberTargetCount = requests.length - memberTargetCount;

  // ── score 분포 집계 ──
  const scoreBandMap = new Map<string, number>();
  for (const res of results) {
    const band = scoreBand(res.score);
    scoreBandMap.set(band, (scoreBandMap.get(band) ?? 0) + 1);
  }
  const scoreBandOrder = ["80-100", "60-79", "40-59", "0-39"];
  const scoreStats = scoreBandOrder.map((band) => ({ band, count: scoreBandMap.get(band) ?? 0 }));

  const avgScore =
    results.length > 0 ? results.reduce((s, r) => s + r.score, 0) / results.length : 0;

  // ── 결과 미생성 건수(요청은 있으나 result 없음) ──
  const pendingCount = requests.filter((r) => !resultByRequestId.has(r.id)).length;

  // 회원 닉네임 배치조회
  const userIds = [
    ...new Set([
      ...requests.map((r) => r.requesterUserId),
      ...requests.map((r) => r.targetUserId).filter((id): id is number => id != null),
    ]),
  ];
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, nickname: true },
  });
  const userMap = new Map(users.map((u) => [u.id, u.nickname]));
  const nick = (id: number) => userMap.get(id) ?? `회원#${id}`;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">매칭/궁합 관리 — 궁합 요청/결과 통계</h1>
        <p className="mt-1 text-sm text-slate-500">
          회원의 궁합 요청(compatibility_requests)과 AI 산출 결과(compatibility_results)를
          집계 조회합니다(조회 전용).
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/matching/profiles" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            매칭 프로필
          </Link>
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
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">궁합 통계</span>
        </nav>
      </div>

      <section className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">전체 요청 건수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{requests.length.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">결과 생성 완료</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{results.length.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">결과 미생성(대기/실패)</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">{pendingCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">평균 궁합 점수</p>
          <p className="mt-1 text-2xl font-bold text-indigo-700">{avgScore.toFixed(1)}</p>
        </div>
      </section>

      <section className="mb-6 grid gap-4 sm:grid-cols-2">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <h2 className="mb-3 text-sm font-semibold text-slate-600">유형(type)별 요청 건수</h2>
          <div className="space-y-2">
            {typeStats.length === 0 && <p className="text-sm text-slate-500">데이터가 없습니다.</p>}
            {typeStats.map(([type, count]) => (
              <div key={type} className="flex items-center justify-between text-sm">
                <span className="text-slate-600">{TYPE_LABEL[type] ?? type}</span>
                <span className="font-semibold text-slate-900">{count}건</span>
              </div>
            ))}
          </div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <h2 className="mb-3 text-sm font-semibold text-slate-600">상대방 유형 비율</h2>
          <div className="space-y-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-slate-600">회원 상대(target_user_id)</span>
              <span className="font-semibold text-slate-900">{memberTargetCount}건</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-slate-600">비회원 상대(target_input)</span>
              <span className="font-semibold text-slate-900">{nonMemberTargetCount}건</span>
            </div>
          </div>
        </div>
      </section>

      <section className="mb-6 rounded-xl border border-slate-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-semibold text-slate-600">궁합 점수(score) 분포</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {scoreStats.map(({ band, count }) => (
            <div key={band} className="rounded-lg border border-slate-200 bg-white/40 p-3 text-center">
              <p className="text-xs text-slate-500">{band}점</p>
              <p className="mt-1 text-xl font-bold text-slate-900">{count}건</p>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-600">요청/결과 상세 목록</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">요청자</th>
                <th className="px-4 py-3">상대</th>
                <th className="px-4 py-3">유형</th>
                <th className="px-4 py-3">점수</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">요청일</th>
              </tr>
            </thead>
            <tbody>
              {requests.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 궁합 요청이 없습니다.
                  </td>
                </tr>
              )}
              {requests.map((r) => {
                const result = resultByRequestId.get(r.id);
                let targetLabel = "-";
                if (r.targetUserId != null) {
                  targetLabel = nick(r.targetUserId);
                } else if (r.targetInput) {
                  try {
                    const parsed = JSON.parse(r.targetInput) as { name?: string };
                    targetLabel = parsed.name ? `${parsed.name}(비회원)` : "비회원";
                  } catch {
                    targetLabel = "비회원";
                  }
                }
                return (
                  <tr key={r.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                    <td className="px-4 py-3 text-slate-700">{nick(r.requesterUserId)}</td>
                    <td className="px-4 py-3 text-slate-700">{targetLabel}</td>
                    <td className="px-4 py-3 text-slate-500">{TYPE_LABEL[r.type] ?? r.type}</td>
                    <td className="px-4 py-3">
                      {result ? (
                        <span className="font-semibold text-indigo-700">{result.score}점</span>
                      ) : (
                        <span className="text-slate-500">-</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {result ? (
                        <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                          결과 완료
                        </span>
                      ) : (
                        <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
                          결과 대기
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(r.createdAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
      <p className="mt-2 text-xs text-slate-500">
        04A F-1/F-2 명시: compatibility_requests.type은 love/friend/business/family,
        compatibility_results.score는 0~100(UQ(request_id) — 요청 1건당 결과 최대 1건)입니다.
      </p>
    </div>
  );
}
