import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  // 샌드박스 프록시 도메인에서의 개발 서버 접근(HMR/웹팩 리소스 포함) 허용.
  // 이 설정이 없으면 코드 수정 후에도 브라우저에 반영되지 않는(Cross-origin 차단) 문제가 발생한다.
  allowedDevOrigins: [
    "3000-icl3vxc7xf6zjzgg3f9cz-8f57ffe2.sandbox.novita.ai",
    "*.sandbox.novita.ai",
  ],
  // [버그 수정] "오늘의 행운숫자" 등 관리자 업로드 이미지가 Flutter Web(CanvasKit 렌더러)에서
  // 로드되지 않는 문제 — public/uploads/* 정적 파일에 CORS 헤더가 없어 크로스오리진 fetch가
  // 차단됨. Image.network()가 다른 오리진(5060 포트)에서 이 서버(3000 포트)의 이미지를
  // 불러오므로 Access-Control-Allow-Origin을 명시적으로 열어준다.
  async headers() {
    return [
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
