import 'package:flutter/material.dart';

/// [귀인지도 화면 전환 배경 플래시 수정 — 사용자 영상 2026-10-14 09:29]
///
/// [증상] `/guinji-map/*` 다크 화면(검정 #0B0B0D) 사이를 이동하면 전환
/// 중에 아이보리/흰색 빈 화면이 깜빡였다(사용자 녹영상 f027~f030 프레임).
///
/// [원인] Android 기본 Zoom 전환(MaterialPageRoute 기본값)은 크로스페이드
/// 방식이라, 전환 중 두 화면 "뒤"의 앱 전역 테마 배경(scaffoldBackgroundColor
/// = 순백색 AppColors.hcBackground)이 그대로 드러난다. 귀인지도 v2 리스킨은
/// 화면을 모두 검정으로 바꿨지만 앱 전역 테마는 라이트(흰색)라 그 틈이
/// 비쳤다. 과거 "아이보리 백지" 제출 버그(guinji_input_screen, endOfFrame
/// 수정)와 같은 계열의 노출 문제다.
///
/// [수정] 페이드 없이 슬라이드만으로 이어지는 불투명(opaque) 전환 — 아래
/// 화면은 항상 불투명한 다크 Scaffold라 배경이 비칠 틈이 없다. 정통사주
/// 섹션이 sajuDimensionEnterRoute(커스텀 PageRouteBuilder)로 같은 문제를
/// 해결한 것과 동일한 선례다.
Route<T> guinjiPageRoute<T extends Object?>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    opaque: true,
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return ColoredBox(
        color: const Color(0xFF0B0B0D),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
