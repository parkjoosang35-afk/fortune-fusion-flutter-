import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// [타로 오즈 리스킨] "오즈의 타로" 감성 컬러 토큰.
///
/// 이 파일은 기존 [TarotColors]/[TarotTextStyles]/[TarotTokens]를 대체하지
/// 않는다(그 파일들은 기존 로직/다른 다크 화면에서 계속 참조되므로
/// read-only로 보존). Oz 리스킨 대상 7화면(홈/허브/카테고리상세/질문/
/// 카드선택/로딩/결과)의 위젯 트리에서만 이 파일을 사용한다.
///
/// 값 출처: `tarot-oz_extracted/oz-styles.css`의 `:root` 커스텀 프로퍼티를
/// 그대로 이식(핸드오프 스펙의 유일한 진실 원천). README의 OzColors 예시와
/// 동일한 값이다.
class OzColors {
  OzColors._();

  // ── 배경 그라디언트 3단(딥퍼플 나이트 스카이) ──
  static const Color bgDeep = Color(0xFF0A0620); // 가장 깊은 배경(하단)
  static const Color bgMid = Color(0xFF1A0F3D); // 중간
  static const Color bgTop = Color(0xFF2D1B5C); // 상단(밝은 보라)

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMid, bgDeep],
    stops: [0.0, 0.45, 1.0],
  );

  // ── 텍스트 ──
  static const Color fg = Color(0xFFFFF8DD); // 메인 텍스트(따뜻한 아이보리)
  static const Color muted = Color(0xBFE8DCF5); // rgba(232,220,245,0.75)
  static const Color faint = Color(0x8CFFF8DD); // rgba(255,248,221,0.55) 근사

  // ── 라인/카드 표면 ──
  static const Color line = Color(0x29F5D98A); // rgba(245,217,138,0.16)
  static const Color card = Color(0x2E8B6EC8); // rgba(139,110,200,0.18)
  static const Color cardSoft = Color(0x268B6EC8); // rgba(139,110,200,0.15)

  // ── 액센트: 골드 ──
  static const Color gold = Color(0xFFF5D97A);
  static const Color goldDeep = Color(0xFFC9982A);
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gold, goldDeep],
  );

  // ── 액센트: 로즈(NEW 배지 등) ──
  static const Color rose = Color(0xFFE87A91);
  static const Color roseDeep = Color(0xFFC94A6B);
  static const LinearGradient roseGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [rose, roseDeep],
  );

  // ── 액센트: 틸(보조) ──
  static const Color teal = Color(0xFF8DBFD6);

  /// 카드/섹션 배경 위에 얹는 은은한 보더.
  static const Color borderSoft = Color(0x26F5D98A); // rgba(245,217,138,0.15)
  static const Color borderStrong = Color(0x4DF5D98A); // rgba(245,217,138,0.3)

  /// 골드 글로우(검은 drop-shadow 대신 사용, README 금지사항 준수).
  static List<BoxShadow> goldGlow({double alpha = 0.35, double blur = 24}) => [
    BoxShadow(
      color: gold.withValues(alpha: alpha),
      blurRadius: blur,
    ),
  ];

  static List<BoxShadow> cardElevation() => const [
    BoxShadow(color: Color(0x59000000), blurRadius: 30, offset: Offset(0, 8)),
  ];
}

/// [타로 오즈 리스킨] 타이포그래피.
///
/// README 스펙은 `GoogleFonts.notoSerifKr`을 사용하지만 이 프로젝트에
/// 고정된 `google_fonts: 6.2.1`에는 해당 메서드가 존재하지 않는다(확인
/// 완료). 대신 같은 명조/세리프 계열인 [GoogleFonts.notoSansKr] weight
/// 900/700으로 유사한 "제목용 굵은 세리프" 톤을 재현한다. 본문/캡션용
/// [GoogleFonts.gowunBatang], 라벨용 [GoogleFonts.ibmPlexMono]는 스펙과
/// 동일하게 사용 가능(둘 다 6.2.1에 존재 확인됨).
class OzTypography {
  OzTypography._();

  /// 히어로 대제목(예: "오늘, 카드가 건네는 한마디"). CSS 대응:
  /// .canvas-title / .oz-hero-card-title(더 큰 사이즈 버전).
  static TextStyle hero({double fontSize = 26, Color color = OzColors.fg}) =>
      GoogleFonts.notoSansKr(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1.25,
        letterSpacing: -0.5,
        color: color,
      );

  /// 화면/섹션 타이틀(예: 탑바 타이틀, 테마 히어로 이름). CSS 대응:
  /// .oz-topbar-title / .oz-theme-hero-name.
  static TextStyle sectionTitle({
    double fontSize = 20,
    FontWeight weight = FontWeight.w700,
    Color color = OzColors.fg,
  }) => GoogleFonts.notoSansKr(
    fontSize: fontSize,
    fontWeight: weight,
    letterSpacing: -0.3,
    color: color,
  );

  /// 카드/서브리스트 제목(둥근 명조 느낌). CSS 대응: .oz-cat-name /
  /// .oz-sublist-name.
  static TextStyle cardName({
    double fontSize = 13,
    Color color = OzColors.fg,
  }) => GoogleFonts.gowunBatang(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: color,
  );

  /// 본문/설명 텍스트. CSS 대응: .oz-cat-desc / .oz-sublist-desc /
  /// .canvas-subtitle.
  static TextStyle body({double fontSize = 13, Color color = OzColors.muted}) =>
      GoogleFonts.gowunBatang(fontSize: fontSize, height: 1.6, color: color);

  /// 이탤릭 톤(따옴표 인용, 무드카피 등)에 사용하는 변형.
  static TextStyle italicBody({
    double fontSize = 13,
    Color color = OzColors.muted,
  }) => GoogleFonts.gowunBatang(
    fontSize: fontSize,
    height: 1.7,
    fontStyle: FontStyle.italic,
    color: color,
  );

  /// 모노스페이스 라벨(태그/eyebrow). CSS 대응: .oz-hero-card-tag /
  /// .canvas-eyebrow / .oz-sublist-num. 항상 트래킹을 넓게, 톤은 골드.
  static TextStyle monoLabel({
    double fontSize = 10,
    Color color = OzColors.gold,
    double letterSpacing = 2.4,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    letterSpacing: letterSpacing,
    color: color,
  );

  /// CTA 버튼 라벨(고밀도 골드 배경 위 다크 텍스트).
  static TextStyle ctaLabel({
    double fontSize = 15,
    Color color = const Color(0xFF2A1A08),
  }) => GoogleFonts.gowunBatang(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
  );
}

/// 스페이싱/라운드 토큰(Oz 전용, 기존 [TarotTokens]와 분리).
class OzTokens {
  OzTokens._();

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 28;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 22;
  static const double radiusPill = 999;
}
