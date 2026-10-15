"use client";

// [2026-10-15, 사용자 격노 정정 — 근본 재설계] 직전 세션은 "결과를 이
// 페이지 안에서 완결"하라는 지시를 "admin_web에 Flutter 궤도맵의 사본을
// 새로 만들어 보여준다"로 잘못 해석했다. 사용자의 실제 지시는 정반대:
//   "귀인지도 초대장을 보내면 초대장에서 생년월일 넣고 관계보기을 누르면
//    결과가 https://sintong.kr/?s=guinji 여기로 바로 들어와야 한다"
// 즉 "웹"이란 admin_web이 그린 커스텀 결과 화면이 아니라, 이미
// `sintong.kr/app/`에 배포되어 있는 **진짜 Flutter 앱**이다. 그리고
// `https://sintong.kr/?s=guinji`는 임의로 지어낸 URL이 아니라 PC 랜딩
// (`sintong_pc_landing/src/landing-v7.js` §7-4)이 이미 구현해 둔 정식
// 메커니즘이다 — 쿼리 `?s=테마`를 읽어 iframe을 그 테마의 실제 앱 라우트
// (`/app/#/guinji-map`)로 띄운다. 모바일(카톡 인앱 브라우저 등)에서는
// `index.html`의 리다이렉트가 이 쿼리를 그대로 `/app/` 뒤에 해시로 붙여
// 전달하도록 이번에 함께 고쳤다(기존엔 쿼리가 유실되는 버그가 있었음).
//
// [유지되는 부분] 이름+생년월일 입력 폼과 `/api/public/guinji/g/{token}/join`
// 호출은 그대로 둔다 — "지도에 이름이 올라간다"(DB 반영)는 실제로 필요한
// 요구사항이고, 이미 정상 동작하는 코드이기 때문이다. 바뀌는 것은 오직
// "성공 이후 무엇을 보여주는가" 뿐이다: 이 페이지 안에 커스텀 결과
// 카드/지도를 그리는 대신, 제출이 성공하면 곧바로
// `https://sintong.kr/?s=guinji`로 이동한다 — admin_web 쪽 커스텀 결과
// 렌더링(ResultCard/RelationNetworkGraph/GuinjiOrbitMap)은 전부 제거.
import { useEffect, useState } from "react";
import { track } from "./funnel";

const SINTONG_GUINJI_WEB_URL = "https://sintong.kr/?s=guinji";

