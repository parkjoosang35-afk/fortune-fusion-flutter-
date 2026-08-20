/// [정통사주 69종 개인화 해석 엔진 — 7단계] A07 평생 자녀운 Analyzer.
///
/// 레거시 `getLifeChildren()`이 자녀성(남=관성/여=식상) 개수만으로 4개
/// 고정 문장(만연형/안정형/풍요형/다자녀형) 중 하나를 골라 반환하고,
/// 신강신약·자녀궁(시지) 관계·신살·대운을 전혀 참조하지 않던 방식을
/// 폐기한다. 대신 [SajuProfile]의 십신 분포·신강신약·자녀궁(시지)이
/// 관여된 합충형파해/원진·자녀궁에 걸린 신살(공망/겁살/재살)·용신/기신·
/// 대운을 A03/A04/A05/A06과 동일한 설계 원칙으로 직접 조회해 자녀운
/// 구조를 매번 새로 판정한다(§4 "문장이 아니라 분석을 개인화").
///
/// [십신 배정 근거 — 레거시와 동일하게 유지, §0 계산 원칙 보존]
/// 자평명리(子平命理) 표준 관행 — 여명(女命)의 자녀성은 식상(食傷, 내가
/// 생하는 오행), 남명(男命)의 자녀성은 관성(官星, 처가 관성을 낳는다는
/// 재생관(財生官) 논리로 남편 입장에서 자식을 관성으로 봄)이다. A06이
/// 채택한 "남=재성(처)/여=관성(부)" 배우자성 배정과 짝을 이루는 표준
/// 조합.
///
/// 사용 데이터(§10 requiredData):
/// - 십신 7위치(tenGods) — 자녀성(남:관살/여:식상) 개수, 인성 개수(육아
///   지원력 상징)
/// - 신강신약(strength) — 육아를 감당할 그릇의 크기
/// - 합충형파해(relationships) — 자녀궁(시지)이 관여된 관계만 필터링
///   (§ A07 고유 근거 — 다른 카테고리는 이 관점으로 조회하지 않음)
/// - 신살(sinsal) — 자녀궁(시지)에 걸린 공망/겁살/재살 등 애정 관련 신호
/// - 용신/기신(yongsin) — 자녀운이 좋아지는/나빠지는 조건
/// - 대운(daewoon) — 자녀 인연·경사가 정점에 이르는 실제 시기
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C/D그룹이 담당), 배우자운(A06이 담당, 배우자성과는 다른 육친성 사용).
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'children_analysis.dart';

/// 자녀궁(시지)에 걸렸을 때 리스크로 채택하는 신살 nameKr 목록
/// (sinsal_engine.dart가 실제로 산출하는 nameKr과 일치).
const Set<String> _childRiskSinsalNames = {'공망', '겁살', '재살'};

class ChildrenAnalyzer extends CategoryAnalyzer<ChildrenAnalysis> {
  const ChildrenAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A07',
    categoryPurpose: '평생에 걸친 자녀 인연의 구조와 육아를 감당하는 그릇의 크기, 자녀궁의 안정성을 분석',
    requiredData: ['십신 분포(자녀성/인성)', '신강신약', '자녀궁(시지) 관계', '신살(공망/겁살/재살)', '용신/기신', '대운'],
    analysisRules: [
      '자녀성(남:관살/여:식상) 개수와 인성 개수를 조합해 자녀 인연 구조(childPattern) 판정',
      '신강신약 × 자녀성 개수 조합으로 육아를 감당할 그릇의 크기(childBondStrength) 판정',
      '자녀궁(시지)이 관여된 합충형파해/원진 관계 조회로 자녀궁 안정성(childPalaceCondition) 판정',
      '자녀궁(시지)에 걸린 신살(공망/겁살/재살) + 자녀성 부재 여부를 조합해 리스크(childRiskPattern) 판정',
      '대운 목록에서 자녀성 범주이거나 용신 오행을 포함하는 대운을 자녀 경사 정점 시기로 판정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '배우자운(A06 담당)'],
    outputStructure: ['자녀 인연 구조', '그릇의 크기', '자녀궁 상태', '리스크', '육아 접근법', '정점 대운'],
  );

