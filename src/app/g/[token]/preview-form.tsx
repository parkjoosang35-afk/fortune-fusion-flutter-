"use client";

// [Phase A-2 — 카톡 공유 바이럴 개선] 로그인 없이 이름·생년월일을 입력해
// 즉시 관계 결과를 보는 웹 미리보기 폼. 서버 컴포넌트(`page.tsx`)에서
// 초대 유효성(state==='ok')이 확인된 경우에만 렌더링된다.
//
// [정직성 원칙] 이 결과는 "간이 미리보기"이며 실제 앱 정식 참여 결과와
// 다를 수 있음을 화면에 항상 표시한다(느낌표 금지 원칙 — 문구는 담담하게).
// 여기서 입력한 정보는 어디에도 저장되지 않는다(서버 라우트 주석 참고).
import { useState } from "react";
import { GUINJI_RELATION_TYPES } from "./relation-meta";

type PreviewResult = {
  ownerName: string;
  relationType: string;
  chemistryScore: number;
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

    setSubmitting(true);
    try {
      const res = await fetch(`/api/public/guinji/g/${token}/preview`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ birthDate }),
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
      <div className="mt-6 rounded-xl border border-white/10 bg-white/5 p-6 text-center">
        <p className="mb-1 text-xs text-slate-400">간이 미리보기 결과</p>
        <p className="mb-3 text-3xl font-bold text-indigo-200">
          {meta?.hanja} {meta?.label}
        </p>
        <p className="mb-4 text-sm text-slate-300">
          {result.ownerName}님과 당신은{" "}
          <span className="text-indigo-300">{meta?.subtitle}</span>의 결이에요.
          <br />
          케미 점수 {result.chemistryScore}점
        </p>
        {meta?.description && (
          <p className="mb-5 text-xs leading-relaxed text-slate-400">{meta.description}</p>
        )}
        <p className="mb-4 text-xs leading-relaxed text-slate-500">
          이 결과는 태어난 시간·정통 만세력을 반영하지 않은 간이 미리보기예요.
          <br />
          앱에서 정식으로 참여하면 더 정확한 결과를 볼 수 있어요.
        </p>
        <a
          href={deepLink}
          className="block w-full rounded-xl bg-indigo-400 px-4 py-3 text-sm font-bold text-slate-900 transition hover:bg-indigo-300"
        >
          앱에서 정식으로 확인하기
        </a>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="mt-6">
      <p className="mb-3 text-xs text-slate-400">생년월일만 입력하면 바로 결과를 볼 수 있어요.</p>
      <div className="mb-3 flex gap-2">
        <input
          value={year}
          onChange={(e) => setYear(e.target.value)}
          placeholder="년(예: 1998)"
          inputMode="numeric"
          maxLength={4}
          className="w-1/3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-center text-sm text-white placeholder:text-slate-500 focus:border-indigo-400 focus:outline-none"
        />
        <input
          value={month}
          onChange={(e) => setMonth(e.target.value)}
          placeholder="월"
          inputMode="numeric"
          maxLength={2}
          className="w-1/3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-center text-sm text-white placeholder:text-slate-500 focus:border-indigo-400 focus:outline-none"
        />
        <input
          value={day}
          onChange={(e) => setDay(e.target.value)}
          placeholder="일"
          inputMode="numeric"
          maxLength={2}
          className="w-1/3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-center text-sm text-white placeholder:text-slate-500 focus:border-indigo-400 focus:outline-none"
        />
      </div>
      {error && <p className="mb-3 text-xs text-rose-400">{error}</p>}
      <button
        type="submit"
        disabled={submitting}
        className="mb-2 block w-full rounded-xl bg-indigo-400 px-4 py-3 text-sm font-bold text-slate-900 transition hover:bg-indigo-300 disabled:opacity-60"
      >
        {submitting ? "확인하는 중" : `${ownerName}님과 나의 관계 보기`}
      </button>
      <p className="text-center text-xs text-slate-500">
        입력한 정보는 저장되지 않아요. 실제 지도에 남기려면 앱에서 로그인 후 참여해 주세요.
      </p>
    </form>
  );
}
