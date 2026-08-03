import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../application/pass_provider.dart';
import 'coupang_pass_sheet.dart';

/// [6단계 운세 탭 정리] 열림패스 기반 이용 구조 공통화.
///
/// 홈 화면(운세 카테고리 그리드)과 FortuneHubScreen(운세 탭) 양쪽에서 동일하게
/// 사용하는 공통 진입 흐름. "각 카테고리 상세 흐름에 공통 패스 체크를 붙인다 /
/// 중복된 진입 흐름이 있으면 공통화한다"는 요구사항에 따라 단일 함수로 통합한다.
///
/// - [requiresPass]가 false면 게이트체크 없이 즉시 라우팅한다(무료 콘텐츠).
/// - [열림패스/복주머니/복주머니 통합정책 §7] AccessChecker.canAccessFortuneScope()가
///   이미 true면(=열림패스 활성) 서버 재검증 없이 즉시 통과시킨다.
/// - 그 외에는 PassProvider.consume()으로 서버 게이트체크 후, 실패 시(유효한
///   열림패스 없음) 발급 유도 바텀시트를 노출한다.
Future<void> navigateWithPassGate(
  BuildContext context, {
  required String title,
  required String route,
  required bool requiresPass,
  // [운세 카테고리 확장] 관리자 카테고리(categoryKey) 탭 시 saju/tarot 공용
  // 입력화면에 초기 토픽/스프레드를 미리 넘겨주기 위한 선택적 라우트 인자.
  // null이면(기존 모든 호출부) 기존 동작과 100% 동일하게 pushNamed(route)만
  // 호출한다(회귀 없음).
  Object? arguments,
}) async {
  if (!requiresPass) {
    Navigator.of(context).pushNamed(route, arguments: arguments);
    return;
  }

  final pass = context.read<PassProvider>();
  if (context.read<AccessChecker>().canAccessFortuneScope()) {
    Navigator.of(context).pushNamed(route, arguments: arguments);
    return;
  }

  final ok = await pass.consume(
    contentType: 'fortune_category',
    contentId: title,
  );
  if (!context.mounted) return;

  if (ok) {
    Navigator.of(context).pushNamed(route, arguments: arguments);
    return;
  }

  await showPassRequiredSheet(context, categoryTitle: title);
}

/// 프리패스 발급 유도 바텀시트 — 진입점.
///
/// [프리패스 단순화 - 쿠팡파트너스 전용] §10 "프리패스는 쿠팡 파트너스 광고
/// 전용 기능으로 운영" 결정에 따라, 과거 광고 시청/파트너 방문/구독 3갈래
/// 선택 목록 + 어드민 광고소스 바인딩 기반 복잡한 OpenPassRewardController
/// 시뮬레이션 플로우를 전부 제거하고, 단일 쿠팡 파트너스 흐름
/// ([showCoupangPassSheet])으로 완전히 대체한다.
///
/// 함수 시그니처(이름 + categoryTitle 파라미터)는 기존과 동일하게 유지해,
/// 이 함수를 호출하는 다른 화면들(all_categories_screen.dart,
/// daily_fortune_result_screen.dart, my_screen.dart 등)은 코드 변경 없이
/// 자동으로 신규 플로우로 전환된다.
Future<void> showPassRequiredSheet(
  BuildContext context, {
  required String categoryTitle,
}) {
  return showCoupangPassSheet(context, categoryTitle: categoryTitle);
}
