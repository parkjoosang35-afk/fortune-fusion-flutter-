/// [서브 디자인 통일 확산 프롬프트] 앱 전역 공용 디자인 토큰.
///
/// 홈 화면 마감 정돈 작업(`home_style_tokens.dart`)에서 확정된 색상/폰트/
/// spacing/radius/iconSize 값을 앱 전체 서브 화면(운세/커뮤니티/행복머니/
/// 마이/결과 페이지)으로 확산하기 위해 `core/theme/`로 승격한 공용 토큰이다.
///
/// 기존 전역 `AppColors`/`AppTypography`/`AppSpacing`는 값 자체가 다르고
/// (예: AppSpacing.lg=16 vs 이 파일 spaceLg=14) 216회+ 참조되는 레거시 상수라
/// 직접 변경하면 회귀 위험이 크다. 따라서 이 파일의 `UnifiedColors`/
/// `UnifiedText`/`UnifiedTokens`를 새 참조 대상으로 두고, 서브 화면 각각에서
/// 하드코딩된 색/폰트/여백을 이 토큰으로 교체해 나간다.
///
/// 값은 홈 화면과 완전히 동일하며 절대 변형하지 않는다.
library;

import 'package:flutter/material.dart';

/// 컬러 팔레트(홈 화면 최종 확정값과 완전 동일)
class UnifiedColors {
  UnifiedColors._();

  // 화면 배경
  static const Color bg = Color(0xFFFFFFFF);

  // 카드 배경(카드 종류별 지정)
  static const Color cardMain = Color(0xFFF0EEFB); // 메인/히어로 카드
  static const Color cardWish = Color(0xFFF5F3FB); // 소원게시판/소원방 계열
  static const Color cardAllMenu = Color(0xFFF3F1F9); // 전체보기/카테고리 카드
  static const Color cardBanner = Color(0xFFF2F0FA); // 배너 계열
  static const Color cardSection = Color(0xFFF6F5FA); // 결과 페이지 섹션 카드
  static const Color passBar = Color(0xFF111111); // 열림패스 바

  /// 비활성 칩 배경(카드 팔레트와 같은 계열로 통일)
  static const Color chipInactiveBg = Color(0xFFF6F5FA);

  // 포인트
  static const Color neon = Color(0xFFC6F24E); // 형광 옐로우그린(최소 사용)
  static const Color black = Color(0xFF111111); // 블랙 포인트/CTA

  // 텍스트
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B75);
  static const Color textCaption = Color(0xFF9A9AA2);

  // 테두리(사용 최소화)
  static const Color border = Color(0xFFECECEF);
}

/// 폰트 시스템(Pretendard 단일, 홈 화면과 완전 동일한 Type Scale)
class UnifiedText {
  UnifiedText._();

  static const String family = 'Pretendard';

  /// Title Large 17 / SemiBold — 화면/섹션 헤더
  static TextStyle titleLarge({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Title 15 / SemiBold — 카드/섹션 제목
  static TextStyle title({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Body Strong 14 / SemiBold — 강조 본문
  static TextStyle bodyStrong({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Body 14 / Medium — 일반 본문
  static TextStyle body({Color color = UnifiedColors.textSecondary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Body Small 13 / Medium
  static TextStyle bodySmall({Color color = UnifiedColors.textSecondary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Caption 12 / Medium — 서브 라벨/메타 정보
  static TextStyle caption({Color color = UnifiedColors.textCaption}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Label/Chip 12 / SemiBold
  static TextStyle chipLabel({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );
}

/// spacing / radius / iconSize 토큰(홈 화면과 완전 동일)
class UnifiedTokens {
  UnifiedTokens._();

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

  /// 화면 좌우 padding / 좌우 기준선(x=16)
  static const double screenPadding = 16;
}
