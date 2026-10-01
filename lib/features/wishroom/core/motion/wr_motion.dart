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
  static const introFull = Duration(milliseconds: 3500); // §3
  static const introShort = Duration(milliseconds: 1200);
  static const introSkipShowAfter = Duration(seconds: 1);
  static const doorOpen = Duration(milliseconds: 1300);
  static const doorDelayFull = Duration(milliseconds: 1700);
  // C · 행동
  static const burst = Duration(milliseconds: 1200);
  static const heartRise = Duration(milliseconds: 2200);
  static const levelUp = Duration(milliseconds: 4200);
  static const levelUpLv10 = Duration(milliseconds: 6200);
  static const toast = Duration(milliseconds: 2600);
  static const push = Duration(milliseconds: 4200);
}

/// §6.1 정성 들이기 타임라인
class DevotionTimeline {
  static const shake = Duration.zero;                        // 흔들림 + POST
  static const flame = Duration(milliseconds: 400);          // 불꽃 1.3배
  static const dust = Duration(milliseconds: 800);           // 빛가루 12~20
  static const petal = Duration(milliseconds: 1200);         // 꽃잎 · 레벨업 판정
  static const light = Duration(milliseconds: 1800);         // 광량 +15% · 문구
  static const end = Duration(milliseconds: 2600);
  static const flameBoost = 1.3, lightBoost = 0.15, dustCount = 18, petalCount = 16;
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
