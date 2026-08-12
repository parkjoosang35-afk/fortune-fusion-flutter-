import 'package:flutter/material.dart';
import 'wish_room_colors.dart';

/// 신통방통 소원방 · 타이포그래피 토큰
///
/// 출처: `tokens/colors_and_type.css` 타입 스케일 + 폰트 패밀리 정의.
/// - display: Noto Serif KR (900) → `NotoSerifKRWish`
/// - body:    Gowun Batang (400/700) → `GowunBatangWish`
/// - mono:    IBM Plex Mono (400/500) → `IBMPlexMonoWish`
/// - ui:      Pretendard (앱 전역 폰트 재사용, 소원방 UI chrome 전용)
/// - hand:    Gaegu (필기체, 드문 사용) — 자산 미확보라 GowunBatangWish로 폴백
///
/// 세 폰트 패밀리(`NotoSerifKRWish`/`GowunBatangWish`/`IBMPlexMonoWish`)는
/// `pubspec.yaml`에 이미 선언되어 있고 자산도 `assets/fonts/wish_room/`에
/// 존재한다(구 소원방 삭제 시 자산은 보존했음). 신규 소원방도 동일 자산을 재사용한다.
class WishRoomText {
  WishRoomText._();

  static const fontDisplay = 'NotoSerifKRWish';
  static const fontBody = 'GowunBatangWish';
  static const fontUi = 'Pretendard';
  static const fontMono = 'IBMPlexMonoWish';
  static const fontHand = 'GowunBatangWish'; // Gaegu 자산 미확보 시 폴백

  /// Hero title — display-1: 900 34px/1.15
  static TextStyle display1(Color color) => TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w900,
    fontSize: 34,
    height: 1.15,
    letterSpacing: -0.02 * 34,
    color: color,
  );

  /// Page title — display-2: 700 26px/1.2
  static TextStyle display2(Color color) => TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.2,
    letterSpacing: -0.02 * 26,
    color: color,
  );

  /// Section header — h1: 700 22px/1.3
  static TextStyle h1(Color color) => TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.3,
    letterSpacing: -0.02 * 22,
    color: color,
  );

  /// h2: 700 18px/1.3
  static TextStyle h2(Color color) => TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 1.3,
    color: color,
  );

  /// Card title (Gowun) — h3: 700 15px/1.4
  static TextStyle h3(Color color) => TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.4,
    color: color,
  );

  /// Wish text — body: 400 15px/1.6
  static TextStyle body(Color color) => TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.6,
    color: color,
  );

  /// Buttons/chips — ui: 500 14px/1.5
  static TextStyle ui(Color color) => TextStyle(
    fontFamily: fontUi,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.5,
    color: color,
  );

  /// caption: 400 12px/1.5
  static TextStyle caption(Color color) => TextStyle(
    fontFamily: fontUi,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.5,
    color: color,
  );

  /// mono-sm: 500 10px/1.4, letter-spacing 0.3em, uppercase 규칙 적용은 호출부에서.
  static TextStyle monoSm(Color color) => TextStyle(
    fontFamily: fontMono,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    height: 1.4,
    letterSpacing: 0.3 * 10,
    color: color,
  );

  /// mono: 500 11px/1.4
  static TextStyle mono(Color color) => TextStyle(
    fontFamily: fontMono,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.4,
    letterSpacing: 0.3 * 11,
    color: color,
  );

  /// glow-text — 강조 텍스트(제목류 밑에 텍스트 섀도우처럼 쓰이던 것은
  /// Flutter에서 Shadow로 흉내내되, 기본 색상만 제공).
  static TextStyle glowText(WishRoomPaletteTokens t) =>
      TextStyle(color: t.glow);
}
