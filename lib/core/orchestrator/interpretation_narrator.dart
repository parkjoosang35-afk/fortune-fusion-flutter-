import '../orchestrator/cross_check_engine.dart';

/// [엔진 통합 지시문 STEP 3 §3] 검증된 [CrossCheckResult]를 "사람이 읽는
/// 한국어 문장"으로 풀어 설명하는 역할의 인터페이스.
///
/// [절대 원칙 — narrator는 절대 verdict를 판정/변경하지 않는다] 이
/// 인터페이스의 구현체는 이미 [CrossCheckEngine]이 결정론적으로 내린
/// [CrossCheckResult.verdict] 값을 "그대로 받아서 설명만" 한다. LLM 기반
/// 구현체를 추후 붙이더라도, LLM에게 넘기는 입력에 verdict가 이미
/// 포함되어 있고 LLM은 그 verdict를 뒤집거나 숨기지 않고 설명 텍스트만
/// 생성해야 한다 — 이것이 "LLM은 판정하지 않고 확정된 결과만 서술한다"는
/// 지시문 원칙의 인터페이스 레벨 강제다.
///
/// [기본 구현만 제공 — LLM 미연동] 이번 STEP 3 범위에서는 LLM을 새로
/// 연동하지 않는다(지시문 "이번 라운드 서버 API 스펙 변경 없음" 원칙과,
/// 과설계 방지 원칙). [RuleOnlyNarrator]가 결정론적 템플릿 문장만으로
/// 항상 비어있지 않은 설명을 생성해, 화면이 "narrator 응답 대기"로 멈추는
/// 일이 없도록 보장한다. 추후 LLM 연동이 필요해지면 이 인터페이스를
/// 구현하는 새 클래스를 추가하기만 하면 되고 호출부는 변경되지 않는다.
abstract class InterpretationNarrator {
  /// 판정된 교차검증 결과 1건을 한국어 설명 문장으로 변환한다.
  String narrate(CrossCheckResult result);

  /// 데이터 부족으로 미판정된 규칙 1건을 설명 문장으로 변환한다.
  String narrateUnjudged(UnjudgedRule unjudged);
}

/// [InterpretationNarrator]의 결정론적 템플릿 기반 기본 구현(LLM 없음).
/// verdict별로 고정된 한국어 문장 패턴에 규칙의 axis/evidence를 꽂아
/// 넣을 뿐이며, 그 자체로 어떤 판정도 내리지 않는다(이미 확정된
/// verdict를 그대로 서술).
class RuleOnlyNarrator implements InterpretationNarrator {
  const RuleOnlyNarrator();

  @override
  String narrate(CrossCheckResult result) {
    final pair = result.pair;
    final axis = result.axis;
    switch (result.verdict) {
      case CrossCheckVerdict.match:
        return '$pair 모두 "$axis" 측면에서 같은 방향을 가리키고 있어요. '
            '서로 다른 방식으로 본 결과가 일치하니 더 믿고 참고해도 좋겠어요.';
      case CrossCheckVerdict.complement:
        return '$pair가 "$axis" 측면에서 서로 다른 결을 보여주고 있어요. '
            '완전히 어긋나는 건 아니고, 한쪽이 놓친 부분을 다른 쪽이 보완해주는 모습이에요.';
      case CrossCheckVerdict.conflict:
        return '$pair가 "$axis" 측면에서 서로 다른 신호를 보이고 있어요. '
            '두 결과가 맞서는 지점이니, 어느 한쪽만 보지 말고 둘 다 참고해 '
            '스스로 판단해보시는 게 좋겠어요.';
    }
  }

  @override
  String narrateUnjudged(UnjudgedRule unjudged) {
    return '${unjudged.pair}의 "${unjudged.axis}" 비교는 아직 ${unjudged.missingDoor} '
        '결과가 없어 판정할 수 없어요. ${unjudged.missingDoor}을(를) 먼저 이용해보시면 '
        '비교해드릴 수 있어요.';
  }
}
