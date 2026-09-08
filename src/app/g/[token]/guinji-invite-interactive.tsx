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
import { GUINJI_RELATION_TYPE_ORDER } from "@/lib/guinji-relation-judger";
import { SINTONG_WEB_URLS } from "./sintong-web-urls";

// [2026-09, 웹 전환 원칙 최종 확정 — 사용자 명시 지시] 신통방통은 원래
// 앱이지만, 지금은 `https://sintong.kr/app/` 경로에 Flutter Web 빌드가
// 이미 배포되어 있어 "앱 설치 없이도" 브라우저에서 즉시 신통방통 메인을
// 그대로 열 수 있다. 이 페이지는 웹이므로, 커스텀 URI 스킴
// (`fortunefusion://`)으로 앱을 열려 시도했다가 실패하면 플레이스토어로
// 유도하던 기존 "딥링크+폴백" 패턴을 전부 제거하고, "내 지도 만들기" 버튼을
// 누르면 곧바로 웹 신통방통 메인의 귀인지도 화면(SINTONG_WEB_URLS.guinji)
// 으로 이동한다 — 앱 설치를 요구하지 않는다.
function goToSintongWeb(url: string) {
  window.location.href = url;
}

type JoinResult = {
  ownerName: string;
  relationType: string;
  chemistryScore: number;
  timeUnknown: boolean;
  dayMasterKr?: string;
  dayMasterElement?: string;
  mapSummary: { total: number; counts: Record<string, number> };
};

// [PRD p.38 LABEL_HUE tone → HEX, `guinji_design_handoff/DEV_SPEC.md` Dart
// RelationLabel enum과 동일한 색상값] page.tsx의 RELATION_COLOR와 가지를 맞춰야 하묀로
// 동일한 값을 사용한다.
const RELATION_COLOR: Record<string, string> = {
  CHEON_GWII: "#F5D97A",
  NA_SALRIDA: "#E8C8F5",
  JORYEOK: "#A8D5E3",
  GACHI_GA: "#C8F5D5",
  NA_SALJINDA: "#F5C8D5",
  CHANG_GYIM: "#E8C890",
  GAMJEONG: "#D5C8F5",
  DEUNGDEUNG: "#A5B5E8",
  KKEURIDA: "#F5A8BD",
  GACHI_BICH: "#F5D97A",
  JAGEUKJE: "#F5B880",
  GINGJANG: "#B5A8E8",
};