  @override
  ChildrenAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);
    final gender = profile.birthInfo.gender;

    // ── ① 자녀성 범주 결정(남=관살/여=식상) + 인성 개수 집계
    // (원국 본기 + 지장간 포함) ──
    final categoryCounts = q.tenGodCategoryCounts(includeHiddenStems: true);
    final String childCategory;
    final String childCategoryLabel;
    if (gender == 'male') {
      childCategory = '관살';
      childCategoryLabel = '관살(자녀성)';
    } else {
      childCategory = '식상';
      childCategoryLabel = '식상(자녀성)';
    }
    final childCount = categoryCounts[childCategory] ?? 0;
    final inseongCount = categoryCounts['인성'] ?? 0;
    evidence.add(
      AnalysisEvidence(
        sourceField: 'birthInfo.gender + tenGods+hiddenStems(5대범주 집계)',
        sourceValue: '성별=$gender → 자녀성=$childCategoryLabel, 개수=$childCount, 인성=$inseongCount',
        rule: '남성은 관살, 여성은 식상을 자녀성으로 채택(전통 명리학 육친법 — 재생관 논리)',
        judgment: '자녀성 개수를 기준으로 자녀 인연 구조 1차 판정',
        interpretationRole: InterpretationRole.primary,
        weight: 0.7,
      ),
    );

    // ── ② 자녀 인연 구조(childPattern) — 레거시 4분류를 인성까지
    // 포함해 세분화(§4) ──
    final String childPattern;
    if (childCount == 1 && inseongCount <= 1) {
      childPattern = '안정형(安定型) — 자녀와 깊고 안정적인 인연을 맺는 구조';
    } else if (childCount >= 2 && inseongCount <= 1) {
      childPattern = '풍요형(豊饒型) — 자녀 인연이 풍부하고 다복한 구조';
    } else if (childCount >= 1 && inseongCount >= 2) {
      childPattern = '조력형(助力型) — 자녀 인연과 함께 주변(인성)의 도움이 두터운 구조';
    } else if (childCount == 0) {
      childPattern = '만연형(晚緣型) — 자녀 인연이 늦거나 특별한 계기로 찾아오는 구조';
    } else {
      childPattern = '혼합형 — 안정적 인연과 다복한 인연이 함께 섞인 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'childCount/inseongCount 조합',
        sourceValue: '자녀성=$childCount, 인성=$inseongCount',
        rule: '자녀성=1&인성≤1→안정형 / 자녀성≥2&인성≤1→풍요형 / 자녀성≥1&인성≥2→조력형 / 자녀성=0→만연형 / 그외→혼합형',
        judgment: childPattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ③ 신강신약 × 자녀성 개수 → 그릇의 크기(childBondStrength) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String childBondStrength;
    if (strengthVerdict == '신강' && childCount >= 2) {
      childBondStrength = '신강용육(身强用育) — 여러 자녀를 감당할 힘이 있어 육아를 주도적으로 이끄는 편';
    } else if (strengthVerdict == '신강' && childCount <= 1) {
      childBondStrength = '신강경육(身强輕育) — 힘은 있으나 자녀성이 적어 스스로 자녀 인연을 적극적으로 만들어가야 하는 구조';
    } else if (strengthVerdict == '신약' && childCount >= 2) {
      childBondStrength = '다자신약(多子身弱) — 자녀 인연 기회는 많으나 육아를 감당할 힘이 부족해 무리한 양육은 부담';
    } else if (strengthVerdict == '신약') {
      childBondStrength = '신약보육(身弱補育) — 배우자·주변의 지지를 받을 때 육아가 더 안정되는 편';
    } else {
      childBondStrength = '중화용육(中和用育) — 상황에 맞춰 유연하게 육아를 운용할 수 있는 구조';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + 자녀성 개수',
          sourceValue: '$strengthVerdict, 자녀성=$childCount',
          rule: '신강+자녀성많음→신강용육 / 신강+자녀성적음→신강경육 / 신약+자녀성많음→다자신약 / 신약→신약보육 / 중화→중화용육',
          judgment: childBondStrength,
          interpretationRole: InterpretationRole.strength,
          weight: 0.95,
        ),
      );
    }

    // ── ④ 자녀궁(시지) 관계(childPalaceCondition) — [A07 고유 근거]
    // 시지가 관여된 합충형파해/원진 관계만 필터링(PHASE2가 이미 계산한
    // relationships를 위치로 재조회할 뿐, 새로 계산하지 않음 §0) ──
    final hourBranchRelations = (profile.relationships ?? const [])
        .where((r) => r.positions.contains('시지'))
        .toList();
    const conflictTypes = {'지지충', '천간충', '형', '파', '해', '원진', '귀문'};
    const harmonyTypes = {'육합', '삼합', '방합', '천간합'};
    final conflictRelations = hourBranchRelations.where((r) => conflictTypes.contains(r.type)).toList();
    final harmonyRelations = hourBranchRelations.where((r) => harmonyTypes.contains(r.type)).toList();
    final String childPalaceCondition;
    if (conflictRelations.isNotEmpty && harmonyRelations.isNotEmpty) {
      childPalaceCondition =
          '자녀궁 혼재 — 시지에 ${harmonyRelations.map((r) => r.type).join(',')}(화합)와 '
          '${conflictRelations.map((r) => r.type).join(',')}(충돌)가 함께 있어 자녀와의 관계에 부침이 있을 수 있는 구조';
    } else if (conflictRelations.isNotEmpty) {
      childPalaceCondition =
          '자녀궁 불안 — 시지가 ${conflictRelations.map((r) => r.type).join(',')} 관계에 놓여 있어 '
          '자녀와 거리감·갈등을 겪을 수 있으나 극복하면 관계가 더 단단해지는 구조';
    } else if (harmonyRelations.isNotEmpty) {
      childPalaceCondition =
          '자녀궁 안정 — 시지가 ${harmonyRelations.map((r) => r.type).join(',')} 관계로 화합해 '
          '자녀와 자연스럽게 조화를 이루는 구조';
    } else {
      childPalaceCondition = '자녀궁 독자형 — 시지가 다른 글자와 특별한 합충 관계 없이 독립적이라 자녀가 스스로 자기 길을 만들어가는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'relationships(시지 관여 합충형파해/원진, PHASE2 실계산)',
        sourceValue:
            '화합=${harmonyRelations.map((r) => r.type).toList()}, 충돌=${conflictRelations.map((r) => r.type).toList()}',
        rule: '시지가 관여된 관계 중 화합(육합/삼합/방합/천간합)과 충돌(충/형/파/해/원진/귀문)을 분류',
        judgment: childPalaceCondition,
        interpretationRole: InterpretationRole.relationship,
        weight: 0.85,
      ),
    );

    // ── §5 개인화 강화: 같은 childPattern이라도 실제 자녀궁 관계
    // 종류·개수는 사람마다 다르다는 것을 supportingEvidence로 기록 ──
    final supportingEvidence = <AnalysisEvidence>[
      AnalysisEvidence(
        sourceField: '시지 관여 관계 상세 목록',
        sourceValue: hourBranchRelations.isEmpty
            ? '없음'
            : hourBranchRelations.map((r) => '${r.type}(${r.characters.join("")})').join(', '),
        rule: '같은 childPattern이라도 자녀궁 관계의 실제 종류/상대 글자는 사람마다 다름(§5)',
        judgment: hourBranchRelations.isEmpty ? '시지 관여 관계 없음' : '${hourBranchRelations.length}건의 자녀궁 관계 확인',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.4,
      ),
    ];

    // ── ⑤ 리스크(childRiskPattern): 자녀궁(시지)에 걸린 공망/겁살/재살
    // + 자녀성 부재 여부 ──
    final sinsalList = profile.sinsal ?? const [];
    final foundChildRiskSinsal = sinsalList
        .where((s) => _childRiskSinsalNames.contains(s.nameKr) && s.foundOn.contains('시지'))
        .map((s) => s.nameKr)
        .toSet()
        .toList();
    final riskParts = <String>[];
    if (foundChildRiskSinsal.contains('공망')) {
      riskParts.add('자녀궁(시지)에 공망이 걸려 있어 자녀 인연이 예상보다 늦어지거나 계획대로 되지 않을 수 있음');
    }
    if (foundChildRiskSinsal.contains('겁살')) {
      riskParts.add('자녀궁에 겁살이 있어 자녀와 관련된 재물·건강 문제에 미리 대비하는 것이 좋음');
    }
    if (foundChildRiskSinsal.contains('재살')) {
      riskParts.add('자녀궁에 재살이 있어 자녀와 관련된 구설이나 예기치 못한 어려움에 유의할 필요');
    }
    if (childCount == 0) {
      riskParts.add('자녀성이 원국에 나타나지 않아 자녀 인연이 늦어지거나 특별한 노력이 필요할 수 있음');
    }
    final childRiskPattern = riskParts.isEmpty ? '두드러진 자녀운 리스크 신호는 확인되지 않음' : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '신살(자녀궁 공망/겁살/재살) + 자녀성 부재 조합',
          sourceValue: '신살=$foundChildRiskSinsal, 자녀성=$childCount',
          rule: '자녀궁(시지)에 공망/겁살/재살 존재 또는 자녀성=0 각각을 리스크 신호로 채택 후 종합',
          judgment: childRiskPattern,
          interpretationRole: InterpretationRole.caution,
          weight: 0.7,
        ),
      );
    }
    // 자녀궁 신살 발견 여부 자체는 항상 세부 근거로 남긴다(§5).
    supportingEvidence.add(
      AnalysisEvidence(
        sourceField: '자녀궁(시지) 신살 존재 여부',
        sourceValue: foundChildRiskSinsal.isEmpty ? '없음' : foundChildRiskSinsal.join(', '),
        rule: '자녀궁 신살 존재 여부는 리스크 판단과 별개로 항상 추적',
        judgment: foundChildRiskSinsal.isEmpty ? '자녀궁에 걸린 신살 없음' : '${foundChildRiskSinsal.join(', ')} 보유',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.3,
      ),
    );

    // ── ⑥ 육아 접근법(childRearingApproach) ──
    final childRearingApproach = _buildApproach(
      childBondStrength: childBondStrength,
      hasConflict: conflictRelations.isNotEmpty,
    );

    // ── ⑦ 자녀 경사 정점 대운(childBlessingDaewoonLabel) — PHASE4
    // 실계산만 사용 ──
    var childBlessingDaewoonLabel = '';
    final daewoonList = profile.daewoon ?? const [];
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    for (final d in daewoonList) {
      final matchesCategory = q.daewoonMatchesCategory(d, childCategory);
      final carriesYongsin = yongsinElement.isNotEmpty && q.daewoonCarriesElement(d, yongsinElement);
      if (matchesCategory || carriesYongsin) {
        childBlessingDaewoonLabel =
            '${d.startAge}세(${d.startYear}년)부터 시작된 ${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운';
        break;
      }
    }
    if (childBlessingDaewoonLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산)',
          sourceValue: childBlessingDaewoonLabel,
          rule: '대운의 천간/지지 십신이 자녀성 범주이거나 용신 오행을 포함하는 첫 대운 채택',
          judgment: '$childBlessingDaewoonLabel 시기에 자녀 관련 인연·경사가 가장 활발해질 가능성',
          interpretationRole: InterpretationRole.timing,
          weight: 0.8,
        ),
      );
    }

    // 현재 대운(§5 "현재 대운")도 항상 supportingEvidence로 남긴다.
    if (referenceDate != null) {
      final current = q.currentDaewoon(referenceDate);
      if (current != null) {
        supportingEvidence.add(
          AnalysisEvidence(
            sourceField: 'currentDaewoon(PHASE4 실계산)',
            sourceValue:
                '${current.startAge}세 ${current.pillar.stemKr}${current.pillar.branchKr}(${current.pillar.stemHanja}${current.pillar.branchHanja})',
            rule: '기준일이 속한 대운을 조회(재계산 아님, PHASE4 목록 조회)',
            judgment: '현재 ${current.pillar.stemKr}${current.pillar.branchKr} 대운을 지나는 중',
            interpretationRole: InterpretationRole.timing,
            weight: 0.5,
          ),
        );
      }
    }

    // ── 좋은 흐름 / 주의 흐름 ──
    final favorable = <String>[
      if (harmonyRelations.isNotEmpty) '자녀궁이 안정적이라 자녀와의 관계를 오래 좋게 유지하기 좋은 환경',
      if (childBlessingDaewoonLabel.isNotEmpty) '$childBlessingDaewoonLabel 시기',
      if (yongsinElement.isNotEmpty) '$yongsinElement 기운이 강해지는 시기·인연',
    ];
    final caution = <String>[
      if (conflictRelations.isNotEmpty) '자녀궁 충돌(${conflictRelations.map((r) => r.type).join(',')})로 인한 갈등 관리',
      if (foundChildRiskSinsal.isNotEmpty) '${foundChildRiskSinsal.join(', ')} 신호에 따른 자녀 관련 사안 대비',
      if (childCount == 0) '자녀 인연이 늦어질 수 있는 만큼 서두르지 않는 마음가짐',
    ];
    if (favorable.isEmpty) favorable.add('현재의 자녀 인연 구조를 안정적으로 유지하는 환경');
    if (caution.isEmpty) caution.add('두드러진 자녀운 리스크 신호는 확인되지 않음');

    final confidence = (profile.strength == null || profile.yongsin == null)
        ? AnalysisConfidence.low
        : (childBlessingDaewoonLabel.isEmpty && riskParts.isEmpty && conflictRelations.isEmpty)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: 최종 판정에 실제로 쓰인 원시 수치 전체를
    // 개발자 검증용으로 남긴다 ──
    final interpretationContext = <String, String>{
      'gender': gender,
      'childCategory': childCategory,
      'childCount': '$childCount',
      'inseongCount': '$inseongCount',
      'strengthVerdict': strengthVerdict,
      'yongsinElement': yongsinElement,
      'hourBranchRelationTypes': hourBranchRelations.map((r) => r.type).join(','),
      'foundChildRiskSinsal': foundChildRiskSinsal.join(','),
      'childBlessingDaewoonLabel': childBlessingDaewoonLabel,
    };

    return ChildrenAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 자녀운',
      coreEvidence: evidence,
      supportingEvidence: supportingEvidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      childPattern: childPattern,
      childBondStrength: childBondStrength,
      childPalaceCondition: childPalaceCondition,
      childRiskPattern: childRiskPattern,
      childRearingApproach: childRearingApproach,
      childBlessingDaewoonLabel: childBlessingDaewoonLabel,
    );
  }

  String _buildApproach({
    required String childBondStrength,
    required bool hasConflict,
  }) {
    final base = childBondStrength.startsWith('신강용육')
        ? '자녀 교육과 양육을 주도적으로 이끌어가되 자녀의 의견도 충분히 존중하는 편이'
        : childBondStrength.startsWith('다자신약')
        ? '여러 자녀를 한꺼번에 다 챙기기보다 우선순위를 정해 힘을 나누어 쓰는 편이'
        : childBondStrength.startsWith('신약보육')
        ? '배우자나 주변의 도움을 편안하게 받아들이며 함께 키워가는 편이'
        : childBondStrength.startsWith('신강경육')
        ? '자녀 인연을 스스로 적극적으로 만들어가고 늦어져도 여유를 갖는 편이'
        : '상황에 맞춰 유연하게 육아 방식을 조율하는 편이';
    final palaceNote = hasConflict ? ' 좋고, 특히 자녀와의 갈등이 쌓이지 않도록 대화를 자주 나누는 습관이 도움이 됨' : ' 좋음';
    return '$base$palaceNote';
  }
}
