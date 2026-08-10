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
  // null이면 [route]를 기준으로 [_categoryKeyByRoute]에서 자동으로 추론한다
  // (모든 호출부를 일일이 수정하지 않아도 되도록, 그리고 누락을 방지하기
  // 위해 이 헬퍼 한 곳에서 매핑을 관리한다). 명시적으로 categoryKey를
  // 넘기면 그 값이 항상 우선한다.
  //
  // [주의 - 타로] 타로는 topic/spreadType에 따라 서버가 categoryKey를
  // tarot/tarot_yesno/tarot_love 중 하나로 동적 결정하는데, 이 게이트 시점
  // (카드 목록 탭)에는 아직 topic이 확정되지 않은 경우가 많아 여기서 잘못된
  // categoryKey를 넘기면 "정상 이용 가능한데 오탐 차단"이 발생할 수 있다.
  // 따라서 타로 라우트는 [_categoryKeyByRoute]에 포함하지 않는다(NO_ACTIVE_PASS만
  // 게이트 확인, 정확한 카테고리별 2회 제한은 tarot API 자신이 최종 담당).
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

  final resolvedCategoryKey = categoryKey ?? _categoryKeyByRoute[route];

  final ok = await pass.consume(
    contentType: 'fortune_category',
    contentId: title,
    categoryKey: resolvedCategoryKey,
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

/// [STEP8 - Flutter categoryKey 연동] 라우트 문자열 → 서버
/// fortune_categories.category_key 자동 매핑표.
///
/// [navigateWithPassGate]를 호출하는 모든 화면(all_categories_screen.dart,
/// home_screen.dart, fortune_hub_screen.dart 등)을 일일이 찾아 categoryKey를
/// 수동으로 넘기게 하면 누락 위험이 크므로, "이 라우트로 들어가면 항상 이
/// categoryKey"라는 1:1 관계가 성립하는 항목만 여기 한 곳에 모아 관리한다.
///
/// - saju/name/face/palm/compatibility는 입력 토픽과 무관하게 서버가 항상
///   고정된 categoryKey 하나만 사용하므로(각 route.ts 확인됨) 안전하게 매핑.
/// - 타로(`/tarot/home` 등)와 오늘의 운세(`/home/daily-fortune-detail`,
///   `/fortune/today/intro`)는 이 표에 포함하지 않는다:
///   * 타로는 topic/spreadType에 따라 서버가 tarot/tarot_yesno/tarot_love 중
///     하나로 동적 결정하므로, 게이트 시점에는 아직 확정되지 않아 오탐 차단
///     위험이 있다(정확한 검증은 tarot API 자신이 최종 담당).
///   * 오늘의 운세(daily)는 fortune_categories.requires_pass=0(무료
///     카테고리)이라 서버 개별 API(daily/route.ts)에 categoryKey 검증 로직이
///     아예 없다 — 게이트에서 categoryKey를 보내도 서버가 무시하지만, 굳이
///     보낼 필요가 없으므로 매핑을 생략한다.
const Map<String, String> _categoryKeyByRoute = {
  '/ai-fortune/saju/input': 'saju',
  '/ai-fortune/name/input': 'name',
  '/ai-fortune/face/capture': 'face',
  '/ai-fortune/palm/capture': 'palm',
  // [주의] 관리자 DB(fortune_categories.route)에는 '/ai-fortune/compatibility/input'로
  // 저장되어 있고, 앱 자체 정적 목록/라우터에는 '/compatibility/input'가
  // 쓰인다(app_router.dart에 등록된 실제 라우트는 후자뿐). 두 값 모두 같은
  // 서버 categoryKey('compatibility')로 매핑해 어느 경로로 진입해도 정상
  // 동작하게 한다(라우팅 자체를 바꾸는 작업은 이번 범위 밖이므로 손대지 않음).
  '/ai-fortune/compatibility/input': 'compatibility',
  '/compatibility/input': 'compatibility',
};

/// [운섹션 87 카테고리 통합 - _openMatrixEntry 서버 검증 연동] 라우트 문자열에
/// 대응하는 서버 categoryKey를 조회한다.
///
/// [_categoryKeyByRoute]는 이 파일 내부에서만 쓰이도록 private였지만,
/// all_categories_screen.dart의 [_openMatrixEntry]가 [CategoryGate.decide]
/// (순수 로컬 판정)로만 진입을 허용해 서버측 카테고리별 2회 제한 검증을
/// 완전히 건너뛰는 구조적 갭이 있어, 동일한 라우트→categoryKey 매핑을
/// 재사용할 수 있도록 공개 함수로 노출한다(매핑표를 두 곳에 중복 관리하지
/// 않기 위함).
String? categoryKeyForRoute(String route) => _categoryKeyByRoute[route];

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
