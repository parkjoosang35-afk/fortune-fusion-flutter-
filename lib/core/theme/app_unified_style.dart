/// [서브 디자인 통일 확산 프롬프트] 앱 전역 공용 디자인 토큰.
///
/// 홈 화면 마감 정돈 작업(`home_style_tokens.dart`)에서 확정된 색상/폰트/
/// spacing/radius/iconSize 값을 앱 전체 서브 화면(운세/커뮤니티/복주머니/
/// 마이/결과 페이지)으로 확산하기 위해 `core/theme/`로 승격한 공용 토큰이다.
///
/// 기존 전역 `AppColors`/`AppTypography`/`AppSpacing`는 값 자체가 다르고
/// (예: AppSpacing.lg=16 vs 이 파일 spaceLg=14) 216회+ 참조되는 레거시 상수라
/// 직접 변경하면 회귀 위험이 크다. 따라서 이 파일의 `UnifiedColors`/
/// `UnifiedText`/`UnifiedTokens`를 새 참조 대상으로 두고, 서브 화면 각각에서
/// 하드코딩된 색/폰트/여백을 이 토큰으로 교체해 나간다.
///
/// [다크 전환 — 2026-10-13 사용자 피드백] 서브 화면(지갑·알림·마이·
/// 결과 등)이 흰 바탕이라 메인페이지(다크)와 이어지지 않는 문제를 해결하기
/// 위해 팔레트를 메인페이지 톤(bg #0B0B0D + 카드 #161618 계열 + 밝은 글자)
/// 으로 통일했다. 개별 화면의 하드코딩 색은 별도 과제로 남긴다.
///
/// [폰트 중앙화 — 2026-11 마이페이지 B시안 폰트 테이블 적용]
/// "신통방통 전체를 선명하고 진하게" 요청에 대응해, 폰트 패밀리/굵기를
/// 이 파일 한 곳에서만 정의하고 화면들은 전부 이 토큰을 참조하도록 한다.
/// 적용 규칙(사용자 제공 폰트 표 기준):
///   - Pretendard 800(ExtraBold): 페이지 타이틀("마이" 등)/이름/섹션
///     제목/카드 제목/버튼 — 기존 600에서 상향(더 굵고 선명하게).
///   - Pretendard 900(Black, 신규 추가): 지갑 "38개" 같은 큰 숫자/강조
///     수치 전용. `assets/fonts/Pretendard-Black.otf`
///     (orioncactus/pretendard 공식 배포본, OFL 1.1 — 상업적 이용 무료).
///   - Pretendard 600~700: 메뉴 아이템 이름/보조 설명 — 기존 500에서 상향.
///   - NotoSerifKR 900: 한자 아이콘 글자(塔 觀 掌 錄 藏 緣 願 福 印 券 符
///     瑞 銅 등) 전용. 본문/서사 텍스트에는 사용하지 않는다(기존
///     GowunBatang 본문체는 이번 1차 적용 범위에서 제외 — 별도 확인 필요).
///   - IBMPlexMono 500: 날짜 라벨("2026 · 11 · 05")/쿠폰 코드 입력 전용.
library;

import 'package:flutter/material.dart';

/// 컬러 팔레트(홈 화면 최종 확정값과 완전 동일)
class UnifiedColors {
  UnifiedColors._();

  // 화면 배경
  static const Color bg = Color(0xFF0B0B0D); // [다크 전환 — 사용자 피드백] 메인페이지와 동일 배경

  // 카드 배경(카드 종류별 지정)
  static const Color cardMain = Color(0xFF1C1C1F); // 메인/히어로 카드 [다크 전환]
  static const Color cardWish = Color(0xFF161618); // 소원게시판/소원방 계열 [다크 전환]
  static const Color cardAllMenu = Color(0xFF1A1A1E); // 전체보기/카테고리 카드 [다크 전환]
  static const Color cardBanner = Color(0xFF19191D); // 배너 계열 [다크 전환]
  static const Color cardSection = Color(0xFF161618); // 결과 페이지 섹션 카드 [다크 전환]
  static const Color passBar = Color(0xFF111111); // 열림패스 바

