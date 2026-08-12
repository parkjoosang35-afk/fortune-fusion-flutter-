import 'package:flutter/material.dart';

/// 소원벽게시판 디자인 토큰.
///
/// [handoff.zip] design/wb3-common.jsx `WB3_VARS`를 이식. 순백 배경 +
/// 앰버(#f59e0b) 단일 액센트, Pretendard 산세리프 체계.
class WishWallColors {
  WishWallColors._();

  static const Color bg = Color(0xFFFFFFFF);
  static const Color bg2 = Color(0xFFFAFAFA);
  static const Color bg3 = Color(0xFFF5F5F5);
  static const Color ink = Color(0xFF0A0A0A);
  static const Color ink2 = Color(0xFF262626);
  static const Color muted = Color(0xFF737373);
  static const Color dim = Color(0xFFA3A3A3);
  static const Color line = Color(0xFFEAEAEA);
  static const Color line2 = Color(0xFFD4D4D4);

  static const Color accent = Color(0xFFF59E0B);
  static const Color accent2 = Color(0xFFD97706);
  static const Color accentSoft = Color(0xFFFEF3C7);

  static const Color red = Color(0xFFEF4444);
  static const Color green = Color(0xFF10B981);
}

/// Pretendard 기반 텍스트 스타일 헬퍼(핸드오프 문서의 타이포 스케일 요약).
class WishWallText {
  WishWallText._();

  static const String family = 'Pretendard';

  static TextStyle display() => const TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w800,
        fontSize: 40,
        letterSpacing: -0.8,
        color: WishWallColors.ink,
      );

  static TextStyle title1() => const TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w800,
        fontSize: 26,
        letterSpacing: -0.6,
        color: WishWallColors.ink,
      );

  static TextStyle title2() => const TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w800,
        fontSize: 22,
        letterSpacing: -0.4,
        color: WishWallColors.ink,
      );

  static TextStyle bodyLarge({Color? color}) => TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w500,
        fontSize: 20,
        letterSpacing: -0.4,
        color: color ?? WishWallColors.ink,
        height: 1.5,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        letterSpacing: -0.2,
        color: color ?? WishWallColors.ink,
      );

  static TextStyle label({Color? color}) => TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: -0.2,
        color: color ?? WishWallColors.ink,
      );

  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: color ?? WishWallColors.muted,
      );

  static TextStyle mono({Color? color}) => TextStyle(
        fontFamily: 'JetBrains Mono',
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1,
        color: color ?? WishWallColors.accent2,
      );
}
