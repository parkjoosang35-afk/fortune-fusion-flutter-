import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [신통방통 타로 65종 주제 연동 지시서 - ④ 관리자 CMS]
// tarot_topics 65개 주제 목록. category_group별로 묶어 fortune-categories 목록
// 페이지와 동일한 레이아웃 패턴(그룹 섹션 + 표)을 재사용한다.
export const dynamic = "force-dynamic";

const GROUP_LABEL: Record<string, string> = {
  love: "연애·관계",
  career: "일·커리어",
  wealth: "금전·현실",
  daily: "일상·운세",
  emotion: "감정·내면",
  special: "특별테마",
};
const GROUP_ORDER = ["love", "career", "wealth", "daily", "emotion", "special"];

const QUESTION_TYPE_LABEL: Record<string, string> = {
  open: "자유질문",
  yes_no: "YES/NO",
  choice_ab: "A/B 양자택일",
};

export default async function TarotTopicsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const topics = await prisma.tarotTopic.findMany({
    where: { deletedAt: null },
    include: { _count: { select: { positions: true } } },
    orderBy: [{ categoryGroup: "asc" }, { topicName: "asc" }],
  });

  const byGroup = new Map<string, typeof topics>();
  for (const t of topics) {
    const list = byGroup.get(t.categoryGroup) ?? [];
    list.push(t);
    byGroup.set(t.categoryGroup, list);
  }

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">타로 65개 주제 관리</h1>
          <p className="mt-1 text-sm text-slate-500">
            "신통방통 타로 65종 주제 연동" 설계표 기준 65개 주제 각각의 질문유형·허용
            스프레드·YES/NO·A/B 양자택일 여부와, 주제×스프레드별 포지션(카드 자리) 해석
            목적을 관리합니다. 총 {topics.length}개 주제.
          </p>
        </div>
        <Link
          href="/ai-content/tarot-cards"
          className="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-600 hover:bg-slate-100"
        >
          ← 타로카드 마스터 관리
        </Link>
      </div>

      <div className="space-y-6">
        {GROUP_ORDER.map((group) => {
          const list = byGroup.get(group) ?? [];
          if (list.length === 0) return null;
          return (
            <section key={group} className="rounded-xl border border-slate-200 bg-white p-5">
              <div className="mb-3 flex items-center gap-2">
                <h2 className="text-base font-semibold text-slate-900">
                  {GROUP_LABEL[group] ?? group}
                </h2>
                <span className="text-xs text-slate-500">({list.length}개)</span>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead>
                    <tr className="border-b border-slate-200 text-xs text-slate-500">
                      <th className="py-2 pr-3">주제</th>
                      <th className="py-2 pr-3">topic_key</th>
                      <th className="py-2 pr-3">질문유형</th>
                      <th className="py-2 pr-3">YES/NO</th>
                      <th className="py-2 pr-3">A/B</th>
                      <th className="py-2 pr-3">포지션</th>
                      <th className="py-2 pr-3">상태</th>
                      <th className="py-2 pr-3"></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200/60">
                    {list.map((t) => (
                      <tr key={t.topicKey}>
                        <td className="py-2 pr-3 font-medium text-slate-900">{t.topicName}</td>
                        <td className="py-2 pr-3 font-mono text-xs text-slate-500">
                          {t.topicKey}
                        </td>
                        <td className="py-2 pr-3 text-slate-600">
                          {QUESTION_TYPE_LABEL[t.questionType] ?? t.questionType}
                        </td>
                        <td className="py-2 pr-3">
                          {t.yesNoEnabled ? (
                            <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                              지원
                            </span>
                          ) : (
                            <span className="text-xs text-slate-500">-</span>
                          )}
                        </td>
                        <td className="py-2 pr-3">
                          {t.isChoiceAb ? (
                            <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs text-indigo-700">
                              지원
                            </span>
                          ) : (
                            <span className="text-xs text-slate-500">-</span>
                          )}
                        </td>
                        <td className="py-2 pr-3 text-xs text-slate-500">
                          {t._count.positions}개
                        </td>
                        <td className="py-2 pr-3">
                          {t.status === "active" ? (
                            <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                              활성
                            </span>
                          ) : (
                            <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
                              비활성
                            </span>
                          )}
                        </td>
                        <td className="py-2 pr-3">
                          <Link
                            href={`/ai-content/tarot-topics/${t.topicKey}`}
                            className="text-xs text-indigo-700 hover:underline"
                          >
                            편집 →
                          </Link>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
