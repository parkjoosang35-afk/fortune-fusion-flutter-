"use client";

// [2026-09, 바이럴 흐름 근본 수정 — 핵심 신설 컴포넌트] 사용자가 격노하며
// 지적한 문제를 그대로 해결한다: "링크를 받은 사람이 이름+생년월일을
// 한 번만 입력하면 (1) 그 자리에서 관계 결과가 나오고 (2) 동시에 지도에
// 실제로 추가되고 (3) 관계 지도 그래프가 새로고침 없이 그 자리에서
// 갱신되어야 한다."
//
// 기존 구조는 폼(`GuinjiPreviewForm`)과 그래프(`RelationNetworkGraph`)가
// 완전히 분리된 서버 컴포넌트 트리(`page.tsx`)에 나란히 렌더링되어 있어,
// 폼 제출 결과가 그래프에 반영될 방법이 없었다. 이 컴포넌트가 그 둘을
// 하나의 클라이언트 상태로 묶어, `/api/public/guinji/g/{token}/join`
// (신설 — 로그인 없이 실제로 DB에 기록하는 API) 호출이 성공하면 즉시
// `counts` state를 갱신해 그래프가 새로고침 없이 바뀌게 한다.
import { useState } from "react";
import { GUINJI_RELATION_TYPES } from "./relation-meta";
import { RelationNetworkGraph, type RelationCount } from "./relation-network-graph";

type JoinResult = {
  ownerName: string;
  relationType: string;
  chemistryScore: number;
  timeUnknown: boolean;
  dayMasterKr?: string;
  dayMasterElement?: string;
  mapSummary: { total: number; counts: Record<string, number> };
};

const RELATION_COLOR: Record<string, string> = {
  guin: "#B98BC9",
  oreunpal: "#5FA3C4",
  inyeon: "#D97A93",
  salrim: "#6FAE7C",
  horang: "#D98A4A",
};
const RELATION_TYPE_ORDER = ["guin", "oreunpal", "inyeon", "salrim", "horang"] as const;

function countsToRelationCounts(counts: Record<string, number>): RelationCount[] {
  return RELATION_TYPE_ORDER.map((key) => ({
    key,
    label: GUINJI_RELATION_TYPES[key].label,
    hanja: GUINJI_RELATION_TYPES[key].hanja,
    color: RELATION_COLOR[key],
    count: counts[key] ?? 0,
  }));
}

