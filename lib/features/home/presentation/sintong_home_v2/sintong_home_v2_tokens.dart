// ═══════════════════════════════════════════════════════════════
// FILE: sintong_home_v2_tokens.dart
// [신통방통 홈 v2 전면 교체 — design_handoff_sintong_main.zip]
//
// 사용자가 업로드한 두 번째 디자인 핸드오프(README.md 기준 "신통방통
// 메인 스크린" — 다크 히어로 캐러셀 + 다크 시트 + 5개 카테고리 진입
// 목차 화면)를 그대로 재현하기 위한 디자인 토큰.
//
// [기존 sintong_home/(v1, 화이트 프리미엄)와 완전히 별개 폴더] 사용자가
// "1"(완전 교체)을 선택했으므로 이 v2가 새 홈 화면의 유일한 시각
// 레이어가 되지만, 과거 세션 관례("파일을 삭제하지 않고 보존")에 따라
// v1 폴더 자체는 삭제하지 않고 남겨둔다(더 이상 import되지 않음).
// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens — README.md "Design Tokens > Colors" 표 그대로.
class SHomeV2Colors {
  SHomeV2Colors._();

  static const Color bgCanvas = Color(0xFF0D0D10); // 프로토타입 캔버스(사용 안 함)
  static const Color phoneBg = Color(0xFFF4F2EC); // 히어로 뒤 배경(이미지가 덮음)
  static const Color sheetBg = Color(0xFF282725); // rgb(40,39,37)
  static const Color sheetFg = Color(0xFFFAF9F9); // rgb(250,249,249)
  static const Color sheetTitleFg = Color(0xFFEEEDED); // rgb(238,237,237)
  static const Color sheetMetaFg = Color(0x8CFAF9F9); // rgba(250,249,249,.55)
  static const Color cardBg = Colors.white;
  static const Color cardTitle = Color(0xFF141414);
  static const Color chipBg = Color(0x1AFFFFFF); // rgba(255,255,255,.10)
  static const Color chipBorder = Color(0x4DFFFFFF); // rgba(255,255,255,.30)
  static const Color chipOnBg = Colors.white;
  static const Color chipOnFg = Color(0xFF111111);
  static const Color heroFg = Colors.white;
  static const Color glow = Color(0xFFF5CF6A); // 촛불 골드
  static const Color accentRed = Color(0xFFC94A3B); // 인장 붉은색
  static const Color ctaBg = Color(0xFFFAF9F9);
  static const Color ctaFg = Color(0xFF141414);
  static const Color navBg = Colors.white;
  static const Color navBorder = Color(0x0F000000); // rgba(0,0,0,.06)
  static const Color navOff = Color(0xFF6B6B6B);
  static const Color navOn = Color(0xFF141414);
  static const Color dotOff = Color(0x4DFFFFFF); // rgba(255,255,255,.30)
  static const Color dotOn = Colors.white;

  // 서브 스크린(_shared.css) 전용 — 다크 시트 톤 그대로 전체 화면 배경.
  static const Color subScaffoldBg = sheetBg;
  static const Color subOptBg = Color(0x0DFFFFFF); // rgba(255,255,255,.05)
  static const Color subOptBorder = Color(0x1AFFEBC8); // rgba(255,235,200,.10)
  static const Color subGlyphBg = Color(0x24F5CF6A); // rgba(245,207,106,.14)
  static const Color subQuoteBg = Color(0x0FF5CF6A); // rgba(245,207,106,.06)
  static const Color subQuoteBorder = Color(0x26F5CF6A); // rgba(245,207,106,.15)
}

/// Radii — README.md "Design Tokens > Radii" 표.
class SHomeV2Radii {
  SHomeV2Radii._();

  static const double card = 14;
  static const double heroStrip = 18;
  static const double sheetTop = 24;
  static const double pill = 999;
}

/// Spacing — 4pt scale.
class SHomeV2Spacing {
  SHomeV2Spacing._();

  static const double screenHPad = 20;
  static const double cardGap = 9;
}

/// Typography — README.md "Design Tokens > Typography" 표.
/// 한글은 Noto Sans KR, 영문/숫자는 Inter. Instrument Serif는 서브
/// 스크린 인용구 강조(영문/한자 전용, 한글 이탤릭 금지 — README §구현
/// 주의사항 7)에만 쓴다.
class SHomeV2Text {
  SHomeV2Text._();

  /// Hero title — Noto Sans KR 500 30/1.15/-2%
  static TextStyle heroTitle({Color color = SHomeV2Colors.heroFg}) =>
      GoogleFonts.notoSansKr(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.6,
        color: color,
      );

  /// Hero eyebrow — Inter 500 11/1, tracking .30em uppercase
  static TextStyle heroEyebrow({Color color = SHomeV2Colors.heroFg}) =>
      GoogleFonts.inter(
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w500,
        letterSpacing: 3.3,
        color: color,
      );

