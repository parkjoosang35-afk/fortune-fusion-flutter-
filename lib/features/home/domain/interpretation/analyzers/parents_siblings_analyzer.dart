/// [정통사주 69종 개인화 해석 엔진 — 8단계] A08 평생 부모·형제운
/// Analyzer.
///
/// 레거시 `getLifeParentsSiblings()`가 인성(정인+편인, 부모성)/비겁(비견+
/// 겁재, 형제성) 개수만으로 각각 3단계(0/1~2/3+) 고정 문장을 반환하고,
/// 신강신약·부모형제궁(월지) 관계·신살·대운을 전혀 참조하지 않던 방식을
/// 폐기한다. 대신 [SajuProfile]의 십신 분포·신강신약·부모형제궁(월지)이
/// 관여된 합충형파해/원진·부모형제궁에 걸린 신살(공망/겁살/재살)·용신/기신·
/// 대운을 A03~A07과 동일한 설계 원칙으로 직접 조회해 부모·형제운 구조를
/// 매번 새로 판정한다(§4 "문장이 아니라 분석을 개인화").
///
/// [십신 배정 근거 — 레거시와 동일하게 유지, §0 계산 원칙 보존] 인성
/// (印星, 정인·편인, 生我者=나를 낳아준 존재)=부모(특히 모친), 비겁(比劫,
/// 비견·겁재, 同五行者=나와 같은 오행)=형제자매·동료. 성별 구분 없이
/// 공통 적용되는 표준 배정(재성=부친으로 보는 학파도 있으나, 모친 중심의
/// 인성 배정이 가장 보편적이라 이 원칙을 채택 — 레거시 주석 그대로 계승).
///
/// [A06/A07과의 구조적 차이 — 중요, [ParentsSiblingsAnalysis] 문서 참조]
/// 부모(인성)와 형제(비겁)는 완전히 독립된 두 개의 육친 관계이므로, 이
/// Analyzer는 parentPattern/parentBondStrength와 siblingPattern/
/// siblingBondStrength를 각각 별도로 판정한다 — 하나의 통합 pattern으로
/// 억지로 합치지 않는다.
///
/// 사용 데이터(§10 requiredData):
/// - 십신 7위치(tenGods) — 인성(부모성)/비겁(형제성) 개수
/// - 신강신약(strength) — 부모·형제의 도움/영향을 감당하는 그릇의 크기
/// - 합충형파해(relationships) — 부모형제궁(월지)이 관여된 관계만 필터링
///   (§ A08 고유 근거 — A06의 일지, A07의 시지와 짝을 이루는 위치 근거,
///   다른 카테고리는 이 관점으로 조회하지 않음)
/// - 신살(sinsal) — 부모형제궁(월지)에 걸린 공망/겁살/재살 등 신호
/// - 용신/기신(yongsin) — 부모·형제운이 좋아지는/나빠지는 조건
/// - 대운(daewoon) — 부모·형제 관련 인연·도움이 정점에 이르는 실제 시기
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C/D그룹이 담당), 배우자운(A06)·자녀운(A07, 각각 다른 육친성 사용).
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'parents_siblings_analysis.dart';

/// 부모형제궁(월지)에 걸렸을 때 리스크로 채택하는 신살 nameKr 목록
/// (sinsal_engine.dart가 실제로 산출하는 nameKr과 일치, A07과 동일 목록을
/// 부모형제궁 관점으로 재사용).
const Set<String> _familyRiskSinsalNames = {'공망', '겁살', '재살'};

