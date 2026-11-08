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
//
// [2차 리뉴얼 — Midnight Navy (야간의 학술 서재), design_handoff_sintong_main
// (2).zip, 2026-11] 사용자 요청: "메인화면 디자인을 바꿀거야 기능은
// 바뀐거는없고 디자인 위치와 색상 디자인 이야". 기존 다크 그레이
// (#282725 sheetBg) + 촛불골드(#F5CF6A glow) 팔레트를 README.md가 지정한
// Midnight Navy(#0B1326/#070D1B) + Champagne Gold(#D4AF37/#EBD58E) +
// Warm Ivory(#F5F5F0) 팔레트로 전면 교체한다. "붉은/분홍 계열 색은
// 사용하지 않습니다" 원칙에 따라 accentRed(#C94A3B)도 더 이상 이 화면
// 어디에서도 쓰지 않는다(상수 자체는 다른 곳이 참조할 수 있어 보존).
// 색상 값만 교체하고 클래스/필드명은 그대로 유지해 이 토큰을 쓰는
// 모든 위젯(토글바/칩/시트/카드)이 코드 변경 없이 새 색을 받도록 한다.
// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

// [폰트 깨짐(□) 버그 수정 — 2026-09-22 사용자 리포트]
// 기존에는 이 화면 전용으로 google_fonts 패키지(GoogleFonts.notoSansKr/
// inter/instrumentSerif)를 써서 폰트를 "런타임에 구글 폰트 서버에서
// 다운로드"하는 방식이었다. 앱 나머지 전체(상단바 '신통방통', 하단
// 네비게이션 등)는 이미 로컬에 내장된 'Pretendard' 폰트를 쓰고 있어
// 네트워크 상태와 무관하게 항상 정상 표시되는데, 이 화면만 예외로
// 네트워크 폰트에 의존해 모바일 환경에서 폰트 다운로드가 지연/실패하면
// 글자가 깨진 사각형(□)으로 보이는 문제가 있었다(실사용자 스크린샷으로
// 확인). 앱 전역에서 이미 pubspec.yaml에 등록해 로컬 asset으로 번들된
// 'Pretendard'(한글/영문/숫자)와 'NotoSerifKR'(한자 — 火/吉 등 이
// 화면에서 쓰는 한자 1글자 액센트를 포함)로 완전히 대체한다.
// fontFamilyFallback으로 Pretendard에 없는 한자 글리프만 NotoSerifKR로
// 자동 대체되도록 해 항상 로컬 파일만으로 100% 렌더링을 보장한다.
const List<String> _kHanjaFallback = ['NotoSerifKR'];

// [Midnight Navy 리뉴얼 — README "폰트" 표] 새 디자인은 4개 폰트 패밀리를
// 역할별로 구분해 쓴다: Display(브랜드명/카드 제목) = Noto Serif KR,
// Body(히어로 문구) = Gowun Batang, UI(칩/탭바) = Pretendard,
// Mono(영문/한자 메타 라벨) = IBM Plex Mono. 4개 모두 이미 pubspec.yaml에
// 로컬 asset으로 번들돼 있어(앱 전역 'IBMPlexMono'/'GowunBatang' 폰트를
// 이미 쓰는 화면이 있음 — app_unified_style.dart 참고) 네트워크 폰트
// 없이 100% 로컬 렌더링이 보장된다. Mono/Gowun 폰트는 한글·한자 글리프를
// 포함하지 않으므로, 혼용 문자열(예: "신통방통 · 神通方通")에서 누락
// 글리프가 Pretendard/NotoSerifKR로 자동 대체되도록 fallback을 둔다.
const List<String> _kMonoFallback = ['Pretendard', 'NotoSerifKR'];
const List<String> _kBodyFallback = ['Pretendard'];

/// Color tokens — [Midnight Navy 리뉴얼] design_handoff_sintong_main(2).zip
/// README.md "Design Tokens" 표 그대로. 필드명은 기존 호출부 호환을 위해
/// 그대로 두고 값만 새 팔레트로 교체했다(아래 각 필드 주석에 README 원본
/// 토큰명을 병기).
class SHomeV2Colors {
  SHomeV2Colors._();

