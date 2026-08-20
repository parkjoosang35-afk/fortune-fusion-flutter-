import 'package:flutter/material.dart';

/// [인트로 3종 색상 정리] 스플래시/인트로페이저(카드1·카드2)/CTA 3개 화면
/// 전용 브랜드 팔레트. 사용자 지정 브랜드 컬러 #90035C(진한 마젠타)를
/// 기준으로 한 톤온톤 구성이다.
///
/// [범위 격리 이유] `core/theme/app_unified_style.dart`의 `UnifiedColors`는
/// 앱 전체 216회+ 참조되는 공용 토큰이라, 여기 값을 바꾸면 인트로 3종 외의
/// 모든 화면(홈/결과/마이페이지 등)의 색까지 함께 바뀐다. 이번 요청은
/// "인트로 3종만" 정리이므로, 공용 토큰은 그대로 두고 이 파일의 전용
/// 팔레트만 인트로 3개 화면(및 그 하위 위젯)에서 참조하도록 분리한다.
class IntroPalette {
  IntroPalette._();

  /// 브랜드 포인트 컬러(사용자 지정).
  static const Color primary = Color(0xFF90035C);

  /// 그라데이션/눌림 상태 등에 쓰는 한 단계 더 짙은 톤.
  static const Color primaryDark = Color(0xFF6E0247);

  /// 카드/배지 등 옅은 배경에 쓰는 톤(브랜드 컬러의 라이트 틴트).
  static const Color primaryLight = Color(0xFFF7E4EF);

  /// 화면 배경 그라데이션의 끝단(거의 흰색에 가까운 아주 옅은 톤).
  static const Color backgroundSoft = Color(0xFFFDF5FA);

  /// 브랜드 컬러 위에 얹는 텍스트/아이콘 색.
  static const Color onPrimary = Color(0xFFFFFFFF);
}
