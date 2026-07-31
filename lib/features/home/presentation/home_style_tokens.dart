/// [홈 화면 최종 마감 정돈 프롬프트] 홈 화면 전용 색상/폰트/spacing/radius/iconSize 토큰.
///
/// 전역 `AppColors`/`AppTypography`/`AppSpacing`는 FortuneHubScreen/
/// CommunityHubScreen/AllCategoriesScreen/LuckyBagScreen 등 다수 화면이 이미
/// 참조하고 있어 값을 직접 바꾸면 그 화면들에 회귀가 발생한다. 이번 요청은
/// "홈 화면만" 대상으로 하므로, 사용자가 제시한 정확한 hex/px 스펙을 이 파일에
/// 홈 화면 전용 토큰으로 분리해서 정의하고 `home_screen.dart`에서만 참조한다.
library;

import 'package:flutter/material.dart';

/// 컬러 팔레트(사용자 최종 확정값, 프롬프트 B 기준)
class HomeColors {
  HomeColors._();

  // 화면 배경
  static const Color bg = Color(0xFFFFFFFF);

  // 카드 배경(카드별 지정)
  static const Color cardMain = Color(0xFFF0EEFB); // 메인 카드(오늘의 운세 이야기)
  static const Color cardWish = Color(0xFFF5F3FB); // 소원게시판/소원방(완전 동일)
  static const Color cardAllMenu = Color(0xFFF3F1F9); // 전체보기 3카드(완전 동일)
  static const Color cardBanner = Color(0xFFF2F0FA); // AI 상담 배너
  static const Color passBar = Color(0xFF111111); // 열림패스 바

  /// [판단 근거] 스펙 원문은 활성 칩 배경만 명시(#C6F24E)하고 비활성 칩 배경
  /// hex는 명시하지 않았다. 프롬프트 A의 "카드배경 기본(#F6F5FA)" 톤을 비활성
  /// 칩 배경으로 채택해 카드 팔레트와 같은 계열로 통일했다.
  static const Color chipInactiveBg = Color(0xFFF6F5FA);

  // 포인트
  static const Color neon = Color(0xFFC6F24E); // 형광 옐로우그린(최소 사용)
  static const Color black = Color(0xFF111111); // 블랙 포인트

  // 텍스트
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B75);
  static const Color textCaption = Color(0xFF9A9AA2);

  // 테두리(사용 최소화)
  static const Color border = Color(0xFFECECEF);
}

/// 폰트 시스템(Pretendard 단일, Type Scale 재확정값)
///
/// 한글 자간 -0.2 / 영숫자 자간 0 규칙은 문자열 단위로 자동 분기하지 않고
/// (혼용 텍스트가 많아 과도한 커스텀 렌더러가 필요해짐) 한글이 대부분인 홈
/// 화면 텍스트 특성상 전체에 -0.2를 일괄 적용했다. 제목류 행간 1.3 / 본문류
/// 행간 1.4 / 캡션 1.3을 정확히 반영한다.
class HomeText {
  HomeText._();

  static const String family = 'Pretendard';

  /// Title Large 17 / SemiBold — 섹션 헤더(예: "타로이야기가기")
  static TextStyle titleLarge({Color color = HomeColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Title 15 / SemiBold — 카드 제목류
  static TextStyle title({Color color = HomeColors.textPrimary}) => TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
    color: color,
  );

  /// Body Strong 14 / SemiBold — 강조 본문(열림패스 라벨 등)
  static TextStyle bodyStrong({Color color = HomeColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Body 14 / Medium — 일반 본문
  static TextStyle body({Color color = HomeColors.textSecondary}) => TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.4,
    color: color,
  );

  /// Body Small 13 / Medium
  static TextStyle bodySmall({Color color = HomeColors.textSecondary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Caption 12 / Medium — 서브 라벨/설명
  static TextStyle caption({Color color = HomeColors.textCaption}) => TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.3,
    color: color,
  );

  /// Label/Chip 12 / SemiBold — 칩 라벨(색상은 PremiumChip이 선택 상태별로 주입)
  static TextStyle chipLabel({Color color = HomeColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );
}

/// spacing / radius / iconSize 토큰(사용자 권장값 그대로)
class HomeTokens {
  HomeTokens._();

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 14;
  static const double spaceXl = 16;
  static const double spaceXxl = 20;

  static const double radiusSm = 12;
  static const double radiusMd = 14;
  static const double radiusLg = 16;
  static const double radiusPill = 24;

  static const double iconSm = 14;
  static const double iconMd = 16;
  static const double iconLg = 20;
  static const double iconXl = 22;

  static const double iconCircleSm = 26;
  static const double iconCircleMd = 28;
  static const double iconCircleLg = 32;
}
