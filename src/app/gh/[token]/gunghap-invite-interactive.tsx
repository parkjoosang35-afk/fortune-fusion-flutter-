"use client";

// [궁합지도(Gunghap Map) `/gh/[token]` 랜딩 신설 — Phase 1]
// `/g/[token]/guinji-invite-interactive.tsx`(귀인지도)의 "웹에서 완결"
// 원칙을 그대로 따른다: 카톡을 눌러 들어온 사람이 이름+생년월일(+시간,
// 음력/윤달, 성별)을 한 번 입력하면, 그 자리에서 궁합 결과(관계유형·
// 등급·8개 분야 무료 등급)가 나오고, 강제 리다이렉트나 회원가입 없이
// 웹 안에서 완결된다. 앱 전환은 결과 카드 하단 "나도 궁합지도 만들기"
// CTA를 사용자가 직접 눌렀을 때만 일어난다.
//
// [백엔드 — Phase 1은 API 신규 개발 없음] 이미 완전히 구현·검증된 기존
// 엔드포인트 `POST /api/public/gunghap/g/{token}/join`을 그대로 호출한다
// (요청 바디 형식은 `join/route.ts`의 `RequestBody` 그대로: name,
// birthDate, calendarType, isLeapMonth, birthTime, gender, agreePolicy,
// agreeAge14). 이 파일은 그 응답(JoinResult 상당)을 렌더링만 할 뿐, 서버
// 로직은 전혀 건드리지 않는다.
import { useState } from "react";
import { SINTONG_WEB_URLS } from "../../g/[token]/sintong-web-urls";

// [8개 분야 한글 라벨 — `gunghap_data.dart`의 `ghMajors.name` /
// `gunghap-narrative.ts`의 `categoryLabel()`과 동일한 값] 서버 전용 모듈
// (`gunghap-category-rules.ts` 등)을 클라이언트 번들에 끌어들이지 않기
// 위해(그 파일들은 서버 전용 계산 로직을 포함) 표시용 값만 이 클라이언트
// 컴포넌트에 복제한다 — "page.tsx의 RELATION_COLOR가 서버 상수를 복제해
// 쓰는" 기존 패턴과 동일 원칙.
const CATEGORY_LABEL: Record<string, string> = {
  love: "연애 궁합",
  marriage: "결혼 궁합",
  intimacy: "속궁합",
  persona: "성격 궁합",
  wealth: "재물 궁합",
  business: "사업 궁합",
  friend: "친구 궁합",
  family: "가족 궁합",
};

interface CategoryFreeView {
  categoryId: string;
  grade: string;
  gradeCode: string;
}

interface JoinResult {
  resultId: string;
  ownerName: string;
  guestName: string;
  relationType: string;
  relationTypeLabel: string;
  relationTypeDesc: string;
  chemistryScore: number;
  grade: string;
  gradeCode: string;
  timeUnknown: boolean;
  dayMasterKr?: string;
  dayMasterElement?: string;
  categories: CategoryFreeView[];
  unlockCost: number;
  joined: boolean;
}

