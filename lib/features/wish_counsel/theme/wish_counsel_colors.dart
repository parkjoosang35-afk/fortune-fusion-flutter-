import 'package:flutter/material.dart';

/// 상담(Midnight Comfort) · 디자인 토큰 (Colors)
///
/// 출처: 첨부 핸드오프 `handoff/04_DESIGN_TOKENS.md` §1(컬러) — 단일 진실의
/// 소스. 다크모드 고정(라이트모드 없음), 카테고리별(사주/타로/고민상담)
/// 감정 컬러를 그대로 이식했다.
///
/// 주의: 이 파일의 색상 상수는 오직 `lib/features/wish_counsel/` 내부에서만
/// 참조한다. 앱 전역 `UnifiedColors`(홈 화면 라이트 테마)와 절대 혼용하지
/// 않는다(디자인 시스템 격리 — wish_room/wish_wall_board와 동일 관행).
enum CounselCategory { saju, tarot, counsel }

class CounselCategoryTokens {
  const CounselCategoryTokens({
    required this.bg1,
    required this.bg2,
    required this.glow,
    required this.accent,
    required this.soft,
    required this.shadow,
    required this.label,
    required this.hanja,
    required this.desc,
  });

  final Color bg1;
  final Color bg2;
  final Color glow;
  final Color accent;
  final Color soft;
  final Color shadow;
  final String label;
  final String hanja;
  final String desc;
}

class WishCounselColors {
  WishCounselColors._();

  // ── 뉴트럴 (전 모듈 공통, 다크 고정) ──
  static const Color bg0 = Color(0xFF0A0A12);
  static const Color bg1 = Color(0xFF14141F);
  static const Color bg2 = Color(0xFF1C1C2A);
  static const Color bg3 = Color(0xFF24243A);
  static const Color fg = Color(0xFFF0ECF5);
  static const Color fg2 = Color(0xB8F0ECF5); // rgba(240,236,245,0.72)
  static const Color muted = Color(0x85F0ECF5); // rgba(240,236,245,0.52)
  static const Color faint = Color(0x52F0ECF5); // rgba(240,236,245,0.32)
  static const Color line = Color(0x14F0ECF5); // rgba(240,236,245,0.08)
  static const Color line2 = Color(0x24F0ECF5); // rgba(240,236,245,0.14)
  static const Color card = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)
  static const Color card2 = Color(0x12FFFFFF); // rgba(255,255,255,0.07)

  // ── 카테고리 컬러 ──
  static const saju = CounselCategoryTokens(
    bg1: Color(0xFF0E1B3A),
    bg2: Color(0xFF1A2A55),
    glow: Color(0xFFD4A95C),
    accent: Color(0xFFF0C674),
    soft: Color(0x1FD4A95C),
    shadow: Color(0x4DD4A95C),
    label: '사주',
    hanja: '四柱',
    desc: '흐름과 기운을 읽어요',
  );

  static const tarot = CounselCategoryTokens(
    bg1: Color(0xFF221033),
    bg2: Color(0xFF38184F),
    glow: Color(0xFFD478A7),
    accent: Color(0xFFE896C0),
    soft: Color(0x1FD478A7),
    shadow: Color(0x4DD478A7),
    label: '타로',
    hanja: '塔羅',
    desc: '카드가 답을 건네요',
  );

  static const counsel = CounselCategoryTokens(
    bg1: Color(0xFF14192E),
    bg2: Color(0xFF232C50),
    glow: Color(0xFF7EC8C4),
    accent: Color(0xFF9CD9D5),
    soft: Color(0x1A7EC8C4),
    shadow: Color(0x477EC8C4),
    label: '고민상담',
    hanja: '傾聽',
    desc: '마음을 조용히 들어요',
  );

  static CounselCategoryTokens of(CounselCategory c) {
    switch (c) {
      case CounselCategory.saju:
        return saju;
      case CounselCategory.tarot:
        return tarot;
      case CounselCategory.counsel:
        return counsel;
    }
  }

  // ── 감정 컬러 ──
  static const Map<String, Color> emotionColors = {
    'anxious': Color(0xFF7EC8C4),
    'stuck': Color(0xFFD478A7),
    'excited': Color(0xFFF0C674),
    'tired': Color(0xFFA89CFF),
    'sad': Color(0xFF8AB4FF),
    'angry': Color(0xFFE88A7A),
  };

  /// 위기 감지 배너 전용 색(화나요/경고와 동일 계열, 강조).
  static const Color crisisBg = Color(0xFF3A1620);
  static const Color crisisBorder = Color(0xFFE88A7A);
  static const Color crisisText = Color(0xFFF7D9D2);
}