  // ── README 원본 토큰(참고용 별칭) ──
  static const Color navy = Color(0xFF0B1326); // 메인 배경
  static const Color navy2 = Color(0xFF070D1B); // 하단 깊은 배경 / 탭바
  static const Color navyTop = Color(0xFF0E1830); // 시트 상단
  static const Color gold = Color(0xFFD4AF37); // Champagne Gold
  static const Color goldHi = Color(0xFFEBD58E); // 하이라이트 · 활성
  static const Color goldLo = Color(0xFF8C7124); // 그라데이션 그림자
  static const Color ivory = Color(0xFFF5F5F0); // Warm Ivory 본문
  static const Color mutedIvory = Color(0x8CF5F5F0); // rgba(245,245,240,.55)
  static const Color lineGold = Color(0x47D4AF37); // rgba(212,175,55,.28)
  static const Color lineGoldSoft = Color(0x24D4AF37); // rgba(212,175,55,.14)
  static const Color cardBorderGold = Color(0x80D4AF37); // rgba(212,175,55,.5)

  static const Color bgCanvas = Color(0xFF05080F); // 프로토타입 캔버스(사용 안 함)
  static const Color phoneBg = navy; // 히어로 뒤 배경(이미지가 덮음)
  static const Color sheetBg = navy; // 메인 배경(#0B1326)
  static const Color sheetFg = ivory;
  static const Color sheetTitleFg = ivory;
  static const Color sheetMetaFg = mutedIvory;
  static const Color cardBg = navyTop; // 카드 배경 폴백(이미지 로드 전)
  static const Color cardTitle = ivory;
  static const Color chipBg = Color(0x8C0B1326); // rgba(11,19,38,.55)
  static const Color chipBorder = Color(0x73D4AF37); // rgba(212,175,55,.45)
  static const Color chipOnBg = gold;
  static const Color chipOnFg = navy;
  static const Color heroFg = ivory;
  static const Color glow = gold; // 포인트 골드(기존 '촛불 골드' 역할 대체)
  static const Color accentRed = Color(0xFFC94A3B); // [미사용] 붉은/분홍 금지 원칙
  static const Color ctaBg = gold;
  static const Color ctaFg = navy;
  static const Color navBg = navy2;
  static const Color navBorder = lineGoldSoft;
  static const Color navOff = mutedIvory;
  static const Color navOn = goldHi;
  static const Color dotOff = Color(0x33D4AF37);
  static const Color dotOn = goldHi;

  // 서브 스크린(_shared.css) 전용 — 다크 네이비 톤 그대로 전체 화면 배경.
  static const Color subScaffoldBg = sheetBg;
  static const Color subOptBg = Color(0x0DD4AF37); // rgba(212,175,55,.05)
  static const Color subOptBorder = Color(0x1AD4AF37); // rgba(212,175,55,.10)
  static const Color subGlyphBg = Color(0x24D4AF37); // rgba(212,175,55,.14)
  static const Color subQuoteBg = Color(0x0FD4AF37); // rgba(212,175,55,.06)
  static const Color subQuoteBorder = Color(0x26D4AF37); // rgba(212,175,55,.15)
}

/// Radii — [Midnight Navy 리뉴얼] README "Radius" 표: 카드 12 · 시트 상단
/// 24(기존과 동일) · 칩/필 999 · 아이콘버튼 50%.
class SHomeV2Radii {
  SHomeV2Radii._();

  static const double card = 12;
  static const double heroStrip = 18;
  static const double sheetTop = 24;
  static const double pill = 999;
}

/// Spacing — [Midnight Navy 리뉴얼] README "Spacing" 표: 그리드 gap 10 ·
/// 그리드 좌우 18 · 헤더 좌우 22.
class SHomeV2Spacing {
  SHomeV2Spacing._();

  static const double screenHPad = 20;
  static const double cardGap = 10;
  static const double gridHPad = 18;
  static const double headerHPad = 22;
}

/// Typography — README.md "Design Tokens > Typography" 표.
/// 한글은 Noto Sans KR, 영문/숫자는 Inter. Instrument Serif는 서브
/// 스크린 인용구 강조(영문/한자 전용, 한글 이탤릭 금지 — README §구현
/// 주의사항 7)에만 쓴다.
class SHomeV2Text {
  SHomeV2Text._();

  /// Hero title — Pretendard 30/1.15/-2%
  /// [폰트 중앙화 — 2026-11 마이페이지 B시안] '타이틀' 규칙(800)에
  /// 맞춰 500 -> 800로 상향. (현재 코드베이스에서 실사용처 없음 —
  /// 추후 이 토큰을 쓰는 화면이 생겨도 일관된 굵기를 갖도록 선반영)
  static TextStyle heroTitle({Color color = SHomeV2Colors.heroFg}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 30,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: color,
  );

  /// Hero eyebrow — Pretendard 11/1, tracking .30em uppercase
  /// [폰트 중앙화] 보조 라벨 규칙(600~700)에 맞춰 500 -> 600로 상향.
  static TextStyle heroEyebrow({Color color = SHomeV2Colors.heroFg}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: _kHanjaFallback,
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w600,
        letterSpacing: 3.3,
        color: color,
      );