class ParentsSiblingsAnalyzer extends CategoryAnalyzer<ParentsSiblingsAnalysis> {
  const ParentsSiblingsAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A08',
    categoryPurpose: '평생에 걸친 부모(인성)와 형제(비겁) 두 축의 인연 구조, 그리고 부모형제궁(월지)의 안정성을 분석',
    requiredData: ['십신 분포(인성/비겁)', '신강신약', '부모형제궁(월지) 관계', '신살(공망/겁살/재살)', '용신/기신', '대운'],
    analysisRules: [
      '인성(부모성) 개수만으로 부모 인연 구조(parentPattern) 판정',
      '비겁(형제성) 개수만으로 형제 인연 구조(siblingPattern) 판정',
      '신강신약 × 인성 개수 조합으로 부모 도움을 받아들이는 방식(parentBondStrength) 판정',
      '신강신약 × 비겁 개수 조합으로 형제·동료의 힘을 활용하는 방식(siblingBondStrength) 판정',
      '부모형제궁(월지)이 관여된 합충형파해/원진 관계 조회로 부모형제궁 안정성(familyPalaceCondition) 판정',
      '부모형제궁(월지)에 걸린 신살(공망/겁살/재살) + 인성·비겁 부재 여부를 조합해 리스크(familyRiskPattern) 판정',
      '대운 목록에서 인성/비겁 범주이거나 용신 오행을 포함하는 대운을 부모·형제 인연 정점 시기로 판정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '배우자운(A06 담당)', '자녀운(A07 담당)'],
    outputStructure: ['부모 인연 구조', '부모 도움을 받는 방식', '형제 인연 구조', '형제 힘을 쓰는 방식', '부모형제궁 상태', '리스크', '관계 접근법', '정점 대운'],
  );

