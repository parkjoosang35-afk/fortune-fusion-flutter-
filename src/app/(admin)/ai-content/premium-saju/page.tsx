import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import AiContentSubNav from "@/components/AiContentSubNav";
import PremiumSajuSectionCreateForm from "@/components/PremiumSajuSectionCreateForm";

// [관리자 2.0 전면 재설계 - Task 12b] 프리미엄사주 PDF 섹션 템플릿 — 목록.
// ai-content/prompts/page.tsx(도메인별 요약 카드 목록)와 동일한 패턴이되,
// "도메인"이 고정 목록이 아니라 관리자가 직접 추가하는 "섹션"이라는 점이 다름.
//
// [1차 범위 안내] schema.prisma PremiumSajuSection 모델 주석 참고 — 실제 PDF
// 렌더링/계산엔진 선택/결제 플로우는 제외, "PDF 섹션별 LLM 프롬프트 템플릿
// 버전 관리"만 구현한다.
export const dynamic = "force-dynamic";

export default async function PremiumSajuPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }
  const canWrite = canWriteMenu(session.roleCode, "ai_content");

  const sections = await prisma.premiumSajuSection.findMany({
    where: { deletedAt: null },
    orderBy: [{ sortOrder: "asc" }, { sectionKey: "asc" }, { version: "desc" }],
  });

  const bySectionKey = new Map<string, typeof sections>();
  for (const s of sections) {
    const list = bySectionKey.get(s.sectionKey) ?? [];
    list.push(s);
    bySectionKey.set(s.sectionKey, list);
  }
  const sectionKeysInOrder = [...bySectionKey.keys()].sort((a, b) => {
    const aOrder = bySectionKey.get(a)![0].sortOrder;
    const bOrder = bySectionKey.get(b)![0].sortOrder;
    return aOrder - bOrder;
  });

  return (
    <div>
      <div className="mb-6">
        <AiContentSubNav />
      </div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">프리미엄 사주 (기획중 — 1차 범위)</h1>
        <p className="mt-1 text-sm text-slate-500">
          30~40페이지 분량 PDF를 구성할 섹션별 LLM 프롬프트 템플릿을 관리합니다. 실제 PDF
          렌더링/계산엔진 선택(saju_engine vs TopicEngine)/결제 플로우는 아직 설계되지
          않았습니다(대표자 승인 후 별도 소단위로 진행 예정).
        </p>
      </div>

      <PremiumSajuSectionCreateForm canWrite={canWrite} />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {sectionKeysInOrder.length === 0 && (
          <p className="col-span-full text-center text-sm text-slate-500">
            등록된 섹션이 없습니다. 위 폼으로 첫 섹션을 추가해주세요.
          </p>
        )}
        {sectionKeysInOrder.map((key) => {
          const list = bySectionKey.get(key)!;
          const active = list.find((t) => t.isActive);
          const latest = list[0];
          return (
            <Link
              key={key}
              href={`/ai-content/premium-saju/${key}`}
              className="rounded-xl border border-slate-200 bg-white p-5 transition hover:border-indigo-500/60 hover:bg-slate-100/60"
            >
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-base font-semibold text-slate-900">
                  {latest.sectionLabel}{" "}
                  <span className="text-xs font-normal text-slate-500">
                    (순서 {latest.sortOrder})
                  </span>
                </h2>
                <span className="rounded-full bg-indigo-100 px-2 py-1 text-xs font-medium text-indigo-700">
                  v{latest.version}까지 {list.length}개 버전
                </span>
              </div>
              {active ? (
                <div>
                  <p className="text-xs text-emerald-700">현재 배포중: v{active.version}</p>
                  <p className="mt-1 line-clamp-2 text-sm text-slate-500">{active.templateBody}</p>
                </div>
              ) : (
                <p className="text-sm text-amber-700">배포된(활성) 버전이 없습니다.</p>
              )}
            </Link>
          );
        })}
      </div>
    </div>
  );
}
