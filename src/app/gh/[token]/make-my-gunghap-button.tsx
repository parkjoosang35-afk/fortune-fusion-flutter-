"use client";

// [궁합지도(Gunghap Map) `/gh/[token]` 랜딩 신설 — Phase 1] REVOKED/NOT_FOUND
// 화면 공용 CTA "나도 궁합지도 만들기". `/g/[token]/make-my-map-button.tsx`
// (귀인지도)와 동일한 원칙(앱 설치 요구 없이 웹 신통방통 메인으로 즉시
// 이동)을 따른다 — 기존 귀인지도 파일은 전혀 수정하지 않고 궁합지도
// 전용으로 새로 만든다.
import { SINTONG_WEB_URLS } from "../../g/[token]/sintong-web-urls";

export function MakeMyGunghapButton() {
  return (
    <button
      type="button"
      onClick={() => {
        window.location.href = SINTONG_WEB_URLS.gunghap;
      }}
      className="mt-5 w-full rounded-2xl px-4 py-3 text-[14px] font-semibold text-[#1A0D2E] shadow-[0_4px_16px_-4px_rgba(245,207,106,0.4)]"
      style={{ backgroundImage: "linear-gradient(135deg, #FADFA0, #F5CF6A)" }}
    >
      나도 궁합지도 만들기
    </button>
  );
}