  @override
  ParentsSiblingsAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);

    // ── ① 인성(부모성)/비겁(형제성) 개수 집계(원국 본기 + 지장간 포함) ──
    final categoryCounts = q.tenGodCategoryCounts(includeHiddenStems: true);
    final parentCount = categoryCounts['인성'] ?? 0;
    final siblingCount = categoryCounts['비겁'] ?? 0;
    evidence.add(
      AnalysisEvidence(
        sourceField: 'tenGods+hiddenStems(5대범주 집계)',
        sourceValue: '인성(부모성)=$parentCount, 비겁(형제성)=$siblingCount',
        rule: '인성=부모성, 비겁=형제성으로 채택(전통 명리학 육친법 — 인성은 生我者, 비겁은 同五行者)',
        judgment: '인성·비겁 개수를 각각 독립된 축으로 부모운·형제운 1차 판정',
        interpretationRole: InterpretationRole.primary,
        weight: 0.7,
      ),
    );

    // ── ② 부모 인연 구조(parentPattern) — 레거시 3단계 분류를
    // 'A — B' 라벨 형식으로 확장(§4) ──
    final String parentPattern;
    if (parentCount == 0) {
      parentPattern = '자립형(自立型) — 부모의 도움보다 스스로 개척하는 힘이 강한 구조';
    } else if (parentCount <= 2) {
      parentPattern = '인복형(印福型) — 부모·윗사람의 도움과 인복이 안정적으로 따르는 구조';
    } else {
      parentPattern = '의존주의형(依存注意型) — 인복은 넘치지만 의존적인 성향은 주의가 필요한 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'parentCount(인성 개수)',
        sourceValue: '인성=$parentCount',
        rule: '인성=0→자립형 / 인성=1~2→인복형 / 인성≥3→의존주의형',
        judgment: parentPattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ③ 형제 인연 구조(siblingPattern) ──
    final String siblingPattern;
    if (siblingCount == 0) {
      siblingPattern = '독행형(獨行型) — 형제·동료보다 혼자 힘으로 해내는 성향이 강한 구조';
    } else if (siblingCount <= 2) {
      siblingPattern = '협력형(協力型) — 형제·동료와 협력하며 함께 성장하는 구조';
    } else {
      siblingPattern = '경쟁형(競爭型) — 경쟁·독립심이 강해 동업·금전 거래에 신중해야 하는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'siblingCount(비겁 개수)',
        sourceValue: '비겁=$siblingCount',
        rule: '비겁=0→독행형 / 비겁=1~2→협력형 / 비겁≥3→경쟁형',
        judgment: siblingPattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ④ 신강신약 × 인성 개수 → 부모 도움을 받아들이는 방식
    // (parentBondStrength) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String parentBondStrength;
    if (strengthVerdict == '신강' && parentCount >= 2) {
      parentBondStrength = '신강중첩인(身强重疊印) — 힘도 있고 인복도 두터워 부모의 지원을 발판으로 더 크게 뻗어나가는 편';
    } else if (strengthVerdict == '신강') {
      parentBondStrength = '신강자립(身强自立) — 힘이 있어 부모 도움이 적어도 스스로 길을 열어가는 편';
    } else if (strengthVerdict == '신약' && parentCount >= 1) {
      parentBondStrength = '신약의인(身弱依印) — 부모·윗사람의 도움을 받을 때 특히 안정감이 커지는 편';
    } else if (strengthVerdict == '신약') {
      parentBondStrength = '신약무의(身弱無依) — 힘이 약한데 인성도 부족해 스스로 기반을 다지는 노력이 더 필요한 편';
    } else {
      parentBondStrength = '중화인복(中和印福) — 상황에 맞춰 부모의 도움을 유연하게 받아들이는 편';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + 인성 개수',
          sourceValue: '$strengthVerdict, 인성=$parentCount',
          rule: '신강+인성많음→신강중첩인 / 신강+인성적음→신강자립 / 신약+인성있음→신약의인 / 신약+인성없음→신약무의 / 중화→중화인복',
          judgment: parentBondStrength,
          interpretationRole: InterpretationRole.strength,
          weight: 0.9,
        ),
      );
    }

    // ── ⑤ 신강신약 × 비겁 개수 → 형제·동료의 힘을 활용하는 방식
    // (siblingBondStrength) ──
    final String siblingBondStrength;
    if (strengthVerdict == '신강' && siblingCount >= 2) {
      siblingBondStrength = '신강경쟁비(身强競爭比) — 힘도 있고 비겁도 많아 경쟁 속에서 존재감을 드러내는 편';
    } else if (strengthVerdict == '신강') {
      siblingBondStrength = '신강독립비(身强獨立比) — 힘이 있어 형제·동료 없이도 스스로 잘 헤쳐나가는 편';
    } else if (strengthVerdict == '신약' && siblingCount >= 1) {
      siblingBondStrength = '신약조력비(身弱助力比) — 형제·동료의 협력을 받을 때 부족한 힘을 채우는 편';
    } else if (strengthVerdict == '신약') {
      siblingBondStrength = '신약고립비(身弱孤立比) — 힘도 약하고 비겁도 부족해 혼자 감당하는 부담이 큰 편';
    } else {
      siblingBondStrength = '중화협비(中和協比) — 상황에 맞춰 형제·동료와의 협력 정도를 유연하게 조절하는 편';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + 비겁 개수',
          sourceValue: '$strengthVerdict, 비겁=$siblingCount',
          rule: '신강+비겁많음→신강경쟁비 / 신강+비겁적음→신강독립비 / 신약+비겁있음→신약조력비 / 신약+비겁없음→신약고립비 / 중화→중화협비',
          judgment: siblingBondStrength,
          interpretationRole: InterpretationRole.strength,
          weight: 0.9,
        ),
      );
    }

    // ── ⑥ 부모형제궁(월지) 관계(familyPalaceCondition) — [A08 고유
    // 근거] 월지가 관여된 합충형파해/원진 관계만 필터링(PHASE2가 이미
    // 계산한 relationships를 위치로 재조회할 뿐, 새로 계산하지 않음 §0) ──
    final monthBranchRelations = (profile.relationships ?? const [])
        .where((r) => r.positions.contains('월지'))
        .toList();
    const conflictTypes = {'지지충', '천간충', '형', '파', '해', '원진', '귀문'};
    const harmonyTypes = {'육합', '삼합', '방합', '천간합'};
    final conflictRelations = monthBranchRelations.where((r) => conflictTypes.contains(r.type)).toList();
    final harmonyRelations = monthBranchRelations.where((r) => harmonyTypes.contains(r.type)).toList();
    final String familyPalaceCondition;
    if (conflictRelations.isNotEmpty && harmonyRelations.isNotEmpty) {
      familyPalaceCondition =
          '부모형제궁 혼재 — 월지에 ${harmonyRelations.map((r) => r.type).join(',')}(화합)와 '
          '${conflictRelations.map((r) => r.type).join(',')}(충돌)가 함께 있어 부모·형제와의 관계에 부침이 있을 수 있는 구조';
    } else if (conflictRelations.isNotEmpty) {
      familyPalaceCondition =
          '부모형제궁 불안 — 월지가 ${conflictRelations.map((r) => r.type).join(',')} 관계에 놓여 있어 '
          '부모·형제와 거리감·갈등을 겪을 수 있으나 극복하면 관계가 더 단단해지는 구조';
    } else if (harmonyRelations.isNotEmpty) {
      familyPalaceCondition =
          '부모형제궁 안정 — 월지가 ${harmonyRelations.map((r) => r.type).join(',')} 관계로 화합해 '
          '부모·형제와 자연스럽게 조화를 이루는 구조';
    } else {
      familyPalaceCondition = '부모형제궁 독자형 — 월지가 다른 글자와 특별한 합충 관계 없이 독립적이라 부모·형제와 각자의 영역을 존중하며 지내는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'relationships(월지 관여 합충형파해/원진, PHASE2 실계산)',
        sourceValue:
            '화합=${harmonyRelations.map((r) => r.type).toList()}, 충돌=${conflictRelations.map((r) => r.type).toList()}',
        rule: '월지가 관여된 관계 중 화합(육합/삼합/방합/천간합)과 충돌(충/형/파/해/원진/귀문)을 분류',
        judgment: familyPalaceCondition,
        interpretationRole: InterpretationRole.relationship,
        weight: 0.85,
      ),
    );

    // ── §5 개인화 강화: 같은 parentPattern/siblingPattern이라도 실제
    // 부모형제궁 관계 종류·개수는 사람마다 다르다는 것을 supportingEvidence
    // 로 기록 ──
    final supportingEvidence = <AnalysisEvidence>[
      AnalysisEvidence(
        sourceField: '월지 관여 관계 상세 목록',
        sourceValue: monthBranchRelations.isEmpty
            ? '없음'
            : monthBranchRelations.map((r) => '${r.type}(${r.characters.join("")})').join(', '),
        rule: '같은 parentPattern/siblingPattern이라도 부모형제궁 관계의 실제 종류/상대 글자는 사람마다 다름(§5)',
        judgment: monthBranchRelations.isEmpty ? '월지 관여 관계 없음' : '${monthBranchRelations.length}건의 부모형제궁 관계 확인',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.4,
      ),
    ];

    // ── ⑦ 리스크(familyRiskPattern): 부모형제궁(월지)에 걸린 공망/겁살/
    // 재살 + 인성/비겁 부재 여부 ──
    final sinsalList = profile.sinsal ?? const [];
    final foundFamilyRiskSinsal = sinsalList
        .where((s) => _familyRiskSinsalNames.contains(s.nameKr) && s.foundOn.contains('월지'))
        .map((s) => s.nameKr)
        .toSet()
        .toList();
    final riskParts = <String>[];
    if (foundFamilyRiskSinsal.contains('공망')) {
      riskParts.add('부모형제궁(월지)에 공망이 걸려 있어 부모·형제와의 인연에서 실속이 예상보다 적게 느껴질 수 있음');
    }
    if (foundFamilyRiskSinsal.contains('겁살')) {
      riskParts.add('부모형제궁에 겁살이 있어 부모·형제와 관련된 재물 문제에 미리 대비하는 것이 좋음');
    }
    if (foundFamilyRiskSinsal.contains('재살')) {
      riskParts.add('부모형제궁에 재살이 있어 부모·형제와 관련된 구설이나 예기치 못한 어려움에 유의할 필요');
    }
    if (parentCount == 0) {
      riskParts.add('인성이 원국에 나타나지 않아 부모의 실질적 도움을 기대하기보다 스스로 기반을 다지는 편이 유리함');
    }
    if (siblingCount == 0) {
      riskParts.add('비겁이 원국에 나타나지 않아 형제·동료의 협력보다 혼자 해내는 방식이 더 잘 맞을 수 있음');
    }
    final familyRiskPattern = riskParts.isEmpty ? '두드러진 부모·형제운 리스크 신호는 확인되지 않음' : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '신살(부모형제궁 공망/겁살/재살) + 인성·비겁 부재 조합',
          sourceValue: '신살=$foundFamilyRiskSinsal, 인성=$parentCount, 비겁=$siblingCount',
          rule: '부모형제궁(월지)에 공망/겁살/재살 존재 또는 인성=0/비겁=0 각각을 리스크 신호로 채택 후 종합',
          judgment: familyRiskPattern,
          interpretationRole: InterpretationRole.caution,
          weight: 0.7,
        ),
      );
    }
    // 부모형제궁 신살 발견 여부 자체는 항상 세부 근거로 남긴다(§5).
    supportingEvidence.add(
      AnalysisEvidence(
        sourceField: '부모형제궁(월지) 신살 존재 여부',
        sourceValue: foundFamilyRiskSinsal.isEmpty ? '없음' : foundFamilyRiskSinsal.join(', '),
        rule: '부모형제궁 신살 존재 여부는 리스크 판단과 별개로 항상 추적',
        judgment: foundFamilyRiskSinsal.isEmpty ? '부모형제궁에 걸린 신살 없음' : '${foundFamilyRiskSinsal.join(', ')} 보유',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.3,
      ),
    );

    // ── ⑧ 관계 접근법(familyRelationApproach) ──
    final familyRelationApproach = _buildApproach(
      parentBondStrength: parentBondStrength,
      siblingBondStrength: siblingBondStrength,
      hasConflict: conflictRelations.isNotEmpty,
    );

    // ── ⑨ 부모·형제 인연 정점 대운(familyBlessingDaewoonLabel) — PHASE4
    // 실계산만 사용(인성 또는 비겁 범주, 또는 용신 오행 매칭) ──
    var familyBlessingDaewoonLabel = '';
    final daewoonList = profile.daewoon ?? const [];
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    for (final d in daewoonList) {
      final matchesParent = q.daewoonMatchesCategory(d, '인성');
      final matchesSibling = q.daewoonMatchesCategory(d, '비겁');
      final carriesYongsin = yongsinElement.isNotEmpty && q.daewoonCarriesElement(d, yongsinElement);
      if (matchesParent || matchesSibling || carriesYongsin) {
        familyBlessingDaewoonLabel =
            '${d.startAge}세(${d.startYear}년)부터 시작된 ${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운';
        break;
      }
    }
    if (familyBlessingDaewoonLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산)',
          sourceValue: familyBlessingDaewoonLabel,
          rule: '대운의 천간/지지 십신이 인성 또는 비겁 범주이거나 용신 오행을 포함하는 첫 대운 채택',
          judgment: '$familyBlessingDaewoonLabel 시기에 부모·형제 관련 인연·도움이 가장 활발해질 가능성',
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
      if (harmonyRelations.isNotEmpty) '부모형제궁이 안정적이라 부모·형제와의 관계를 오래 좋게 유지하기 좋은 환경',
      if (familyBlessingDaewoonLabel.isNotEmpty) '$familyBlessingDaewoonLabel 시기',
      if (yongsinElement.isNotEmpty) '$yongsinElement 기운이 강해지는 시기·인연',
    ];
    final caution = <String>[
      if (conflictRelations.isNotEmpty) '부모형제궁 충돌(${conflictRelations.map((r) => r.type).join(',')})로 인한 갈등 관리',
      if (foundFamilyRiskSinsal.isNotEmpty) '${foundFamilyRiskSinsal.join(', ')} 신호에 따른 부모·형제 관련 사안 대비',
      if (parentCount == 0 || siblingCount == 0) '부모 또는 형제의 도움이 상대적으로 적을 수 있는 만큼 스스로의 기반을 준비하는 마음가짐',
    ];
    if (favorable.isEmpty) favorable.add('현재의 부모·형제 인연 구조를 안정적으로 유지하는 환경');
    if (caution.isEmpty) caution.add('두드러진 부모·형제운 리스크 신호는 확인되지 않음');

    final confidence = (profile.strength == null || profile.yongsin == null)
        ? AnalysisConfidence.low
        : (familyBlessingDaewoonLabel.isEmpty && riskParts.isEmpty && conflictRelations.isEmpty)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: 최종 판정에 실제로 쓰인 원시 수치 전체를
    // 개발자 검증용으로 남긴다 ──
    final interpretationContext = <String, String>{
      'parentCount': '$parentCount',
      'siblingCount': '$siblingCount',
      'strengthVerdict': strengthVerdict,
      'yongsinElement': yongsinElement,
      'monthBranchRelationTypes': monthBranchRelations.map((r) => r.type).join(','),
      'foundFamilyRiskSinsal': foundFamilyRiskSinsal.join(','),
      'familyBlessingDaewoonLabel': familyBlessingDaewoonLabel,
    };

    return ParentsSiblingsAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 부모·형제운',
      coreEvidence: evidence,
      supportingEvidence: supportingEvidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      parentPattern: parentPattern,
      parentBondStrength: parentBondStrength,
      siblingPattern: siblingPattern,
      siblingBondStrength: siblingBondStrength,
      familyPalaceCondition: familyPalaceCondition,
      familyRiskPattern: familyRiskPattern,
      familyRelationApproach: familyRelationApproach,
      familyBlessingDaewoonLabel: familyBlessingDaewoonLabel,
    );
  }

  String _buildApproach({
    required String parentBondStrength,
    required String siblingBondStrength,
    required bool hasConflict,
  }) {
    final parentPart = parentBondStrength.startsWith('신강중첩인')
        ? '부모의 지원을 발판으로 삼아 더 크게 나아가고'
        : parentBondStrength.startsWith('신강자립')
        ? '부모 도움에 크게 의지하지 않고 스스로 길을 열어가고'
        : parentBondStrength.startsWith('신약의인')
        ? '부모·윗사람의 도움을 편안하게 받아들이고'
        : parentBondStrength.startsWith('신약무의')
        ? '부모 도움이 적은 만큼 스스로 기반을 다지는 데 힘을 쏟고'
        : '상황에 맞춰 부모와의 관계 거리를 유연하게 조절하고';
    final siblingPart = siblingBondStrength.startsWith('신강경쟁비')
        ? '형제·동료와의 경쟁도 성장의 발판으로 삼는 편이'
        : siblingBondStrength.startsWith('신강독립비')
        ? '형제·동료 없이도 스스로 잘 헤쳐나가는 편이'
        : siblingBondStrength.startsWith('신약조력비')
        ? '형제·동료의 협력을 적극적으로 받아들이는 편이'
        : siblingBondStrength.startsWith('신약고립비')
        ? '혼자 감당하려 하지 말고 주변에 도움을 요청하는 습관을 들이는 편이'
        : '형제·동료와의 협력 정도를 상황에 맞춰 조절하는 편이';
    final conflictNote = hasConflict ? ' 좋고, 특히 부모·형제와의 갈등이 쌓이지 않도록 감정을 오래 묵히지 않는 습관이 도움이 됨' : ' 좋음';
    return '$parentPart, $siblingPart$conflictNote';
  }
}
