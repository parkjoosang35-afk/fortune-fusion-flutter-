// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// [로딩 스피너 무한 대기 버그 수정 - 2026-09-23 사용자 리포트: 앱이
// 계속 로딩중]
//
// [원인] Flutter 기본 빌드가 생성하는 flutter_bootstrap.js는 CanvasKit
// 렌더러(WASM 기반 그래픽 엔진)를 로컬에 이미 번들해 두고도 그걸 쓰지
// 않고 구글 CDN(https://www.gstatic.com/flutter-canvaskit/...)에서
// "매번 새로 다운로드"하도록 기본 설정되어 있었다. 사용자 네트워크
// 환경(회사/학교 방화벽, 통신사 프록시, 해외망 등)에서 gstatic.com
// 접속이 느리거나 차단되면, canvaskit.wasm(약 7MB) 다운로드가 영원히
// 끝나지 않아 앱이 첫 프레임을 절대 그리지 못하고 스피너에서 무한
// 대기하는 문제가 발생했다(사용자 화면 녹화로 확인 — 다크 배경 위
// 흰색 스피너만 계속 회전).
//
// [수정] canvasKitBaseUrl을 "canvaskit/"(상대 경로 — <base href>
// 기준으로 자동 해석되어 운영 서버 /app/canvaskit/, 로컬 미리보기
// /canvaskit/ 양쪽 모두에서 올바르게 동작)로 고정해, build/web/
// canvaskit/ 폴더에 이미 포함된 canvaskit.js/.wasm 파일을 그대로
// 쓰도록 강제한다. 이렇게 하면 main.dart.js와 마찬가지로 같은
// 서버(sintong.kr)에서 한 번에 받아지므로 외부 CDN 네트워크 상태와
// 완전히 무관해진다.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
