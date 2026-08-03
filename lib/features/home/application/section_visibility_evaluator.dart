import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../domain/page_config_model.dart';

/// [메인화면 관리자 편집기] §7/§17 SectionVisibilityEvaluator
///
/// 서버(`/api/public/page-configs/home`)는 발행된 섹션 원본을 그대로 내려주고,
/// "지금 이 사용자에게 이 섹션을 보여줄지"는 전부 클라이언트가 판단한다. 판단
/// 순서는 다음과 같고, 하나라도 실패하면 해당 섹션은 숨김 처리된다.
///   1) status/isVisible(관리자가 숨김/보관 처리했는가)
///   2) scheduleEnabled+startAt/endAt(예약 노출 기간 내인가)
///   3) platformTargets(현재 플랫폼이 대상에 포함되는가)
///   4) displayRules(모든 활성 조건을 AND로 만족하는가 — admin 조건 편집기는
///      섹션 하나에 여러 조건을 추가할 수 있으며, 이 구현은 "전부 만족해야
///      노출"으로 해석한다. 조건이 하나도 없으면 통과)
///
/// [Phase-1 범위 한계] isNewUser/wishBoardParticipatedToday는 현재 앱에
/// 신규가입일/사용자별 게시 여부를 조회할 수 있는 API가 없어 보수적으로
/// `false`를 기본값으로 사용한다(§ Phase-1 스코프 경계 문서화 원칙과 동일하게,
/// 이후 해당 API가 추가되면 HomeVisibilityContext 생성부만 갱신하면 된다).
class HomeVisibilityContext {
  final bool isLoggedIn;
  final bool isNewUser;
  final bool openPassActive;
  final int happyMoneyBalance;
  final int luckPouchBalance;
  final bool dailyFortuneViewedToday;
  final bool wishBoardParticipatedToday;
  final String platform; // 'android' | 'ios' | 'web'
  final DateTime now;

  const HomeVisibilityContext({
    required this.isLoggedIn,
    required this.now,
    this.isNewUser = false,
    this.openPassActive = false,
    this.happyMoneyBalance = 0,
    this.luckPouchBalance = 0,
    this.dailyFortuneViewedToday = false,
    this.wishBoardParticipatedToday = false,
    this.platform = 'android',
  });

  /// 현재 플랫폼 문자열(admin_web PLATFORM_TARGETS 값과 동일한 표기)
  static String currentPlatformKey() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'android';
    }
  }
}

class SectionVisibilityEvaluator {
  const SectionVisibilityEvaluator();

  bool isVisible(PageSectionModel section, HomeVisibilityContext ctx) {
    // 1) 관리자 노출 상태
    if (section.status != 'visible' || !section.isVisible) return false;

    // 2) 예약 노출 기간
    if (section.scheduleEnabled) {
      if (section.startAt != null && ctx.now.isBefore(section.startAt!)) {
        return false;
      }
      if (section.endAt != null && ctx.now.isAfter(section.endAt!)) {
        return false;
      }
    }

    // 3) 플랫폼 타겟
    final targets = section.platformTargets;
    if (targets != null && targets.isNotEmpty && !targets.contains(ctx.platform)) {
      return false;
    }

    // 4) 노출 조건(displayRules) - 전부 AND
    for (final rule in section.displayRules) {
      if (!_matchesRule(rule, ctx)) return false;
    }

    return true;
  }

