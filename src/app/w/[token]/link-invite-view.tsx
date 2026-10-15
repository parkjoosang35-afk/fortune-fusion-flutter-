"use client";

// [소원방 공유 랜딩 — 클라이언트 뷰] 서버 컴포넌트(page.tsx)가 OG 메타용으로
// 조회한 최소 정보를 이 컴포넌트가 받는다.
//
// [2026-10-15, 사용자 격노 정정 — 근본 재설계] 직전 세션은 "그대로 그사람의
// 소원방으로 바로 들어가게"라는 지시를 "admin_web이 Flutter 화면의 사본을
// 새로 그려서 보여준다"로 잘못 해석했다(실제 방 데이터를 fetch해 카드를
// 다시 그리고, 응원/메시지/복주머니는 가입 안내 패널로 막는 방식). 귀인지도
// (`guinji-invite-interactive.tsx`)에서 사용자가 지적한 것과 완전히 동일한
// 근본 오류다: "웹"이란 admin_web이 그린 커스텀 화면이 아니라, 이미
// `sintong.kr/app/`에 배포되어 있는 **진짜 Flutter 앱**이다.
//
// [정정된 구현] 이 페이지(토큰이 유효하면)는 더 이상 방 콘텐츠를 자체
// fetch해서 다시 그리지 않는다 — 곧바로 `https://sintong.kr/app/#/w/{token}`
// 로 이동시킨다. 이 named route(`/w/{token}`)는 Flutter 앱(`app_router.dart`)
// 에 이미 구현되어 있고(`LinkInviteScreen` → "소원방에 들어가기" 버튼 →
// `OtherRoomScreen`), 바로 그 화면이 "진짜 그 사람의 소원방"이다. 앱은 전혀
// 건드리지 않는다(사용자 지시 "앱 건들지 말고") — admin_web은 그 화면으로
// 보내는 다리 역할만 한다. 응원/메시지/복주머니가 로그인을 요구하는 것도
// 이미 그 화면(OtherRoomScreen → WishRoomProvider)이 처리하는 기존 동작이라
// admin_web이 별도로 "회원가입 안내 패널"을 또 만들 필요가 없다.
//
// [OG 메타 유지] 카카오톡 등 SNS 크롤러는 JS를 실행하지 않으므로, 아래
// useEffect 리다이렉트는 "사람이 실제로 열었을 때"만 동작하고
// `generateMetadata()`(page.tsx, 서버 컴포넌트)가 만든 오픈그래프 미리보기
// 카드는 그대로 보인다 — 이 정정으로 바뀌는 것이 없다.
import { useEffect } from "react";

type ViewState = "ok" | "not_found" | "error";

type LinkInviteViewProps = {
  token: string;
  state: ViewState;
  ownerNickname?: string;
  text?: string;
};

const SERIF = "'Noto Serif KR', serif";

export function LinkInviteView({ token, state, ownerNickname, text }: LinkInviteViewProps) {
  useEffect(() => {
    if (state !== "ok") return;
    window.location.href = `https://sintong.kr/app/#/w/${token}`;
  }, [state, token]);

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

  // [리다이렉트 대기 중 노출되는 최소 화면] useEffect가 즉시 실행되므로
  // 실사용자에게는 거의 보이지 않지만, 네트워크가 느린 경우를 대비해
  // "이동 중" 상태를 짧게 보여준다. ownerNickname/text는 그 찰나의
  // 화면에서도 "맞는 초대장을 열었다"는 확신을 주기 위해 사용한다.
  return (
    <div className="relative mx-auto w-full max-w-[440px] px-4 py-10 text-center">
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
      <div className="rounded-3xl border border-[#E8DDD0] bg-white/85 p-8 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
        <span className="mb-3 block text-[34px]">🕯</span>
        <h1 style={{ fontFamily: SERIF }} className="mb-2 text-lg font-bold text-[#2A2438]">
          {ownerNickname ?? "누군가"}님의 소원방으로 이동 중이에요
        </h1>
        {text && <p className="mb-2 text-sm text-[#6E5A54]">&quot;{text}&quot;</p>}
        <p className="text-[12px] text-[#A08C82]">설치 없이 바로 열려요 · 잠시만 기다려 주세요</p>
      </div>
    </div>
  );
}