  /// Hero sub — Pretendard 13/1.55
  /// [폰트 중앙화] 본문/설명 규칙에 맞춰 400 -> 600로 상향.
  static TextStyle heroSub({Color color = SHomeV2Colors.heroFg}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w600,
    color: color,
  );

  /// Sheet title("운세 엔진") — [Midnight Navy 리뉴얼] README "헤더" 절:
  /// Noto Serif KR 700 23px/1, letter-spacing -.02em. 실제 금색
  /// 그라데이션(linear-gradient 180deg #EBD58E→#D4AF37 55%→#8C7124)은
  /// TextStyle만으로 표현할 수 없어 호출부가 ShaderMask로 이 스타일에
  /// 입힌다(색은 ShaderMask의 BlendMode.srcIn이 덮어쓰므로 Colors.white
  /// 고정 — 마스크 알파만 이 글리프 모양을 따른다).
  static TextStyle sheetTitle({Color color = Colors.white}) => TextStyle(
    fontFamily: 'NotoSerifKR',
    fontFamilyFallback: _kBodyFallback,
    fontSize: 23,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.46,
    color: color,
  );

  /// Sheet subtitle mono("SINTONG · 命理書") — README "헤더" 절:
  /// IBM Plex Mono 500 9.5px, letter-spacing .34em,
  /// rgba(212,175,55,.6).
  static TextStyle sheetSubtitleMono({Color color = const Color(0x99D4AF37)}) =>
      TextStyle(
        fontFamily: 'IBMPlexMono',
        fontFamilyFallback: _kMonoFallback,
        fontSize: 9.5,
        height: 1,
        fontWeight: FontWeight.w500,
        letterSpacing: 3.23,
        color: color,
      );

  /// Sheet meta — 12/1
  /// [폰트 중앙화] 보조 라벨 규칙에 맞춰 500 -> 600로 상향.
  static TextStyle sheetMeta({Color color = SHomeV2Colors.sheetMetaFg}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: _kHanjaFallback,
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Card title — [Midnight Navy 리뉴얼] README "카드 공통" 절: Noto
  /// Serif KR 700, letter-spacing -.02em, #F5F5F0. 큰 카드 21px/작은
  /// 카드 15px로 크기가 달라 [fontSize]를 파라미터로 받는다(기본값은
  /// 리스트형 타일 등 기존 실사용처 호환을 위해 기존 13 유지).
  static TextStyle cardTitle({
    Color color = SHomeV2Colors.cardTitle,
    double fontSize = 13,
  }) => TextStyle(
    fontFamily: 'NotoSerifKR',
    fontFamilyFallback: _kBodyFallback,
    fontSize: fontSize,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: fontSize * -0.02,
    color: color,
  );

  /// 카드 한자 라벨("貴人 · GUIN" 등, 큰 카드 전용) — README "카드 공통"
  /// 절: IBM Plex Mono 500 9px, letter-spacing .32em, #D4AF37.
  static TextStyle cardHanjaLabel({Color color = SHomeV2Colors.gold}) =>
      TextStyle(
        fontFamily: 'IBMPlexMono',
        fontFamilyFallback: _kMonoFallback,
        fontSize: 9,
        height: 1,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.88,
        color: color,
      );

  /// 히어로 바로가기 칩 — README "동영상 히어로" 절: Pretendard 500
  /// 11px(기존 [chip] 12.5px와 별개 — 픽셀 단위 일치를 위해 새 스타일로
  /// 분리, 하단 시트 리스트형 타일의 [chip] 실사용처는 건드리지 않음).
  static TextStyle heroChip({Color color = SHomeV2Colors.ivory}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w500,
    color: color,
  );

  /// Chip label — 12.5/1
  /// [폰트 중앙화] '메뉴 아이템' 규칙(600~700)에 맞춰
  /// 비활성 500 -> 600, 활성 600 -> 700로 상향.
  static TextStyle chip({Color color = Colors.white, bool active = false}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: _kHanjaFallback,
        fontSize: 12.5,
        height: 1,
        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
        color: color,
      );

  /// CTA — 14.5/1/-0.5%
  /// [폰트 중앙화] '버튼' 규칙(700)에 맞춰 600 -> 700로 상향.
  static TextStyle cta({Color color = SHomeV2Colors.ctaFg}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 14.5,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.0725,
    color: color,
  );

  /// Brand mono — Pretendard 10.5, tracking .12em uppercase
  /// [폰트 중앙화] 상단바 '신통방통' 브랜드 텍스트 — 메뉴/라벨급
  /// 강조 규칙(700)에 맞춰 600 -> 700로 상향.
  static TextStyle brandMono({Color color = Colors.white}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 10.5,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.26,
    color: color,
  );

  /// Nav label — 10/1/-2%
  /// [폰트 중앙화] midnight_bottom_nav.dart와 동일한 규칙 —
  /// 비선택 500 -> 600로 상향(선택 700은 유지, 현재 코드베이스에서
  /// 실사용처 없음 — 추후 대비 선반영).
  static TextStyle navLabel({
    Color color = SHomeV2Colors.navOff,
    bool active = false,
  }) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 10,
    height: 1,
    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
    letterSpacing: -0.2,
    color: color,
  );

