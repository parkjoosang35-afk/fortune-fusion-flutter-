/// [정통사주 69종 개인화 해석 엔진 — 1단계] Category Analyzer 공통 인터페이스.
///
/// 사용자 최종 지시 §5 "모든 카테고리에 Category Analyzer를 만든다" +
/// §10 "69종 카테고리 중복 방지 시스템"에 대응한다.
///
/// [입력 원칙] 모든 [CategoryAnalyzer]는 오직 [SajuProfile](PHASE1~4가
/// 이미 계산한 불변 값 객체)만을 입력으로 받는다. 절대 여기서 만세력을
/// 다시 계산하지 않는다 — 계산은 PHASE1~4의 몫이고, 이 계층은 "이미
/// 계산된 값을 어떻게 해석할지"만 담당한다(§21 "LLM은 계산에 관여 금지"
/// 와 같은 원칙을 analyzer 계층에도 적용: analyzer는 계산기가 아니라
/// 해석기다).
library;

import '../manseryeok/saju_profile.dart';
import 'category_analysis.dart';

/// 카테고리 중복 방지 메타데이터(§10) — 각 Analyzer가 자기 소개를 하는
/// 정적 정보. 실제 판단 로직에 영향을 주진 않지만, §8의 자동 검증
/// 테스트가 "A03과 A04가 같은 requiredData만 쓰면서 다른 결론을 내는지"
/// 등을 점검할 때 참고 자료로 쓰인다.
class CategoryMetadata {
  const CategoryMetadata({
    required this.categoryId,
    required this.categoryPurpose,
    required this.requiredData,
    required this.analysisRules,
    required this.excludedData,
    required this.outputStructure,
  });

  final String categoryId;

  /// 이 카테고리가 답하려는 질문(예: "평생에 걸친 재물 획득/축적 구조").
  final String categoryPurpose;

  /// 이 카테고리가 실제로 사용하는 SajuProfile 필드/범주 목록(예:
  /// ['재성', '식상', '비겁', '인성', '용신', '대운']).
  final List<String> requiredData;

  /// 이 카테고리가 적용하는 분석 규칙 이름 목록(사람이 읽는 요약).
  final List<String> analysisRules;

  /// 이 카테고리가 의도적으로 사용하지 않는 데이터(다른 카테고리와의
  /// 경계를 명시, 예: A03은 '오늘 일진'을 사용하지 않음).
  final List<String> excludedData;

  /// 이 카테고리 결과가 담을 출력 구조 요약(예: ['재물 구조', '획득 방식',
  /// '축적 방식', '위험요인', '시기', '종합결론']).
  final List<String> outputStructure;
}

/// 모든 카테고리 Analyzer가 구현하는 공통 인터페이스.
///
/// [T]는 그 카테고리 고유의 [CategoryAnalysis] 하위 클래스(예:
/// WealthAnalysis).
abstract class CategoryAnalyzer<T extends CategoryAnalysis> {
  const CategoryAnalyzer();

  /// 이 Analyzer의 자기소개 메타데이터.
  CategoryMetadata get metadata;

  /// [profile]은 반드시 PHASE1~4가 모두 완료된(strength/yongsin/daewoon
  /// 등이 채워진) 상태여야 한다 — 그렇지 않으면 각 Analyzer 구현체가
  /// 방어적으로 confidence를 낮추거나 StateError를 던진다(카테고리별로
  /// 문서화).
  ///
  /// [referenceDate]는 "오늘/올해" 기준 시점(C/D그룹처럼 세운/월운이
  /// 필요한 카테고리에서 사용, A/B그룹은 무시 가능).
  T analyze(SajuProfile profile, {DateTime? referenceDate});
}
