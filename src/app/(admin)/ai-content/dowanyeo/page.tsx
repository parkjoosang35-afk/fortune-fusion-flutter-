import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, canDeleteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import AiContentSubNav from "@/components/AiContentSubNav";
import DowanyeoCounselorForm from "@/components/DowanyeoCounselorForm";
import DowanyeoCounselorRow from "@/components/DowanyeoCounselorRow";
import DowanyeoRequestRow from "@/components/DowanyeoRequestRow";

// [관리자 2.0 전면 재설계 - Task 12a] 도완녀상담 — 신청/배정/진행/완료 현황.
// RBAC: "ai_content" 재사용(rbac.ts 주석 결정, 사이드바 스켈레톤 링크 활성화).
//
// [1차 범위 안내] schema.prisma DowanyeoConsultationRequest 모델 주석 및
// actions/dowanyeo.ts 주석 참고 — 실시간 채팅/예약 슬롯/정산은 제외, 관리자
// 수동 배정 기반의 운영 현황 추적 화면이다.
export const dynamic = "force-dynamic";

const STATUS_FILTERS = ["requested", "assigned", "in_progress", "completed", "cancelled"] as const;

export default async function DowanyeoPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const canWrite = canWriteMenu(session.roleCode, "ai_content");
  const canCancel = canDeleteMenu(session.roleCode, "ai_content") || canWrite;

  const { status } = await searchParams;
  const validStatus = status && (STATUS_FILTERS as readonly string[]).includes(status) ? status : undefined;

  const [counselors, requests, counts] = await Promise.all([
    prisma.dowanyeoCounselor.findMany({
      where: { deletedAt: null },
      orderBy: { createdAt: "desc" },
    }),
    prisma.dowanyeoConsultationRequest.findMany({
      where: validStatus ? { status: validStatus } : undefined,
      orderBy: { createdAt: "desc" },
      take: 50,
      include: {
        user: { select: { nickname: true } },
        counselor: { select: { name: true } },
      },
    }),
    Promise.all(
      STATUS_FILTERS.map((s) => prisma.dowanyeoConsultationRequest.count({ where: { status: s } }))
    ),
  ]);

  const activeCounselors = counselors.filter((c) => c.status === "active");

  const tabs: { value: string | undefined; label: string; count: number }[] = [
    { value: undefined, label: "전체", count: counts.reduce((a, b) => a + b, 0) },
    { value: "requested", label: "신청", count: counts[0] },
    { value: "assigned", label: "배정완료", count: counts[1] },
    { value: "in_progress", label: "진행중", count: counts[2] },
    { value: "completed", label: "완료", count: counts[3] },
    { value: "cancelled", label: "취소", count: counts[4] },
  ];

  return (
    <div>
      <div className="mb-6">
        <AiContentSubNav />
      </div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">도완녀 상담 (기획중 — 1차 범위)</h1>
        <p className="mt-1 text-sm text-slate-500">
          신청 → 배정 → 진행중 → 완료의 운영 현황만 추적하는 1차 범위 화면입니다. 실시간
          채팅/화상상담, 자동매칭, 예약 슬롯, 정산은 아직 설계되지 않았습니다(대표자 승인 후
          별도 소단위로 진행 예정).
        </p>
      </div>

      <section className="mb-6 rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          카운슬러 명단 ({activeCounselors.length}명 활성 / 총 {counselors.length}명)
        </h2>
        <DowanyeoCounselorForm canWrite={canWrite} />
        <div className="space-y-2">
          {counselors.length === 0 && (
            <p className="text-sm text-slate-500">등록된 카운슬러가 없습니다.</p>
          )}
          {counselors.map((c) => (
            <DowanyeoCounselorRow key={c.id} counselor={c} canWrite={canWrite} />
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">상담 신청 현황</h2>
        <div className="mb-4 flex flex-wrap gap-2">
          {tabs.map((t) => (
            <a
              key={t.label}
              href={t.value ? `/ai-content/dowanyeo?status=${t.value}` : "/ai-content/dowanyeo"}
              className={`rounded-full border px-3 py-1.5 text-xs font-medium ${
                validStatus === t.value
                  ? "border-indigo-400 bg-indigo-100 text-indigo-700"
                  : "border-slate-200 bg-white text-slate-600 hover:bg-slate-100"
              }`}
            >
              {t.label} ({t.count})
            </a>
          ))}
        </div>

        <div className="space-y-3">
          {requests.length === 0 && (
            <div className="rounded-xl border border-dashed border-slate-300 bg-white/40 p-8 text-center text-sm text-slate-500">
              해당 상태의 신청이 없습니다.
            </div>
          )}
          {requests.map((r) => (
            <DowanyeoRequestRow
              key={r.id}
              request={{
                id: r.id,
                topic: r.topic,
                requestMemo: r.requestMemo,
                preferredAt: r.preferredAt,
                status: r.status,
                createdAt: r.createdAt,
                userNickname: r.user.nickname,
                counselorName: r.counselor?.name ?? null,
              }}
              counselors={activeCounselors.map((c) => ({ id: c.id, name: c.name }))}
              canWrite={canWrite}
              canCancel={canCancel}
            />
          ))}
        </div>
      </section>
    </div>
  );
}
