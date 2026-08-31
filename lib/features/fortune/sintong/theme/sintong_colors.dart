// ═══════════════════════════════════════════════════════════════
// SINTONG COLORS — Dawn Hanji Palette (새벽 한지)
// [관상·손금 신통방통 리스킨] 디자인 핸드오프 이식.
//
// 크림 페이퍼 배경 + 러스트 랜턴 CTA + 잉크 브라운 인장.
// 이 팔레트는 관상·손금 화면에만 국소 적용되며, 앱 전역 테마와는 무관하다.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class SintongColors {
  SintongColors._();

  // ── Background ─────────────────────────────────────────────
  /// 스크린 상단 틴트.
  static const Color bg1 = Color(0xFFFAF3E0);
  /// 스크린 하단 base.
  static const Color bg2 = Color(0xFFEFE4C8);
  /// 무대 배경(프리뷰용).
  static const Color stageBg = Color(0xFFD9C9A3);

  // ── Foreground / Text ──────────────────────────────────────
  /// 본문 색(warm ink).
  static const Color fg = Color(0xFF2A1F14);
  /// 부차 텍스트.
  static Color muted = const Color(0xFF2A1F14).withValues(alpha: 0.72);
  /// 더 옅은 메타 라벨용.
  static Color mutedSoft = const Color(0xFF2A1F14).withValues(alpha: 0.55);

  // ── Semantic ───────────────────────────────────────────────
  /// 촛불 러스트 — Primary CTA 배경.
  static const Color glow = Color(0xFFD97941);
  /// 마법진 스트로크. 잉크 브라운.
  static const Color sigil = Color(0xFF8B5A2B);
  /// 인장 붉은 갈색.
  static const Color accent = Color(0xFF8B3A2B);
  /// 제이드(부차 강조).
  static const Color crystal = Color(0xFF7BA896);

  // ── Utility ────────────────────────────────────────────────
  /// 카드 배경.
  static Color card = const Color(0xFF8B5A2B).withValues(alpha: 0.06);
  /// 하이라이트 카드(관상·손금 통합 카드).
  static Color cardAccent = const Color(0xFFD97941).withValues(alpha: 0.14);
  /// 헤어라인.
  static Color line = const Color(0xFF3C2D1E).withValues(alpha: 0.15);
  /// 대시 라인.
  static Color lineDashed = const Color(0xFF3C2D1E).withValues(alpha: 0.35);
  /// glow shadow(halo).
  static Color glowShadow = const Color(0xFFD97941).withValues(alpha: 0.28);

  // ── Hanja stamp seals ──────────────────────────────────────
  /// 觀(관상용) 스탬프 색.
  static const Color stampGuan = Color(0xFF8B3A2B);
  /// 紋(손금용) 스탬프 색.
  static const Color stampMun = Color(0xFFA35A2A);
}