export function GunghapInviteInteractive({
  token,
  ownerName,
}: {
  token: string;
  ownerName: string;
}) {
  const [name, setName] = useState("");
  const [year, setYear] = useState("");
  const [month, setMonth] = useState("");
  const [day, setDay] = useState("");
  const [calendarType, setCalendarType] = useState<"solar" | "lunar">("solar");
  const [isLeapMonth, setIsLeapMonth] = useState(false);
  const [timeKnown, setTimeKnown] = useState(false);
  const [hour, setHour] = useState("");
  const [minute, setMinute] = useState("");
  const [gender, setGender] = useState<"female" | "male" | null>(null);
  const [agreePolicy, setAgreePolicy] = useState(false);
  const [agreeAge14, setAgreeAge14] = useState(false);
  const [policyModal, setPolicyModal] = useState<{ title: string; path: string } | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<JoinResult | null>(null);

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

    if (!gender) {
      setError("성별을 선택해 주세요.");
      return;
    }

    if (!agreePolicy || !agreeAge14) {
      setError("개인정보처리방침 동의와 14세 이상 확인에 체크해 주세요.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch(`/api/public/gunghap/g/${token}/join`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: name.trim(),
          birthDate,
          calendarType,
          isLeapMonth: calendarType === "lunar" ? isLeapMonth : false,
          birthTime,
          gender,
          agreePolicy,
          agreeAge14,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        setError(json.error ?? "결과를 확인할 수 없어요.");
        return;
      }
      setResult(json.data as JoinResult);
    } catch {
      setError("네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <>
      <div className="rounded-3xl border border-[#3A2A52] bg-[#1F1133] p-6 shadow-[0_4px_20px_-8px_rgba(245,207,106,0.15)]">
        <p className="mb-1 flex items-center justify-center gap-1.5 text-center text-[13px] text-[#C9BBA8]">
          <span className="text-[#F5CF6A]">✦</span>
          나와 {ownerName}님의 궁합은 어떨까?
          <span className="text-[#F5CF6A]">✦</span>
        </p>

        {result ? (
          <ResultCard ownerName={ownerName} result={result} />
        ) : (
          <form onSubmit={handleSubmit} className="mt-4">
            <p className="mb-3 text-center text-xs text-[#8C7F6E]">
              이름과 생년월일을 입력하면, 바로 두 사람의 궁합 결과가 나와요.
            </p>

            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="이름(닉네임도 괜찮아요)"
              maxLength={20}
              className="mb-3 w-full rounded-2xl border border-[#3A2A52] bg-[#24163B] px-3 py-2.5 text-center text-sm text-[#F8F2E6] placeholder:text-[#8C7F6E] focus:border-[#F5CF6A] focus:outline-none focus:ring-2 focus:ring-[#F5CF6A]/25"
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
                      ? "bg-[#F5CF6A] text-[#1A0D2E]"
                      : "bg-[#24163B] text-[#C9BBA8] border border-[#3A2A52]"
                  }`}
                >
                  {v === "solar" ? "양력" : "음력"}
                </button>
              ))}
            </div>

            {/* [음력 윤달] 양력이면 노출하지 않는다(join/route.ts가 양력일 때
                isLeapMonth를 무시하는 것과 동일 원칙). */}
            {calendarType === "lunar" && (
              <div className="mb-3 flex justify-center">
                <label className="flex items-center gap-2 text-xs text-[#C9BBA8]">
                  <input
                    type="checkbox"
                    checked={isLeapMonth}
                    onChange={(e) => setIsLeapMonth(e.target.checked)}
                    className="h-4 w-4 accent-[#F5CF6A]"
                  />
                  윤달이에요
                </label>
              </div>
            )}

            <div className="mb-3 flex gap-2">
              <input
                value={year}
                onChange={(e) => setYear(e.target.value)}
                placeholder="년(예: 1998)"
                inputMode="numeric"
                maxLength={4}
                className="w-1/3 rounded-2xl border border-[#3A2A52] bg-[#24163B] px-3 py-2.5 text-center text-sm text-[#F8F2E6] placeholder:text-[#8C7F6E] focus:border-[#F5CF6A] focus:outline-none focus:ring-2 focus:ring-[#F5CF6A]/25"
              />
              <input
                value={month}
                onChange={(e) => setMonth(e.target.value)}
                placeholder="월"
                inputMode="numeric"
                maxLength={2}
                className="w-1/3 rounded-2xl border border-[#3A2A52] bg-[#24163B] px-3 py-2.5 text-center text-sm text-[#F8F2E6] placeholder:text-[#8C7F6E] focus:border-[#F5CF6A] focus:outline-none focus:ring-2 focus:ring-[#F5CF6A]/25"
              />
              <input
                value={day}
                onChange={(e) => setDay(e.target.value)}
                placeholder="일"
                inputMode="numeric"
                maxLength={2}
                className="w-1/3 rounded-2xl border border-[#3A2A52] bg-[#24163B] px-3 py-2.5 text-center text-sm text-[#F8F2E6] placeholder:text-[#8C7F6E] focus:border-[#F5CF6A] focus:outline-none focus:ring-2 focus:ring-[#F5CF6A]/25"
              />
            </div>

            {/* 시간 알음/모름 토글 */}
            <div className="mb-3 flex justify-center gap-2">
              <button
                type="button"
                onClick={() => setTimeKnown(false)}
                className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                  !timeKnown ? "bg-[#F5CF6A] text-[#1A0D2E]" : "bg-[#24163B] text-[#C9BBA8] border border-[#3A2A52]"
                }`}
              >
                시간 모름
              </button>
              <button
                type="button"
                onClick={() => setTimeKnown(true)}
                className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                  timeKnown ? "bg-[#F5CF6A] text-[#1A0D2E]" : "bg-[#24163B] text-[#C9BBA8] border border-[#3A2A52]"
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
                  className="w-1/2 max-w-[120px] rounded-2xl border border-[#3A2A52] bg-[#24163B] px-3 py-2.5 text-center text-sm text-[#F8F2E6] placeholder:text-[#8C7F6E] focus:border-[#F5CF6A] focus:outline-none focus:ring-2 focus:ring-[#F5CF6A]/25"
                />
                <input
                  value={minute}
                  onChange={(e) => setMinute(e.target.value)}
                  placeholder="분"
                  inputMode="numeric"
                  maxLength={2}
                  className="w-1/2 max-w-[120px] rounded-2xl border border-[#3A2A52] bg-[#24163B] px-3 py-2.5 text-center text-sm text-[#F8F2E6] placeholder:text-[#8C7F6E] focus:border-[#F5CF6A] focus:outline-none focus:ring-2 focus:ring-[#F5CF6A]/25"
                />
              </div>
            )}

            <p className="mb-2 text-center text-xs text-[#8C7F6E]">성별</p>
            <div className="mb-4 flex gap-2">
              {(["female", "male"] as const).map((g) => (
                <button
                  key={g}
                  type="button"
                  onClick={() => setGender(g)}
                  className={`flex-1 rounded-2xl px-4 py-2.5 text-sm font-medium transition ${
                    gender === g
                      ? "bg-[#F5CF6A] text-[#1A0D2E]"
                      : "bg-[#24163B] text-[#C9BBA8] border border-[#3A2A52]"
                  }`}
                >
                  {g === "female" ? "여성" : "남성"}
                </button>
              ))}
            </div>

            {/* 동의 체크박스 — 개인정보처리방침 / 14세 이상 확인 (필수) */}
            <div className="mb-3 space-y-1.5 text-left">
              <label className="flex items-center justify-between gap-2 text-xs text-[#C9BBA8]">
                <span className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={agreePolicy}
                    onChange={(e) => setAgreePolicy(e.target.checked)}
                    className="h-4 w-4 accent-[#F5CF6A]"
                  />
                  (필수) 개인정보처리방침에 동의합니다.
                </span>
                <button
                  type="button"
                  onClick={() => setPolicyModal({ title: "개인정보처리방침", path: "/privacy-policy" })}
                  className="shrink-0 text-[#F5CF6A] underline underline-offset-2"
                >
                  보기
                </button>
              </label>
              <label className="flex items-center gap-2 text-xs text-[#C9BBA8]">
                <input
                  type="checkbox"
                  checked={agreeAge14}
                  onChange={(e) => setAgreeAge14(e.target.checked)}
                  className="h-4 w-4 accent-[#F5CF6A]"
                />
                (필수) 만 14세 이상입니다.
              </label>
            </div>

            <div className="mb-3 text-center">
              <button
                type="button"
                onClick={() => setPolicyModal({ title: "이용약관(회원약관)", path: "/terms" })}
                className="text-xs text-[#8C7F6E] underline underline-offset-2"
              >
                회원약관 보기
              </button>
            </div>

            {error && <p className="mb-3 text-center text-xs text-[#EF7A55]">{error}</p>}
            <button
              type="submit"
              disabled={submitting}
              className="mb-2 block w-full rounded-2xl bg-[#F5CF6A] px-4 py-3.5 text-sm font-bold text-[#1A0D2E] shadow-[0_8px_32px_-12px_rgba(245,207,106,0.22)] transition-transform active:scale-[0.98] hover:bg-[#FADFA0] disabled:opacity-60"
            >
              {submitting ? "확인하는 중" : `${ownerName}님과 나의 궁합 보기`}
            </button>
            <p className="text-center text-xs text-[#8C7F6E]">
              결과 확인은 무료예요. 다시 입력할 필요 없어요.
            </p>
          </form>
        )}
      </div>

      {policyModal && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/60"
          onClick={() => setPolicyModal(null)}
        >
          <div
            className="flex h-[88vh] w-full max-w-md flex-col overflow-hidden rounded-t-3xl bg-[#1A0D2E]"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-[#3A2A52] px-4 py-3">
              <p className="text-sm font-bold text-[#F8F2E6]">{policyModal.title}</p>
              <button
                type="button"
                onClick={() => setPolicyModal(null)}
                aria-label="닫기"
                className="text-lg text-[#C9BBA8]"
              >
                ✕
              </button>
            </div>
            <iframe
              src={policyModal.path}
              title={policyModal.title}
              className="flex-1 bg-white"
            />
            <div className="p-4">
              <button
                type="button"
                onClick={() => setPolicyModal(null)}
                className="block w-full rounded-2xl bg-[#F5CF6A] px-4 py-3 text-sm font-bold text-[#1A0D2E]"
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}
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
  // [핵심] 자동 리다이렉트 없음 — 무료 결과(관계유형/등급/8개 분야 등급)는
  // 이 웹 페이지 안에서 이미 완결된다. 상세 보고서(4요소 서술)는 초대를
  // 보낸 사람(owner)이 앱에서 복주머니로 잠금해제해야 볼 수 있다는 안내만
  // 보여준다(join/route.ts 응답이 애초에 무료 뷰만 내려줌 — 이 화면이
  // 추가로 숨기는 게 아니라 서버가 안 주는 것).
  return (
    <div className="mt-4 rounded-2xl border border-[#3A2A52] bg-[#0A0716] p-6 text-center">
      <p className="mb-1 text-xs text-[#8C7F6E]">
        {result.dayMasterKr ? `나의 일간 · ${result.dayMasterKr}(${result.dayMasterElement})` : "궁합 결과"}
      </p>
      <p style={{ fontFamily: "'Noto Serif KR', serif" }} className="mb-2 text-2xl font-bold text-[#F5CF6A]">
        {result.relationTypeLabel}
      </p>
      <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-[#F5CF6A] bg-[#24163B] px-3 py-1 text-[12px] text-[#F5CF6A]">
        {result.grade} · {result.chemistryScore}점
      </div>
      <p className="mb-4 text-sm leading-relaxed text-[#C9BBA8]">{result.relationTypeDesc}</p>
      {result.timeUnknown && (
        <p className="mb-3 text-xs leading-relaxed text-[#8C7F6E]">
          태어난 시간을 입력하지 않아 정오(12:00) 기준으로 계산했어요.
        </p>
      )}

      <div className="mb-4 text-left">
        <p className="mb-2 text-center text-[11px] font-semibold uppercase tracking-widest text-[#F5CF6A]">
          8개 분야 궁합 등급
        </p>
        <div className="grid grid-cols-2 gap-2">
          {result.categories.map((c) => (
            <div
              key={c.categoryId}
              className="flex items-center justify-between rounded-xl border border-[#3A2A52] bg-[#1F1133] px-3 py-2"
            >
              <span className="text-xs text-[#C9BBA8]">
                {CATEGORY_LABEL[c.categoryId] ?? c.categoryId}
              </span>
              <span className="text-xs font-bold text-[#F5CF6A]">{c.grade}</span>
            </div>
          ))}
        </div>
      </div>

      <p className="mb-4 rounded-xl bg-[#7BA05B]/10 px-3 py-2 text-xs font-medium text-[#5A7A43]">
        분야별 상세 보고서는 {ownerName}님이 앱에서 복주머니로 잠금해제한 뒤
        확인할 수 있어요.
      </p>

      <p className="mb-2 text-xs text-[#8C7F6E]">나도 두 사람의 궁합이 궁금하다면</p>
      <button
        type="button"
        onClick={() => {
          window.location.href = SINTONG_WEB_URLS.gunghap;
        }}
        className="block w-full rounded-2xl bg-[#F5CF6A] px-4 py-3.5 text-sm font-bold text-[#1A0D2E] shadow-[0_8px_32px_-12px_rgba(245,207,106,0.22)] transition-transform active:scale-[0.98] hover:bg-[#FADFA0]"
      >
        ✧ 나도 궁합지도 만들기 · 무료
      </button>
      <p className="mt-2 text-center text-[11px] text-[#8C7F6E]">
        설치 없이 바로 열려요 · 신통방통 웹
      </p>
    </div>
  );
}
