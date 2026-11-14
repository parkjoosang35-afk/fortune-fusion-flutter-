import 'package:flutter/material.dart';

/// [반응형 완전 정비 — 2026-11, 전역 글자배율 안전망]
///
/// ## 배경 (사용자 리포트: "어떤 휴대폰에선 사이즈가 말도 안되게 안 잡힌다")
/// 안드로이드/iOS 기기에는 "설정 > 디스플레이 > 글자 크기(접근성)"가 있고,
/// 이 값은 Flutter에 `MediaQuery.textScalerOf(context)`로 전달된다. 이
/// 배율은 기기·사용자 설정에 따라 0.85배 ~ 2.0배 이상까지 다양하게
/// 퍼져 있는데, 지금까지 이 앱은 이 배율을 **딱 2개 화면**
/// (`character_shop_screen.dart`, `wishroom_shell.dart`)에서만 1.3배로
/// 제한했고, 나머지 모든 화면은 시스템 배율을 그대로 받아 썼다.
///
/// 고정 크기 박스에 큰 글자가 들어가면 텍스트가 잘리거나, 버튼이
/// 화면 밖으로 밀려나거나, 카드가 깨지는 문제가 생긴다 — 이것이
/// "어떤 기기에서는 말도 안 되게 사이즈가 안 잡힌다"는 현상의 핵심
/// 원인 중 하나다. (반대로 아주 작게 보이는 경우는 하드코딩된
/// `fontSize`가 애초에 작게 디자인된 화면의 문제이며, 이쪽은 화면별
/// 정밀 수정 대상이다 — `docs/RESPONSIVE_AUDIT.md` 참고.)
///
/// ## 해결 방식
/// 이미 두 화면에서 검증되어 실사용 중인 "1.3배 상한" 정책을
/// `MaterialApp.builder`(모든 라우트/팝업/모달의 공통 조상) 레벨로
/// 승격해 **앱 전체에 자동 적용**한다. 개별 화면의 기존 로컬 clamp는
/// 그대로 둬도 무해하다(이미 1.3배 이하인 값을 다시 1.3배로 clamp해도
/// 변화 없음 — min(x, 1.3)을 두 번 적용하는 것과 동일).
///
/// 하한(0.9배)도 함께 두는 이유: 일부 기기는 "작게" 설정을 0.85배
/// 이하로 지원하는데, 디자인 기준 폰트 크기 자체가 가독성을 고려해
/// 정해진 값이므로 지나치게 작아지면 반대로 가독성이 나빠진다.
///
/// 이 값들은 QA 전용 `?ts=` 오버라이드(`readQaTextScaleOverride`)와는
/// 완전히 독립적으로 동작한다 — 적용 순서는 app.dart에서
/// "시스템 배율 clamp → QA 오버라이드" 순으로 체이닝된다.
class AppTextScaleGuard {
  AppTextScaleGuard._();

  /// 허용 최소 배율. 이보다 작은 시스템 설정은 이 값으로 올림(clamp)한다.
  static const double minScale = 0.9;

  /// 허용 최대 배율. 이보다 큰 시스템 설정(접근성 "매우 크게" 등)은
  /// 이 값으로 내림(clamp)한다. 기존에 두 화면에서 검증되어 실사용
  /// 중이던 1.3배 정책과 동일한 값이다.
  static const double maxScale = 1.3;

  /// 주어진 [context]의 현재 시스템 텍스트 배율을 [minScale]~[maxScale]
  /// 범위로 제한한 [TextScaler]를 반환한다.
  static TextScaler clamp(BuildContext context) {
    return MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: minScale, maxScaleFactor: maxScale);
  }
}
