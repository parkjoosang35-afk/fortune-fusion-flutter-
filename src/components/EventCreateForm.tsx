"use client";

import { useActionState, useRef, useState } from "react";
import { createEvent, type EventFormState } from "@/app/actions/events";

const initialState: EventFormState = {};

// 이벤트 타입별 config 예시 템플릿(05§3.8 "이벤트 타입별 설정 폼" 요구사항을
// 파일 업로드 없는 CMS 구현 범위 내에서, event_type 선택 시 자동으로 예시 JSON
// 뼈대를 채워주는 방식으로 수용한다 — 원칙② 설계충돌 방지: 04A config는
// JSONB(플러그인 구조)이므로 타입별 스키마를 강제하지 않고 자유 JSON 편집을 허용).
const CONFIG_TEMPLATES: Record<string, string> = {
  attendance_bonus: JSON.stringify(
    { daily_reward_point: 50, consecutive_bonus: { "7": 500, "30": 3000 } },
    null,
    2
  ),
  roulette: JSON.stringify(
    {
      segments: [
        { label: "100포인트", weight: 40, reward_point: 100 },
        { label: "꽝", weight: 60, reward_point: 0 },
      ],
      daily_spin_limit: 1,
    },
    null,
    2
  ),
  special_mission: JSON.stringify(
    { missions: [{ id: "share_app", title: "앱 공유하기", reward_point: 200 }] },
    null,
    2
  ),
};

export default function EventCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createEvent, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const [eventType, setEventType] = useState<keyof typeof CONFIG_TEMPLATES>("attendance_bonus");
  const [config, setConfig] = useState(CONFIG_TEMPLATES.attendance_bonus);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
        setConfig(CONFIG_TEMPLATES.attendance_bonus);
        setEventType("attendance_bonus");
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-2"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">새 이벤트 추가</h3>
      <input
        type="text"
        name="title"
        placeholder="이벤트 제목"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="imageUrl"
        placeholder="배너 이미지 URL (선택)"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="eventType"
        value={eventType}
        onChange={(e) => {
          const t = e.target.value as keyof typeof CONFIG_TEMPLATES;
          setEventType(t);
          setConfig(CONFIG_TEMPLATES[t]);
        }}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="attendance_bonus">출석 보너스</option>
        <option value="roulette">룰렛</option>
        <option value="special_mission">특별 미션</option>
      </select>
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        시작일시
        <input
          type="datetime-local"
          name="startAt"
          required
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        종료일시
        <input
          type="datetime-local"
          name="endAt"
          required
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <label className="col-span-full flex flex-col gap-1 text-xs text-slate-400">
        설정(config, JSON) — 타입별 예시가 자동 채워집니다. 필요에 맞게 수정하세요.
        <textarea
          name="config"
          value={config}
          onChange={(e) => setConfig(e.target.value)}
          rows={6}
          required
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 font-mono text-xs text-white outline-none focus:border-indigo-500"
        />
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          이벤트가 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "이벤트 추가"}
        </button>
      </div>
    </form>
  );
}
