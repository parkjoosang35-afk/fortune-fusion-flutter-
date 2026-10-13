import 'package:flutter/material.dart';

/// [사용자 피드백 — 상단바·하단바에서 클릭해 들어가는 화면들] 지갑·알림·
/// 설정(마이페이지) 등 2차 화면이 기본 흰 바탕이라 메인페이지(다크)와
/// 이어지지 않는 문제를 해결한다. 각 화면의 Scaffold를 이 테마로 감싸면
/// 기본 글자색·앱바·위젯 색이 다크로 통일된다(명시적 색상은 그대로 유지).
ThemeData sintongDarkPageTheme() {
  const bg = Color(0xFF0B0B0D);
  const gold = Color(0xFFE9C46A);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(
      surface: bg,
      primary: gold,
      secondary: gold,
      onSurface: Color(0xFFF2F0EC),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: Color(0xFFF2F0EC),
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: const Color(0x22FFFFFF),
    listTileTheme: const ListTileThemeData(iconColor: Color(0xFFF2F0EC)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? gold : Colors.white38,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? gold.withValues(alpha: .45)
            : Colors.white24,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF241A08),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: gold),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1C1C1F),
      contentTextStyle: TextStyle(color: Color(0xFFF2F0EC)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// [페이지 다크 래퍼] 화면 코드를 거의 건드리지 않고 테마만 씌운다.
class DarkPage extends StatelessWidget {
  const DarkPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Theme(data: sintongDarkPageTheme(), child: child);
}
