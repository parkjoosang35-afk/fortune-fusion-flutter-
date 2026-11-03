// ═══════════════════════════════════════════════════════════════
// FILE: gh_typography.dart
// [궁합지도 Star Map 디자인 적용] `flutter_starter/.../gh_typography.dart`
// 포팅본. 원본 핸드오프는 google_fonts(GoogleFonts.notoSerifKr 등)를
// 쓰지만, 이 프로젝트는 이미 동일한 서체 3종(NotoSerifKR/GowunBatang/
// IBMPlexMono)을 assets/fonts/wish_room/ 에 번들하여 family 이름으로
// 직접 참조하는 기존 관례(saju_dark_tokens.dart 등)가 있으므로, 중복
// 네트워크/에셋 다운로드 없이 동일 패턴을 그대로 따른다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'gh_tokens.dart';

abstract final class GHText {
  static const _serif = 'NotoSerifKR';
  static const _body = 'GowunBatang';
  static const _mono = 'IBMPlexMono';
  static const _ui = 'Pretendard';

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

  static TextStyle reportSection() => const TextStyle(
    fontFamily: _serif,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: GHColors.gold,
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
}
