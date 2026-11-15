// ═══════════════════════════════════════════════════════════════
// FILE: gh_typography.dart
// [궁합지도 전면 리디자인 — 2026-11 2차 핸드오프] `00_DEV_MAPPING.md`
// §2-5(서체) 반영. 서체 체계(Pretendard·Noto Serif KR·IBM Plex Mono)는
// 기존과 동일(§2-5와 이미 일치) — 색상은 gh_tokens.dart 교체로 자동
// 반영된다. 이번 변경은 §2-5 크기표에 정의된 신규 역할(homeTitle·
// sheetTitle·resultTitle·reportCover·appBar·chip·navLabel)을 추가한다.
// 기존 역할(display/title/reportSection/cardTitle/reportBody/button/
// ui/caption/mono)은 이름과 시그니처를 유지해 하위 호환을 지킨다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'gh_tokens.dart';

abstract final class GHText {
  static const _serif = 'NotoSerifKR';
  // [폰트 전환 — 2026-11] GowunBatang -> Pretendard.
  static const _body = 'Pretendard';
  static const _mono = 'IBMPlexMono';
  static const _ui = 'Pretendard';

  // ── §2-5 homeTitle: 25/900/1.3, -0.035em — S01 헤더 ──
  static TextStyle homeTitle({double size = 25, Color color = GHColors.fg}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.3,
        letterSpacing: -0.035 * size,
        color: color,
      );

  /// display: 24/700/1.32, -0.025em — 화면 제목 (GHTitle 본문)
  static TextStyle display({double size = 28, Color color = GHColors.ivory}) =>
      TextStyle(
        fontFamily: _serif,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.3,
        letterSpacing: -0.035 * size,
        color: color,
      );

  static TextStyle title({double size = 24, Color color = GHColors.ivory}) =>
      TextStyle(
        fontFamily: _serif,
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

  static TextStyle cardTitle({double size = 15.5, Color color = GHColors.ivory}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.4,
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
}
