"use client";

// [귀인지도 초대링크 재발급 v1.1 — 2026 Phase, §7-2/7-3] REVOKED/INVALID
// 화면 공용 CTA "나도 내 귀인 지도 만들기". `guinji-invite-interactive.tsx`의
// `goToSintongWeb()`와 동일한 원칙(앱 설치 요구 없이 웹 신통방통 메인의
// 귀인지도 화면으로 즉시 이동)을 따른다 — 별도 딥링크/스토어 폴백 없음.
import { SINTONG_WEB_URLS } from "./sintong-web-urls";
import { track } from "./funnel";

export function MakeMyMapButton() {
  return (
    <button
      type="button"
      onClick={() => {
        track("app_cta_click"); // [귀인지도 v2 퍼널 ⑤] 설치/전환 CTA 클릭
        window.location.href = SINTONG_WEB_URLS.guinji;
      }}
      className="mt-5 w-full rounded-2xl px-4 py-3 text-[14px] font-semibold text-white shadow-[0_4px_16px_-4px_rgba(166,121,94,0.4)]"
      style={{ backgroundImage: "linear-gradient(135deg, #F7E4AE, #E9C46A)" }}
    >
      나도 내 귀인 지도 만들기
    </button>
  );
}
