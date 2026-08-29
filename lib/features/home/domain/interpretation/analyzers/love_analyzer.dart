/// [정통사주 69종 개인화 해석 엔진 — 6단계] A06 평생 배우자·결혼운 Analyzer.
///
/// 레거시 `getLifeLove()`가 배우자성(남=재성/여=관성) 정편 개수만으로
/// 4개 고정 문장(정통형/다연형/만혼형/혼합형) 중 하나를 골라 반환하고,
/// 신강신약·배우자궁(일지) 관계·신살·대운을 전혀 참조하지 않던 방식을
/// 폐기한다. 대신 [SajuProfile]의 십신 분포·신강신약·배우자궁(일지)이
/// 관여된 합충형파해/원진·애정 관련 신살(년살=도화/육해살)·용신/기신·
/// 대운을 A03/A04/A05와 동일한 설계 원칙으로 직접 조회해 배우자·결혼
/// 구조를 매번 새로 판정한다(§4 "문장이 아니라 분석을 개인화").
///
/// 사용 데이터(§10 requiredData):
/// - 십신 7위치(tenGods) — 배우자성(남:재성/여:관살) 개수, 비겁 개수
/// - 신강신약(strength) — 결혼생활을 감당할 그릇의 크기
/// - 합충형파해(relationships) — 배우자궁(일지)이 관여된 관계만 필터링
///   (§ A06 고유 근거 — 다른 카테고리는 이 관점으로 조회하지 않음)
/// - 신살(sinsal) — 년살(도화)/육해살 등 애정 관련 신호
/// - 용신/기신(yongsin) — 배우자운이 좋아지는/나빠지는 조건
/// - 대운(daewoon) — 혼인·인연이 정점에 이르는 실제 시기
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C/D그룹이 담당), 자녀운(A07이 담당, 배우자성과는 다른 육친성 사용).
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'love_analysis.dart';

/// 애정·인연과 직결되는 신살 nameKr 목록(sinsal_engine.dart가 실제로
/// 산출하는 nameKr과 일치 — 12신살 중 '년살'이 전통적으로 도화(桃花)에
/// 해당하는 자리이고, '육해살'은 관계의 마찰·이별 신호로 함께 쓰인다).
const Set<String> _romanceRiskSinsalNames = {'년살', '육해살'};

class LoveAnalyzer extends CategoryAnalyzer<LoveAnalysis> {
  const LoveAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A06',
    categoryPurpose: '평생에 걸친 배우자 인연의 구조와 결혼생활을 감당하는 그릇의 크기, 배우자궁의 안정성을 분석',
    requiredData: [
      '십신 분포(배우자성/비겁)',
      '신강신약',
      '배우자궁(일지) 관계',
      '신살(년살/육해살)',
      '용신/기신',
      '대운',
    ],
    analysisRules: [
      '배우자성(남:재성/여:관살) 개수와 비겁 개수를 조합해 인연 구조(spousePattern) 판정',
      '신강신약 × 배우자성 개수 조합으로 결혼생활을 감당할 그릇의 크기(spouseBondStrength) 판정',
      '배우자궁(일지)이 관여된 합충형파해/원진 관계 조회로 배우자궁 안정성(spousePalaceCondition) 판정',
      '애정 관련 신살(년살/육해살) 존재 + 비겁 개수를 조합해 리스크(romanceRiskPattern) 판정',
      '대운 목록에서 배우자성 범주이거나 용신 오행을 포함하는 대운을 혼인 정점 시기로 판정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '자녀운(A07 담당)'],
    outputStructure: [
      '인연 구조',
      '그릇의 크기',
      '배우자궁 상태',
      '리스크',
      '연애·결혼 접근법',
      '정점 대운',
    ],
  );

