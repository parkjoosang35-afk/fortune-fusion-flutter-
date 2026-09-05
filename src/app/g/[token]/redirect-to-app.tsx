"use client";

// [초대 링크 = 플러터 원본 페이지 기반 전환 — B-1 즉시 자동 리다이렉트]
//
// [배경] 지금까지 이 페이지(`/g/[token]`)는 admin_web(Next.js)에 자체적으로
// 이름+생년월일 입력 폼과 결과 카드(`GuinjiInviteInteractive`)를 구현해
// "웹에서 완결되는 게스트 경험"을 제공했었다. 하지만 사용자가 명시적으로
// "초대 링크는 우리 플러터 원본 페이지를 보내는 걸 기반으로 가야 한다"고
// 정정했다 — 즉 게스트가 실제로 보게 될 화면은 admin_web의 별도 재구현이
// 아니라, Flutter 앱의 진짜 화면(`GuinjiMapGuestJoinScreen` →
// `GuinjiGuestResultScreen`, 호스트 이름+관계유형+케미점수까지 이미 완성돼
// 있는 원본)이어야 한다는 뜻이다.
//
// [카톡 미리보기(OG 카드)는 그대로 유지] 카카오톡 등 SNS 크롤러는 JS를
// 실행하지 않고 서버가 렌더링한 HTML의 OG 메타태그만 읽으므로, 이 페이지의
// `generateMetadata()`(page.tsx, 손대지 않음)가 만드는 "{ownerName}님이
// 초대한 귀인 지도" 미리보기 카드는 지금과 동일하게 계속 뜬다. 이
// 컴포넌트는 오직 실제 사람이 링크를 "클릭한 뒤"에만 실행되는 클라이언트
// 사이드 리다이렉트라 크롤러 단계에는 아무 영향이 없다.
//
// [즉시 자동 전환 — B-1] 마운트 즉시(useEffect, 지연 없음) Flutter 웹 앱의
// 원본 `/g/{token}` 라우트로 `window.location.replace()` 이동한다. Flutter
// 웹은 기본 Hash URL 전략을 쓰므로(main.dart에 usePathUrlStrategy() 호출이
// 없음) 대상 URL은 `{appUrl}/#/g/{token}` 형태여야 하고, 이 경로는
// `app_router.dart`의 onGenerateRoute가 switch 진입 전에 이미
// `/g/{token}` → `GuinjiMapGuestJoinScreen(token: token)`으로 파싱하도록
// 완성되어 있다(코드 추가 불필요).
//
// [주의 — 과거 "자동 리다이렉트 절대 금지" 원칙과는 다른 사안] 그 금지
// 원칙은 "앱이 설치됐는지 확인해 강제로 앱스토어로 보내거나 커스텀 스킴을
// 시도하는 것"에 대한 것이었다(게스트가 결과를 보기도 전에 앱으로
// 튕기려던 과거 버그). 이번 건은 웹→웹(admin_web 페이지 → Flutter 웹
// 페이지) 이동으로, 앱 설치 여부 확인이나 스토어 이동이 전혀 없어 그
// 원칙과 충돌하지 않는다 — 오히려 "게스트가 보는 화면이 결국 무엇이어야
// 하는가"에 대한 사용자의 새 지시를 따르는 것이다.
//
// [자동 이동이 안 될 경우를 위한 안전장치] 팝업 차단·느린 네트워크 등으로
// 자동 이동이 실패할 가능성에 대비해, 화면에 수동 이동 링크도 항상 함께
// 보여준다(자동 이동이 성공하면 사용자는 이 화면을 거의 보지 못한다).
import { useEffect } from "react";

const SERIF = "'Noto Serif KR', serif";

const HERO_STARS_BG =
  "radial-gradient(1px 1px at 20% 30%, rgba(212,165,116,.6) 50%, transparent 100%)," +
  "radial-gradient(1px 1px at 70% 20%, rgba(232,180,165,.5) 50%, transparent 100%)," +
  "radial-gradient(1.2px 1.2px at 40% 70%, rgba(212,165,116,.4) 50%, transparent 100%)," +
  "radial-gradient(1px 1px at 85% 60%, rgba(232,180,165,.5) 50%, transparent 100%)";

export function RedirectToApp({
  ownerName,
  appUrl,
  token,
}: {
  ownerName: string;
  appUrl: string;
  token: string;
}) {
  // Flutter 웹 기본 Hash URL 전략 — 대상 URL은 항상 `#/g/{token}` 형태.
  const target = `${appUrl.replace(/\/$/, "")}/#/g/${token}`;

  useEffect(() => {
    window.location.replace(target);
  }, [target]);

  return (
    <div className="relative mx-auto w-full max-w-[440px] px-5 py-10">
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
        style={{ backgroundImage: HERO_STARS_BG }}
        aria-hidden
      />
      <div className="relative mb-6 flex items-center justify-center gap-1.5">
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
        {/* 로딩 스피너 */}
        <div className="mx-auto mb-5 h-8 w-8 animate-spin rounded-full border-[3px] border-[#E8DDD0] border-t-[#A6795E]" />

        <h1 style={{ fontFamily: SERIF }} className="mb-2 text-lg font-bold text-[#2A2438]">
          {ownerName}님의 귀인 지도로
          <br />
          이동하고 있어요
        </h1>
        <p className="mb-6 text-sm leading-relaxed text-[#6E5A54]">
          생일만 입력하면 바로
          <br />
          {ownerName}님과의 관계가 나와요.
        </p>

        {/* 자동 이동이 늦거나 차단됐을 때를 위한 수동 이동 링크 */}
        <a
          href={target}
          className="block w-full rounded-2xl bg-[#A6795E] px-4 py-3.5 text-sm font-bold text-white shadow-[0_8px_32px_-12px_rgba(166,121,94,0.22)] transition-transform active:scale-[0.98] hover:bg-[#B58567]"
        >
          자동으로 이동하지 않나요? 여기를 눌러주세요
        </a>
      </div>
    </div>
  );
}
