/// [BirthdayPickerModal 포팅 — 2/4: 팔레트]
///
/// 원본: `handoff-extract/BirthdayPickerModal.jsx`의 `PALETTES` 객체를
/// Dart로 포팅. 색상 HEX 값은 원본과 완전히 동일하게 유지한다(디자인
/// 핸드오프 계약 — 임의 변형 금지). `colors_and_type.css`의 두 팔레트
/// (Midnight Temple / Dawn Hanji) 값과도 일치한다.
library;

import 'package:flutter/material.dart';

enum BirthdayPickerPalette { midnight, hanji }

class BirthdayPickerColors {
  const BirthdayPickerColors({
    required this.bg1,
    required this.bg2,
    required this.tail,
    required this.fg,
    required this.muted,
    required this.glow,
    required this.glowShadow,
    required this.line,
    required this.card,
    required this.cardHover,
    required this.chipBorder,
    required this.slotEmpty,
    required this.slotHint,
    required this.ctaText,
    required this.errorColor,
    required this.checkGlyph,
    required this.backdrop,
    required this.sigilColor,
    required this.sigilOpacity,
    required this.stars,
    required this.hanjiGrain,
    required this.overlay,
    required this.bgWashes,
  });

  final Color bg1;
  final Color bg2;
  final Color tail;
  final Color fg;
  final Color muted;
  final Color glow;
  final Color glowShadow;
  final Color line;
  final Color card;
  final Color cardHover;
  final Color chipBorder;
  final Color slotEmpty;
  final Color slotHint;
  final Color ctaText;
  final Color errorColor;
  final Color checkGlyph;
  final Color backdrop;
  final Color sigilColor;
  final double sigilOpacity;
  final bool stars;
  final bool hanjiGrain;
  final Color overlay;

  /// 배경 그라디언트 워시(장식용 radial gradient 3겹) — CustomPainter에서
  /// 사용할 색상 목록.
  final List<Color> bgWashes;
}

const BirthdayPickerColors _midnight = BirthdayPickerColors(
  bg1: Color(0xFF1A0D2E),
  bg2: Color(0xFF0A0716),
  tail: Color(0xFF05030D),
  fg: Color(0xFFF8F2E6),
  muted: Color(0x9EE8DCC8), // rgba(232,220,200,0.62)
  glow: Color(0xFFF5CF6A),
  glowShadow: Color(0x59F5CF6A), // rgba(245,207,106,0.35)
  line: Color(0x1FFFEBC8), // rgba(255,235,200,0.12)
  card: Color(0x0FFFEBC8), // rgba(255,235,200,0.06)
  cardHover: Color(0x1EF5CF6A), // rgba(245,207,106,0.12)
  chipBorder: Color(0x80F5CF6A),
  slotEmpty: Color(0x40E8DCC8), // rgba(232,220,200,0.25)
  slotHint: Color(0x66E8DCC8), // rgba(232,220,200,0.4)
  ctaText: Color(0xFF2A1F14),
  errorColor: Color(0xFFE88A75),
  checkGlyph: Color(0xFF2A1F14),
  backdrop: Color(0x9905030D), // rgba(5,3,13,0.6)
  sigilColor: Color(0xFFF5CF6A),
  sigilOpacity: 0.55,
  stars: true,
  hanjiGrain: false,
  overlay: Color(0xDD0A0716),
  bgWashes: [
    Color(0x248DBFD6), // rgba(141,191,214,0.14)
    Color(0x1FF5CF6A), // rgba(245,207,106,0.12)
    Color(0x19C94A3B), // rgba(201,74,59,0.10)
  ],
);

const BirthdayPickerColors _hanji = BirthdayPickerColors(
  bg1: Color(0xFFFAF3E0),
  bg2: Color(0xFFEFE4C8),
  tail: Color(0xFFE8D9B3),
  fg: Color(0xFF2A1F14),
  muted: Color(0x8C3C2D1E), // rgba(60,45,30,0.55)
  glow: Color(0xFFD97941),
  glowShadow: Color(0x47D97941), // rgba(217,121,65,0.28)
  line: Color(0x263C2D1E), // rgba(60,45,30,0.15)
  card: Color(0x0F8B5A2B), // rgba(139,90,43,0.06)
  cardHover: Color(0x24D97941), // rgba(217,121,65,0.14)
  chipBorder: Color(0x80D97941),
  slotEmpty: Color(0x383C2D1E), // rgba(60,45,30,0.22)
  slotHint: Color(0x663C2D1E), // rgba(60,45,30,0.4)
  ctaText: Color(0xFFFAF3E0),
  errorColor: Color(0xFF8B3A2B),
  checkGlyph: Color(0xFFFAF3E0),
  backdrop: Color(0x593C2D1E), // rgba(60,45,30,0.35)
  sigilColor: Color(0xFF8B5A2B),
  sigilOpacity: 0.28,
  stars: false,
  hanjiGrain: true,
  overlay: Color(0xBFFAF3E0),
  bgWashes: [
    Color(0x1AD97941), // rgba(217,121,65,0.10)
    Color(0x148B3A2B), // rgba(139,58,43,0.08)
    Color(0x1A8B5A2B), // rgba(139,90,43,0.10)
  ],
);

const Map<BirthdayPickerPalette, BirthdayPickerColors> kBirthdayPalettes = {
  BirthdayPickerPalette.midnight: _midnight,
  BirthdayPickerPalette.hanji: _hanji,
};
