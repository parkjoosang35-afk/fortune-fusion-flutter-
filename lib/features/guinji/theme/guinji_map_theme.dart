import 'package:flutter/material.dart';

/// [2026-09 새 디자인 리스킨] `/guinji-map/*` 8화면(L/I/C/M/N/F/S/Y) 전용
/// 아이보리 + 로즈골드 팔레트. 기존 `guinji_theme.dart`의 `GuinjiColors`
/// (다크/라벤더 톤, `/guinji/*` 프로덕션 화면 및 이전 리스킨 버전에서 사용)
/// 와는 완전히 분리된 네임스페이스다. 절대 혼용하지 말 것.
///
/// 새 디자인 zip `lib/guiindo/theme/colors.dart`의 `AppColors`를 그대로
/// 이식한 값이며, 색상 하나하나 동일하다.
class GmColors {
  GmColors._();

  // 배경
  static const bgIvory = Color(0xFFFBF7EF);
  static const bgCream = Color(0xFFF5EBDC);
  static const parchment = Color(0xFFF0E4D0);

  // 로즈골드
  static const rose50 = Color(0xFFFBEFE8);
  static const rose100 = Color(0xFFF5D9C9);
  static const rose200 = Color(0xFFEFC4AB);
  static const rose300 = Color(0xFFE2A88A);
  static const rose400 = Color(0xFFD69175);
  static const rose500 = Color(0xFFC99B7F);
  static const rose600 = Color(0xFFB58567);
  static const rose700 = Color(0xFFA6795E);
  static const rose800 = Color(0xFF7E5A47);
  static const rose900 = Color(0xFF5A4131);

  // Accent
  static const blush = Color(0xFFE8B4A5);
  static const gold = Color(0xFFD4A574);
  static const goldLight = Color(0xFFE8CBA0);

  // 텍스트
  static const ink = Color(0xFF2A2438);
  static const inkSoft = Color(0xFF6E5A54);
  static const inkFaint = Color(0xFFA08C82);
  static const ivory = Color(0xFFFBF7EF);

  // 라인
  static const line = Color(0xFFE8DDD0);
  static const lineSoft = Color(0xFFF0E7DA);

  // 카테고리별 색상(귀인/인연/보완/조심) — GuinjiRelationMeta.category와 매핑.
  static const categoryBoost = rose500; // 귀인
  static const categoryPath = gold; // 인연
  static const categoryWarm = blush; // 보완
  static const categoryCare = rose800; // 조심

  // 그라디언트
  static const gradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2438), Color(0xFF4A3A4A)],
  );

  static const gradientRose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [rose400, rose500],
  );

  static const gradientRoseText = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [rose700, blush],
  );

  /// [GuinjiRelationMeta.category] → 카테고리 대표 색상.
  static Color categoryColor(String category) {
    switch (category) {
      case 'boost':
        return categoryBoost;
      case 'path':
        return categoryPath;
      case 'warm':
        return categoryWarm;
      case 'care':
        return categoryCare;
    }
    return categoryBoost;
  }
}

/// 폰트 패밀리 — 기존 `GuinjiFonts`와 동일한 실제 폰트 리소스(NotoSerifKR /
/// Pretendard)를 가리키므로 새로 등록할 필요 없이 이름만 다시 노출한다.
class GmFonts {
  GmFonts._();
  static const serif = 'NotoSerifKR';
  static const sans = 'Pretendard';
}

class GmText {
  GmText._();

  static const display = TextStyle(
    fontFamily: GmFonts.serif,
    fontSize: 44,
    height: 1.15,
    letterSpacing: -0.88,
    fontWeight: FontWeight.w700,
    color: GmColors.ink,
  );

  static const h1 = TextStyle(
    fontFamily: GmFonts.serif,
    fontSize: 32,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: GmColors.ink,
  );

  static const h2 = TextStyle(
    fontFamily: GmFonts.serif,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: GmColors.ink,
  );

  static const h3 = TextStyle(
    fontFamily: GmFonts.serif,
    fontSize: 20,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: GmColors.ink,
  );

  static const body = TextStyle(fontSize: 15, height: 1.6, color: GmColors.ink);

  static const bodySoft = TextStyle(
    fontSize: 13.5,
    height: 1.6,
    color: GmColors.inkSoft,
  );

  static const small = TextStyle(fontSize: 13, height: 1.5, color: GmColors.inkSoft);

  static const micro = TextStyle(
    fontSize: 11,
    height: 1.4,
    letterSpacing: 0.44,
    color: GmColors.inkFaint,
  );

  static const labelMini = TextStyle(
    fontSize: 10,
    height: 1,
    letterSpacing: 1.2,
    color: GmColors.rose700,
    fontWeight: FontWeight.w600,
  );
}
