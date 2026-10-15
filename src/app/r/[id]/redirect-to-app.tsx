"use client";

// [2026-10, 앱·웹 분리 개발 전면 폐기 — 결과 공유 페이지까지 동일 적용]
// 사용자가 격노하며 지적한 핵심: "귀인지도 결과 공유페이지 2군데(/r/[id],
// /web-result/[id])를 없애고 바로 신통방통 결과페이지 나오게 해라. 타로
// 정통사주 관상 손금 결과페이지도 다 신통방통 결과페이지 바로 나오도록
// 수정해라 — 이것도 웹이야." 초대장(`/g/{token}`, `/w/{token}`)과
// 완전히 동일한 구조의 중복 개발 실수가 결과 공유 쪽(`/r/{shareId}`)에도
// 그대로 있었다: admin_web이 `service-result-view.tsx` +
// `content/{tarot,saju,face-palm,relationship,wish}-content.tsx`로
// 타로·정통사주·관상·손금·귀인지도·소원방 6종 결과를 전부 다시 그려
// 보여주고 있었다.
//
// [근본 원인] `https://sintong.kr/app/`(Flutter 웹앱)에는 이미
// `/r/{shareId}` named route(app_router.dart)가 있다 —
// `SharedResultScreen`이 `GET /api/public/share/{shareId}`를 호출해
// 6종 결과 전부(타로 카드/질문, 정통사주, 관상, 손금, 귀인지도, 소원방)를
// 완전하게 보여준다. admin_web이 똑같은 걸 다시 만들 필요가 없었다.
//
// [수정] 이 서버(admin_web)의 `/r/{shareId}`(및 `/web-result/{shareId}`)
// 경로가 하는 유일한 역할은 카카오톡 등 SNS 크롤러를 위한 OG 미리보기
// 생성뿐이다(크롤러는 JS를 실행하지 않아 Flutter SPA를 볼 수 없으므로
// generateMetadata()의 SSR 메타가 필수). 실제 사람 방문자는 이 컴포넌트가
// 마운트되자마자 즉시 `https://sintong.kr/app/#/r/{shareId}`(진짜
// 신통방통 웹, Flutter 빌드)로 이동한다.
export function RedirectToApp({ shareId }: { shareId: string }) {
  if (typeof window !== "undefined") {
    window.location.replace(`https://sintong.kr/app/#/r/${shareId}`);
  }
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0B0B0D]">
      <p className="text-sm text-[#8A8880]">신통방통으로 이동하는 중...</p>
    </div>
  );
}