  @override
  LoveAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);
    final gender = profile.birthInfo.gender;

    // ── ① 배우자성 범주 결정(남=재성/여=관살) + 비겁 개수 집계
    // (원국 본기 + 지장간 포함) ──
    final categoryCounts = q.tenGodCategoryCounts(includeHiddenStems: true);
    final String spouseCategory;
    final String spouseCategoryLabel;
    if (gender == 'male') {
      spouseCategory = '재성';
      spouseCategoryLabel = '재성(처성)';
    } else {
      spouseCategory = '관살';
      spouseCategoryLabel = '관살(부성)';
    }
    final spouseCount = categoryCounts[spouseCategory] ?? 0;
    final biCount = categoryCounts['비겁'] ?? 0;
    evidence.add(
      AnalysisEvidence(
        sourceField: 'birthInfo.gender + tenGods+hiddenStems(5대범주 집계)',
        sourceValue:
            '성별=$gender → 배우자성=$spouseCategoryLabel, 개수=$spouseCount, 비겁=$biCount',
        rule: '남성은 재성, 여성은 관살을 배우자성으로 채택(전통 명리학 육친법)',
        judgment: '배우자성 개수를 기준으로 인연 구조 1차 판정',
        interpretationRole: InterpretationRole.primary,
        weight: 0.7,
      ),
    );

    // ── ② 인연 구조(spousePattern) — 레거시 4분류를 비겁까지 포함해
    // 세분화(§4) ──
    final String spousePattern;
    if (spouseCount == 1 && biCount == 0) {
      spousePattern = '정연형(正緣形) — 정해진 인연을 만나 오래가는 안정적 결혼 구조';
    } else if (spouseCount >= 2 && biCount == 0) {
      spousePattern = '다연형(多緣形) — 이성 인연이 여러 번 오가며 선택의 폭이 넓은 구조';
    } else if (spouseCount >= 1 && biCount >= 2) {
      spousePattern = '경쟁연형(競爭緣形) — 배우자를 두고 경쟁·삼각관계 가능성이 있어 신중한 선택이 필요한 구조';
    } else if (spouseCount == 0) {
      spousePattern = '만혼·특수연형(晩婚·特殊緣形) — 인연의 시작이 늦거나 특별한 계기로 맺어지는 구조';
    } else {
      spousePattern = '혼합형 — 안정적 인연과 활발한 인연이 함께 섞인 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'spouseCount/biCount 조합',
        sourceValue: '배우자성=$spouseCount, 비겁=$biCount',
        rule:
            '배우자성=1&비겁=0→정연형 / 배우자성≥2&비겁=0→다연형 / 배우자성≥1&비겁≥2→경쟁연형 / 배우자성=0→만혼특수연형 / 그외→혼합형',
        judgment: spousePattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ③ 신강신약 × 배우자성 개수 → 그릇의 크기(spouseBondStrength) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String spouseBondStrength;
    if (strengthVerdict == '신강' && spouseCount >= 2) {
      spouseBondStrength = '신강용배(身强用配) — 여러 인연을 감당할 힘이 있어 관계를 주도적으로 이끄는 편';
    } else if (strengthVerdict == '신강' && spouseCount <= 1) {
      spouseBondStrength =
          '신강경연(身强輕緣) — 힘은 있으나 배우자성이 적어 스스로 인연을 적극적으로 만들어야 하는 구조';
    } else if (strengthVerdict == '신약' && spouseCount >= 2) {
      spouseBondStrength = '연다신약(緣多身弱) — 인연 기회는 많으나 관계를 감당할 힘이 부족해 무리한 관계는 부담';
    } else if (strengthVerdict == '신약') {
      spouseBondStrength = '신약보연(身弱補緣) — 배우자·상대방의 지지를 받을 때 관계가 더 안정되는 편';
    } else {
      spouseBondStrength = '중화용배(中和用配) — 상황에 맞춰 유연하게 관계를 운용할 수 있는 구조';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + 배우자성 개수',
          sourceValue: '$strengthVerdict, 배우자성=$spouseCount',
          rule:
              '신강+배우자성많음→신강용배 / 신강+배우자성적음→신강경연 / 신약+배우자성많음→연다신약 / 신약→신약보연 / 중화→중화용배',
          judgment: spouseBondStrength,
          interpretationRole: InterpretationRole.strength,
          weight: 0.95,
        ),
      );
    }

    // ── ④ 배우자궁(일지) 관계(spousePalaceCondition) — [A06 고유 근거]
    // 일지가 관여된 합충형파해/원진 관계만 필터링(PHASE2가 이미 계산한
    // relationships를 위치로 재조회할 뿐, 새로 계산하지 않음 §0) ──
    final dayBranchRelations = (profile.relationships ?? const [])
        .where((r) => r.positions.contains('일지'))
        .toList();
    final conflictTypes = {'지지충', '천간충', '형', '파', '해', '원진', '귀문'};
    final harmonyTypes = {'육합', '삼합', '방합', '천간합'};
    final conflictRelations = dayBranchRelations
        .where((r) => conflictTypes.contains(r.type))
        .toList();
    final harmonyRelations = dayBranchRelations
        .where((r) => harmonyTypes.contains(r.type))
        .toList();
    final String spousePalaceCondition;
    if (conflictRelations.isNotEmpty && harmonyRelations.isNotEmpty) {
      spousePalaceCondition =
          '배우자궁 혼재 — 일지에 ${harmonyRelations.map((r) => r.type).join(',')}(화합)와 '
          '${conflictRelations.map((r) => r.type).join(',')}(충돌)가 함께 있어 관계에 부침이 있을 수 있는 구조';
    } else if (conflictRelations.isNotEmpty) {
      spousePalaceCondition =
          '배우자궁 불안 — 일지가 ${conflictRelations.map((r) => r.type).join(',')} 관계에 놓여 있어 '
          '배우자와의 갈등·이별 위기를 겪을 수 있으나 극복하면 관계가 더 단단해지는 구조';
    } else if (harmonyRelations.isNotEmpty) {
      spousePalaceCondition =
          '배우자궁 안정 — 일지가 ${harmonyRelations.map((r) => r.type).join(',')} 관계로 화합해 '
          '배우자와 자연스럽게 조화를 이루는 구조';
    } else {
      spousePalaceCondition =
          '배우자궁 독자형 — 일지가 다른 글자와 특별한 합충 관계 없이 독립적이라 스스로 관계를 만들어가는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'relationships(일지 관여 합충형파해/원진, PHASE2 실계산)',
        sourceValue:
            '화합=${harmonyRelations.map((r) => r.type).toList()}, 충돌=${conflictRelations.map((r) => r.type).toList()}',
        rule: '일지가 관여된 관계 중 화합(육합/삼합/방합/천간합)과 충돌(충/형/파/해/원진/귀문)을 분류',
        judgment: spousePalaceCondition,
        interpretationRole: InterpretationRole.relationship,
        weight: 0.85,
      ),
    );

    // ── §5 개인화 강화: 같은 spousePattern이라도 실제 배우자궁 관계
    // 종류·개수는 사람마다 다르다는 것을 supportingEvidence로 기록 ──
    final supportingEvidence = <AnalysisEvidence>[
      AnalysisEvidence(
        sourceField: '일지 관여 관계 상세 목록',
        sourceValue: dayBranchRelations.isEmpty
            ? '없음'
            : dayBranchRelations
                  .map((r) => '${r.type}(${r.characters.join("")})')
                  .join(', '),
        rule: '같은 spousePattern이라도 배우자궁 관계의 실제 종류/상대 글자는 사람마다 다름(§5)',
        judgment: dayBranchRelations.isEmpty
            ? '일지 관여 관계 없음'
            : '${dayBranchRelations.length}건의 배우자궁 관계 확인',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.4,
      ),
    ];

    // ── ⑤ 리스크(romanceRiskPattern): 년살(도화)/육해살 + 비겁 개수 ──
    final sinsalList = profile.sinsal ?? const [];
    final foundRomanceSinsal = sinsalList
        .where(
          (s) =>
              _romanceRiskSinsalNames.contains(s.nameKr) &&
              s.foundOn.isNotEmpty,
        )
        .map((s) => s.nameKr)
        .toSet()
        .toList();
    final riskParts = <String>[];
    if (foundRomanceSinsal.contains('년살')) {
      riskParts.add('년살(도화)이 있어 이성에게 매력적으로 비치는 만큼 다양한 유혹·삼각관계에 대한 절제가 필요');
    }
    if (foundRomanceSinsal.contains('육해살')) {
      riskParts.add('육해살이 있어 가까운 사이일수록 오히려 오해나 마찰이 생기기 쉬우니 소통에 더 신경 쓸 필요');
    }
    if (biCount >= 2 && spouseCount >= 1) {
      riskParts.add('비겁이 $biCount개로 많아 배우자를 두고 경쟁하거나 형제·동료와 갈등이 생길 소지');
    }
    final romanceRiskPattern = riskParts.isEmpty
        ? '두드러진 애정상 리스크 신호는 확인되지 않음'
        : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '신살(년살/육해살) + 비겁 개수 조합',
          sourceValue: '신살=$foundRomanceSinsal, 비겁=$biCount, 배우자성=$spouseCount',
          rule: '년살(도화) 또는 육해살 존재 / 비겁≥2&배우자성≥1 각각을 리스크 신호로 채택 후 종합',
          judgment: romanceRiskPattern,
          interpretationRole: InterpretationRole.caution,
          weight: 0.7,
        ),
      );
    }
    // 애정 신살 발견 여부 자체는 항상 세부 근거로 남긴다(§5).
    supportingEvidence.add(
      AnalysisEvidence(
        sourceField: '애정 관련 신살(년살/육해살) 존재 여부',
        sourceValue: foundRomanceSinsal.isEmpty
            ? '없음'
            : foundRomanceSinsal.join(', '),
        rule: '애정 신살 존재 여부는 리스크 판단과 별개로 항상 추적',
        judgment: foundRomanceSinsal.isEmpty
            ? '애정 관련 신살 없음'
            : '${foundRomanceSinsal.join(', ')} 보유',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.3,
      ),
    );

    // ── ⑥ 연애·결혼 접근법(recommendedApproach) ──
    final recommendedApproach = _buildApproach(
      spouseBondStrength: spouseBondStrength,
      spousePalaceCondition: spousePalaceCondition,
      hasConflict: conflictRelations.isNotEmpty,
    );

    // ── ⑦ 혼인 정점 대운(marriagePeakDaewoonLabel) — PHASE4 실계산만
    // 사용 ──
    var marriagePeakDaewoonLabel = '';
    final daewoonList = profile.daewoon ?? const [];
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    for (final d in daewoonList) {
      final matchesCategory = q.daewoonMatchesCategory(d, spouseCategory);
      final carriesYongsin =
          yongsinElement.isNotEmpty &&
          q.daewoonCarriesElement(d, yongsinElement);
      if (matchesCategory || carriesYongsin) {
        marriagePeakDaewoonLabel =
            '${d.startAge}세(${d.startYear}년)부터 시작된 ${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운';
        break;
      }
    }
    if (marriagePeakDaewoonLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산)',
          sourceValue: marriagePeakDaewoonLabel,
          rule: '대운의 천간/지지 십신이 배우자성 범주이거나 용신 오행을 포함하는 첫 대운 채택',
          judgment: '$marriagePeakDaewoonLabel 시기에 혼인·인연운이 가장 활발해질 가능성',
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
            judgment:
                '현재 ${current.pillar.stemKr}${current.pillar.branchKr} 대운을 지나는 중',
            interpretationRole: InterpretationRole.timing,
            weight: 0.5,
          ),
        );
      }
    }

    // ── 좋은 흐름 / 주의 흐름 ──
    final favorable = <String>[
      if (harmonyRelations.isNotEmpty) '배우자궁이 안정적이라 관계를 오래 유지하기 좋은 환경',
      if (marriagePeakDaewoonLabel.isNotEmpty) '$marriagePeakDaewoonLabel 시기',
      if (yongsinElement.isNotEmpty) '$yongsinElement 기운이 강해지는 시기·인연',
    ];
    final caution = <String>[
      if (conflictRelations.isNotEmpty)
        '배우자궁 충돌(${conflictRelations.map((r) => r.type).join(',')})로 인한 갈등 관리',
      if (foundRomanceSinsal.isNotEmpty)
        '${foundRomanceSinsal.join(', ')} 신호에 따른 이성 관계 절제',
      if (biCount >= 2 && spouseCount >= 1) '경쟁·삼각관계로 이어질 수 있는 상황에 대한 신중함',
    ];
    if (favorable.isEmpty) favorable.add('현재의 인연 구조를 안정적으로 유지하는 환경');
    if (caution.isEmpty) caution.add('두드러진 애정상 리스크 신호는 확인되지 않음');

    final confidence = (profile.strength == null || profile.yongsin == null)
        ? AnalysisConfidence.low
        : (marriagePeakDaewoonLabel.isEmpty &&
              riskParts.isEmpty &&
              conflictRelations.isEmpty)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: 최종 판정에 실제로 쓰인 원시 수치 전체를
    // 개발자 검증용으로 남긴다 ──
    final interpretationContext = <String, String>{
      'gender': gender,
      'spouseCategory': spouseCategory,
      'spouseCount': '$spouseCount',
      'biCount': '$biCount',
      'strengthVerdict': strengthVerdict,
      'yongsinElement': yongsinElement,
      'dayBranchRelationTypes': dayBranchRelations.map((r) => r.type).join(','),
      'foundRomanceSinsal': foundRomanceSinsal.join(','),
      'marriagePeakDaewoonLabel': marriagePeakDaewoonLabel,
    };

    return LoveAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 배우자·결혼운',
      coreEvidence: evidence,
      supportingEvidence: supportingEvidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      spousePattern: spousePattern,
      spouseBondStrength: spouseBondStrength,
      spousePalaceCondition: spousePalaceCondition,
      romanceRiskPattern: romanceRiskPattern,
      recommendedApproach: recommendedApproach,
      marriagePeakDaewoonLabel: marriagePeakDaewoonLabel,
    );
  }

  String _buildApproach({
    required String spouseBondStrength,
    required String spousePalaceCondition,
    required bool hasConflict,
  }) {
    final base = spouseBondStrength.startsWith('신강용배')
        ? '관계를 주도적으로 이끌어가되 상대의 의견도 충분히 배려하는 편이'
        : spouseBondStrength.startsWith('연다신약')
        ? '여러 인연에 흔들리기보다 한 사람에게 집중하는 편이'
        : spouseBondStrength.startsWith('신약보연')
        ? '상대방의 지지와 배려를 편안하게 받아들이는 편이'
        : spouseBondStrength.startsWith('신강경연')
        ? '먼저 다가가고 인연을 적극적으로 만들어가는 편이'
        : '상황에 맞춰 유연하게 관계를 조율하는 편이';
    final palaceNote = hasConflict
        ? ' 좋고, 특히 사소한 갈등이 쌓이지 않도록 대화를 자주 나누는 습관이 도움이 됨'
        : ' 좋음';
    return '$base$palaceNote';
  }
}
