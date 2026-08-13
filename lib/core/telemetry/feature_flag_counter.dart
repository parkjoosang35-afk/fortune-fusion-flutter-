import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [AI 사주 호출 점진 전환] feature flag별 호출 횟수를 SharedPreferences에
/// 누적 기록하는 경량 카운터.
///
/// [기존 패턴 재사용] 신규 SQLite/Hive/서버 API를 추가하지 않고,
/// [CategoryUsageStore](`lib/core/domain/gate/category_usage_store.dart`)와
/// 동일한 저장 패턴(SharedPreferences + static 메서드)을 그대로 따른다.
/// (참고: 프로젝트 전체를 grep한 결과 'feature_flag_counter'라는 이름의
/// 기존 모듈은 없었다 — 이 파일이 신규 모듈이다.)
///
/// [저장 방식] flagKey 하나당 2개 값을 저장한다:
/// - 누적 카운트: `feature_flag_counter_total_v1_<flagKey>` (int)
/// - 일자별 카운트: `feature_flag_counter_daily_v1_<flagKey>_<yyyyMMdd>` (int)
///
/// [주의] 이 카운터는 "운영 관측용 힌트"일 뿐이며, 실제 결제/게이트 판정에는
/// 전혀 관여하지 않는다. 초기화([resetFlag])는 운영 디버그 메뉴에서만 호출
/// 해야 한다(일반 사용자 플로우에서는 절대 호출하지 않음).
class FeatureFlagCounter {
  FeatureFlagCounter._();

  static const _totalKeyPrefix = 'feature_flag_counter_total_v1_';
  static const _dailyKeyPrefix = 'feature_flag_counter_daily_v1_';

  static String _dailyKey(String flagKey, DateTime date) {
    final ymd =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '$_dailyKeyPrefix${flagKey}_$ymd';
  }

  /// [flagKey] 호출 1회를 누적/일자별 카운트에 동시에 반영한다.
  ///
  /// 예: `FeatureFlagCounter.incrementFlag('ai_saju_main_requested')`.
  static Future<void> incrementFlag(String flagKey) async {
    final prefs = await SharedPreferences.getInstance();

    final totalKey = '$_totalKeyPrefix$flagKey';
    final total = (prefs.getInt(totalKey) ?? 0) + 1;
    await prefs.setInt(totalKey, total);

    final dailyKey = _dailyKey(flagKey, DateTime.now());
    final daily = (prefs.getInt(dailyKey) ?? 0) + 1;
    await prefs.setInt(dailyKey, daily);

    // [관측용 콘솔 로그] 운영 디버그 메뉴가 없는 환경에서도 콘솔에서 바로
    // 누적/일자별 카운트를 확인할 수 있게 한다(디버그 빌드에서만 출력).
    if (kDebugMode) {
      debugPrint(
        '[FeatureFlagCounter] $flagKey -> total=$total, today=$daily',
      );
    }
  }

  /// [flagKey]의 "누적" 카운트를 반환한다(오늘 하루가 아니라 전체 기간).
  static Future<int> readFlag(String flagKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_totalKeyPrefix$flagKey') ?? 0;
  }

  /// [flagKey]의 "오늘" 카운트만 반환한다.
  static Future<int> readFlagToday(String flagKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyKey(flagKey, DateTime.now())) ?? 0;
  }

  /// [운영 디버그 메뉴 전용] [flagKey]의 누적/오늘 카운트를 모두 0으로
  /// 초기화한다. 일반 사용자 플로우에서는 절대 호출하지 않을 것.
  static Future<void> resetFlag(String flagKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_totalKeyPrefix$flagKey');
    await prefs.remove(_dailyKey(flagKey, DateTime.now()));
    if (kDebugMode) {
      debugPrint('[FeatureFlagCounter] $flagKey -> reset');
    }
  }
}
