import 'package:flutter/material.dart';
import 'app_colors.dart';

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §5 폰트 시스템
///
/// Pretendard 기준 타이포 위계를 중앙 관리한다. 화이트 프리미엄 리디자인
/// 대상 화면(HomeScreen 등)은 이 클래스의 스타일을 우선 사용하고,
/// 기존 화면(TextTheme.headlineLarge 등)은 그대로 유지한다.
///
/// 위계:
/// - Hero Title    28 / Bold
/// - Section Title 20 / Bold
/// - Card Title    17 / SemiBold
/// - Body Main     15 / Regular
/// - Body Strong   15 / Medium
/// - Caption       13 / Regular
/// - Small Label   12 / Medium
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Pretendard';

  static const TextStyle heroTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.premiumTextPrimary,
    height: 1.3,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.premiumTextPrimary,
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.premiumTextPrimary,
    height: 1.35,
  );

  static const TextStyle bodyMain = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.premiumTextSecondary,
    height: 1.45,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.premiumTextPrimary,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.premiumTextSecondary,
    height: 1.4,
  );

  static const TextStyle smallLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.premiumTextTertiary,
    height: 1.3,
  );
}
