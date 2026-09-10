"use client";

// [신통방통 타로 65종 주제 연동 지시서 - ④ 관리자 CMS]
// 주제 메타(주제명/설명/질문유형/허용스프레드/YESNO/AB/프롬프트도메인/상태) 편집 폼.
// FortuneCategoryMetaForm.tsx와 동일한 패턴(useActionState + 단일 저장 폼).
import { useActionState } from "react";
import { updateTarotTopic, type TarotTopicActionState } from "@/app/actions/tarot-topics";

const initialState: TarotTopicActionState = {};

const ALL_SPREADS = [
  { value: "one_card", label: "1카드" },
  { value: "three_card", label: "3카드" },
  { value: "five_card", label: "5카드" },
  { value: "yes_no", label: "YES/NO" },
  { value: "choice_ab", label: "A/B 양자택일" },
] as const;

interface Props {
  topicKey: string;
  topicName: string;
  description: string;
  questionType: string;
  allowedSpreads: string[];
  yesNoEnabled: boolean;
  isChoiceAb: boolean;
  promptDomain: string;
  status: string;
  canWrite: boolean;
}

export default function TarotTopicMetaForm({
  topicKey,
  topicName,
  description,
  questionType,
  allowedSpreads,
  yesNoEnabled,
  isChoiceAb,
  promptDomain,
  status,
  canWrite,
}: Props) {
  const [state, formAction, pending] = useActionState(updateTarotTopic, initialState);

  return (
    <form action={formAction} className="space-y-3">
      <input type="hidden" name="topicKey" value={topicKey} />

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">주제명</label>
        <input
          name="topicName"
          defaultValue={topicName}
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        />
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">
          주제 설명(AI 프롬프트 user_question 앞에 붙는 설명)
        </label>
        <textarea
          name="description"
          defaultValue={description}
          rows={2}
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-600">질문 유형</label>
          <select
            name="questionType"
            defaultValue={questionType}
            disabled={!canWrite}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
          >
            <option value="open">자유질문(open)</option>
            <option value="yes_no">YES/NO(yes_no)</option>
            <option value="choice_ab">A/B 양자택일(choice_ab)</option>
          </select>
        </div>
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-600">
            프롬프트 도메인(ai_prompt_templates 매핑)
          </label>
          <input
            name="promptDomain"
            defaultValue={promptDomain}
            disabled={!canWrite}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-mono text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
          />
        </div>
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">허용 스프레드</label>
        <div className="flex flex-wrap gap-3 rounded-lg border border-slate-200 bg-white/40 px-3 py-2">
          {ALL_SPREADS.map((s) => (
            <label key={s.value} className="flex items-center gap-1.5 text-sm text-slate-700">
              <input
                type="checkbox"
                name="allowedSpreads"
                value={s.value}
                defaultChecked={allowedSpreads.includes(s.value)}
                disabled={!canWrite}
              />
              {s.label}
            </label>
          ))}
        </div>
        <p className="mt-1 text-xs text-slate-500">
          아래에서 편집 가능한 포지션은 여기서 체크된 스프레드만 노출됩니다.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <label className="flex items-center gap-2 rounded-lg border border-slate-200 bg-white/40 px-3 py-2 text-sm text-slate-700">
          <input
            type="checkbox"
            name="yesNoEnabled"
            defaultChecked={yesNoEnabled}
            disabled={!canWrite}
          />
          YES/NO 리딩 허용 (12개 지정 주제만 켜야 함)
        </label>
        <label className="flex items-center gap-2 rounded-lg border border-slate-200 bg-white/40 px-3 py-2 text-sm text-slate-700">
          <input
            type="checkbox"
            name="isChoiceAb"
            defaultChecked={isChoiceAb}
            disabled={!canWrite}
          />
          A/B 양자택일 허용 (daily_direction_of_choice 1개 주제만 켜야 함)
        </label>
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">상태</label>
        <select
          name="status"
          defaultValue={status}
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        >
          <option value="active">활성</option>
          <option value="inactive">비활성</option>
        </select>
      </div>

      {state.error && (
        <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          저장되었습니다.
        </p>
      )}

      {canWrite && (
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "저장 중..." : "저장"}
        </button>
      )}
    </form>
  );
}
