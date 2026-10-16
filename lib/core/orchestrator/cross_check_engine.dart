import 'cross_check_rule.dart';
import 'unified_fortune_profile.dart';

/// [엔진 통합 지시문 STEP 3 §4] 두 점수를 비교해 내리는 최종 판정.
///
/// - [match]: 두 점수가 같은 방향이고 충분히 가깝다(서로 뒷받침).
/// - [complement]: 두 점수가 다르지만 극단적으로 충돌하지는 않는다
///   (서로 다른 면을 보여주며 보완).
/// - [conflict]: 두 점수의 차이(delta)가 임계치를 넘는다(명백한 모순).
///
/// [절대 원칙] 이 enum 값은 오직 [CrossCheckEngine.evaluate]의 결정론적
/// 수치 비교로만 결정된다 — LLM/narrator는 이 값을 절대 바꾸거나 다시
/// 판정하지 않는다(지시문 §2 "verdict는 LLM이 아니라 규칙 코드가 정한다").
/// conflict를 match로 둔갑시키거나 숨기는 것은 금지된다(지시문 §2).
enum CrossCheckVerdict { match, complement, conflict }

/// [엔진 통합 지시문 STEP 3 §6] 규칙 1건의 교차검증 결과. 이 클래스의
/// [toJson]이 지시문이 요구한 정확한 verdict JSON 스키마
/// (`ruleId/pair/axis/verdict/scoreA/scoreB/delta/evidence/sources`)를
/// 그대로 생성한다.
class CrossCheckResult {
  const CrossCheckResult({
    required this.ruleId,
    required this.pair,
    required this.axis,
    required this.verdict,
    required this.scoreA,
    required this.scoreB,
    required this.delta,
    required this.evidence,
    required this.sources,
  });

  final String ruleId;
  final String pair;
  final String axis;
  final CrossCheckVerdict verdict;
  final double scoreA;
  final double scoreB;
  final double delta;

  /// 두 추출기의 근거 텍스트를 함께 담는다(순서: [A근거, B근거]).
  final List<String> evidence;

  /// 두 점수가 각각 어느 문(door)에서 나왔는지(예: ['사주', '관상']).
  final List<String> sources;

  Map<String, dynamic> toJson() => {
    'ruleId': ruleId,
    'pair': pair,
    'axis': axis,
    'verdict': verdict.name,
    'scoreA': scoreA,
    'scoreB': scoreB,
    'delta': delta,
    'evidence': evidence,
    'sources': sources,
  };
}

/// 규칙 하나를 평가하려 했으나 필요한 데이터가 없어(둘 중 한쪽 문을
/// 아직 이용하지 않음) "판정 자체를 할 수 없었던" 상태.
/// [FortuneOrchestrator]는 이 상태를 UI에 "아직 비교할 수 없어요" 식으로
/// 정직하게 보여줘야 한다 — 임의 기본값으로 판정을 꾸며내지 않는다.
class UnjudgedRule {
  const UnjudgedRule({
    required this.ruleId,
    required this.pair,
    required this.axis,
    required this.missingDoor,
  });

  final String ruleId;
  final String pair;
  final String axis;

  /// 어느 쪽 문의 데이터가 없어서 판정을 못 했는지(예: '관상').
  final String missingDoor;
}

/// [엔진 통합 지시문 STEP 3 §4] 결정론적 교차검증 규칙 엔진.
///
/// 입력 두 점수(-1.0~+1.0)의 절댓값 차이(delta)를 아래 두 임계치와
/// 비교해 [CrossCheckVerdict]를 결정한다. 순수 함수이며 상태를 갖지
/// 않고, 네트워크/LLM 호출이 전혀 없다 — 같은 입력에는 항상 같은
/// 출력을 낸다(결정론성, 테스트 케이스 §5 요구사항).
class CrossCheckEngine {
  CrossCheckEngine._();

  /// [TODO — 도메인 튜닝] 두 점수 차이가 이 값 이하이면 "match"(서로
  /// 뒷받침)로 판정한다. 현재 0.25는 "-1.0~+1.0 전체 폭(2.0)의 약 1/8"
  /// 이라는 보수적 추정치이며, 실사용 데이터 축적 후 도메인 전문가가
  /// 재조정해야 한다.
  static const double matchTolerance = 0.25;

  /// [TODO — 도메인 튜닝] 두 점수 차이가 이 값 이상이면 "conflict"(명백한
  /// 모순)로 판정한다. 현재 0.70은 "두 점수가 거의 반대 극단에 있을 때"를
  /// 보수적으로 가정한 값이며, 실사용 데이터 축적 후 재조정이 필요하다.
  static const double conflictThreshold = 0.70;

  /// 규칙 1개를 평가한다. 두 추출기 중 하나라도 null이면(데이터 없음)
  /// [UnjudgedRule]을 반환하고, 둘 다 값이 있으면 [CrossCheckResult]를
  /// 반환한다.
  static Object evaluateRule(
    CrossCheckRule rule,
    UnifiedFortuneProfile profile,
  ) {
    final a = rule.extractA(profile);
    final b = rule.extractB(profile);
    if (a == null || b == null) {
      final missingDoor = a == null ? rule.doorA : rule.doorB;
      return UnjudgedRule(
        ruleId: rule.ruleId,
        pair: rule.pair,
        axis: rule.axis,
        missingDoor: missingDoor,
      );
    }

    final delta = (a.score - b.score).abs();
    final CrossCheckVerdict verdict;
    if (delta >= conflictThreshold) {
      verdict = CrossCheckVerdict.conflict;
    } else if (delta <= matchTolerance) {
      verdict = CrossCheckVerdict.match;
    } else {
      verdict = CrossCheckVerdict.complement;
    }

    return CrossCheckResult(
      ruleId: rule.ruleId,
      pair: rule.pair,
      axis: rule.axis,
      verdict: verdict,
      scoreA: a.score,
      scoreB: b.score,
      delta: delta,
      evidence: [a.evidenceText, b.evidenceText],
      sources: [a.sourceDoor, b.sourceDoor],
    );
  }

  /// 여러 규칙을 한 번에 평가해, 판정된 결과와 미판정 규칙을 분리해
  /// 반환한다. 순서는 입력 [rules] 순서를 유지한다.
  static ({List<CrossCheckResult> judged, List<UnjudgedRule> unjudged})
  evaluateAll(List<CrossCheckRule> rules, UnifiedFortuneProfile profile) {
    final judged = <CrossCheckResult>[];
    final unjudged = <UnjudgedRule>[];
    for (final rule in rules) {
      final outcome = evaluateRule(rule, profile);
      if (outcome is CrossCheckResult) {
        judged.add(outcome);
      } else if (outcome is UnjudgedRule) {
        unjudged.add(outcome);
      }
    }
    return (judged: judged, unjudged: unjudged);
  }
}
