"use client";

import { useActionState, useState } from "react";
import { sendSegmentNotification, type SegmentSendFormState } from "@/app/actions/segment-send";

const initialState: SegmentSendFormState = {};

const GRADE_OPTIONS = [
  { code: "bronze", label: "브론즈" },
  { code: "silver", label: "실버" },
  { code: "gold", label: "골드" },
  { code: "vip", label: "VIP" },
];

const ACTIVITY_OPTIONS = [
  { value: "", label: "(조건 없음)" },
  { value: "recent_login_7d", label: "최근 7일 이내 로그인" },
  { value: "recent_login_30d", label: "최근 30일 이내 로그인" },
  { value: "dormant_30d", label: "30일 이상 미접속" },
  { value: "dormant_90d", label: "90일 이상 미접속" },
];

interface Template {
  id: number;
  code: string;
  title: string;
}

export default function SegmentSendForm({
  templates,
  activeUserCount,
  canWrite,
}: {
  templates: Template[];
  activeUserCount: number;
  canWrite: boolean;
}) {
  const [state, formAction, pending] = useActionState(sendSegmentNotification, initialState);
  const [targetType, setTargetType] = useState<"all" | "condition">("all");

  if (!canWrite) {
    return (
      <p className="rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-500">
        발송 실행 권한이 없습니다.(조회만 가능)
      </p>
    );
  }

  if (templates.length === 0) {
    return (
      <p className="rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-500">
        등록된 알림 템플릿이 없습니다. 먼저 &quot;알림 템플릿 관리&quot;에서 템플릿을
        추가해주세요.
      </p>
    );
  }

  return (
    <form
      action={formAction}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-2"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">세그먼트 발송 실행</h3>
      <p className="col-span-full text-xs text-slate-500">
        현재 활성(status=active) 회원 총 {activeUserCount}명 중, 아래 조건에 해당하는 회원에게
        알림을 발송합니다. 발송된 알림은 &quot;발송 이력 조회&quot;에서 확인할 수 있습니다.
      </p>

      <label className="flex flex-col gap-1 text-xs text-slate-400 md:col-span-2">
        발송 템플릿
        <select
          name="templateId"
          required
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          {templates.map((t) => (
            <option key={t.id} value={t.id}>
              [{t.code}] {t.title}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1 text-xs text-slate-400">
        발송 대상
        <select
          name="targetType"
          value={targetType}
          onChange={(e) => setTargetType(e.target.value as "all" | "condition")}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          <option value="all">전체 발송(활성 회원 전체)</option>
          <option value="condition">조건별 발송</option>
        </select>
      </label>

      {targetType === "condition" && (
        <>
          <fieldset className="col-span-full grid grid-cols-1 gap-3 rounded-lg border border-slate-800 p-3 md:grid-cols-3">
            <legend className="px-1 text-xs font-medium text-slate-400">조건 설정</legend>

            <div className="flex flex-col gap-1 text-xs text-slate-400">
              등급(복수 선택 가능, 미선택 시 전체 등급)
              <div className="flex flex-wrap gap-2">
                {GRADE_OPTIONS.map((g) => (
                  <label
                    key={g.code}
                    className="flex items-center gap-1 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-slate-300"
                  >
                    <input
                      type="checkbox"
                      name="gradeCodes"
                      value={g.code}
                      className="accent-indigo-500"
                    />
                    {g.label}
                  </label>
                ))}
              </div>
            </div>

            <div className="flex flex-col gap-1 text-xs text-slate-400">
              가입일(기간)
              <input
                type="date"
                name="joinedFrom"
                className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
              />
              <input
                type="date"
                name="joinedTo"
                className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
              />
            </div>

            <label className="flex flex-col gap-1 text-xs text-slate-400">
              활동패턴
              <select
                name="activityPattern"
                className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
              >
                {ACTIVITY_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </select>
            </label>
          </fieldset>
        </>
      )}

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          {state.sentCount}명에게 발송이 완료되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "발송 중..." : "발송 실행"}
        </button>
      </div>
    </form>
  );
}