  /// 비활성 칩 배경(카드 팔레트와 같은 계열로 통일)
  static const Color chipInactiveBg = Color(0xFF1C1C1F); // [다크 전환]

  // 포인트
  static const Color neon = Color(0xFFC6F24E); // 형광 옐로우그린(최소 사용)
  static const Color black = Color(0xFFE9C46A); // [다크 전환] CTA → 골드 포인트

  // 텍스트
  static const Color textPrimary = Color(0xFFF2F0EC); // [다크 전환] 밝은 글자
  static const Color textSecondary = Color(0xFFB9B5AC); // [다크 전환]
  static const Color textCaption = Color(0xFF8A8880); // [다크 전환]

  // 테두리(사용 최소화)
  static const Color border = Color(0xFF2A2A2E); // [다크 전환]
}

/// 폰트 시스템 — 앱 전체 타이포그래피 "중앙 설정".
///
/// family: Pretendard(UI 전반) / NotoSerifKR(한자 아이콘 전용) /
/// IBMPlexMono(날짜·코드 전용). 이 3개 외 폰트(GowunBatang 등)는 쓰지 않는다.
/// 굵기(FontWeight)는 전부 이 클래스의 named style을 통해서만 정하고,
/// 화면 코드에서 `fontFamily:`/`FontWeight:`를 직접 하드코딩하지 않는다.
/// → 나중에 굵기/폰트를 다시 바꿀 일이 생기면 이 파일만 고치면 된다.
class UnifiedText {
  UnifiedText._();

  static const String family = 'Pretendard';
  static const String hanjaFamily = 'NotoSerifKR';
  static const String monoFamily = 'IBMPlexMono';

  /// Title Large 17 / ExtraBold(800) — 페이지 타이틀("마이" 등)/화면 헤더.
  /// [폰트 중앙화] 기존 600 → 800으로 상향(더 굵고 선명하게).
  static TextStyle titleLarge({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Title 15 / ExtraBold(800) — 카드/섹션 제목, 이름.
  /// [폰트 중앙화] 기존 600 → 800으로 상향.
  static TextStyle title({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Number Strong — 지갑 "38개"/적립 "+3" 같은 큰 강조 숫자 전용.
  /// Pretendard 900(Black). size는 호출부에서 필요에 맞게 override.
  static TextStyle numberStrong({
    Color color = UnifiedColors.textPrimary,
    double fontSize = 22,
  }) => TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    height: 1.2,
    color: color,
  );

  /// Body Strong 14 / Bold(700) — 버튼 라벨, 메뉴 아이템 이름.
  /// [폰트 중앙화] 기존 600 → 700으로 상향.
  static TextStyle bodyStrong({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Body 14 / SemiBold(600) — 일반 본문/보조 설명.
  /// [폰트 중앙화] 기존 500 → 600으로 상향.
  static TextStyle body({Color color = UnifiedColors.textSecondary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Body Small 13 / SemiBold(600).
  /// [폰트 중앙화] 기존 500 → 600으로 상향.
  static TextStyle bodySmall({Color color = UnifiedColors.textSecondary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  /// Caption 12 / SemiBold(600) — 서브 라벨/메타 정보.
  /// [폰트 중앙화] 기존 500 → 600으로 상향.
  static TextStyle caption({Color color = UnifiedColors.textCaption}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Label/Chip 12 / Bold(700).
  /// [폰트 중앙화] 기존 600 → 700으로 상향.
  static TextStyle chipLabel({Color color = UnifiedColors.textPrimary}) =>
      TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// 한자 아이콘 전용(塔 觀 掌 錄 藏 緣 願 福 印 券 符 瑞 銅 등).
  /// NotoSerifKR 900(Black). 본문/서사 텍스트에는 사용하지 않는다.
  static TextStyle hanjaIcon({
    Color color = UnifiedColors.textPrimary,
    double fontSize = 20,
  }) => TextStyle(
    fontFamily: hanjaFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    height: 1.0,
    color: color,
  );

  /// 날짜 라벨("2026 · 11 · 05")/쿠폰 코드 입력 전용. IBMPlexMono 500.
  static TextStyle monoLabel({
    Color color = UnifiedColors.textSecondary,
    double fontSize = 12,
  }) => TextStyle(
    fontFamily: monoFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
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
