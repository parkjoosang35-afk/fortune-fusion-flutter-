import 'package:flutter/material.dart';

/// 03단계 UX/UI 설계서 §2 디자인 시스템 토큰 - Color 구체화
/// Primary: 브랜드 보라/남색 계열(운세/신비 컨셉)
/// Secondary: 행복머니/리워드 강조색(골드/옐로)
///
/// [웹→앱 이식] "신통방통" 모바일웹의 "신비롭고 고급스러운 밤하늘(검정·남색·보라·금색)"
/// 디자인 시스템 팔레트를 그대로 이식하여 다크 테마를 기본 정체성으로 승격한다.
/// (참고: 신통방통 css/style.css :root 변수 --bg-deep/--bg-navy/--purple/--gold 등)
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // [운세 앱 개발 프롬프트-메인 UI 리뉴얼] 현대카드 앱 스타일 팔레트
  // 참고 스크린샷(신통방통 x 현대카드 앱) 정밀 색상 추출값.
  // 메인 홈 화면(라이트 모드)의 1차 소스오브트루스로 사용하고,
  // 기존 신비 컨셉 다크 팔레트(deepSpace 등)는 결과화면/리추얼 등에서 계속 활용.
  // ══════════════════════════════════════════════════════════════
  // [Sowoon.kr 리디자인 프롬프트] 골드 액센트 팔레트로 전환(퍼플→골드).
  // 기존 hcPurple*는 하위호환을 위해 값만 유지하되, 메인 화면/전역 테마에서는
  // 더 이상 참조하지 않는다(레거시).
  static const Color hcPurple = Color(0xFF5E17EB); // (레거시, 미사용)
  static const Color hcPurpleContainer = Color(0xFFEAEAFF); // (레거시, 미사용)

  /// 액센트: 블루/바이올렛 계열 (레퍼런스 스크린샷 기반 리디자인)
  /// (이름은 하위호환을 위해 hcGold*로 유지하되 실제 색상값은 블루/바이올렛)
  static const Color hcGold = Color(0xFF5F39F8); // 텍스트 강조/아이콘
  static const Color hcGoldDark = Color(0xFF4B2AE0); // 버튼/선택 상태 등 진한 톤
  static const LinearGradient hcGoldGradient = LinearGradient(
    colors: [hcGold, hcGoldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 배지 연한 배경(라벤더) - 액센트 컬러 전용 소프트 배경
  static const Color hcAccentSoft = Color(0xFFEEEBFF);

  /// 텍스트: 검은색/진한 회색 계열
  static const Color hcTextDark = Color(0xFF1A1A1A); // 헤드라인/타이틀
  static const Color hcTextBody = Color(0xFF333333); // 본문/AppBar 텍스트

  /// 경계선/구분선: 라이트 그레이
  static const Color hcBorderLight = Color(0xFFEEEEEE);
  static const Color hcBorderLight2 = Color(0xFFF5F5F5);

  /// 배지 배경: 라이트 라벤더(액센트 소프트 톤)
  static const Color hcCream = Color(0xFFEEEBFF);
  static const Color hcCream2 = Color(0xFFF7F5FF);

  /// 카드 그림자: 밝은 그레이(미세함, rgba(0,0,0,0.08))
  static const Color hcCardShadow = Color(0x14000000);

  static const Color hcInk = Color(
    0xFF14121F,
  ); // CTA 버튼 배경(다크 네이비/블랙) - 레퍼런스 스크린샷 기준
  static const Color hcCardBg = Color(0xFFFFFFFF); // 카드 배경(화이트 + 라이트그레이 경계)
  static const Color hcCardBg2 = Color(0xFFF5F5F5); // 운세 메뉴 그리드 카드 배경(라이트 그레이)
  static const Color hcBackground = Color(0xFFFFFFFF); // 전체 배경(순백색)
  static const Color hcAmber = Color(0xFFFF9500); // "인기" 배지(별도 강조 색상)
  static const Color hcTextSecondary = Color(0xFF666666); // 보조/설명 텍스트
  static const Color hcBrownStart = Color(0xFF472D1E); // 소원방 배너 그라디언트 시작
  static const Color hcBrownEnd = Color(0xFF2C1A10); // 소원방 배너 그라디언트 끝

  static const LinearGradient hcWishRoomGradient = LinearGradient(
    colors: [hcBrownStart, hcBrownEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 운세 메뉴 그리드 아이콘 원형(화이트) 안에 들어가는 아이콘 색상(카테고리별 소프트 틴트)
  /// - 카드 배경 자체는 통일된 라이트 그레이(hcCardBg2)를 사용하고, 아이콘만 행복머니 컬러로.
  static const Map<String, Color> hcCategoryIconColor = {
    'daily': Color(0xFFFF9500),
    'saju': hcGoldDark,
    'tarot': hcGold,
    'compatibility': Color(0xFFFF3B69),
    'zodiac': Color(0xFFE8B400),
    'palm': Color(0xFF8A8A8E),
    'face': Color(0xFFE8935A),
    'yearly': Color(0xFF8A8A8E),
  };

  // ── Primary (보라/남색 - 신비/운세 컨셉) ──
  // 신통방통 --purple 계열로 정밀 조정
  static const Color primary = Color(0xFF7B4FD1); // --purple
  static const Color primaryDark = Color(0xFF4A2A8C); // --purple-deep
  static const Color primaryLight = Color(0xFFA97CF0); // --purple-light
  static const Color primaryContainer = Color(0xFFEDE7FF);

  // 배경 그라디언트(신비로운 밤하늘 느낌) - 신통방통 --bg-deep/--bg-navy
  static const Color deepSpace = Color(0xFF05040F); // --bg-deep
  static const Color deepSpaceLight = Color(0xFF161335); // --bg-navy-2

  // ── Secondary (골드/옐로 - 행복머니/리워드) ──
  // 신통방통 --gold 계열로 정밀 조정
  static const Color secondary = Color(0xFFE0B356); // --gold
  static const Color secondaryDark = Color(0xFFA9772F); // --gold-deep
  static const Color secondaryLight = Color(0xFFF5D992); // --gold-light

  // ── Semantic ──
  static const Color success = Color(0xFF5FE3B3); // --success
  static const Color warning = Color(0xFFFFA940);
  static const Color error = Color(0xFFFF6B8B); // --danger
  static const Color info = Color(0xFF4DA8FF);

  // ── Neutral (라이트 모드) ──
  static const Color background = Color(0xFFF7F5FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E1A2B);
  static const Color textSecondary = Color(0xFF6E6880);
  static const Color textHint = Color(0xFFACA8BD);
  static const Color divider = Color(0xFFEAE6F5);

  // ── Dark surfaces (결과화면 등 신비 컨셉 강조 영역) ──
  static const Color onDeepSpace = Color(0xFFF5F2FF);

  static const LinearGradient mysticGradient = LinearGradient(
    colors: [deepSpace, primaryDark, deepSpaceLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [secondaryLight, secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 신통방통 --gradient-purple 이식 - 보조 보라 그라디언트(부적/매칭 등 강조 영역)
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [primaryDark, primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark mode neutrals (07단계 §10 신규, 신통방통 팔레트로 정밀 조정) ──
  // [Fortune Fusion UI 리뉴얼 프롬프트] 웹 프로토타입(딥네이비+골드/퍼플 우주 감성)
  // 톤에 맞춰 다크 팔레트 값을 우주 감성 색상으로 갱신한다.
  // (이 상수들은 app_theme.dart의 dark ThemeData 생성에만 쓰이고, 화면 코드에서
  // 직접 참조되는 곳은 없어 값 변경이 다른 화면에 영향을 주지 않는다)
  static const Color backgroundDark = Color(0xFF0B0B1E); // = bgPrimary
  static const Color surfaceDark = Color(0xFF13132B); // = bgSecondary (카드 배경)
  static const Color surfaceDark2 = Color(0xFF1E1E3F); // = bgTertiary (서브 카드)
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB8B8D4);
  static const Color textHintDark = Color(0xFF7A7A9C);
  static const Color textDimDark = Color(0xFF4A4A6E);
  static const Color dividerDark = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
  static const Color primaryContainerDark = Color(
    0x339D7BFF,
  ); // accentPurple 20%

  /// 신통방통 --gradient-card 이식 - 다크 모드 카드 표면(옅은 화이트 오버레이 그라디언트)
  /// 배경 위에 얹어 미세한 유리질감(glass-card)을 표현할 때 사용.
  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0x0FFFFFFF), Color(0x03FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 다크 모드 카드 보더(은은한 화이트 테두리) - 신규 우주 팔레트 border와 동일 값
  static const Color cardBorderDark = Color(0x1AFFFFFF);

  /// 골드 글로우 보더 - 강조 카드(오늘의 운세, CTA 등)
  static const Color goldGlowBorder = Color(0x3AFFD700);

  // ══════════════════════════════════════════════════════════════
  // [Fortune Fusion UI 리뉴얼 프롬프트] 🌌 우주 감성 팔레트 (신규)
  // 웹 프로토타입 톤 매칭. CosmicCard/StarryBackground/HeroFortuneCard 등
  // 신규 Presentation 위젯 전용으로 추가하는 토큰들이며, 기존 토큰(primary,
  // secondary, textPrimary 등)은 하위호환을 위해 그대로 유지한다.
  // ══════════════════════════════════════════════════════════════
  // 배경 (딥 네이비 → 자정 하늘)
  static const Color bgPrimary = Color(0xFF0B0B1E); // 최상위 배경
  static const Color bgSecondary = Color(0xFF13132B); // 카드 배경
  static const Color bgTertiary = Color(0xFF1E1E3F); // 서브 카드
  static const Color bgElevated = Color(0xFF252547); // 떠있는 요소

  // 행복머니 컬러 (우주 별빛)
  static const Color accentGold = Color(0xFFFFD700); // 행복머니 🍀
  static const Color accentPurple = Color(0xFF9D7BFF); // 신비/타로
  static const Color accentPink = Color(0xFFFF6B9D); // 소원/감성
  static const Color accentBlue = Color(0xFF4DA6FF); // 운세/미션
  static const Color accentMint = Color(0xFF6EE7B7); // 완료/성공

  // 그라디언트 (히어로 카드용)
  static const LinearGradient gradientCosmic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E3F), Color(0xFF3D2A5F), Color(0xFF1E1E3F)],
  );
  static const LinearGradient gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
  );
  static const LinearGradient gradientWish = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B9D), Color(0xFF9D7BFF)],
  );

  // 카드 테두리 (은은한 별빛)
  static const Color border = Color(0x1AFFFFFF); // 흰색 10%
  static const Color borderStrong = Color(0x33FFFFFF); // 흰색 20%

  // 텍스트(우주 감성 다크 전용) - 기존 textPrimary/textSecondary(라이트 고정값)와
  // 이름이 충돌하여 그대로 재사용할 수 없으므로 cosmicText* 이름으로 노출한다.
  // 값 자체는 위 textPrimaryDark/textSecondaryDark/textHintDark/textDimDark와 동일.
  static const Color cosmicTextPrimary = textPrimaryDark; // 0xFFFFFFFF
  static const Color cosmicTextSecondary = textSecondaryDark; // 0xFFB8B8D4
  static const Color cosmicTextTertiary = textHintDark; // 0xFF7A7A9C
  static const Color cosmicTextDim = textDimDark; // 0xFF4A4A6E

  // ── 브랜드 컬러 네이밍 체계 별칭 (03단계 §3.1 신규) ──
  // 기존 상수와 값은 동일, "무엇을 위한 색인지" 브랜드 언어로 재노출한다.
  // 코드 마이그레이션 부담 없이 신규 화면부터 아래 이름을 우선 사용할 것을 권장.
  static const Color mysticPurple = primary; // 신비/사주·타로 컨셉 대표색
  static const Color premiumGold = secondary; // 행복머니/리워드/구독 프리미엄
  static const Color fortuneBlue = info; // 신뢰/정보 전달(AI상담, 안내)
  static const Color hopeGreen = success; // 희망/긍정/완료

  // ── 다크모드 대응 컨텍스트 헬퍼 (07단계 §10 보강) ──
  // 화면 곳곳에서 AppColors.textHint/textSecondary/primaryContainer 등을
  // 다크모드에서도 자동으로 올바른 톤을 쓰도록 하는 컨텍스트 인지형 접근자.
  // 기존 상수(라이트 고정값)는 하위호환을 위해 유지하고, 신규/수정 코드는
  // 아래 *Of(context) 헬퍼 사용을 권장한다.
  static Color textHintOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textHintDark : textHint;
  }

  static Color textSecondaryOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textSecondaryDark : textSecondary;
  }

  static Color textPrimaryOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textPrimaryDark : textPrimary;
  }

  /// 아이콘 원형 배지 등의 컨테이너 배경 - 다크모드에서는 옅은 보라 대신
  /// 카드보다 살짝 밝은 반투명 화이트(신통방통 유리질감)를 사용한다.
  static Color containerOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0x1FA97CF0) : primaryContainer;
  }

  static Color dividerOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dividerDark : divider;
  }

  /// 오늘의 행운 색상(Luck Color) 후보 팔레트 — 03단계 §3.1
  /// `daily_fortunes.lucky_color`(문자열, 예: "보라") 값을 실제 색상으로 매핑할 때 사용.
  /// 홈 리추얼 배너(§14)에서 중복 정의되어 있던 팔레트를 이곳으로 중앙화.
  static const Map<String, Color> luckColorPalette = {
    '보라': primaryLight,
    '골드': secondary,
    '블루': info,
    '그린': success,
  };

  // ══════════════════════════════════════════════════════════════
  // [Fortune Fusion 디자인 우선 리디자인 프롬프트] ✨ 화이트 프리미엄 팔레트 (신규)
  //
  // 기존 다크 "우주(Cosmic)" 팔레트(bgPrimary/cosmicText* 등, 위 §섹션)는
  // FortuneHub/CommunityHub/LuckyBag/My 등 아직 손대지 않는 화면들이 광범위하게
  // 참조하고 있어(12개 파일) 값 자체를 바꾸면 그 화면들이 깨진다. 따라서 값을
  // 덮어쓰지 않고, 이번 리디자인 대상(HomeScreen/공통위젯 신규분/하단탭)에서만
  // 사용할 새 "Premium*" 이름의 화이트 베이스 상수를 별도로 추가한다.
  // 다음 턴 이후 화면별로 점진적으로 이 팔레트로 옮겨갈 수 있다.
  // ══════════════════════════════════════════════════════════════

  // ── 배경 ──
  static const Color premiumBgMain = Color(0xFFFCFBFF); // Main Background
  static const Color premiumBgSection = Color(0xFFFFFFFF); // Section Background
  static const Color premiumBgSubtle = Color(0xFFF7F4FF); // Subtle Surface(연라벤더)
  static const Color premiumBgSecondary = Color(0xFFF9FAFC); // Secondary Surface(연회색)

  // ── 텍스트 ──
  static const Color premiumTextPrimary = Color(0xFF17181C);
  static const Color premiumTextSecondary = Color(0xFF6B7280);
  static const Color premiumTextTertiary = Color(0xFF9CA3AF);

  // ── 행복머니 컬러 ──
  static const Color premiumMainPurple = Color(0xFF6F5BFF);
  static const Color premiumSoftLavender = Color(0xFFEAE5FF);
  static const Color premiumDeepNavy = Color(0xFF1F2340);
  static const Color premiumSoftGold = Color(0xFFF6C453);
  static const Color premiumMintAccent = Color(0xFFBDEFE1);
  static const Color premiumCoralAccent = Color(0xFFFF8FA3); // 약하게만 사용

  // ── 보더 ──
  static const Color premiumLightBorder = Color(0xFFECE8F5);
  static const Color premiumCardBorder = Color(0xFFEFEAF7);

  /// 히어로 카드용 은은한 퍼플 그라디언트(화이트 → 연라벤더)
  static const LinearGradient premiumHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [premiumBgSection, premiumSoftLavender],
  );

  /// Primary CTA 그라디언트(딥네이비 → 메인퍼플) — 과하지 않게 살짝만.
  static const LinearGradient premiumCtaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [premiumDeepNavy, premiumMainPurple],
  );

  /// 골드 톤(행복머니/보상) 전용 은은한 그라디언트
  static const LinearGradient premiumGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBE0A6), premiumSoftGold],
  );

  /// 카드 은은한 그림자(다크 그림자 대신 아주 연한 퍼플 톤)
  static const Color premiumCardShadow = Color(0x146F5BFF);

  // ══════════════════════════════════════════════════════════════
  // [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] ⚡ 액센트 확장 (신규)
  //
  // 첨부 기준 시안(화이트+소프트퍼플카드+블랙CTA+네온옐로우그린 행복머니) 반영.
  // 기존 premiumCtaGradient(네이비→퍼플)는 홈 화면에서 계속 쓰이므로 값을
  // 바꾸지 않고, "블랙 CTA" 및 "네온 라임" 전용 신규 토큰만 별도로 추가한다.
  // 이번 턴부터 서브 허브 화면(운세/행복머니/커뮤니티)은 아래 토큰을 사용한다.
  // ══════════════════════════════════════════════════════════════

  /// 메인 블랙 CTA 배경(순수 블랙에 가까운 다크) - 첨부 시안의 "+ 오늘의 운세보기" 버튼.
  static const Color premiumBlackCta = Color(0xFF121212);

  /// 행복머니 액션 전용 네온 옐로우그린(형광) - 선택된 칩 / 원형 액션 버튼 / 상태 강조.
  static const Color premiumNeonLime = Color(0xFFD2F547);

  /// 네온 라임 위에 올라가는 텍스트/아이콘 색상(항상 다크 톤 대비).
  static const Color premiumNeonLimeOnColor = Color(0xFF17181C);

  /// 비활성 칩 / 보조 정보용 연회색.
  static const Color premiumInactiveGrey = Color(0xFFF0F0F0);
  static const Color premiumInactiveGreyText = Color(0xFF6B6B6F);

  // ══════════════════════════════════════════════════════════════
  // [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 홈 화면 기준 시안 전용 (신규)
  //
  // 첨부 홈 화면 목업(화이트+블랙CTA+인디고 히어로카드+네온라임 원형버튼) 정밀 색상
  // 추출값. 기존 premiumHeroGradient(화이트→연라벤더)는 다른 화면에서 계속 쓰이므로
  // 값을 바꾸지 않고, 홈 히어로카드 전용 진한 인디고 그라디언트를 별도로 추가한다.
  // ══════════════════════════════════════════════════════════════
  static const Color premiumIndigoStart = Color(0xFF5E5AD2);
  static const Color premiumIndigoEnd = Color(0xFF5853C2);

  /// 홈 화면 "오늘의 운세 이야기" 히어로카드 전용 진한 인디고 그라디언트.
  static const LinearGradient premiumIndigoHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [premiumIndigoStart, premiumIndigoEnd],
  );
}