export function GuinjiInviteInteractive({
  token,
  ownerName,
  initialCounts,
}: {
  token: string;
  ownerName: string;
  initialCounts: RelationCount[];
}) {
  const [name, setName] = useState("");
  const [year, setYear] = useState("");
  const [month, setMonth] = useState("");
  const [day, setDay] = useState("");
  const [calendarType, setCalendarType] = useState<"solar" | "lunar">("solar");
  const [timeKnown, setTimeKnown] = useState(false);
  const [hour, setHour] = useState("");
  const [minute, setMinute] = useState("");
  const [agreePolicy, setAgreePolicy] = useState(false);
  const [agreeAge14, setAgreeAge14] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<JoinResult | null>(null);
  // [핵심] 그래프 데이터를 이 화면(클라이언트) state로 끌어올려, 폼 제출
  // 성공 시 서버 응답의 mapSummary로 바로 교체한다(새로고침 불필요).
  const [counts, setCounts] = useState<RelationCount[]>(initialCounts);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!name.trim()) {
      setError("이름을 입력해 주세요.");
      return;
    }
    const y = Number(year);
    const m = Number(month);
    const d = Number(day);
    if (!Number.isInteger(y) || y < 1900 || y > 2100 || !Number.isInteger(m) || m < 1 || m > 12 || !Number.isInteger(d) || d < 1 || d > 31) {
      setError("생년월일을 다시 확인해 주세요.");
      return;
    }
    const birthDate = `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

    let birthTime: string | null = null;
    if (timeKnown) {
      const hh = Number(hour);
      const mm = Number(minute) || 0;
      if (!Number.isInteger(hh) || hh < 0 || hh > 23) {
        setError("태어난 시간을 다시 확인해 주세요.");
        return;
      }
      birthTime = `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
    }

    if (!agreePolicy || !agreeAge14) {
      setError("개인정보처리방침 동의와 14세 이상 확인에 체크해 주세요.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch(`/api/public/guinji/g/${token}/join`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: name.trim(),
          birthDate,
          calendarType,
          birthTime,
          agreePolicy,
          agreeAge14,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        setError(json.error ?? "결과를 확인할 수 없어요.");
        return;
      }
      setResult(json.data);
      // [핵심] 서버가 돌려준 최신 집계로 그래프를 즉시 갱신 — 새로고침 없이
      // "지도에 이름이 올라간" 상태를 그 자리에서 보여준다.
      setCounts(countsToRelationCounts(json.data.mapSummary.counts));
    } catch {
      setError("네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <>
      <div className="rounded-2xl border border-amber-900/10 bg-white/70 p-6 shadow-sm">
        <p className="mb-1 text-center text-sm font-bold text-stone-700">
          나는 {ownerName}님에게 어떤 사람일까?
        </p>

        {result ? (
          <ResultCard ownerName={ownerName} result={result} />
        ) : (
          <form onSubmit={handleSubmit} className="mt-4">
            <p className="mb-3 text-center text-xs text-stone-400">
              이름과 생년월일을 입력하면, 바로 결과가 나오고 지도에 이름이 올라가요.
            </p>

            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="이름(닉네임도 괜찮아요)"
              maxLength={20}
              className="mb-3 w-full rounded-lg border border-amber-900/15 bg-white px-3 py-2 text-center text-sm text-stone-800 placeholder:text-stone-400 focus:border-amber-500 focus:outline-none"
            />

            {/* 음력/양력 토글 */}
            <div className="mb-3 flex justify-center gap-2">
              {(["solar", "lunar"] as const).map((v) => (
                <button
                  key={v}
                  type="button"
                  onClick={() => setCalendarType(v)}
                  className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                    calendarType === v
                      ? "bg-amber-700 text-white"
                      : "bg-white text-stone-500 border border-amber-900/15"
                  }`}
                >
                  {v === "solar" ? "양력" : "음력"}
                </button>
              ))}
            </div>

            <div className="mb-3 flex gap-2">
              <input
                value={year}
                onChange={(e) => setYear(e.target.value)}
                placeholder="년(예: 1998)"
                inputMode="numeric"
                maxLength={4}
                className="w-1/3 rounded-lg border border-amber-900/15 bg-white px-3 py-2 text-center text-sm text-stone-800 placeholder:text-stone-400 focus:border-amber-500 focus:outline-none"
              />
              <input
                value={month}
                onChange={(e) => setMonth(e.target.value)}
                placeholder="월"
                inputMode="numeric"
                maxLength={2}
                className="w-1/3 rounded-lg border border-amber-900/15 bg-white px-3 py-2 text-center text-sm text-stone-800 placeholder:text-stone-400 focus:border-amber-500 focus:outline-none"
              />
              <input
                value={day}
                onChange={(e) => setDay(e.target.value)}
                placeholder="일"
                inputMode="numeric"
                maxLength={2}
                className="w-1/3 rounded-lg border border-amber-900/15 bg-white px-3 py-2 text-center text-sm text-stone-800 placeholder:text-stone-400 focus:border-amber-500 focus:outline-none"
              />
            </div>

            {/* 시간 알음/모름 토글 */}
            <div className="mb-3 flex justify-center gap-2">
              <button
                type="button"
                onClick={() => setTimeKnown(false)}
                className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                  !timeKnown ? "bg-amber-700 text-white" : "bg-white text-stone-500 border border-amber-900/15"
                }`}
              >
                시간 모름
              </button>
              <button
                type="button"
                onClick={() => setTimeKnown(true)}
                className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                  timeKnown ? "bg-amber-700 text-white" : "bg-white text-stone-500 border border-amber-900/15"
                }`}
              >
                시간 입력
              </button>
            </div>

            {timeKnown && (
              <div className="mb-3 flex justify-center gap-2">
                <input
                  value={hour}
                  onChange={(e) => setHour(e.target.value)}
                  placeholder="시(0~23)"
                  inputMode="numeric"
                  maxLength={2}
                  className="w-1/2 max-w-[120px] rounded-lg border border-amber-900/15 bg-white px-3 py-2 text-center text-sm text-stone-800 placeholder:text-stone-400 focus:border-amber-500 focus:outline-none"
                />
                <input
                  value={minute}
                  onChange={(e) => setMinute(e.target.value)}
                  placeholder="분"
                  inputMode="numeric"
                  maxLength={2}
                  className="w-1/2 max-w-[120px] rounded-lg border border-amber-900/15 bg-white px-3 py-2 text-center text-sm text-stone-800 placeholder:text-stone-400 focus:border-amber-500 focus:outline-none"
                />
              </div>
            )}

            {/* 동의 체크박스 — 개인정보처리방침 / 14세 이상 확인 (필수) */}
            <div className="mb-3 space-y-1.5 text-left">
              <label className="flex items-center gap-2 text-xs text-stone-500">
                <input
                  type="checkbox"
                  checked={agreePolicy}
                  onChange={(e) => setAgreePolicy(e.target.checked)}
                  className="h-4 w-4 accent-amber-700"
                />
                (필수) 개인정보처리방침에 동의합니다.
              </label>
              <label className="flex items-center gap-2 text-xs text-stone-500">
                <input
                  type="checkbox"
                  checked={agreeAge14}
                  onChange={(e) => setAgreeAge14(e.target.checked)}
                  className="h-4 w-4 accent-amber-700"
                />
                (필수) 만 14세 이상입니다.
              </label>
            </div>

            {error && <p className="mb-3 text-center text-xs text-rose-500">{error}</p>}
            <button
              type="submit"
              disabled={submitting}
              className="mb-2 block w-full rounded-xl bg-amber-700 px-4 py-3 text-sm font-bold text-white transition hover:bg-amber-600 disabled:opacity-60"
            >
              {submitting ? "확인하는 중" : `${ownerName}님과 나의 관계 보기`}
            </button>
            <p className="text-center text-xs text-stone-400">
              결과 확인과 동시에 지도에 이름이 올라가요. 다시 입력할 필요 없어요.
            </p>
          </form>
        )}
      </div>

      {/* 관계 지도 네트워크 그래프 — 제출 성공 시 counts state가 갱신되어
          이 컴포넌트가 새로고침 없이 즉시 다시 그려진다. */}
      <RelationNetworkGraph counts={counts} ownerName={ownerName} />
    </>
  );
}

function ResultCard({ ownerName, result }: { ownerName: string; result: JoinResult }) {
  const meta = GUINJI_RELATION_TYPES[result.relationType];
  return (
    <div className="mt-4 rounded-xl border border-amber-900/10 bg-amber-900/5 p-6 text-center">
      <p className="mb-1 text-xs text-stone-400">
        {result.dayMasterKr ? `나의 일간 · ${result.dayMasterKr}(${result.dayMasterElement})` : "관계 결과"}
      </p>
      <p className="mb-3 text-3xl font-bold text-amber-800">
        {meta?.hanja} {meta?.label}
      </p>
      <p className="mb-4 text-sm text-stone-600">
        {result.ownerName ?? ownerName}님과 당신은{" "}
        <span className="font-medium text-amber-700">{meta?.subtitle}</span>의 결이에요.
        <br />
        케미 점수 {result.chemistryScore}점
      </p>
      {meta?.description && (
        <p className="mb-3 text-xs leading-relaxed text-stone-500">{meta.description}</p>
      )}
      {result.timeUnknown && (
        <p className="mb-3 text-xs leading-relaxed text-stone-400">
          태어난 시간을 입력하지 않아 정오(12:00) 기준으로 계산했어요.
        </p>
      )}
      <p className="rounded-lg bg-emerald-700/10 px-3 py-2 text-xs font-medium text-emerald-800">
        지도에 이름이 올라갔어요 🎉 아래 관계 지도에서 확인해 보세요.
      </p>
    </div>
  );
}
