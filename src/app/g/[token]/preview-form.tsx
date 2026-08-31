"use client";

// [Phase A-2 — 카톡 공유 바이럴 개선] 로그인 없이 이름·생년월일을 입력해
// 즉시 관계 결과를 보는 웹 미리보기 폼. 서버 컴포넌트(`page.tsx`)에서
// 초대 유효성(state==='ok')이 확인된 경우에만 렌더링된다.
//
// [정확도 개선 — 2026-09] 사용자가 "생년월일만 넣어도 정확한 만세력·관계가
// 나와야 한다"고 요구해, 서버가 이제 실제 만세력 엔진(lunar-javascript,
// Flutter SajuEngine과 동일 알고리즘)으로 계산한다(`saju-manseryeok-engine.ts`
// 참고). 이 폼은 그 정확도를 살리기 위해 음력/양력 구분과 태어난 시간
// (선택) 입력을 추가했다 — 시간을 모르면 "시간 모름"을 선택해 정오 가정
// 근사로 계산된다(화면에 안내 문구 표시).
//
// [정직성 원칙] 여기서 입력한 정보는 어디에도 저장되지 않는다(서버 라우트
// 주석 참고).
import { useState } from "react";
import { GUINJI_RELATION_TYPES } from "./relation-meta";

type PreviewResult = {
  ownerName: string;
  relationType: string;
  chemistryScore: number;
  timeUnknown: boolean;
  dayMasterKr?: string;
  dayMasterElement?: string;
};

export function GuinjiPreviewForm({
  token,
  ownerName,
  deepLink,
}: {
  token: string;
  ownerName: string;
  deepLink: string;
}) {
  const [year, setYear] = useState("");
  const [month, setMonth] = useState("");
  const [day, setDay] = useState("");
  const [calendarType, setCalendarType] = useState<"solar" | "lunar">("solar");
  const [timeKnown, setTimeKnown] = useState(false);
  const [hour, setHour] = useState("");
  const [minute, setMinute] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<PreviewResult | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

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

    setSubmitting(true);
    try {
      const res = await fetch(`/api/public/guinji/g/${token}/preview`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ birthDate, calendarType, birthTime }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        setError(json.error ?? "결과를 확인할 수 없어요.");
        return;
      }
      setResult(json.data);
    } catch {
      setError("네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.");
    } finally {
      setSubmitting(false);
    }
  }

  if (result) {
    const meta = GUINJI_RELATION_TYPES[result.relationType];
    return (
      <div className="mt-4 rounded-xl border border-amber-900/10 bg-amber-900/5 p-6 text-center">
        <p className="mb-1 text-xs text-stone-400">
          {result.dayMasterKr ? `나의 일간 · ${result.dayMasterKr}(${result.dayMasterElement})` : "관계 미리보기 결과"}
        </p>
        <p className="mb-3 text-3xl font-bold text-amber-800">
          {meta?.hanja} {meta?.label}
        </p>
        <p className="mb-4 text-sm text-stone-600">
          {result.ownerName}님과 당신은{" "}
          <span className="font-medium text-amber-700">{meta?.subtitle}</span>의 결이에요.
          <br />
          케미 점수 {result.chemistryScore}점
        </p>
        {meta?.description && (
          <p className="mb-5 text-xs leading-relaxed text-stone-500">{meta.description}</p>
        )}
        {result.timeUnknown && (
          <p className="mb-4 text-xs leading-relaxed text-stone-400">
            태어난 시간을 입력하지 않아 정오(12:00) 기준으로 계산했어요.
            <br />
            정확한 시간을 알면 결과가 달라질 수 있어요.
          </p>
        )}
        <a
          href={deepLink}
          className="block w-full rounded-xl bg-amber-700 px-4 py-3 text-sm font-bold text-white transition hover:bg-amber-600"
        >
          앱에서 정식으로 확인하기
        </a>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="mt-4">
      <p className="mb-3 text-center text-xs text-stone-400">생년월일만 입력하면 바로 결과를 볼 수 있어요.</p>

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

      {/* 시간 일치/시간 불일치(모름) 토글 */}
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

      {error && <p className="mb-3 text-center text-xs text-rose-500">{error}</p>}
      <button
        type="submit"
        disabled={submitting}
        className="mb-2 block w-full rounded-xl bg-amber-700 px-4 py-3 text-sm font-bold text-white transition hover:bg-amber-600 disabled:opacity-60"
      >
        {submitting ? "확인하는 중" : `${ownerName}님과 나의 관계 보기`}
      </button>
      <p className="text-center text-xs text-stone-400">
        입력한 정보는 저장되지 않아요. 실제 지도에 남기려면 앱에서 로그인 후 참여해 주세요.
      </p>
    </form>
  );
}
