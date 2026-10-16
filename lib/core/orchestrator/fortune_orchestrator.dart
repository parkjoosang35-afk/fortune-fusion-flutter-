import 'package:flutter/foundation.dart';

import '../../features/auth/domain/user_model.dart';
import 'cross_check_engine.dart';
import 'cross_check_rule.dart';
import 'cross_check_rules.dart';
import 'door_engine_gateway.dart';
import 'unified_fortune_profile.dart';

/// [엔진 통합 지시문 STEP 3 §3] 5개 문(사주/타로/관상/손금/궁합)의 최신
/// 결과를 모아 [UnifiedFortuneProfile]을 구성하고, [CrossCheckEngine]에
/// 넘겨 교차검증 결과를 산출하는 상위 조율자.
///
/// [history-first 원칙] 지시문의 "엔진을 다시 호출하기 전에 history API를
/// 먼저 확인한다" 원칙을 그대로 따른다 — [DoorEngineGateway] 구현체들은
/// 모두 `getHistory()`(조회 전용)만 호출하고, 새 분석(예: AI 호출)을
/// 트리거하지 않는다. 사용자가 해당 문을 한 번도 이용한 적이 없으면
/// 데이터가 없을 뿐이고(null), 오케스트레이터는 이를 "없음"으로 정직하게
/// 보고한다 — 가짜 데이터로 채우지 않는다.
///
/// [재구현 금지 원칙] 이 클래스는 사주/타로/관상/손금/궁합의 계산 로직을
/// 단 한 줄도 다시 구현하지 않는다 — 전부 [DoorEngineGateway]를 통해
/// 기존 Repository/엔진을 호출해서 얻은 결과를 재배치할 뿐이다.
class FortuneOrchestrator {
  FortuneOrchestrator({
    required DoorEngineGateway gateway,
    List<CrossCheckRule> rules = defaultCrossCheckRules,
  }) : _gateway = gateway,
       _rules = rules;

  final DoorEngineGateway _gateway;
  final List<CrossCheckRule> _rules;

  /// 5개 문의 최신 결과를 모두 병렬로 조회해 [UnifiedFortuneProfile]을
  /// 구성한다. 각 조회는 서로 독립적이며, 하나가 실패/없음이어도 나머지
  /// 조회에 영향을 주지 않는다(부분 실패 허용 — 지시문 §7 테스트케이스1
  /// "일부 엔진만 유효해도 동작").
  Future<UnifiedFortuneProfile> buildProfile(UserModel? user) async {
    // [설계 메모] Future.wait는 동일 타입의 Future 리스트만 받을 수 있어,
    // 반환 타입이 서로 다른 6개 게이트웨이 호출을 한 리스트에 담을 수
    // 없다. 대신 각 Future를 먼저 발행(아직 await하지 않음)해 "동시에
    // 시작"시킨 뒤, 각각 개별로 await해 모은다 — 순차 대기처럼 보이지만
    // 실제로는 6개 호출이 모두 이미 진행 중인 상태에서 결과만 순서대로
    // 받는 것이므로 병렬 실행 효과는 동일하다.
    final sajuProfileFuture = _gateway.getSajuProfile(user);
    final sajuResultFuture = _gateway.getSajuResult(user);
    final tarotFuture = _gateway.getLatestTarot();
    final faceFuture = _gateway.getLatestFace();
    final palmFuture = _gateway.getLatestPalm();
    final compatibilityFuture = _gateway.getLatestCompatibility();

    return UnifiedFortuneProfile(
      sajuProfile: await sajuProfileFuture,
      sajuResult: await sajuResultFuture,
      tarotResult: await tarotFuture,
      faceResult: await faceFuture,
      palmResult: await palmFuture,
      compatibilityResult: await compatibilityFuture,
    );
  }

  /// [buildProfile]로 모은 통합 프로필에 등록된 모든 교차검증 규칙을
  /// 적용해 판정 결과(및 미판정 규칙)를 반환한다. 네트워크 호출 없이
  /// 순수 계산만 수행하므로 빠르다.
  ({List<CrossCheckResult> judged, List<UnjudgedRule> unjudged})
  evaluate(UnifiedFortuneProfile profile) {
    return CrossCheckEngine.evaluateAll(_rules, profile);
  }

  /// [buildProfile] + [evaluate]를 한 번에 수행하는 편의 메서드.
  Future<
    ({
      UnifiedFortuneProfile profile,
      List<CrossCheckResult> judged,
      List<UnjudgedRule> unjudged,
    })
  >
  run(UserModel? user) async {
    final profile = await buildProfile(user);
    final outcome = evaluate(profile);
    if (kDebugMode) {
      debugPrint(
        '[FortuneOrchestrator] [run] 판정 ${outcome.judged.length}건, '
        '미판정 ${outcome.unjudged.length}건 '
        '(채워진 문 ${profile.filledDoorCount}/5)',
      );
    }
    return (
      profile: profile,
      judged: outcome.judged,
      unjudged: outcome.unjudged,
    );
  }
}
