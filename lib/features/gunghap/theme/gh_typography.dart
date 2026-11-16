// ═══════════════════════════════════════════════════════════════
// FILE: gh_typography.dart
// [궁합지도 전면 리디자인 v4] design_handoff_gunghap_map_v4
// `00_DEV_MAPPING.md` §2-5(서체) + `flutter_starter/lib/gunghap/
// theme/gh_typography.dart`(v3 참고 구현) 포팅.
//
// [서체 전략] v4 참고 코드는 google_fonts 패키지(GoogleFonts.notoSerifKr/
// ibmPlexMono)를 쓰지만, 이 프로젝트는 앱 전역에서 Pretendard·
// NotoSerifKR·IBMPlexMono를 pubspec.yaml 로컬 에셋 폰트로 등록해
// 쓰는 체계를 유지한다(§2-5: "UI 전반은 Pretendard, 한자는 Noto Serif KR
// fallback, 영문·숫자 메타는 IBM Plex Mono"). 그래서 모든 스타일의
// 기본 fontFamily는 Pretendard이고, 한자 글리프가 섞일 수 있는 자리는
// fontFamilyFallback으로 NotoSerifKR을 추가해 글자가 깨지지 않도록
// 한다(이전에는 display/title이 통째로 NotoSerifKR을 기본 폰트로 썼던
// 오류가 있어 이번에 Pretendard 기본 + fallback 방식으로 바로잡았다).
//
// [하위 호환] 기존 역할(display/title/reportSection/cardTitle/
// reportBody/button/ui/caption/mono)은 이름과 시그니처를 유지한다
// (전역 72~1회 호출부가 있어 이름을 바꾸면 컴파일이 깨진다). v4가 추가한
// 신규 역할(homeTitle/sheetTitle/resultTitle/reportCover/appBar/chip/
// navLabel/hanja/body/sectionTitle)도 함께 제공한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'gh_tokens.dart';

abstract final class GHText {
  static const _serif = 'NotoSerifKR';
  // [폰트 전환 — 2026-11] GowunBatang -> Pretendard.
  static const _body = 'Pretendard';
  static const _mono = 'IBMPlexMono';
  static const _ui = 'Pretendard';
  // §2-5: "Pretendard에 한자 글리프 없음 → fontFamilyFallback".
  static const _hanjaFallback = [_serif];

  // ── §2-5 homeTitle: 25/900/1.3, -0.035em — S01 헤더 ──
  static TextStyle homeTitle({double size = 25, Color color = GHColors.fg}) =>
      TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _hanjaFallback,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.3,
        letterSpacing: -0.035 * size,
        color: color,
      );

  /// display: 24/700/1.32, -0.025em — 화면 제목 (GHTitle 본문)
  /// [수정 — v4] 기본 폰트를 NotoSerifKR → Pretendard로 교체(§2-5:
  /// "제목 포함 UI 전반은 Pretendard"). 한자는 fallback으로 처리.
  static TextStyle display({double size = 28, Color color = GHColors.ivory}) =>
      TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _hanjaFallback,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.3,
        letterSpacing: -0.035 * size,
        color: color,
      );

  static TextStyle title({double size = 24, Color color = GHColors.ivory}) =>
      TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _hanjaFallback,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.35,
        letterSpacing: -0.025 * size,
        color: color,
      );

  // ── §2-5 sheetTitle: 21~22/900/1.35, -0.03em — 시트 제목 ──
  static TextStyle sheetTitle({double size = 21, Color color = GHColors.fg}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.35,
        letterSpacing: -0.03 * size,
        color: color,
      );

  // ── §2-5 resultTitle: 34/900/1.2, -0.03em + gradTitle — S17 세부명 ──
  // gradTitle은 그라데이션 텍스트이므로 색은 호출부에서 ShaderMask로
  // 덧씌운다. 기본 color는 GHColors.fg(그라데이션 미적용 폴백).
  static TextStyle resultTitle({double size = 34, Color color = GHColors.fg}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.2,
        letterSpacing: -0.03 * size,
        color: color,
      );

  // ── §2-5 reportCover: 30/900, -0.03em — S22 표지 ──
  static TextStyle reportCover({double size = 30, Color color = GHColors.fg}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.03 * size,
        color: color,
      );

  /// §2-5 sectionTitle: 19/700, accent, -0.02em — 보고서 장
  static TextStyle reportSection() => TextStyle(
    fontFamily: _serif,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: GHColors.accent,
    letterSpacing: -0.38,
  );

  // [수정 — v4] §2-5 cardTitle: 14.5~16 / 800 / 1.3 (기존 w700 → w800).
  static TextStyle cardTitle({double size = 15.5, Color color = GHColors.ivory}) =>
      TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _hanjaFallback,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: color,
      );

  // ── §2-5 appBar: 16/700 — AppBar 제목 ──
  static TextStyle appBar({double size = 16, Color color = GHColors.fg}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// reportBody: 15.5/400/1.95 — 보고서 본문
  static TextStyle reportBody() => TextStyle(
    fontFamily: _body,
    fontSize: 15.5,
    height: 1.95,
    color: GHColors.ivory.withValues(alpha: .92),
  );

  static TextStyle button({double size = 15.5, Color color = GHColors.ink}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: color,
      );

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = GHColors.ivory,
    double height = 1.55,
  }) => TextStyle(
    fontFamily: _ui,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Minimum 12. Use for captions / hints.
  static TextStyle caption({Color color = GHColors.gray}) =>
      ui(size: 12, color: color, height: 1.5);

  /// UPPERCASE mono label — always pass upper-cased text.
  static TextStyle mono({Color color = GHColors.gray, double size = 9.5}) =>
      TextStyle(
        fontFamily: _mono,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: size * 0.3,
        color: color,
      );

  // ── §2-5 chip: 12/600 ──
  static TextStyle chip({Color color = GHColors.muted}) => TextStyle(
    fontFamily: _ui,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color,
  );

  // ── §2-5 navLabel: 11.5/500(on 700) — 하단바 ──
  static TextStyle navLabel({bool active = false, Color? color}) => TextStyle(
    fontFamily: _ui,
    fontSize: 11.5,
    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
    color: color ?? (active ? GHColors.accent : GHColors.muted),
  );

  // ── §2-5 sectionTitle: 19/700, accent, -0.02em — 보고서 장(v4 신규명)
  // reportSection()과 동일(하위호환 별칭).
  static TextStyle sectionTitle() => reportSection();

  /// §2-5 body: 13.5~14/400~600/1.6 — 일반 본문(v4 신규, ui()의 별칭).
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = GHColors.fg,
  }) => ui(size: size, weight: weight, color: color, height: 1.6);

  /// 한자 단독 표기 — 일간 · 인장 · 장 번호(v4 신규).
  static TextStyle hanja({
    double size = 22,
    Color color = GHColors.fg,
    FontWeight weight = FontWeight.w900,
  }) => TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: const [_body],
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}
