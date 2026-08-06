import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// 03단계 §2 + 07단계 §core/theme 구체화
/// Typography: 한글 가독성 우선(시스템 기본 폰트 사용, Pretendard 미포함 환경 대응)
///
/// [9단계 화이트톤 전환] 앱은 화이트/골드 라이트 테마로만 동작하는 정책이
/// 확정되어 이제 다크모드로 진입할 UI 경로가 없다(ThemeProvider가 항상
/// ThemeMode.light 반환). 이에 따라 AppTheme.dark getter와 관련 다크 전용
/// ThemeData 정의(카드/다이얼로그/탭바/버튼/칩/바텀네비/디바이더/스낵바 등)
/// 전체를 삭제했다(유지→수정→통합→off→삭제 원칙의 최종 단계). MaterialApp의
/// darkTheme 파라미터도 app.dart에서 함께 제거했다.
class AppTheme {
  AppTheme._();

  /// [운세 앱 개발 프롬프트-메인 UI 리뉴얼] 앱 전체 기본 폰트 - Pretendard
  /// (현대카드 앱 스타일의 굵고 또렷한 한글 타이포그래피 재현을 위해 채택)
  static const String fontFamily = 'Pretendard';

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.hcGoldDark,
        primary: AppColors.hcGoldDark,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.hcBackground,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.hcBackground,
        foregroundColor: AppColors.hcTextBody,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.hcTextBody,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.hcTextDark,
          height: 1.3,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.hcTextDark,
          height: 1.3,
        ),
        headlineSmall: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.hcTextDark,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.hcTextDark,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.hcTextDark,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.hcTextBody,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.hcTextSecondary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textHint,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.hcCardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.hcCardLarge),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.hcCardLarge),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.hcGoldDark,
        unselectedLabelColor: AppColors.hcTextSecondary,
        indicatorColor: AppColors.hcGoldDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hcInk,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.hcButtonPill),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.hcGoldDark,
          side: const BorderSide(color: AppColors.hcGoldDark),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.hcButtonPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.hcGoldDark),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.hcCream,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.hcGoldDark,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        side: BorderSide.none,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.hcGoldDark,
        unselectedItemColor: AppColors.hcTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hcBorderLight,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.hcGoldDark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.hcGoldDark,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonSmall),
        ),
      ),
    );
  }
}
