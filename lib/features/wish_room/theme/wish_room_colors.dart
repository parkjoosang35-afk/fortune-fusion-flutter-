import 'package:flutter/material.dart';

/// 신통방통 소원방 · 디자인 토큰 (Colors)
///
/// 출처: 디자인 핸드오프 `tokens/colors_and_type.css` (단일 진실의 소스).
/// 3개 팔레트(심야의 신전/새벽 한지/달빛 크리스탈)를 모두 Dart 상수로 옮기고,
/// [WishRoomPalette]로 런타임에 교체할 수 있도록 한다.
///
/// 기본 팔레트는 복주머니 기능 전용 기본값인 "달빛 크리스탈(Moonlit Crystal)"이다.
/// (dev-spec.md §2 "팔레트 · 달빛 크리스탈" 인용 값과 100% 동일하게 유지할 것 —
/// 임의로 색상값을 조정하지 않는다.)
///
/// 주의: 이 파일의 색상 상수는 오직 `lib/features/wish_room/` 내부에서만
/// 참조한다. 앱 전역 `AppColors`와 절대 혼용하지 않는다(디자인 시스템 격리).
enum WishRoomPalette { midnight, hanji, crystal }

class WishRoomPaletteTokens {
  const WishRoomPaletteTokens({
    required this.bg1,
    required this.bg2,
    required this.fg,
    required this.muted,
    required this.glow,
    required this.glowShadow,
    required this.crystal,
    required this.accent,
    required this.card,
    required this.line,
    required this.sigil,
  });

  final Color bg1;
  final Color bg2;
  final Color fg;
  final Color muted;
  final Color glow;
  final Color glowShadow;
  final Color crystal;
  final Color accent;
  final Color card;
  final Color line;
  final Color sigil;
}

class WishRoomColors {
  WishRoomColors._();

  /// 심야의 신전 (Midnight Temple) — 기본 소원방 팔레트(촛불금)
  static const midnight = WishRoomPaletteTokens(
    bg1: Color(0xFF1A0D2E),
    bg2: Color(0xFF0A0716),
    fg: Color(0xFFF8F2E6),
    muted: Color(0x9EE8DCC8), // rgba(232,220,200,0.62)
    glow: Color(0xFFF5CF6A),
    glowShadow: Color(0x59F5CF6A), // rgba(245,207,106,0.35)
    crystal: Color(0xFF8DBFD6),
    accent: Color(0xFFC94A3B),
    card: Color(0x0DFFEBC8), // rgba(255,235,200,0.05)
    line: Color(0x1FFFEBC8), // rgba(255,235,200,0.12)
    sigil: Color(0xFFF5CF6A),
  );

  /// 새벽 한지 (Dawn Hanji) — 라이트 팔레트
  static const hanji = WishRoomPaletteTokens(
    bg1: Color(0xFFFAF3E0),
    bg2: Color(0xFFEFE4C8),
    fg: Color(0xFF2A1F14),
    muted: Color(0x8C3C2D1E), // rgba(60,45,30,0.55)
    glow: Color(0xFFD97941),
    glowShadow: Color(0x47D97941), // rgba(217,121,65,0.28)
    crystal: Color(0xFF7BA896),
    accent: Color(0xFF8B3A2B),
    card: Color(0x0F8B5A2B), // rgba(139,90,43,0.06)
    line: Color(0x263C2D1E), // rgba(60,45,30,0.15)
    sigil: Color(0xFF8B5A2B),
  );

  /// 달빛 크리스탈 (Moonlit Crystal) — 복주머니 기능 기본 팔레트
  static const crystal = WishRoomPaletteTokens(
    bg1: Color(0xFF3D3568),
    bg2: Color(0xFF1E1A3A),
    fg: Color(0xFFF0EAFF),
    muted: Color(0xA6DCD2F5), // rgba(220,210,245,0.65)
    glow: Color(0xFFE8C8F5),
    glowShadow: Color(0x59E8C8F5), // rgba(232,200,245,0.35)
    crystal: Color(0xFFA8D5E3),
    accent: Color(0xFF7FB8D4),
    card: Color(0x14C8B4FF), // rgba(200,180,255,0.08)
    line: Color(0x26DCC8FF), // rgba(220,200,255,0.15)
    sigil: Color(0xFFE8C8F5),
  );

  static WishRoomPaletteTokens of(WishRoomPalette p) {
    switch (p) {
      case WishRoomPalette.midnight:
        return midnight;
      case WishRoomPalette.hanji:
        return hanji;
      case WishRoomPalette.crystal:
        return crystal;
    }
  }

  /// 시트/모달의 고정 그라디언트 배경 (GuideModal/ShortageDialog 공용, 팔레트 무관 고정값)
  static const sheetGradientTop = Color(0xFF2C2650);
  static const sheetGradientBottom = Color(0xFF1A1533);
  static const sheetBorder = Color(0x2EDCC8FF); // rgba(220,200,255,0.18)
  static const backdropColor = Color(0xB80A0716); // rgba(10,7,22,0.72)

  /// 인장(Seal) 텍스트 색 — 항상 흰빛 크림톤 고정(팔레트 무관)
  static const sealTextColor = Color(0xFFFFF9E8);
  static const sealBg = Color(0xFFC94A3B); // seal red (accent, midnight 기준 고정 사용처 많음)

  /// 버튼 primary 텍스트(글로우 배경 위) 색 — 항상 진보라 고정
  static const onGlowText = Color(0xFF2A1A3A);
}