export function GuinjiInviteInteractive({
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
  const [timeKnown, setTimeKnown] = useState(false);
  const [hour, setHour] = useState("");
  const [minute, setMinute] = useState("");
  const [agreePolicy, setAgreePolicy] = useState(false);
  const [agreeAge14, setAgreeAge14] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [redirecting, setRedirecting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // [귀인지도 v2 퍼널 ①] 초대 링크가 실제로 열렸음을 기록(6단 루프의 시작점).
  useEffect(() => {
    track("share_og_open", token);
  }, [token]);

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
        setSubmitting(false);
        return;
      }
      track("join_done", token); // [귀인지도 v2 퍼널 ③] 참가 완료
      // [2026-10-15, 사용자 명시 지시 — 최종 확정] 참여 등록(DB 반영)은
      // 위 join API 호출로 이미 끝났다. 결과 확인은 admin_web이 아니라
      // PC 랜딩의 `?s=` 공유 메커니즘을 타고 신통방통 "웹"(진짜 Flutter
      // 앱) 귀인지도 화면으로 즉시 이동해서 보여준다.
      setRedirecting(true);
      window.location.href = SINTONG_GUINJI_WEB_URL;
    } catch {
      setError("네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.");
      setSubmitting(false);
    }
  }

  return (
    <div className="rounded-3xl border border-[#2A2A2E] bg-[#161618] p-6 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
      <p className="mb-1 flex items-center justify-center gap-1.5 text-center text-[13px] text-[#8A8880]">
        <span className="text-[#E9C46A]">✦</span>
        나는 {ownerName}님에게 어떤 사람일까?
        <span className="text-[#E9C46A]">✦</span>
      </p>

      {redirecting ? (
        <div className="mt-6 flex flex-col items-center gap-3 py-6 text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-[#2A2A2E] border-t-[#E9C46A]" />
          <p className="text-sm text-[#8A8880]">
            신통방통 웹에서 결과를 확인하고 있어요...
          </p>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="mt-4">
          <p className="mb-3 text-center text-xs text-[#575650]">
            이름과 생년월일을 입력하면, 신통방통 웹에서 바로 결과를 볼 수 있어요.
          </p>

          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="이름(닉네임도 괜찮아요)"
            maxLength={20}
            className="mb-3 w-full rounded-2xl border border-[#2A2A2E] bg-[#1C1C1F] px-3 py-2.5 text-center text-sm text-[#F2F0EC] placeholder:text-[#575650] focus:border-[#E9C46A] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
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
                    ? "bg-[#E9C46A] text-white"
                    : "bg-[#1C1C1F] text-[#8A8880] border border-[#2A2A2E]"
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
              className="w-1/3 rounded-2xl border border-[#2A2A2E] bg-[#1C1C1F] px-3 py-2.5 text-center text-sm text-[#F2F0EC] placeholder:text-[#575650] focus:border-[#E9C46A] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
            />
            <input
              value={month}
              onChange={(e) => setMonth(e.target.value)}
              placeholder="월"
              inputMode="numeric"
              maxLength={2}
              className="w-1/3 rounded-2xl border border-[#2A2A2E] bg-[#1C1C1F] px-3 py-2.5 text-center text-sm text-[#F2F0EC] placeholder:text-[#575650] focus:border-[#E9C46A] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
            />
            <input
              value={day}
              onChange={(e) => setDay(e.target.value)}
              placeholder="일"
              inputMode="numeric"
              maxLength={2}
              className="w-1/3 rounded-2xl border border-[#2A2A2E] bg-[#1C1C1F] px-3 py-2.5 text-center text-sm text-[#F2F0EC] placeholder:text-[#575650] focus:border-[#E9C46A] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
            />
          </div>

          {/* 시간 알음/모름 토글 */}
          <div className="mb-3 flex justify-center gap-2">
            <button
              type="button"
              onClick={() => setTimeKnown(false)}
              className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                !timeKnown ? "bg-[#E9C46A] text-white" : "bg-[#1C1C1F] text-[#8A8880] border border-[#2A2A2E]"
              }`}
            >
              시간 모름
            </button>
            <button
              type="button"
              onClick={() => setTimeKnown(true)}
              className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                timeKnown ? "bg-[#E9C46A] text-white" : "bg-[#1C1C1F] text-[#8A8880] border border-[#2A2A2E]"
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
                className="w-1/2 max-w-[120px] rounded-2xl border border-[#2A2A2E] bg-[#1C1C1F] px-3 py-2.5 text-center text-sm text-[#F2F0EC] placeholder:text-[#575650] focus:border-[#E9C46A] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
              />
              <input
                value={minute}
                onChange={(e) => setMinute(e.target.value)}
                placeholder="분"
                inputMode="numeric"
                maxLength={2}
                className="w-1/2 max-w-[120px] rounded-2xl border border-[#2A2A2E] bg-[#1C1C1F] px-3 py-2.5 text-center text-sm text-[#F2F0EC] placeholder:text-[#575650] focus:border-[#E9C46A] focus:outline-none focus:ring-2 focus:ring-[#FBEFE8]"
              />
            </div>
          )}

          {/* 동의 체크박스 — 개인정보처리방침 / 14세 이상 확인 (필수) */}
          <div className="mb-3 space-y-1.5 text-left">
            <label className="flex items-center gap-2 text-xs text-[#8A8880]">
              <input
                type="checkbox"
                checked={agreePolicy}
                onChange={(e) => setAgreePolicy(e.target.checked)}
                className="h-4 w-4 accent-[#E9C46A]"
              />
              (필수) 개인정보처리방침에 동의합니다.
            </label>
            <label className="flex items-center gap-2 text-xs text-[#8A8880]">
              <input
                type="checkbox"
                checked={agreeAge14}
                onChange={(e) => setAgreeAge14(e.target.checked)}
                className="h-4 w-4 accent-[#E9C46A]"
              />
              (필수) 만 14세 이상입니다.
            </label>
          </div>

          {error && <p className="mb-3 text-center text-xs text-[#EF7A55]">{error}</p>}
          <button
            type="submit"
            disabled={submitting}
            className="mb-2 block w-full rounded-2xl bg-[#E9C46A] px-4 py-3.5 text-sm font-bold text-white shadow-[0_8px_32px_-12px_rgba(166,121,94,0.22)] transition-transform active:scale-[0.98] hover:bg-[#F2D488] disabled:opacity-60"
          >
            {submitting ? "확인하는 중" : `${ownerName}님과 나의 관계 보기`}
          </button>
          <p className="text-center text-xs text-[#575650]">
            결과는 설치 없이 신통방통 웹에서 바로 보여요.
          </p>
        </form>
      )}
    </div>
  );
}
