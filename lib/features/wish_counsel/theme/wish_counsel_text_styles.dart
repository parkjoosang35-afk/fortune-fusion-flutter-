import 'package:flutter/material.dart';
import 'wish_counsel_colors.dart';

/// 상담(Midnight Comfort) · 타이포그래피 토큰
///
/// 출처: `handoff/04_DESIGN_TOKENS.md` §2. Noto Serif KR/Gowun Batang/
/// IBM Plex Mono 폰트는 이미 `wish_room` 모듈이 pubspec.yaml에 등록해 둔
/// 전역 폰트 패밀리(`NotoSerifKRWish`/`GowunBatangWish`/`IBMPlexMonoWish`)를
/// 그대로 재사용한다(중복 등록 방지, 폰트 패밀리명은 앱 전역에서 유일하면
/// 어느 feature에서든 참조 가능). UI 크롬(버튼/칩/라벨)은 앱 전역
/// `Pretendard`를 사용한다.
class WishCounselText {
  WishCounselText._();

  static const String display = 'NotoSerifKRWish';
  static const String body = 'GowunBatangWish';
  static const String ui = 'Pretendard';
  static const String mono = 'IBMPlexMonoWish';

  static TextStyle display1({Color color = WishCounselColors.fg}) =>
      TextStyle(
        fontFamily: display,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 1.3,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle display2({Color color = WishCounselColors.fg}) =>
      TextStyle(
        fontFamily: display,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.35,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle title({Color color = WishCounselColors.fg}) => TextStyle(
        fontFamily: ui,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        height: 1.3,
        color: color,
      );

  static TextStyle heading({Color color = WishCounselColors.fg}) => TextStyle(
        fontFamily: ui,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.4,
        color: color,
      );

  static TextStyle bodyText({Color color = WishCounselColors.fg, double size = 14}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: 1.7,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle bodySmall({Color color = WishCounselColors.fg2}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 1.6,
        color: color,
      );

  static TextStyle caption({Color color = WishCounselColors.fg2}) =>
      TextStyle(
        fontFamily: ui,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 1.5,
        color: color,
      );

  static TextStyle uiLabel({Color color = WishCounselColors.fg, double size = 14}) =>
      TextStyle(
        fontFamily: ui,
        fontWeight: FontWeight.w600,
        fontSize: size,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle monoLabel({Color color = WishCounselColors.fg2}) =>
      TextStyle(
        fontFamily: mono,
        fontWeight: FontWeight.w500,
        fontSize: 10,
        letterSpacing: 1.4,
        color: color,
      );
}
