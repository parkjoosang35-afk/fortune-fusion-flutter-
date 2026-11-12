"use client";

import { useActionState, useState } from "react";
import {
  testSajuEngineFactsAction,
  testSajuEngineCategories69Action,
  checkSajuEngineHealthAction,
  type SajuEngineTestState,
  type EngineHealthCheckState,
} from "@/app/actions/saju-engine-admin";

// [2026-11-12 사주엔진관리 신규] 관리자가 생년월일시를 입력해 로컬/샌드박스
// 엔진에 실제 계산을 요청하고 결과를 확인하는 클라이언트 패널.
// [안전장치] baseUrl 입력란은 기본값(샌드박스 로컬)을 제공하되 수정 가능 —
// 단, 실제 호출은 Server Action(saju-engine-admin.ts)이 "127.0.0.1/localhost"
// 포함 여부를 다시 검증해 운영 도메인 호출을 이중으로 차단한다.

const initialTestState: SajuEngineTestState = {};
const initialHealthState: EngineHealthCheckState = {};

export default function SajuEngineLiveTestPanel({ defaultBaseUrl }: { defaultBaseUrl: string }) {
  const [baseUrl, setBaseUrl] = useState(defaultBaseUrl);
  const [healthState, healthAction, healthPending] = useActionState(
    checkSajuEngineHealthAction,
    initialHealthState
  );
  const [factsState, factsAction, factsPending] = useActionState(testSajuEngineFactsAction, initialTestState);
  const [cat69State, cat69Action, cat69Pending] = useActionState(
    testSajuEngineCategories69Action,
    initialTestState
  );

  return (
    <div className="space-y-4 rounded-xl border border-slate-200 bg-white p-4">
      <div>
        <label className="block text-xs font-medium text-slate-600">엔진 주소(로컬/샌드박스만 허용)</label>
        <input
          type="text"
          value={baseUrl}
          onChange={(e) => setBaseUrl(e.target.value)}
          className="mt-1 w-full max-w-md rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-mono"
          placeholder="http://127.0.0.1:8977"
        />
      </div>

      <form action={healthAction} className="flex items-center gap-3">
        <input type="hidden" name="baseUrl" value={baseUrl} />
        <button
          type="submit"
          disabled={healthPending}
          className="rounded-lg bg-slate-700 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-slate-800 disabled:opacity-50"
        >
          {healthPending ? "확인 중..." : "① 헬스체크(GET /health)"}
        </button>
        {healthState.success && (
          <span className="text-xs text-emerald-700">
            ✅ status={healthState.status} (응답 {healthState.latencyMs}ms)
          </span>
        )}
        {healthState.error && <span className="text-xs text-rose-700">❌ {healthState.error}</span>}
      </form>

      <div className="border-t border-slate-100 pt-4">
        <p className="mb-2 text-xs font-medium text-slate-600">② 생년월일시 입력 → 실계산 테스트</p>
        <form action={factsAction} className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <input type="hidden" name="baseUrl" value={baseUrl} />
          <div>
            <label className="block text-xs text-slate-500">년</label>
            <input name="year" type="number" defaultValue={1990} required className="mt-1 w-full rounded-lg border border-slate-300 px-2 py-1 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-slate-500">월</label>
            <input name="month" type="number" defaultValue={5} required min={1} max={12} className="mt-1 w-full rounded-lg border border-slate-300 px-2 py-1 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-slate-500">일</label>
            <input name="day" type="number" defaultValue={15} required min={1} max={31} className="mt-1 w-full rounded-lg border border-slate-300 px-2 py-1 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-slate-500">시(0~23, 모르면 비움)</label>
            <input name="hour" type="number" min={0} max={23} defaultValue={14} className="mt-1 w-full rounded-lg border border-slate-300 px-2 py-1 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-slate-500">분</label>
            <input name="minute" type="number" min={0} max={59} defaultValue={30} className="mt-1 w-full rounded-lg border border-slate-300 px-2 py-1 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-slate-500">성별</label>
            <select name="gender" defaultValue="M" className="mt-1 w-full rounded-lg border border-slate-300 px-2 py-1 text-sm">
              <option value="M">남</option>
              <option value="F">여</option>
            </select>
          </div>
          <div>
            <label className="block text-xs text-slate-500">야자시 정책</label>
            <select name="zihourPolicy" defaultValue="traditional" className="mt-1 w-full rounded-lg border border-slate-300 px-2 py-1 text-sm">
              <option value="traditional">전통(23시 익일파)</option>
              <option value="legacy">레거시</option>
            </select>
          </div>
          <div className="flex items-end gap-3">
            <label className="flex items-center gap-1 text-xs text-slate-500">
              <input type="checkbox" name="isLunar" /> 음력
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-500">
              <input type="checkbox" name="isLeapMonth" /> 윤달
            </label>
          </div>

          <div className="col-span-2 flex items-end gap-2 sm:col-span-4">
            <button
              type="submit"
              disabled={factsPending}
              className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-indigo-700 disabled:opacity-50"
            >
              {factsPending ? "계산 중..." : "facts 계산 (POST /saju/v3/facts)"}
            </button>
            <button
              type="submit"
              formAction={cat69Action}
              disabled={cat69Pending}
              className="rounded-lg bg-purple-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-purple-700 disabled:opacity-50"
            >
              {cat69Pending ? "계산 중..." : "69종 전체 계산 (POST /saju/v3/categories69)"}
            </button>
          </div>
        </form>

        {factsState.error && <p className="mt-2 text-xs text-rose-700">❌ {factsState.error}</p>}
        {factsState.success && (
          <div className="mt-2">
            <p className="text-xs text-emerald-700">✅ 응답 {factsState.latencyMs}ms</p>
            <pre className="mt-1 max-h-96 overflow-auto rounded-lg bg-slate-900 p-3 text-xs text-slate-100">
              {factsState.resultJson}
            </pre>
          </div>
        )}

        {cat69State.error && <p className="mt-2 text-xs text-rose-700">❌ {cat69State.error}</p>}
        {cat69State.success && (
          <div className="mt-2">
            <p className="text-xs text-emerald-700">✅ 응답 {cat69State.latencyMs}ms (69종 전체)</p>
            <pre className="mt-1 max-h-96 overflow-auto rounded-lg bg-slate-900 p-3 text-xs text-slate-100">
              {cat69State.resultJson}
            </pre>
          </div>
        )}
      </div>
    </div>
  );
}
