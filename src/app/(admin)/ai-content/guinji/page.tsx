import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import AiContentSubNav from "@/components/AiContentSubNav";

// [신통방통 관리자 최종 간소화 실행 지시서 §2 "콘텐츠 관리 — 귀인지도/정통사주/
// 타로/소원방/관상/손금"] 전수조사 결과 6개 필수 콘텐츠 중 귀인지도만 유일하게
// 관리자 조회 화면이 없었다(GuinjiMap/GuinjiMapMember/GuinjiRelationship/
// GuinjiShareEvent/GuinjiUnlockRecord 5개 테이블은 라이브로 운영 중이나
// AiContentSubNav.tsx 주석대로 "디자인 변경 작업과 충돌 피하려 허브 통합에서
// 제외"된 채 방치되어 있었음). §2 "필요한 메뉴는 실제 DB·API·앱·웹 UI와
// 연동하고, 없는 관리 기능은 최소한으로 보완"에 따라 조회 전용 화면을 신설한다.
// [범위] CUD는 전혀 제공하지 않는다(엔진 판정 결과를 사람이 수정할 근거가
// 없음 — guinji-relation-judger.ts/guinji-v2가 결정론적으로 계산). 운영자가
// 확인할 수 있어야 하는 것은 "지도 생성 현황/멤버 수/바이럴 공유 지표"뿐이다.
export const dynamic = "force-dynamic";

function fmtDate(d: Date | null | undefined): string {
  return d ? d.toISOString().slice(0, 19).replace("T", " ") : "-";
}

const RELATION_LABEL: Record<string, string> = {
  guin: "귀인",
  oreunpal: "오른팔",
  inyeon: "인연",
  salrim: "살림꾼",
  horang: "호랑이선생",
};

export default async function GuinjiPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const [totalMaps, activeMaps, totalMembers, totalRelationships, totalShareEvents, joinedShareEvents, recentMaps] =
    await Promise.all([
      prisma.guinjiMap.count(),
      prisma.guinjiMap.count({ where: { status: "active", deletedAt: null } }),
      prisma.guinjiMapMember.count({ where: { status: "active", deletedAt: null } }),
      prisma.guinjiRelationship.count(),
      prisma.guinjiShareEvent.count(),
      prisma.guinjiShareEvent.count({ where: { joinedAt: { not: null } } }),
      prisma.guinjiMap.findMany({
        where: { deletedAt: null },
        orderBy: { createdAt: "desc" },
        take: 30,
        include: {
          owner: { select: { id: true, nickname: true } },
          _count: { select: { members: true, shareEvents: true } },
        },
      }),
    ]);

  const relationTypeCounts = await prisma.guinjiRelationship.groupBy({
    by: ["relationType"],
    _count: { relationType: true },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">6개콘텐츠관리 — 귀인지도</h1>
        <p className="mt-1 text-sm text-slate-500">
          귀인지도(GuinjiMap) 생성·참여·관계판정·바이럴 공유 현황을 조회합니다. (조회 전용 —
          관계 판정은 엔진이 결정론적으로 계산하므로 관리자가 수정하지 않습니다)
        </p>
      </div>

      <AiContentSubNav />

      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">전체 지도 수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalMaps}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">활성 지도 수</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{activeMaps}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">전체 멤버 수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalMembers}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">관계 판정 건수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalRelationships}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">공유 링크 오픈</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalShareEvents}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">공유 → 참여 전환</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">{joinedShareEvents}</p>
        </div>
      </div>

      <h2 className="mb-3 text-lg font-semibold text-slate-900">관계유형 분포</h2>
      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-5">
        {relationTypeCounts.map((r) => (
          <div key={r.relationType} className="rounded-xl border border-slate-200 bg-white p-3 text-center">
            <p className="text-xs text-slate-500">{RELATION_LABEL[r.relationType] ?? r.relationType}</p>
            <p className="mt-1 text-xl font-bold text-slate-900">{r._count.relationType}</p>
          </div>
        ))}
        {relationTypeCounts.length === 0 && (
          <p className="col-span-full text-sm text-slate-500">아직 판정된 관계가 없습니다.</p>
        )}
      </div>

      <h2 className="mb-3 text-lg font-semibold text-slate-900">최근 생성된 지도 (최근 30건)</h2>
      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">소유자</th>
              <th className="px-4 py-3">지도명</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">초대링크 상태</th>
              <th className="px-4 py-3">멤버 수</th>
              <th className="px-4 py-3">공유 이벤트</th>
              <th className="px-4 py-3">생성일</th>
            </tr>
          </thead>
          <tbody>
            {recentMaps.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  생성된 지도가 없습니다.
                </td>
              </tr>
            )}
            {recentMaps.map((m) => (
              <tr key={m.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                <td className="px-4 py-3 text-slate-700">{m.owner.nickname}</td>
                <td className="px-4 py-3 text-slate-700">{m.name}</td>
                <td className="px-4 py-3">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs ${
                      m.status === "active"
                        ? "bg-emerald-100 text-emerald-700"
                        : "bg-white text-slate-500"
                    }`}
                  >
                    {m.status === "active" ? "활성" : m.status}
                  </span>
                </td>
                <td className="px-4 py-3">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs ${
                      m.inviteStatus === "active"
                        ? "bg-emerald-100 text-emerald-700"
                        : "bg-amber-100 text-amber-700"
                    }`}
                  >
                    {m.inviteStatus === "active" ? "정상" : "중단됨"}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-600">{m._count.members}</td>
                <td className="px-4 py-3 text-slate-600">{m._count.shareEvents}</td>
                <td className="px-4 py-3 text-xs text-slate-500">{fmtDate(m.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