function countsToRelationCounts(counts: Record<string, number>): RelationCount[] {
  return GUINJI_RELATION_TYPE_ORDER.map((key) => ({
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
      <div className="rounded-3xl border border-[#E8DDD0] bg-white/85 p-6 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
        <p className="mb-1 flex items-center justify-center gap-1.5 text-center text-[13px] text-[#6E5A54]">
          <span className="text-[#C99B7F]">✦</span>
          나는 {ownerName}님에게 어떤 사람일까?
          <span className="text-[#C99B7F]">✦</span>
        </p>

        {result ? (
          <ResultCard ownerName={ownerName} result={result} />
        ) : (
          <form onSubmit={handleSubmit} className="mt-4">
            <p className="mb-3 text-center text-xs text-[#A08C82]">
              이름과 생년월일을 입력하면, 바로 결과가 나오고 지도에 이름이 올라가요.
            </p>

            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="이름(닉네임도 괜찮아요)"
              maxLength={20}
              className="mb-3 w-full rounded-2xl border border-[#E8DDD0] bg-white px-3 py-2.5 text-center text-sm text-[#2A2438] placeholder:text-[#A08C82] focus:border-[#C99B7F] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
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
                      ? "bg-[#A6795E] text-white"
                      : "bg-white text-[#6E5A54] border border-[#E8DDD0]"
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
                className="w-1/3 rounded-2xl border border-[#E8DDD0] bg-white px-3 py-2.5 text-center text-sm text-[#2A2438] placeholder:text-[#A08C82] focus:border-[#C99B7F] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
              />
              <input
                value={month}
                onChange={(e) => setMonth(e.target.value)}
                placeholder="월"
                inputMode="numeric"
                maxLength={2}
                className="w-1/3 rounded-2xl border border-[#E8DDD0] bg-white px-3 py-2.5 text-center text-sm text-[#2A2438] placeholder:text-[#A08C82] focus:border-[#C99B7F] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
              />
              <input
                value={day}
                onChange={(e) => setDay(e.target.value)}
                placeholder="일"
                inputMode="numeric"
                maxLength={2}
                className="w-1/3 rounded-2xl border border-[#E8DDD0] bg-white px-3 py-2.5 text-center text-sm text-[#2A2438] placeholder:text-[#A08C82] focus:border-[#C99B7F] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
              />
            </div>

            {/* 시간 알음/모름 토글 */}
            <div className="mb-3 flex justify-center gap-2">
              <button
                type="button"
                onClick={() => setTimeKnown(false)}
                className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                  !timeKnown ? "bg-[#A6795E] text-white" : "bg-white text-[#6E5A54] border border-[#E8DDD0]"
                }`}
              >
                시간 모름
              </button>
              <button
                type="button"
                onClick={() => setTimeKnown(true)}
                className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                  timeKnown ? "bg-[#A6795E] text-white" : "bg-white text-[#6E5A54] border border-[#E8DDD0]"
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
                  className="w-1/2 max-w-[120px] rounded-2xl border border-[#E8DDD0] bg-white px-3 py-2.5 text-center text-sm text-[#2A2438] placeholder:text-[#A08C82] focus:border-[#C99B7F] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
                />
                <input
                  value={minute}
                  onChange={(e) => setMinute(e.target.value)}
                  placeholder="분"
                  inputMode="numeric"
                  maxLength={2}
                  className="w-1/2 max-w-[120px] rounded-2xl border border-[#E8DDD0] bg-white px-3 py-2.5 text-center text-sm text-[#2A2438] placeholder:text-[#A08C82] focus:border-[#C99B7F] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
                />
              </div>
            )}

            {/* 동의 체크박스 — 개인정보처리방침 / 14세 이상 확인 (필수) */}
            <div className="mb-3 space-y-1.5 text-left">
              <label className="flex items-center gap-2 text-xs text-[#6E5A54]">
                <input
                  type="checkbox"
                  checked={agreePolicy}
                  onChange={(e) => setAgreePolicy(e.target.checked)}
                  className="h-4 w-4 accent-[#A6795E]"
                />
                (필수) 개인정보처리방침에 동의합니다.
              </label>
              <label className="flex items-center gap-2 text-xs text-[#6E5A54]">
                <input
                  type="checkbox"
                  checked={agreeAge14}
                  onChange={(e) => setAgreeAge14(e.target.checked)}
                  className="h-4 w-4 accent-[#A6795E]"
                />
                (필수) 만 14세 이상입니다.
              </label>
            </div>

            {error && <p className="mb-3 text-center text-xs text-[#C97E5B]">{error}</p>}
            <button
              type="submit"
              disabled={submitting}
              className="mb-2 block w-full rounded-2xl bg-[#A6795E] px-4 py-3.5 text-sm font-bold text-white shadow-[0_8px_32px_-12px_rgba(166,121,94,0.22)] transition-transform active:scale-[0.98] hover:bg-[#B58567] disabled:opacity-60"
            >
              {submitting ? "확인하는 중" : `${ownerName}님과 나의 관계 보기`}
            </button>
            <p className="text-center text-xs text-[#A08C82]">
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

function ResultCard({
  ownerName,
  result,
}: {
  ownerName: string;
  result: JoinResult;
}) {
  const meta = GUINJI_RELATION_TYPES[result.relationType];

  // [핵심] 자동 리다이렉트 없음. 결과·관계 지도는 이 페이지(웹) 안에서
  // 이미 완결된다(바로 아래 RelationNetworkGraph에 자기 이름이 올라간
  // 지도가 실시간으로 보인다) — 게스트는 회원가입도, 앱 설치도 강요받지
  // 않는다. 아래 CTA는 "본인이 스스로 원할 때"만 누르는 선택적 다음
  // 단계인데, 이 서비스는 이미 웹으로도 완전히 동작하므로 눌렀을 때
  // 앱 설치가 아니라 웹 신통방통 메인 귀인지도로 바로 이동한다.
  return (
    <div className="mt-4 rounded-2xl border border-[#E8DDD0] bg-[#F5EBDC] p-6 text-center">
      <p className="mb-1 text-xs text-[#A08C82]">
        {result.dayMasterKr ? `나의 일간 · ${result.dayMasterKr}(${result.dayMasterElement})` : "관계 결과"}
      </p>
      <p style={{ fontFamily: "'Noto Serif KR', serif" }} className="mb-3 text-3xl font-bold text-[#A6795E]">
        {meta?.hanja} {meta?.label}
      </p>
      <p className="mb-4 text-sm text-[#6E5A54]">
        {result.ownerName ?? ownerName}님과 당신은{" "}
        <span className="font-medium text-[#A6795E]">{meta?.subtitle}</span>의 결이에요.
        <br />
        케미 점수 {result.chemistryScore}점
      </p>
      {meta?.description && (
        <p className="mb-3 text-xs leading-relaxed text-[#6E5A54]">{meta.description}</p>
      )}
      {result.timeUnknown && (
        <p className="mb-3 text-xs leading-relaxed text-[#A08C82]">
          태어난 시간을 입력하지 않아 정오(12:00) 기준으로 계산했어요.
        </p>
      )}
      <p className="mb-4 rounded-xl bg-[#7BA05B]/10 px-3 py-2 text-xs font-medium text-[#5A7A43]">
        지도에 이름이 올라갔어요. 아래 관계 지도에서 바로 확인해 보세요.
      </p>

      {/* [핵심] 여기까지가 게스트에게 강요되는 흐름의 끝이다 — 결과 확인,
          지도 반영 모두 이 웹 페이지 안에서 완결됐다(회원가입 없음).
          아래는 "본인이 스스로 원할 때"만 누르는 선택적 다음 단계다.
          (design_handoff_guinji_web README Y·Guest Result 스펙:
          서브 카피 "당신의 지도에는 누가 있을까요" + Primary CTA
          "✧ 내 지도 만들기 · 무료") */}
      <p className="mb-2 text-xs text-[#A08C82]">당신의 지도에는 누가 있을까요</p>
      <button
        type="button"
        onClick={() => goToSintongWeb(SINTONG_WEB_URLS.guinji)}
        className="block w-full rounded-2xl bg-[#A6795E] px-4 py-3.5 text-sm font-bold text-white shadow-[0_8px_32px_-12px_rgba(166,121,94,0.22)] transition-transform active:scale-[0.98] hover:bg-[#B58567]"
      >
        ✧ 내 지도 만들기 · 무료
      </button>
      <p className="mt-2 text-center text-[11px] text-[#A08C82]">
        설치 없이 바로 열려요 · 신통방통 웹
      </p>
    </div>
  );
}
