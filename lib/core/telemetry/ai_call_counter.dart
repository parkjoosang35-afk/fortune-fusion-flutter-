import '../../config/feature_flags.dart';
import 'feature_flag_counter.dart';

/// [AI 사주 호출 점진 전환] [FeatureFlagCounter]에 대한 얇은 래퍼.
///
/// [역할 분리]
/// - [recordRequestSajuCalled]: `SajuRepository.requestSaju()`가 호출될
///   때마다 flag 값과 무관하게 "먼저" 카운트만 남긴다(관측 목적 — 실제
///   LLM 호출 시도가 몇 번 일어났는지 그대로 기록).
/// - [isGatePassed]: 현재 [FeatureFlags.kUseLegacyAiSajuMain] 값을 그대로
///   돌려준다. 호출부(SajuProvider)는 이 값으로 "실제 LLM 호출" vs
///   "룰 기반 우회" 분기를 결정한다.
///
/// [주의] 이 클래스는 게이트 판정([CategoryGate]/[PassProvider])과 전혀
/// 무관하다. 오직 "메인 AI 해석 호출을 얼마나 하고 있는지" 관측/제어만
/// 담당한다.
class AiCallCounter {
  AiCallCounter._();

  /// [FeatureFlagCounter]에 저장되는 flag 키. 대시보드/디버그 메뉴에서도
  /// 동일한 문자열로 조회할 수 있도록 상수로 고정한다.
  static const String flagKey = 'ai_saju_main_requested';

  /// `SajuRepository.requestSaju()` 호출 시도 자체를 카운트한다(flag 값에
  /// 관계없이 항상 호출 — "요청이 몇 번 발생했는지"를 있는 그대로 관측).
  static Future<void> recordRequestSajuCalled() {
    return FeatureFlagCounter.incrementFlag(flagKey);
  }

  /// 현재 [FeatureFlags.kUseLegacyAiSajuMain] 값을 반환한다.
  ///
  /// - `true`: 실 LLM 해석 호출을 그대로 진행해도 되는 상태(게이트 통과).
  /// - `false`: 메인 AI 호출을 건너뛰고 룰 기반 결과로 우회해야 하는 상태.
  static bool isGatePassed() => FeatureFlags.kUseLegacyAiSajuMain;

  /// [운영 디버그 메뉴 전용] 누적 카운트 조회.
  static Future<int> readTotalCalled() {
    return FeatureFlagCounter.readFlag(flagKey);
  }

  /// [운영 디버그 메뉴 전용] 오늘 카운트 조회.
  static Future<int> readTodayCalled() {
    return FeatureFlagCounter.readFlagToday(flagKey);
  }
}
