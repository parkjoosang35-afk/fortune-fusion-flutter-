import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/widgets/app_dialog.dart';
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
  // [STEP8 - Flutter categoryKey 연동] fortune_categories.category_key와
  // 동일한 값(예: 'saju', 'name', 'face', 'palm', 'compatibility')을 넘기면
  // 서버가 "이 프리패스로 이 카테고리를 이미 2회 이용했는지"도 함께 확인한다.
  // null이면(기존 모든 호출부) 기존과 동일하게 활성 패스 여부만 확인한다.
  //
  // [주의 - 타로] 타로는 topic/spreadType에 따라 서버가 categoryKey를
  // tarot/tarot_yesno/tarot_love 중 하나로 동적 결정하는데, 이 게이트 시점
  // (카드 목록 탭)에는 아직 topic이 확정되지 않은 경우가 많아 여기서 잘못된
  // categoryKey를 넘기면 "정상 이용 가능한데 오탐 차단"이 발생할 수 있다.
  // 따라서 타로 호출부는 categoryKey를 넘기지 않는다(NO_ACTIVE_PASS만 게이트
  // 확인, 정확한 카테고리별 2회 제한은 tarot API 자신이 최종 담당).
  String? categoryKey,
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
    categoryKey: categoryKey,
  );
  if (!context.mounted) return;

  if (ok) {
    Navigator.of(context).pushNamed(route, arguments: arguments);
    return;
  }

  // [STEP8] 카테고리별 이용횟수 초과(CATEGORY_LIMIT_REACHED)는 "패스가 없다"는
  // 안내가 아니라 서버가 내려준 구체적인 안내 문구(예: "오늘 이 프리패스로
  // 이용할 수 있는 횟수(2회)를 모두 사용했습니다.")를 그대로 보여준다.
  if (pass.lastErrorReason == 'CATEGORY_LIMIT_REACHED' && context.mounted) {
    await showCategoryLimitReachedSheet(
      context,
      categoryTitle: title,
      message: pass.lastError,
    );
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

/// [STEP8 - Flutter categoryKey 연동] 카테고리별 이용횟수 초과
/// (CATEGORY_LIMIT_REACHED) 안내 다이얼로그.
///
/// "패스가 없어서 못 본다"는 [showPassRequiredSheet](쿠팡 광고 유도)와는
/// 성격이 완전히 다르다 — 이미 유효한 열림패스를 갖고 있지만 해당 카테고리를
/// 이번 패스로 이미 최대 횟수(기본 2회)만큼 이용했다는 뜻이므로, 광고를 다시
/// 보라고 유도하지 않고 서버가 내려준 안내 문구만 보여주고 닫는다.
Future<void> showCategoryLimitReachedSheet(
  BuildContext context, {
  required String categoryTitle,
  String? message,
}) {
  return showAppInfoDialog(
    context,
    title: '이용 횟수 초과',
    message: message ??
        '$categoryTitle 운세는 이번 프리패스로 이용할 수 있는 횟수를 모두 사용했습니다.',
    confirmLabel: '확인',
  );
}
