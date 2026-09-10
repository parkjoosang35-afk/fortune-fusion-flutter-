import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import TarotTopicMetaForm from "@/components/TarotTopicMetaForm";
import TarotPositionRow from "@/components/TarotPositionRow";

// [신통방통 타로 65종 주제 연동 지시서 - ④ 관리자 CMS]
// 주제 상세: 메타 편집 폼(좌) + 스프레드별 포지션(카드 자리) 편집 표(우).
// categories/[categoryKey]/page.tsx와 동일한 2컬럼(lg:grid-cols-3) 레이아웃 패턴.
export const dynamic = "force-dynamic";

const SPREAD_LABEL: Record<string, string> = {
  one_card: "1카드",
  three_card: "3카드",
  five_card: "5카드",
  yes_no: "YES/NO",
  choice_ab: "A/B 양자택일",
};
const SPREAD_ORDER = ["one_card", "three_card", "five_card", "yes_no", "choice_ab"];

const GROUP_LABEL: Record<string, string> = {
  love: "연애·관계",
  career: "일·커리어",
  wealth: "금전·현실",
  daily: "일상·운세",
  emotion: "감정·내면",
  special: "특별테마",
};

interface Props {
  params: Promise<{ topicKey: string }>;
}

export default async function TarotTopicDetailPage({ params }: Props) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }
  const canWrite =
    canAccessMenu(session.roleCode, "ai_content") &&
    !!RBAC_MATRIX.ai_content[session.roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;

  const { topicKey } = await params;
  const topic = await prisma.tarotTopic.findUnique({
    where: { topicKey },
    include: {
      positions: {
        where: { deletedAt: null },
        orderBy: [{ spreadType: "asc" }, { positionIndex: "asc" }],
      },
    },
  });
  if (!topic) notFound();

  let allowedSpreads: string[] = [];
  try {
    allowedSpreads = JSON.parse(topic.allowedSpreads) as string[];
  } catch {
    allowedSpreads = [];
  }

  const positionsBySpread = new Map<string, typeof topic.positions>();
  for (const p of topic.positions) {
    const list = positionsBySpread.get(p.spreadType) ?? [];
    list.push(p);
    positionsBySpread.set(p.spreadType, list);
  }

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link
          href="/ai-content/tarot-topics"
          className="text-sm text-slate-500 hover:text-slate-900"
        >
          ← 타로 65개 주제 목록
        </Link>
      </div>

      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">
          {topic.topicName}
          <span className="ml-2 text-sm font-normal text-slate-500">
            ({GROUP_LABEL[topic.categoryGroup] ?? topic.categoryGroup} · {topic.topicKey})
          </span>
        </h1>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="lg:col-span-1">
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-slate-900">주제 메타 편집</h2>
            <TarotTopicMetaForm
              topicKey={topic.topicKey}
              topicName={topic.topicName}
              description={topic.description ?? ""}
              questionType={topic.questionType}
              allowedSpreads={allowedSpreads}
              yesNoEnabled={topic.yesNoEnabled}
              isChoiceAb={topic.isChoiceAb}
              promptDomain={topic.promptDomain}
              status={topic.status}
              canWrite={canWrite}
            />
          </section>
        </div>

        <div className="lg:col-span-2">
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-1 text-sm font-semibold text-slate-900">
              스프레드별 포지션(카드 자리) 관리
            </h2>
            <p className="mb-4 text-xs text-slate-500">
              각 포지션의 이름과 AI에게 전달할 해석 목적을 편집합니다. 포지션 개수/순서는
              리딩 엔진과 결합되어 있어 이 화면에서 추가·삭제할 수 없습니다.
            </p>

            {SPREAD_ORDER.filter((s) => allowedSpreads.includes(s)).map((spreadType) => {
              const list = positionsBySpread.get(spreadType) ?? [];
              return (
                <div key={spreadType} className="mb-5">
                  <h3 className="mb-2 text-xs font-semibold uppercase text-slate-500">
                    {SPREAD_LABEL[spreadType] ?? spreadType} ({list.length}포지션)
                  </h3>
                  {list.length === 0 ? (
                    <p className="rounded-lg border border-dashed border-slate-300 px-3 py-3 text-xs text-slate-500">
                      허용 스프레드로 켜져 있지만 등록된 포지션이 없습니다. 데이터 정합성을
                      확인해주세요.
                    </p>
                  ) : (
                    <div className="overflow-x-auto rounded-lg border border-slate-200">
                      <table className="w-full text-left text-sm">
                        <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
                          <tr>
                            <th className="px-3 py-2">#</th>
                            <th className="px-3 py-2">포지션명</th>
                            <th className="px-3 py-2">해석 목적</th>
                          </tr>
                        </thead>
                        <tbody>
                          {list.map((p) => (
                            <TarotPositionRow
                              key={p.id}
                              position={p}
                              topicKey={topic.topicKey}
                              canWrite={canWrite}
                            />
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              );
            })}

            {allowedSpreads.every((s) => !SPREAD_ORDER.includes(s)) && (
              <p className="text-sm text-slate-500">허용된 스프레드가 없습니다.</p>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
