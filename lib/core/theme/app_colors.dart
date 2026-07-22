import 'package:flutter/material.dart';

/// 03단계 UX/UI 설계서 §2 디자인 시스템 토큰 - Color 구체화
/// Primary: 브랜드 보라/남색 계열(운세/신비 컨셉)
/// Secondary: 포인트/리워드 강조색(골드/옐로)
class AppColors {
  AppColors._();

  // ── Primary (보라/남색 - 신비/운세 컨셉) ──
  static const Color primary = Color(0xFF6C4DFF);
  static const Color primaryDark = Color(0xFF4B2ED6);
  static const Color primaryLight = Color(0xFF9C82FF);
  static const Color primaryContainer = Color(0xFFEDE7FF);

  // 배경 그라디언트(신비로운 밤하늘 느낌)
  static const Color deepSpace = Color(0xFF1A1035);
  static const Color deepSpaceLight = Color(0xFF2D1B5E);

  // ── Secondary (골드/옐로 - 포인트/리워드) ──
  static const Color secondary = Color(0xFFFFC542);
  static const Color secondaryDark = Color(0xFFE8A800);
  static const Color secondaryLight = Color(0xFFFFE0A3);

  // ── Semantic ──
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFA940);
  static const Color error = Color(0xFFFF5757);
  static const Color info = Color(0xFF4DA8FF);

  // ── Neutral ──
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
}
