"use client";

// [복주머니 마케팅 쿠폰 최종본 §37 화면⑭ "고객 · 쿠폰 등록"]
// `/w/[token]`·`/g/[token]`·`/r/[id]`와 동일한 "앱·웹 분리" 원칙을 그대로
// 따른다 — 쿠폰 등록(미리보기→로그인 유도→실제 등록) 흐름은 이미 Flutter
// 웹앱(`https://sintong.kr/app/`)의 `/coupon/{token}` named route
// (app_router.dart → BokjuCouponResolveScreen)에 완전히 구현되어 있다
// (비로그인 시 PendingBokjuCouponStore에 토큰을 저장해두고 로그인 화면으로
// 보낸 뒤 로그인 완료 시 자동 복귀하는 것까지 전부 native 쪽에서 처리).
// admin_web(Next.js)에 쿠폰 등록 폼이나 결과 카드를 다시 만들 필요가 없다.
//
// 이 서버(admin_web)의 `/coupon/{token}` 경로가 하는 유일한 역할은 카카오톡
// 등 SNS 크롤러를 위한 OG 미리보기(제목/설명/이미지) 생성뿐이다(크롤러는
// JS를 실행하지 않으므로 Flutter SPA의 동적 내용을 볼 수 없음 — page.tsx의
// generateMetadata() 참고). 실제 사람이 이 링크를 열면 이 컴포넌트가
// 마운트되자마자 즉시 `https://sintong.kr/app/#/coupon/{token}`으로
// 이동한다.
export function RedirectToApp({ token }: { token: string }) {
  if (typeof window !== "undefined") {
    window.location.replace(`https://sintong.kr/app/#/coupon/${token}`);
  }
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0B0B0D]">
      <p className="text-sm text-[#8A8880]">신통방통으로 이동하는 중...</p>
    </div>
  );
}
