import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  // 샌드박스 프록시 도메인에서의 개발 서버 접근(HMR/웹팩 리소스 포함) 허용.
  // 이 설정이 없으면 코드 수정 후에도 브라우저에 반영되지 않는(Cross-origin 차단) 문제가 발생한다.
  allowedDevOrigins: [
    "3000-icl3vxc7xf6zjzgg3f9cz-8f57ffe2.sandbox.novita.ai",
    "*.sandbox.novita.ai",
    // [Item 4 E2E 테스트 디버깅 중 발견] Playwright(Chromium)가 HMR WebSocket에
    // Origin: http://127.0.0.1:4300 헤더를 보내는데, 이 값이 allowedDevOrigins에
    // 없으면 Next.js dev 서버가 핸드셰이크 자체를 거부(HTTP/0.9 손상 응답)한다.
    // 그 결과 클라이언트 React가 "use client" 컴포넌트의 이벤트 리스너를 전혀
    // 바인딩하지 못해(hydration 자체는 되어 보이지만 onClick 등이 0개) 모든
    // 버튼 클릭이 조용히 무시되는 현상이 발생했다 — 로컬 Playwright E2E 테스트
    // 실행을 위해 127.0.0.1/localhost를 명시적으로 허용한다.
    // 중요: Next.js의 block-cross-site-dev.js는 Origin 헤더를 parseUrl()로
    // 파싱해서 "hostname"만 추출(포트 제외)한 뒤 allowedDevOrigins 배열과
    // 정확히 문자열 비교한다. 따라서 "127.0.0.1:4300"처럼 포트를 포함하면
    // 절대 매칭되지 않는다 (실제 비교 대상은 포트 없는 "127.0.0.1"). 최초
    // 수정 시 이 점을 놓쳐서 수정이 전혀 효과가 없었다 — 포트 없이 등록해야 한다.
    "127.0.0.1",
    "localhost",
  ],
  // [버그 수정] "오늘의 행운숫자" 등 관리자 업로드 이미지가 Flutter Web(CanvasKit 렌더러)에서
  // 로드되지 않는 문제 — public/uploads/* 정적 파일에 CORS 헤더가 없어 크로스오리진 fetch가
  // 차단됨. Image.network()가 다른 오리진(5060 포트)에서 이 서버(3000 포트)의 이미지를
  // 불러오므로 Access-Control-Allow-Origin을 명시적으로 열어준다.
  async headers() {
    return [
      {
        source: "/preview/:path*",
        headers: [
          { key: "Cache-Control", value: "no-store, must-revalidate" },
        ],
      },
      {
        source: "/uploads/:path*",
        headers: [
          { key: "Access-Control-Allow-Origin", value: "*" },
          { key: "Cross-Origin-Resource-Policy", value: "cross-origin" },
        ],
      },
    ];
  },
};

export default nextConfig;
