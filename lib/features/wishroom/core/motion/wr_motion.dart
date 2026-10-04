// 신통방통 소원방 · Motion tokens (wishroom.css keyframes 1:1)
// 규칙: 크롬 애니메이션 ≥ 1s, 스프링 바운스 버튼 금지. 파티클만 빠르게.
import 'package:flutter/animation.dart';

class WrCurves {
  static const out = Cubic(0.22, 1, 0.36, 1);        // 기본 진입
  static const overshoot = Cubic(0.34, 1.56, 0.64, 1); // sigil-draw, pop-in, stamp, bloom
  static const door = Cubic(0.7, 0, 0.3, 1);          // 문 개방, 봉인 수축
}

class WrDur {
  // A · 상시
  static const flameFlicker = Duration(milliseconds: 2600);
  static const haloPulse = Duration(milliseconds: 3400);
  static const glowPulse = Duration(milliseconds: 2400);
  static const moonPulse = Duration(seconds: 6);
  static const sigilSlow = Duration(seconds: 120);
  static const sigilMid = Duration(seconds: 60);
  static const sigilFast = Duration(seconds: 30);
  static const breathe = Duration(milliseconds: 4200);
  static const blink = Duration(seconds: 5);
  static const lanternSway = Duration(seconds: 5);
  static const bellSway = Duration(milliseconds: 3600);
  static const firefly = [Duration(seconds: 9), Duration(seconds: 12)];
  static const cloud = [Duration(seconds: 38), Duration(seconds: 54)];
  // B · 진입
  static const screen = Duration(milliseconds: 900);
  static const inkAppear = Duration(milliseconds: 1400);
  static const cameraIn = Duration(milliseconds: 2200);
  static const sheet = Duration(milliseconds: 500);
  // §3 Intro — 원본 screens-a2.jsx › Intro() setTimeout 체인과 1:1 일치시킨 값.
  // full: 1000(스킵표시) → 1100(st1) → 2000(st2:문) → 3100(st3:리빌) → 4600(finish)
  // short: 700(st3) → 1500(finish)
  static const introFull = Duration(milliseconds: 4600); // §3 (원본과 일치하도록 수정됨 — 기존 3500ms는 오기)
  static const introFullSt1 = Duration(milliseconds: 1100);
  static const introFullSt2 = Duration(milliseconds: 2000);
  static const introFullSt3 = Duration(milliseconds: 3100);
  static const introShort = Duration(milliseconds: 1500); // (원본과 일치하도록 수정됨 — 기존 1200ms는 오기)
  static const introShortSt3 = Duration(milliseconds: 700);
  static const introSkipShowAfter = Duration(seconds: 1);
  static const doorOpen = Duration(milliseconds: 1300);
  static const doorDelayFull = Duration(milliseconds: 1700);
  // C · 행동
  static const burst = Duration(milliseconds: 1200);
  static const heartRise = Duration(milliseconds: 2200);
  // [버그수정 — 전수감사] app2/fx2.jsx › LevelUp(): setTimeout(onDone, level===10?5600:3800).
  // 기존 4200/6200ms는 원본과 불일치(오기)였음.
  static const levelUp = Duration(milliseconds: 3800);
  static const levelUpLv10 = Duration(milliseconds: 5600);
  static const toast = Duration(milliseconds: 2600);
  static const push = Duration(milliseconds: 4200);
}

/// §6.1 정성 들이기 타임라인 — docs/screens/A_인트로_작성_메인.md `devote()` 표 1:1.
/// t=0.0 shake+wash+ring3+gold버스트26+꽃잎버스트10(POST) · 0.3 boost1 · 0.7 burst18+spiral+plus-up+(아이템보너스)
/// · 1.1 꽃잎22+나비4 · 1.7 boost2+wash+RITUAL.done캡션 · 2.3 말씀카드 · 2.9 연출끝.
class DevotionTimeline {
  static const shake = Duration.zero;                 // 0.0 — 흔들림+wash+ring+버스트, POST 요청
  static const boost1 = Duration(milliseconds: 300);  // 0.3 — 촛불 광원 300→470
  static const burst2 = Duration(milliseconds: 700);  // 0.7 — 버스트18+빛나선+plus-up+아이템보너스
  static const petal = Duration(milliseconds: 1100);  // 1.1 — 꽃잎22+나비4
  static const boost2 = Duration(milliseconds: 1700); // 1.7 — boost2+wash+RITUAL.done
  static const quote = Duration(milliseconds: 2300);  // 2.3 — 말씀 카드
  static const end = Duration(milliseconds: 2900);    // 2.9 — 연출 끝
  static const lightBoost = 0.15;
}

/// §6.2 촛불 다시 밝히기
class RekindleTimeline {
  static const spark = Duration(milliseconds: 600), grow = Duration(milliseconds: 1300), bloom = Duration(milliseconds: 2100), end = Duration(milliseconds: 3400);
  static const brightness = {'dark': .06, 'spark': .14, 'grow': .7, 'bloom': 1.0};
}

/// §14.1 완료 연출
class CompleteTimeline {
  static const steps = [600, 1600, 2600, 3600, 4600, 5600]; // 촛불max → 황금빛 → 개화 → 빛상승 → 축하 → 문구
}

/// §13.3 성능 예산
class WrPerf {
  static const maxParticles = 80, maxParticlesLow = 40, targetFps = 60, lowFps = 30;
}