  // ── 서브 스크린(_shared.css) 전용 ──

  /// Sub header title (hdr-title) — 10.5, tracking .22em uppercase
  /// [폰트 중앙화] 600 -> 700로 상향 (현재 실사용처 없음 — 선반영).
  static TextStyle subHeaderTitle({Color color = Colors.white}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 10.5,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.31,
    color: color,
  );

  /// Hero strip eyebrow (.eb) — 10/1, tracking .28em uppercase
  /// [폰트 중앙화] 500 -> 600로 상향 (현재 실사용처 없음 — 선반영).
  static TextStyle subHeroEyebrow({Color color = Colors.white}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 10,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.8,
    color: color,
  );

  /// Hero strip title (.ti) — 22/1.2/-1%
  /// [폰트 중앙화] '타이틀' 규칙에 맞춰 700 -> 800로 상향
  /// (현재 실사용처 없음 — 선반영).
  static TextStyle subHeroTitle({Color color = Colors.white}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.22,
    color: color,
  );

  /// Section head — 15/1.2/-0.5%
  /// [폰트 중앙화] '섹션 타이틀' 규칙(800)에 맞춰 700 -> 800로 상향
  /// (현재 실사용처 없음 — 선반영).
  static TextStyle sectionHead({Color color = SHomeV2Colors.sheetTitleFg}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: _kHanjaFallback,
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.075,
        color: color,
      );

  /// Section sub — 12.5/1.6
  /// [폰트 중앙화] 본문/설명 규칙에 맞춰 400 -> 600로 상향
  /// (현재 실사용처 없음 — 선반영).
  static TextStyle sectionSub({Color color = const Color(0x9EFAF9F9)}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: _kHanjaFallback,
        fontSize: 12.5,
        height: 1.6,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Option title — 13.5/1.2/-0.5%
  /// [폰트 중앙화] '메뉴 아이템' 규칙에 맞춰 600 -> 700로 상향
  /// (현재 실사용처 없음 — 선반영).
  static TextStyle optTitle({Color color = SHomeV2Colors.sheetTitleFg}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: _kHanjaFallback,
        fontSize: 13.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.0675,
        color: color,
      );

  /// Option sub — 11.5/1.4
  /// [폰트 중앙화] 본문/설명 규칙에 맞춰 400 -> 600로 상향
  /// (현재 실사용처 없음 — 선반영).
  static TextStyle optSub({Color color = const Color(0x8CFAF9F9)}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 11.5,
    height: 1.4,
    fontWeight: FontWeight.w600,
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

  /// Quote body — 13/1.65/-0.5%
  /// [폰트 중앙화] 본문/설명 규칙에 맞춰 400 -> 600로 상향
  /// (현재 실사용처 없음 — 선반영).
  static TextStyle quote({Color color = const Color(0xD9FAF9F9)}) => TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: _kHanjaFallback,
    fontSize: 13,
    height: 1.65,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.065,
    color: color,
  );

  /// Quote emphasis(영문/한자 전용 이탤릭 강조) — italic 400 15.
  /// [한글 금지] 한글 문자열에는 절대 이 스타일을 쓰지 않는다(README
  /// §구현 주의사항 7). 네트워크 폰트(Instrument Serif) 의존을 없애기
  /// 위해 로컬 Pretendard 이탤릭으로 대체한다(영문/한자 전용이라 큰
  /// 시각적 차이 없음 — Pretendard는 fontStyle.italic을 합성 이탤릭으로
  /// 렌더링한다).
  /// [폰트 중앙화] 이탤릭 강조용 장식 텍스트라 다른 항목만큼 굵게
  /// 올리진 않고 보수적으로 기본(400) -> 500만 상향(현재 실사용처
  /// 없음 — 선반영).
  static TextStyle quoteEmphasis({Color color = SHomeV2Colors.glow}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: _kHanjaFallback,
        fontSize: 15,
        height: 1,
        fontWeight: FontWeight.w500,
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
