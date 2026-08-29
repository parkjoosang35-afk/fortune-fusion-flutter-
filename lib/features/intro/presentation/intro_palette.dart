import 'package:flutter/material.dart';

/// [인트로 3종 색상 정리 → Moonlit Crystal 리스킨] 스플래시/인트로페이저
/// (카드1·카드2)/CTA 3개 화면 전용 브랜드 팔레트.
///
/// [2026 디자인 핸드오프 반영] 온보딩 디자인 핸드오프(design_handoff_onboarding_flow)의
/// "Moonlit Crystal(달빛 크리스탈)" 팔레트 값을 그대로 이식했다. 이 값들은 프로젝트에
/// 이미 존재하는 `wish_room/theme/wish_room_theme.dart`의 `WishRoomColors`와
/// 색상값이 완전히 동일하다(다크 보라~네이비 배경 + 라벤더 glow 강조 + 아쿠아 accent).
///
/// [범위 격리 원칙 유지] `core/theme/app_unified_style.dart`의 `UnifiedColors`
/// (앱 전역 화이트 톤, 216회+ 참조)와 `core/theme/app_colors.dart`(메인 브랜드 컬러)는
/// 절대 건드리지 않는다. 이 파일은 인트로 3개 화면(및 그 하위 위젯)에서만 참조되는
/// 격리된 전용 팔레트다 — 웰컴 리워드 팝업(Phase C)도 이 원칙에 따라 별도 격리된
/// 색상만 사용하고 앱 전역 메인 컬러는 참조하지 않는다.
class IntroPalette {
  IntroPalette._();

  /// 화면 배경 그라데이션 상단(핸드오프 --bg-1).
  static const Color backgroundTop = Color(0xFF3D3568);

  /// 화면 배경 그라데이션 하단(핸드오프 --bg-2).
  static const Color backgroundBottom = Color(0xFF1E1A3A);

  /// 기존 참조 호환용 별칭(Scaffold backgroundColor 등 단일 색 필요 시).
  static const Color backgroundSoft = backgroundTop;

  /// 포인트 컬러 - 달빛 라벤더 glow(핸드오프 --glow). 버튼/인디케이터/강조 아이콘에 사용.
  static const Color primary = Color(0xFFE8C8F5);

  /// 그라데이션 보조 톤 - 아쿠아 accent(핸드오프 --accent).
  static const Color primaryDark = Color(0xFF7FB8D4);

  /// 반투명 카드/배지 배경(핸드오프 --card, 다크 배경 위에 얹는 옅은 오버레이).
  static const Color primaryLight = Color(0x14C8B4FF);

  /// 카드/배지 테두리(핸드오프 --line).
  static const Color cardBorder = Color(0x26DCC8FF);

  /// glow(=primary) 솔리드 배경 위에 얹는 텍스트/아이콘 색
  /// (핸드오프 버튼 텍스트 색 #2a1a3a와 동일 톤 - 대비 확보용 진한 남보라).
  static const Color onPrimary = Color(0xFF2A1A3A);

  /// 다크 배경 위 기본 텍스트(핸드오프 --fg).
  static const Color textPrimary = Color(0xFFF0EAFF);

  /// 다크 배경 위 보조/캡션 텍스트(핸드오프 --muted).
  static const Color textSecondary = Color(0xA6DCD2F5);

  /// 페이지 인디케이터(비활성 점) 등 아주 옅은 강조가 필요한 자리 전용.
  /// primaryLight(카드 오버레이용, alpha 8%)보다 조금 더 진해 다크 배경에서도
  /// 위치를 식별할 수 있다.
  static const Color indicatorInactive = Color(0x40DCC8FF);

  // ───────────────────────── [핸드오프 콘텐츠 반영] 추가 색상 ─────────────────────────
  // 아래 3개는 2026 핸드오프 콘텐츠 재작업(카피/구조 1:1 이식) 시 새로 필요해진
  // 값으로, tokens/colors_and_type.css의 나머지 변수를 마저 옮긴 것이다.

  /// 페이지2(오늘의 결) 캐릭터 halo·accent 그라디언트용 아쿠아(핸드오프 --crystal).
  static const Color crystal = Color(0xFFA8D5E3);

  /// 제목 accent 그라디언트 상단 톤(핸드오프 --gold), page2/4 title.accent에 사용.
  static const Color gold = Color(0xFFF5D97A);

  /// 제목 text-shadow 전용(핸드오프 --glow-shadow, primary의 35% 알파).
  static const Color glowShadow = Color(0x59E8C8F5);

  // ───────────────────────── [Phase B - 02_SignUp_Login.html 반영] ─────────────────────────

  /// 필드 에러/위험 상태 전용(핸드오프 --danger). 로그인/회원가입 화면에서
  /// 비밀번호 확인 불일치 등 에러 힌트 텍스트·테두리에 사용한다. 인트로
  /// 3화면(01_Intro.html)에는 없던 색으로, 02번 핸드오프 문서에서 처음 등장했다.
  static const Color danger = Color(0xFFF5A8BD);
}