  /// Hero sub — Inter/NotoSansKR 400 13/1.55
  static TextStyle heroSub({Color color = SHomeV2Colors.heroFg}) =>
      GoogleFonts.notoSansKr(
        fontSize: 13,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Sheet title — 700 15/1.2/-0.5%
  static TextStyle sheetTitle({Color color = SHomeV2Colors.sheetTitleFg}) =>
      GoogleFonts.notoSansKr(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.075,
        color: color,
      );

  /// Sheet meta — 500 12/1
  static TextStyle sheetMeta({Color color = SHomeV2Colors.sheetMetaFg}) =>
      GoogleFonts.notoSansKr(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Card title — 700 13/1.3/-0.5%
  static TextStyle cardTitle({Color color = SHomeV2Colors.cardTitle}) =>
      GoogleFonts.notoSansKr(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.065,
        color: color,
      );

  /// Chip label — 500(active 600) 12.5/1
  static TextStyle chip({
    Color color = Colors.white,
    bool active = false,
  }) => GoogleFonts.notoSansKr(
    fontSize: 12.5,
    height: 1,
    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
    color: color,
  );

  /// CTA — 600 14.5/1/-0.5%
  static TextStyle cta({Color color = SHomeV2Colors.ctaFg}) =>
      GoogleFonts.notoSansKr(
        fontSize: 14.5,
        height: 1,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.0725,
        color: color,
      );

  /// Brand mono — Inter 600 10.5, tracking .12em uppercase
  static TextStyle brandMono({Color color = Colors.white}) => GoogleFonts.inter(
    fontSize: 10.5,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.26,
    color: color,
  );

  /// Nav label — 500(active 700) 10/1/-2%
  static TextStyle navLabel({
    Color color = SHomeV2Colors.navOff,
    bool active = false,
  }) => GoogleFonts.notoSansKr(
    fontSize: 10,
    height: 1,
    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
    letterSpacing: -0.2,
    color: color,
  );

  // ── 서브 스크린(_shared.css) 전용 ──

  /// Sub header title (hdr-title) — 600 10.5, tracking .22em uppercase
  static TextStyle subHeaderTitle({Color color = Colors.white}) =>
      GoogleFonts.inter(
        fontSize: 10.5,
        height: 1,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.31,
        color: color,
      );

  /// Hero strip eyebrow (.eb) — 500 10/1, tracking .28em uppercase
  static TextStyle subHeroEyebrow({Color color = Colors.white}) =>
      GoogleFonts.inter(
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.8,
        color: color,
      );

  /// Hero strip title (.ti) — 700 22/1.2/-1%
  static TextStyle subHeroTitle({Color color = Colors.white}) =>
      GoogleFonts.notoSansKr(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.22,
        color: color,
      );

  /// Section head — 700 15/1.2/-0.5%
  static TextStyle sectionHead({Color color = SHomeV2Colors.sheetTitleFg}) =>
      GoogleFonts.notoSansKr(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.075,
        color: color,
      );

  /// Section sub — 400 12.5/1.6
  static TextStyle sectionSub({Color color = const Color(0x9EFAF9F9)}) =>
      GoogleFonts.notoSansKr(
        fontSize: 12.5,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Option title — 600 13.5/1.2/-0.5%
  static TextStyle optTitle({Color color = SHomeV2Colors.sheetTitleFg}) =>
      GoogleFonts.notoSansKr(
        fontSize: 13.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.0675,
        color: color,
      );

  /// Option sub — 400 11.5/1.4
  static TextStyle optSub({Color color = const Color(0x8CFAF9F9)}) =>
      GoogleFonts.notoSansKr(
        fontSize: 11.5,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Option glyph(한자 1글자) — Noto Serif KR 900 15
  /// (google_fonts 패키지엔 notoSerifKr() 메서드가 없어 컴파일 에러가
  /// 났었음 — 프로젝트 전역에서 이미 로컬로 번들된 'NotoSerifKR' 폰트
  /// 패밀리를 pubspec.yaml에 등록해 두고 fontFamily로 직접 참조하는
  /// 패턴을 쓰고 있으므로(sintong_typography.dart 등과 동일하게) 그
  /// 방식을 그대로 따른다.)
  static TextStyle optGlyph({Color color = SHomeV2Colors.glow}) => TextStyle(
        fontFamily: 'NotoSerifKR',
        fontSize: 15,
        height: 1,
        fontWeight: FontWeight.w900,
        color: color,
      );

  /// Quote body — 400 13/1.65/-0.5%
  static TextStyle quote({Color color = const Color(0xD9FAF9F9)}) =>
      GoogleFonts.notoSansKr(
        fontSize: 13,
        height: 1.65,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.065,
        color: color,
      );

  /// Quote emphasis(영문/한자 전용 이탤릭 세리프) — Instrument Serif
  /// italic 400 15. [한글 금지] 한글 문자열에는 절대 이 스타일을 쓰지
  /// 않는다(README §구현 주의사항 7). 각 서브 화면에서 <em> 부분은
  /// 한글이므로 실제로는 optTitle 굵기 정도의 강조로 대체해 렌더링한다.
  static TextStyle quoteEmphasis({Color color = SHomeV2Colors.glow}) =>
      GoogleFonts.instrumentSerif(
        fontSize: 15,
        height: 1,
        fontStyle: FontStyle.italic,
        color: color,
      );
}

/// Animation durations/curves — README.md "애니메이션 스펙" 표.
class SHomeV2Motion {
  SHomeV2Motion._();

  static const Duration heroTrackMove = Duration(milliseconds: 1100);
  static const Curve heroTrackCurve = Cubic(0.7, 0, 0.2, 1);

  static const Duration captionFade = Duration(milliseconds: 900);
  static const Duration captionDelay = Duration(milliseconds: 300);
  static const Curve captionCurve = Cubic(0.4, 0, 0.2, 1);

  static const Duration kenBurns = Duration(seconds: 6);

  static const Duration chipTransition = Duration(milliseconds: 300);
  static const Duration dotTransition = Duration(milliseconds: 500);
  static const Duration navColorTransition = Duration(milliseconds: 200);

  static const Duration autoCycle = Duration(seconds: 6);
  static const Duration doubleTapWindow = Duration(milliseconds: 700);
}
