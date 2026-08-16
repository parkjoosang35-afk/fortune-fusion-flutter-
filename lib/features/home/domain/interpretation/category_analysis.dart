/// [정통사주 69종 개인화 해석 엔진 — 1단계] 카테고리 분석 결과 공통 모델.
///
/// 사용자 최종 지시 §6 "카테고리별 분석 데이터 스키마" + §11 "결과 페이지
/// 7단 구조"에 대응한다. 모든 [CategoryAnalyzer]는 자연어 문장을 만들기
/// 전에 반드시 이 구조화된 데이터를 먼저 산출해야 한다.
///
/// 개별 카테고리(재물/직업/건강 등)는 이 클래스를 확장(extends)해 그
/// 카테고리 고유의 필드(예: WealthAnalysis.wealthPattern)를 추가한다 —
/// 이 파일은 "모든 카테고리가 공통으로 갖는 뼈대"만 정의한다.
library;

import 'analysis_evidence.dart';

/// 결과 페이지 7단 구조 중 "시기" 섹션에 들어갈 데이터.
///
/// [절대 원칙 — 가짜 시기 금지] 사용자 최종 지시 §18에 따라, 이 안의
/// 모든 필드는 PHASE4가 실제로 계산한 대운/세운/월운 값에서만 채워져야
/// 한다. "아마 올해쯤" 같은 문자열을 생성기가 임의로 만들어 넣지 않는다.
/// 대운/세운과 무관한 카테고리(예: A02 성격)는 이 필드 자체를 null로
/// 둔다.
class TimingInfo {
  const TimingInfo({
    this.currentDaewoonLabel,
    this.currentYearLabel,
    this.importantPeriods = const [],
  });

  /// 현재 대운 표기(예: "32세(2004년)부터 시작된 갑자(甲子) 대운").
  final String? currentDaewoonLabel;

  /// 현재 세운(올해) 표기(예: "2026년 병오(丙午)년").
  final String? currentYearLabel;

  /// 카테고리 판단상 중요한 시기 목록(예: 용신 대운 진입 구간).
  final List<String> importantPeriods;

  bool get isEmpty =>
      currentDaewoonLabel == null &&
      currentYearLabel == null &&
      importantPeriods.isEmpty;

  Map<String, dynamic> toJson() => {
    'currentDaewoonLabel': currentDaewoonLabel,
    'currentYearLabel': currentYearLabel,
    'importantPeriods': importantPeriods,
  };
}

/// [CategoryAnalysis] — 69종 전체가 공통으로 상속하는 "구조화된 분석
/// 결과" 뼈대.
///
/// 문장을 만들기 전 단계의 산출물이며, 이 객체 자체에는 완성된 한국어
/// 문장이 없다(문장은 [NarrativeGenerator]가 이 데이터를 입력받아 별도로
/// 생성한다 — 사용자 최종 지시 §20 "SajuProfile + CategoryAnalysis +
/// InterpretationRules → FortuneNarrative").
abstract class CategoryAnalysis {
  const CategoryAnalysis({
    required this.categoryId,
    required this.categoryName,
    required this.coreEvidence,
    required this.favorableConditions,
    required this.cautionConditions,
    this.timing,
    this.confidence = AnalysisConfidence.medium,
  });

  /// 카테고리 ID(예: 'A03').
  final String categoryId;

  /// 카테고리 표시 이름(예: '평생재물운').
  final String categoryName;

  /// 이 분석에 실제로 사용된 판단 근거 전체(추적성 확보 — §7).
  final List<AnalysisEvidence> coreEvidence;

  /// 좋은 흐름이 살아나는 조건 목록(결과 페이지 ④).
  final List<String> favorableConditions;

  /// 주의해야 하는 조건 목록(결과 페이지 ⑤).
  final List<String> cautionConditions;

  /// 시기 정보(결과 페이지 ⑥). 대운/세운과 무관한 카테고리는 null.
  final TimingInfo? timing;

  /// 이 분석의 신뢰도(원국에 핵심 근거 글자가 없으면 low로 낮아짐).
  final AnalysisConfidence confidence;

  /// 하위 클래스가 자신의 고유 필드를 함께 직렬화하도록 구현한다
  /// (자동 검증 테스트 §14가 이 JSON을 비교해 카테고리 차별성을 검사한다).
  Map<String, dynamic> toJson();

  /// 공통 필드만 직렬화 — 하위 클래스의 toJson()이 이 맵을 baseJson으로
  /// 받아 자신의 필드를 추가하는 패턴을 권장한다.
  Map<String, dynamic> baseJson() => {
    'categoryId': categoryId,
    'categoryName': categoryName,
    'coreEvidence': coreEvidence.map((e) => e.toJson()).toList(),
    'favorableConditions': favorableConditions,
    'cautionConditions': cautionConditions,
    'timing': timing?.toJson(),
    'confidence': confidence.label,
  };
}
