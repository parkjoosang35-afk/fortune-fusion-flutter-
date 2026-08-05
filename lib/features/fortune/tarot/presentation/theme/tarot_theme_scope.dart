import 'package:flutter/material.dart';
import 'tarot_colors.dart';
import 'tarot_perf_monitor.dart';

/// [타로 섹션 전면 개편 §10-3] 타로 서브트리 전체를 다크 미스틱 톤으로
/// 감싸는 스코프 위젯.
///
/// 앱 전역 라이트 테마([UnifiedColors])를 건드리지 않고, 타로 라우트에
/// 진입한 순간부터 `Theme.of(context)`가 다크 브랜치를 반환하도록
/// [Theme] 위젯으로 `ThemeData(brightness: Brightness.dark, ...)`를
/// 국소적으로 주입한다. 이렇게 해야 다른 화면(홈/커뮤니티 등)에 회귀
/// 버그를 만들지 않는다(§1-3 실행 원칙 3).
///
/// [§11 P6] 모든 타로 화면이 예외 없이 이 위젯으로 감싸져 있다는 점을
/// 이용해([TarotThemeScope]는 8개 화면 전부의 공통 진입점), 여기 한
/// 곳에서만 [TarotPerfMonitor.enter]/`exit`를 연결하면 화면마다 개별
/// 배선할 필요 없이 "타로 섹션에 머무는 동안" 자동으로 프레임 성능을
/// 관측할 수 있다(과설계 방지 - 신규 배선 지점 최소화).
class TarotThemeScope extends StatefulWidget {
  final Widget child;
  const TarotThemeScope({super.key, required this.child});

  static ThemeData buildThemeData() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TarotColors.bgVoid,
      canvasColor: TarotColors.bgVoid,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.dark(
        primary: TarotColors.pinkGlow,
        secondary: TarotColors.starlightGold,
        surface: TarotColors.bgIndigo,
        onSurface: TarotColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: TarotColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: TarotColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: TarotColors.borderSoft,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  @override
  State<TarotThemeScope> createState() => _TarotThemeScopeState();
}

class _TarotThemeScopeState extends State<TarotThemeScope> {
  @override
  void initState() {
    super.initState();
    TarotPerfMonitor.enter();
  }

  @override
  void dispose() {
    TarotPerfMonitor.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: TarotThemeScope.buildThemeData(), child: widget.child);
  }
}
