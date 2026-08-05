import 'package:flutter/material.dart';

/// [타로 섹션 전면 개편 §5 디자인 시스템] 타로 전용 다크 미스틱 토큰.
///
/// 앱 전역 라이트 테마([UnifiedColors], `app_unified_style.dart`)와 완전히
/// 분리된 별도의 색상 세트다. 기존 `AppColors`(다크 팔레트, `deepSpace`/
/// `mysticGradient`/`goldGradient` 등)는 다른 다크 화면(로딩류)에서도 범용으로
/// 참조되고 있어 값을 바꾸면 그 화면들에 영향을 준다. 따라서 "타로만의 색
/// 규칙"(금색 절제 + 핑크글로우/문라이트실버 확대)을 강제하기 위해 이 파일을
/// 신설하고, 값 자체는 기존 `AppColors`의 검증된 다크 톤(`deepSpace`,
/// `deepSpaceLight`, `primaryLight` 등)을 재사용/보강하는 방식으로 정의한다.
///
/// 금색 절제 규칙(§5-1 명문화): [goldAccentGradient]는 (1) 프리미엄 배지,
/// (2) 금전 그룹 카테고리 컬러, (3) 결과화면 "행운의 숫자/색" 타일 등
/// 국소 강조에만 사용한다. 카드 프론트 전체 배경, 히어로 전체 배경, CTA
/// 버튼 배경에는 사용하지 않는다.
class TarotColors {
  TarotColors._();

  // ── 배경 레이어(메인, §5-2 레이어드 배경의 L1) ──
  static const Color bgVoid = Color(0xFF07061A); // 가장 깊은 배경(별빛 대비 확보)
  static const Color bgIndigo = Color(0xFF181433); // 중간 레이어
  static const Color bgNavy = Color(0xFF23204A); // 상단 레이어

  // ── 포인트 컬러(요구사항 3색: pink glow / starlight gold / moonlight silver) ──
  static const Color pinkGlow = Color(0xFFFF9EC4);
  static const Color pinkGlowDeep = Color(0xFFB76FA8);
  static const Color starlightGold = Color(0xFFE8C97A); // 채도를 낮춰 "과한 금색" 방지
  static const Color starlightGoldDeep = Color(0xFFD9A85C);
  static const Color moonSilver = Color(0xFFC9D3EC);
  static const Color moonSilverDeep = Color(0xFFA5B4D8);

  // ── 텍스트(다크 배경 대비, WCAG AA 이상 명도대비 확보) ──
  static const Color textPrimary = Color(0xFFF3F1FF);
  static const Color textSecondary = Color(0xFFB2AEDB);
  static const Color textFaint = Color(0xFF7C77A8);

  // ── 카드/섹션 표면 ──
  static const Color surfaceCard = Color(0x14FFFFFF); // 반투명 화이트(유리질감)
  static const Color surfaceCardStrong = Color(0x1FFFFFFF);
  static const Color borderSoft = Color(0x1FFFFFFF);
  static const Color borderGlow = Color(0x3AFF9EC4); // 강조 카드용 핑크 글로우 보더

  // ── 그라디언트 ──
  static const LinearGradient nightGradient = LinearGradient(
    colors: [bgVoid, bgIndigo, bgNavy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient pinkGlowGradient = LinearGradient(
    colors: [pinkGlowDeep, pinkGlow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient moonSilverGradient = LinearGradient(
    colors: [moonSilverDeep, moonSilver],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 금색은 국소 강조 전용(§5-1 규칙). 전체 배경에 사용 금지.
  static const LinearGradient goldAccentGradient = LinearGradient(
    colors: [starlightGoldDeep, starlightGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 카드 뒷면 등 "타로다움"의 기본 배경(기존 AppColors.mysticGradient 계열
  /// 톤을 승계해 시각적 일관성을 유지하되, 이 파일 내에서 독립적으로 관리).
  static const LinearGradient cardBackGradient = LinearGradient(
    colors: [bgVoid, pinkGlowDeep, bgNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── 카테고리 그룹 대표 컬러(§4 서브카테고리 설계와 1:1 대응) ──
  static const Color groupLove = Color(0xFFB76FA8); // 로즈퍼플
  static const Color groupLoveGlow = Color(0xFFFF9EC4); // 핑크글로우
  static const Color groupCareer = Color(0xFF5B7FC4); // 블루실버
  static const Color groupWealth = Color(
    0xFFD9A85C,
  ); // 앰버골드(이 그룹에서만 절제된 강조로 허용)
  static const Color groupDaily = Color(0xFFB7C4E0); // 문라이트실버
  static const Color groupEmotion = Color(0xFFC9AEE0); // 라일락
  static const Color groupSpecial = Color(0xFF5B3A8C); // 진한 퍼플
  static const Color groupSpecialNavy = Color(0xFF1B1B3A);

  static Color textHintOf(BuildContext context) => textFaint;
}
