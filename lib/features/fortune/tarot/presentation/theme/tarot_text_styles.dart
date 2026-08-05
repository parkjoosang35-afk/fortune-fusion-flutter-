import 'package:flutter/material.dart';
import 'tarot_colors.dart';

/// [타로 섹션 전면 개편 §5-3 타이포그래피 / 폰트 일관성 정리]
///
/// 이전에는 제목류에 `GowunBatang`(세리프) 폰트를 지정했으나, 이 폰트 자산이
/// 프로젝트에 실제로 존재하지 않아(`pubspec.yaml` 미등록, 파일 없음)
/// 플랫폼마다 다른 시스템 기본 세리프로 조용히 폴백되고 있었다. 그 결과
/// 본문(Pretendard, 산세리프)과 제목의 스타일·체감 크기가 어긋나 "폰트가
/// 일정하지 않다"는 문제가 발생했다. 이를 해결하기 위해 제목/본문 모두
/// `Pretendard` 하나로 통일하고, 전체 크기 스케일도 한 단계씩 낮춰
/// 화면 전체의 위계를 촘촘하고 일관되게 재정렬했다.
///
/// 크기 스케일(축소 후): heroTitle 20 > screenTitle 18 > categoryTitle 16
/// > sectionHeader 15 > ctaLabel/body/bodyStrong 14 > bodySmall/moodCopy 12
/// > caption/chipLabel 11.
class TarotTextStyles {
  TarotTextStyles._();

  static const String _fontFamily = 'Pretendard';

  // ── 제목류(Pretendard로 통일, 두께로 위계 표현) ──
  static const TextStyle heroTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: TarotColors.textPrimary,
    letterSpacing: 0.2,
    height: 1.35,
  );

  static const TextStyle screenTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: TarotColors.textPrimary,
    letterSpacing: 0.1,
    height: 1.35,
  );

  static const TextStyle categoryTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: TarotColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: TarotColors.textPrimary,
  );

  // ── 본문(가독성 우선) ──
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: TarotColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: TarotColors.textPrimary,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: TarotColors.textSecondary,
    height: 1.55,
  );

  static const TextStyle moodCopy = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    color: TarotColors.textFaint,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: TarotColors.textFaint,
  );

  static const TextStyle chipLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: TarotColors.textPrimary,
  );

  static const TextStyle ctaLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: TarotColors.textPrimary,
    letterSpacing: 0.2,
  );
}