  /// 목록에서 노출 가능한 섹션만 sortOrder 순서 그대로 필터링.
  List<PageSectionModel> filterVisible(
    List<PageSectionModel> sections,
    HomeVisibilityContext ctx,
  ) {
    final result = sections.where((s) => isVisible(s, ctx)).toList();
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  bool _matchesRule(PageSectionDisplayRule rule, HomeVisibilityContext ctx) {
    switch (rule.ruleType) {
      case 'login_status':
        return _boolCompare(ctx.isLoggedIn, rule);
      case 'non_login':
        return _boolCompare(!ctx.isLoggedIn, rule, expectTrueOnly: true);
      case 'new_user':
        return _boolCompare(ctx.isNewUser, rule, expectTrueOnly: true);
      case 'open_pass_inactive':
        return _boolCompare(!ctx.openPassActive, rule, expectTrueOnly: true);
      case 'open_pass_active':
        return _boolCompare(ctx.openPassActive, rule, expectTrueOnly: true);
      case 'happy_money_balance':
        return _numberCompare(ctx.happyMoneyBalance, rule);
      case 'luck_pouch_insufficient':
        return _luckPouchInsufficient(ctx.luckPouchBalance, rule);
      case 'daily_fortune_viewed':
        return _boolCompare(ctx.dailyFortuneViewedToday, rule, expectTrueOnly: true);
      case 'daily_fortune_not_viewed':
        return _boolCompare(!ctx.dailyFortuneViewedToday, rule, expectTrueOnly: true);
      case 'wish_board_participated':
        return _boolCompare(ctx.wishBoardParticipatedToday, rule, expectTrueOnly: true);
      case 'wish_board_not_participated':
        return _boolCompare(!ctx.wishBoardParticipatedToday, rule, expectTrueOnly: true);
      case 'event_period':
        return _eventPeriodMatches(rule, ctx.now);
      case 'platform':
        return _platformMatches(rule, ctx.platform);
      default:
        // 알 수 없는 ruleType은 안전하게 통과시킨다(향후 확장 대비, 화면이
        // 통째로 사라지는 것보다는 노출을 유지하는 쪽이 덜 위험하다는 판단).
        return true;
    }
  }

  bool _boolCompare(
    bool actual,
    PageSectionDisplayRule rule, {
    bool expectTrueOnly = false,
  }) {
    // expectTrueOnly=true인 규칙(non_login/new_user/open_pass_* 등)은
    // ruleValue가 대개 "true" 하나뿐이므로, ruleValue를 "true"로 지정한
    // 경우에만 실제 actual 값을 그대로 사용한다(관리자가 "true"가 아닌 값을
    // 넣는 실수를 했더라도 규칙 자체 의도(예: 신규가입자에게만)를 지키기 위함).
    final expected = rule.ruleValue.toLowerCase() != 'false';
    if (expectTrueOnly) {
      return expected ? actual : !actual;
    }
    switch (rule.ruleOperator) {
      case 'not_equals':
        return actual != expected;
      case 'in':
        return rule.ruleValue
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .contains(actual.toString());
      default:
        return actual == expected;
    }
  }

  bool _numberCompare(int actual, PageSectionDisplayRule rule) {
    final threshold = int.tryParse(rule.ruleValue.trim());
    if (threshold == null) return true;
    switch (rule.ruleOperator) {
      case 'gte':
        return actual >= threshold;
      case 'lte':
        return actual <= threshold;
      default:
        return actual == threshold;
    }
  }

  bool _luckPouchInsufficient(int balance, PageSectionDisplayRule rule) {
    final threshold = int.tryParse(rule.ruleValue.trim()) ?? 0;
    switch (rule.ruleOperator) {
      case 'lte':
        return balance <= threshold;
      default:
        return balance <= threshold; // equals도 "이하=부족"으로 동일 취급
    }
  }

  bool _eventPeriodMatches(PageSectionDisplayRule rule, DateTime now) {
    // ruleValue 형식: "YYYY-MM-DD~YYYY-MM-DD"(관리자가 입력한 기간).
    // 형식이 다르면 안전하게 통과시킨다.
    final parts = rule.ruleValue.split('~');
    if (parts.length != 2) return true;
    final start = DateTime.tryParse(parts[0].trim());
    final end = DateTime.tryParse(parts[1].trim());
    if (start == null || end == null) return true;
    return !now.isBefore(start) && !now.isAfter(end);
  }

  bool _platformMatches(PageSectionDisplayRule rule, String platform) {
    final values = rule.ruleValue
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .toList();
    switch (rule.ruleOperator) {
      case 'not_equals':
        return !values.contains(platform);
      default:
        return values.contains(platform);
    }
  }
}
