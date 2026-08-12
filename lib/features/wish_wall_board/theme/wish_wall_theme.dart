import 'package:flutter/material.dart';

/// 신통방통 소원방(소원벽게시판) 디자인 토큰.
///
/// [디자인 히스토리] 원래 "신통방통 소원방"(구 wish_room 모듈, 화폐 시스템과
/// 함께 삭제됨)은 짙은 자정보라 배경 + 촛불금 글로우의 "심야의 신전" 팔레트를
/// 썼다. 화폐(조각) 시스템은 걷어내고 소원벽게시판(wish_wall_board, 복주머니
/// 단일 화폐)으로 통합했지만, 그 어둡고 신비로운 분위기는 다시 이 팔레트로
/// 복원한다. 앰버 액센트(#f59e0b 계열)는 그대로 유지해 촛불 느낌을 잇는다.
class WishWallColors {
  WishWallColors._();

  static const Color bg = Color(0xFF1A0D2E); // 짙은 자정보라 배경
  static const Color bg2 = Color(0xFF241A3D); // 카드/칩/컨테이너 배경
  static const Color bg3 = Color(0xFF2C2153); // 아바타/보조 배경

  /// 주 텍스트/아이콘 색(크림빛 화이트) — 밝은 배경 시절의 "ink"(짙은 잉크색)
  /// 역할을 다크 배경에서도 그대로 이어받아, 대부분의 텍스트/아이콘은 이 값을
  /// 참조하는 것만으로 자동으로 밝은 색으로 전환된다.
  static const Color ink = Color(0xFFF8F2E6);
  static const Color ink2 = Color(0xFFD8CBB8); // 보조(비활성) 텍스트
  static const Color muted = Color(0xFFC2B6DA); // 옅은 라벤더-크림 muted
  static const Color dim = Color(0xFF8F84AC); // 가장 옅은 dim
  static const Color line = Color(0x26F5EBD8); // 반투명 헤어라인
  static const Color line2 = Color(0x3DF5EBD8); // 조금 더 강한 반투명 라인

  static const Color accent = Color(0xFFF59E0B); // 촛불 앰버 (유지)
  static const Color accent2 = Color(0xFFD97706); // 짙은 앰버 (유지)
  static const Color accentSoft = Color(0x33F59E0B); // 반투명 앰버(다크 배경용)

  static const Color red = Color(0xFFEF6659);
  static const Color green = Color(0xFF34D399);
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
