"use client";

// [소원방 공유 랜딩 — 클라이언트 뷰] 서버 컴포넌트(page.tsx)가 조회한
// 데이터를 받아 렌더링만 담당한다(OG 메타태그는 서버에서 처리 완료).
//
// [앱 설치자 대응] Android App Links(autoVerify, pathPrefix="/w")가
// 정상 검증되면 OS가 이 페이지 자체를 열지 않고 앱의 LinkInviteScreen을
// 직접 띄운다. 이 페이지가 보인다는 것은 "미설치 또는 검증 실패" 상태
// 라는 뜻이므로, 상단에 설치 유도 배너를 항상 노출한다(`/g/[token]`,
// `/r/[id]`와 동일한 2단계 구조 원칙). "앱에서 열기" 버튼은 커스텀
// 스킴(`fortunefusion://w/{token}`)을 먼저 시도해, 앱은 설치돼 있는데
// App Links 검증만 실패한 케이스도 구제한다.
import { useState } from "react";

type ViewState = "ok" | "not_found" | "error";

type LinkInviteViewProps = {
  token: string;
  state: ViewState;
  ownerNickname?: string;
  text?: string;
  level?: number;
  levelName?: string;
  daysLit?: number;
};

const SERIF = "'Noto Serif KR', serif";

function tryOpenApp(token: string) {
  // [Android App Links 검증 실패/iOS 폴백 대응] 커스텀 스킴 우선 시도.
  window.location.href = `fortunefusion://w/${token}`;
}

export function LinkInviteView({
  token,
  state,
  ownerNickname,
  text,
  level,
  levelName,
  daysLit,
}: LinkInviteViewProps) {
  const [attemptedAppOpen, setAttemptedAppOpen] = useState(false);

  if (state !== "ok") {
    return (
      <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
        <div className="relative mb-5 flex items-center justify-center gap-1.5">
          <span
            className="flex h-6 w-6 items-center justify-center rounded-full"
            style={{ backgroundImage: "linear-gradient(135deg, #E2A88A, #A6795E)" }}
          >
            <span className="text-[10px] font-bold leading-none text-white">신</span>
          </span>
          <span style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#2A2438]">
            신통방통
          </span>
        </div>
        <div className="relative rounded-3xl border border-[#E8DDD0] bg-white/85 p-8 text-center shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
          <span className="mb-3 block text-[34px]">🔒</span>
          <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#2A2438]">
            더 이상 열 수 없는 링크예요
          </h1>
          <p className="mb-2 text-sm leading-relaxed text-[#6E5A54]">
            링크가 만료되었거나
            <br />
            소원방 주인이 공개 범위를 바꿨을 수 있어요.
          </p>
        </div>
      </div>
    );
  }

  return (
    <>
      {/* [설치 유도 배너] App Links 검증 실패/미설치 상태에서만 이 페이지가
          보이므로 항상 상단에 노출한다. */}
      <div className="sticky top-0 z-10 flex items-center justify-between gap-3 bg-[#2A2438] px-4 py-2.5 text-white">
        <span className="text-[12px] leading-snug">
          신통방통 앱에서 더 다양한 운세를 만나보세요
        </span>
        <a
          href="https://play.google.com/store/apps/details?id=com.fortunefusion.fortune"
          className="shrink-0 rounded-full bg-white px-3 py-1 text-[11px] font-bold text-[#2A2438]"
        >
          앱 설치
        </a>
      </div>

      <section className="relative overflow-hidden">
        <div className="relative mx-auto w-full max-w-[440px] px-5 pt-6 pb-6">
          <div className="mb-5 flex items-center gap-1.5">
            <span
              className="flex h-6 w-6 items-center justify-center rounded-full"
              style={{ backgroundImage: "linear-gradient(135deg, #E2A88A, #A6795E)" }}
            >
              <span className="text-[10px] font-bold leading-none text-white">신</span>
            </span>
            <span style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#2A2438]">
              신통방통
            </span>
          </div>

          <div className="mb-4 inline-flex items-center gap-2 whitespace-nowrap rounded-full border border-[#F5D9C9] bg-[#FBEFE8] px-3 py-1.5">
            <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#C99B7F]" />
            <span className="whitespace-nowrap text-[11px] font-semibold text-[#A6795E]">
              소원방 초대
            </span>
          </div>

          <h1
            style={{ fontFamily: SERIF }}
            className="mb-3 text-[26px] font-bold leading-[1.35] tracking-tight text-[#2A2438]"
          >
            {ownerNickname}님이
            <br />
            소원방에 초대했어요
          </h1>

          <div className="mb-5 space-y-2 rounded-3xl border border-[#E8DDD0] bg-white/85 p-5 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
            <p className="text-[12px] font-semibold text-[#A6795E]">
              {daysLit}일째 밝히는 중 · Lv.{level} {levelName ? `(${levelName})` : ""}
            </p>
            <p className="text-[15px] leading-relaxed text-[#2A2438]">&quot;{text}&quot;</p>
          </div>

          <p className="mb-5 text-[13px] leading-relaxed text-[#6E5A54]">
            촛불 하나 함께 밝혀주세요. 앱에서 응원 메시지와 복주머니를 보낼 수 있어요.
          </p>

          <button
            onClick={() => {
              setAttemptedAppOpen(true);
              tryOpenApp(token);
            }}
            className="w-full rounded-2xl py-3.5 text-center text-[15px] font-bold text-white shadow-[0_4px_20px_-4px_rgba(166,121,94,0.4)]"
            style={{ backgroundImage: "linear-gradient(90deg, #A6795E, #E8B4A5)" }}
          >
            🕯 앱에서 소원방 열기
          </button>
          {attemptedAppOpen && (
            <p className="mt-2 text-center text-[11px] text-[#A08C82]">
              앱이 설치되어 있지 않다면 위 설치 버튼을 눌러주세요.
            </p>
          )}
        </div>
      </section>

      <footer className="mx-auto w-full max-w-[440px] border-t border-[#E8DDD0] px-5 pt-5 pb-2 text-center">
        <p className="text-[10px] text-[#A08C82]">© 2026 Sintongbangtong. All rights reserved.</p>
      </footer>
    </>
  );
}
