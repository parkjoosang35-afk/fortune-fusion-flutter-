// lib/features/guinji/widgets/guinji_animation_spec.dart
// [귀인지도 v2 리스킨 — 핸드오프 이식] 시안의 애니메이션 타이밍을 상수로
// 고정 — 디자인 확인 시 이 값만 조정. `귀인지도_최종_핸드오프.html`
// `window.GJ_CODE_FILES`의
// `lib/features/guinji_map/widgets/guinji_animation_spec.dart`를 1:1 이식.
import 'package:flutter/animation.dart';

/// 01 인트로 시네마틱 (13.5초 루프 · 2회차부터 타이틀/CTA 고정 · '건너뛰기' = 완성 상태로 점프).
class IntroTiming {
  static const meAppear = Duration(milliseconds: 200); // 나 얼굴 84px · easeOutBack 900ms
  static const circleDraw = Duration(milliseconds: 700); // 오행 원 PathMetric 1.6s · 40s/회전, 육각 60s 역회전
  static const elementLabel = Duration(milliseconds: 1300); // 木火土金水 120ms 간격 페이드
  static const arrive0 = Duration(milliseconds: 2200); // 인연 6명 도착 시작
  static const arriveGap = Duration(milliseconds: 620); // 사람 간격 (유성 500ms → 충격파 2겹 → 얼굴 팝 520ms → 인장 +260ms → 연결선 +520ms)
  static const complete = Duration(milliseconds: 6420); // 빛 폭발 · 링 3겹 · 스트릭 18개 · heavyImpact
  static const title = Duration(milliseconds: 6720); // 글자별 등장 45ms 간격 (blur 8→0, y 14→0)
  static const cta = Duration(milliseconds: 7220); // CTA 숨쉬기 2.4s · 반짝임 스윕 2.8s
  static const loop = Duration(milliseconds: 13500);
  static const warp = Duration(milliseconds: 1100); // CTA 탭 → 6배 확대 + blur + 화이트아웃 → 정보입력
  static const Curve pop = Curves.easeOutBack;
}

/// 지인 도착 (빈 지도/기존 지도에서 새 멤버 감지 시) — 1인 약 2.9초, 다수면 4.7초 간격 최대 3명.
class ArrivalTiming {
  static const toastLead = Duration(milliseconds: 900); // 토스트는 도착 0.9초 전부터 3.1초 노출
  static const comet = Duration(milliseconds: 900); // 화면 밖 → 슬롯, 2차 베지어 · 꼬리 6개(28ms 지연)
  static const impact = Duration(milliseconds: 900); // 플래시 35% · 링 3개(0/140/300ms, 3.4~6배) · 불꽃 22개 · 흔들림 ±2px 300ms · heavyImpact
  static const facePop = Duration(milliseconds: 960); // scale 0→1.18→1 · 밝기 3→1
  static const stamp = Duration(milliseconds: 1350); // 인장 scale 3.2, -14° → 1 · mediumImpact
  static const line = Duration(milliseconds: 1700); // 연결선 650ms (유형색 1.6px + 블러 6px)
  static const pulse = Duration(milliseconds: 2350); // 빛 점 3개 110ms 간격 → 나 링 파동 2.6배
  static const card = Duration(milliseconds: 2900); // 결과 카드 + 점수 카운트업 1.1s · 선은 흰 1px로 복귀
  static const between = Duration(milliseconds: 4700);
  static const maxSequential = 3; // 그 이상은 한 번에 페이드 인
}

/// 07 풀이 인트로 (결제 직후) — 최소 4.4초, '풀이 읽기'는 사용자가 눌러야 이동 (자동 이동 금지).
class DeepIntroTiming {
  static const stepGap = Duration(milliseconds: 1100); // 진행 문구 4줄
  static const lineDraw = Duration(milliseconds: 2400);
  static const circleSpin = Duration(seconds: 24);
}

/// 접근성: MediaQuery.disableAnimations == true 이면 유성·불꽃·흔들림·워프 생략, 페이드만.
