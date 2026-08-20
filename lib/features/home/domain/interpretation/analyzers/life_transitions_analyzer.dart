/// [정통사주 69종 개인화 해석 엔진 — 10단계] A10 인생 5대 전환점
/// Analyzer.
///
/// 레거시 `getLifeTransitionPoints()`가 대운 목록(PHASE4 실계산) 앞 5개의
/// 시작연령/시작연도/간지만 그대로 나열하고, 그 전환점이 "왜" 전환점인지
/// (십신 범주가 얼마나 바뀌는지, 용신/기신 중 어디에 해당하는지)는 전혀
/// 판정하지 않던 방식을 폐기한다. 대신 [SajuProfile]의 대운 목록·용신/
/// 기신·신강신약을 A06~A09와 동일한 설계 원칙으로 직접 조회해, 각 전환점
/// 마다 "무엇이 바뀌는가"와 "그 변화가 좋은 방향인가"를 매번 새로
/// 판정한다(§4 "문장이 아니라 분석을 개인화").
///
/// [A06/A07/A08/A09와의 구조적 차이 — 중요] A06/A07/A08은 고정된 궁
/// 위치(일지/시지/월지), A09는 문창귀인이 걸린 위치를 고유 근거로
/// 채택했다. A10은 특정 궁이나 신살이 아니라, 대운이 바뀔 때마다 십신
/// 5대 범주(비겁/식상/재성/관살/인성)가 이전 대운과 얼마나 달라지는지
/// (대전환/소전환/순환형)와 그 대운이 용신/기신 중 어디에 해당하는지
/// (호전/주의/중립)를 [A10 고유 근거]로 채택한다 — 다른 카테고리는 이
/// 관점으로 대운 목록 전체를 순회 비교하지 않는다.
///
/// 사용 데이터(§10 requiredData):
/// - 대운(daewoon) — PHASE4 실계산 목록 앞 5개, 각 항목의 십신(천간/지지)
/// - 용신/기신(yongsin) — 전환점이 좋은 방향인지 판정하는 기준
/// - 신강신약(strength) — 전환기를 감당하는 방식
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C/D그룹이 담당), 특정 주제별 대운 흐름(재물/직업 등은 B그룹이 담당 —
/// A10은 "전환의 질과 방향"이라는 메타 관점만 다룬다).
library;

import '../../manseryeok/saju_profile.dart';
import '../../manseryeok/strength_engine.dart' show tenGodCategoryOf;
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'life_transitions_analysis.dart';

class LifeTransitionsAnalyzer extends CategoryAnalyzer<LifeTransitionsAnalysis> {
  const LifeTransitionsAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A10',
    categoryPurpose: '평생 대운 흐름 속에서 실제로 인생의 방향이 크게 바뀌는 전환점 5개를 찾아 그 성격을 분석',
    requiredData: ['대운(앞 5개)', '용신/기신', '신강신약'],
    analysisRules: [
      '대운 목록 앞 5개 각각을 이전 대운과 비교해 십신 범주(천간+지지) 변화 정도로 대전환/소전환/순환형 분류',
      '대전환 개수를 기준으로 전체 전환 성격(transitionPattern) 4단계 판정',
      '신강신약을 기준으로 전환기를 대하는 방식(transitionBondStrength) 판정',
      '각 전환점이 용신/기신 오행을 포함하는지 조회해 호전/주의/중립으로 분류(turningPointsCondition)',
      '기신과 맞닿은 전환점 개수·시점을 리스크(transitionRiskPattern)로 판정',
      '호전+대전환이 겹치는 첫 전환점을 가장 주목할 전환점(keyTurningPointLabel)으로 채택',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '재물·직업 등 주제별 대운 흐름(B그룹 담당)'],
    outputStructure: ['전환 성격', '전환기 대응 방식', '전환점별 상세', '리스크', '전환 접근법', '핵심 전환점'],
  );

  @override
  LifeTransitionsAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);

    // ── ① 대운 목록(PHASE4 실계산) 앞 5개를 이전 대운과 비교해 십신
    // 범주(천간+지지) 변화 정도로 분류 ──
    final daewoonList = profile.daewoon ?? const [];
    final top5 = daewoonList.take(5).toList();
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    final gisinElement = profile.yongsin?.gisin ?? '';

    final classified = <_TransitionInfo>[];
    for (var i = 0; i < top5.length; i++) {
      final d = top5[i];
      final stemCat = tenGodCategoryOf(d.tenGodStem);
      final branchCat = tenGodCategoryOf(d.tenGodBranch);
      String changeLevel;
      if (i == 0) {
        // 첫 전환점은 비교 대상(출생 이전 대운)이 없어, 그 자체를
        // "새로운 국면의 시작"이라는 의미로 소전환으로 채택(방어적 기본값).
        changeLevel = '소전환';
      } else {
        final prev = top5[i - 1];
        final prevStemCat = tenGodCategoryOf(prev.tenGodStem);
        final prevBranchCat = tenGodCategoryOf(prev.tenGodBranch);
        final stemChanged = stemCat != prevStemCat;
        final branchChanged = branchCat != prevBranchCat;
        if (stemChanged && branchChanged) {
          changeLevel = '대전환';
        } else if (stemChanged || branchChanged) {
          changeLevel = '소전환';
        } else {
          changeLevel = '순환형';
        }
      }
      final carriesYongsin = yongsinElement.isNotEmpty && q.daewoonCarriesElement(d, yongsinElement);
      final carriesGisin = gisinElement.isNotEmpty && q.daewoonCarriesElement(d, gisinElement);
      final String direction;
      if (carriesYongsin && !carriesGisin) {
        direction = '호전';
      } else if (carriesGisin && !carriesYongsin) {
        direction = '주의';
      } else {
        direction = '중립';
      }
      classified.add(
        _TransitionInfo(
          entry: d,
          changeLevel: changeLevel,
          direction: direction,
          label: '${d.startAge}세(${d.startYear}년)부터 시작된 '
              '${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운',
        ),
      );
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'daewoon(PHASE4 실계산, 앞 5개)',
        sourceValue: classified.map((c) => '${c.label}=${c.changeLevel}/${c.direction}').join(' | '),
        rule: '이전 대운과 십신 범주(천간+지지)가 모두 바뀌면 대전환, 하나만 바뀌면 소전환, 그대로면 순환형으로 분류',
        judgment: '${classified.length}개 전환점 중 대전환 ${classified.where((c) => c.changeLevel == '대전환').length}개 확인',
        interpretationRole: InterpretationRole.primary,
        weight: 0.9,
      ),
    );

    // ── ② 전체 전환 성격(transitionPattern) — 대전환 개수 기준 4단계 ──
    final bigTransitionCount = classified.where((c) => c.changeLevel == '대전환').length;
    final String transitionPattern;
    if (bigTransitionCount >= 3) {
      transitionPattern = '급변형(急變型) — 대운이 바뀔 때마다 삶의 국면이 완전히 새로 짜이는 구조';
    } else if (bigTransitionCount == 2) {
      transitionPattern = '변곡형(變曲型) — 몇 차례의 큰 굴곡을 지나며 인생의 방향이 크게 꺾이는 구조';
    } else if (bigTransitionCount == 1) {
      transitionPattern = '완만형(緩慢型) — 대부분은 잔잔히 흐르다 한 번의 큰 전환을 지나는 구조';
    } else {
      transitionPattern = '순류형(順流型) — 큰 굴곡 없이 이전의 흐름이 자연스럽게 이어지는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'bigTransitionCount(대전환 개수)',
        sourceValue: '$bigTransitionCount',
        rule: '대전환≥3→급변형 / 대전환=2→변곡형 / 대전환=1→완만형 / 대전환=0→순류형',
        judgment: transitionPattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ③ 신강신약 → 전환기 대응 방식(transitionBondStrength) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String transitionBondStrength;
    if (strengthVerdict == '신강' && bigTransitionCount >= 2) {
      transitionBondStrength = '신강주도(身强主導) — 큰 전환이 잦아도 스스로 방향을 잡아 주도적으로 헤쳐나가는 편';
    } else if (strengthVerdict == '신강') {
      transitionBondStrength = '신강안정(身强安定) — 전환이 크지 않은 만큼 힘을 차분히 쌓아가며 안정적으로 대응하는 편';
    } else if (strengthVerdict == '신약' && bigTransitionCount >= 2) {
      transitionBondStrength = '신약격동(身弱激動) — 전환이 잦고 힘이 약해 변화의 물살을 크게 느낄 수 있어 주변의 지지가 중요한 편';
    } else if (strengthVerdict == '신약') {
      transitionBondStrength = '신약적응(身弱適應) — 힘은 약하지만 전환이 크지 않아 천천히 적응해 나갈 수 있는 편';
    } else {
      transitionBondStrength = '중화순응(中和順應) — 상황에 맞춰 유연하게 전환기를 받아들이는 편';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + bigTransitionCount',
          sourceValue: '$strengthVerdict, 대전환=$bigTransitionCount',
          rule: '신강+대전환많음→신강주도 / 신강+대전환적음→신강안정 / 신약+대전환많음→신약격동 / 신약+대전환적음→신약적응 / 중화→중화순응',
          judgment: transitionBondStrength,
          interpretationRole: InterpretationRole.strength,
          weight: 0.85,
        ),
      );
    }

    // ── ④ [A10 고유 근거] 전환점별 상세(turningPointsCondition) — 각
    // 전환점의 changeLevel/direction을 순서대로 서술 ──
    final turningPointsCondition = classified.isEmpty
        ? '대운 정보가 부족해 전환점을 판정할 수 없음'
        : classified.map((c) => '${c.label}(${c.changeLevel}·${c.direction})').join(', ');
    evidence.add(
      AnalysisEvidence(
        sourceField: '대운 전환점별 십신범주 변화 + 용신/기신 대조(PHASE4 실계산)',
        sourceValue: turningPointsCondition,
        rule: '각 전환점의 변화 정도(대전환/소전환/순환형)와 용신·기신 대조 결과(호전/주의/중립)를 순서대로 매핑',
        judgment: '전환점 5개의 성격이 각각 다르게 나타남',
        interpretationRole: InterpretationRole.relationship,
        weight: 0.85,
      ),
    );

    // ── §5 개인화 강화: 같은 transitionPattern이라도 전환점의 실제
    // 연령·간지·방향은 사람마다 다르다는 것을 supportingEvidence로 기록 ──
    final supportingEvidence = <AnalysisEvidence>[
      AnalysisEvidence(
        sourceField: '전환점 상세 목록',
        sourceValue: classified.map((c) => c.label).join(', '),
        rule: '같은 transitionPattern이라도 전환점의 실제 연령·간지·방향은 사람마다 다름(§5)',
        judgment: '${classified.length}개 전환점 확인',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.4,
      ),
    ];

    // ── ⑤ 리스크(transitionRiskPattern): 기신과 맞닿은 전환점 개수·시점 ──
    final gisinTransitions = classified.where((c) => c.direction == '주의').toList();
    final riskParts = <String>[];
    if (gisinTransitions.isNotEmpty) {
      riskParts.add(
        '${gisinTransitions.map((c) => c.label).join(', ')} 시기는 기신과 맞닿아 있어 전환 과정에서 평소보다 신중한 결정이 필요',
      );
    }
    if (bigTransitionCount >= 3) {
      riskParts.add('대운이 바뀔 때마다 국면이 크게 달라지는 만큼, 매 전환점마다 새로운 환경에 적응하는 시간이 필요할 수 있음');
    }
    final transitionRiskPattern = riskParts.isEmpty ? '두드러진 전환점 리스크 신호는 확인되지 않음' : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '기신 대조 전환점 + bigTransitionCount 조합',
          sourceValue: '기신전환점=${gisinTransitions.length}, 대전환=$bigTransitionCount',
          rule: '기신과 맞닿은 전환점 존재 또는 대전환 3개 이상을 리스크 신호로 채택 후 종합',
          judgment: transitionRiskPattern,
          interpretationRole: InterpretationRole.caution,
          weight: 0.7,
        ),
      );
    }
    // 호전 전환점 개수도 항상 세부 근거로 남긴다(§5).
    final yongsinTransitions = classified.where((c) => c.direction == '호전').toList();
    supportingEvidence.add(
      AnalysisEvidence(
        sourceField: '용신/기신 대조 전환점 개수',
        sourceValue: '호전=${yongsinTransitions.length}, 주의=${gisinTransitions.length}, 중립=${classified.length - yongsinTransitions.length - gisinTransitions.length}',
        rule: '전환점별 용신/기신 대조 결과는 리스크 판단과 별개로 항상 추적',
        judgment: '호전 ${yongsinTransitions.length}개, 주의 ${gisinTransitions.length}개',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.3,
      ),
    );

    // ── ⑥ 전환 접근법(transitionApproach) ──
    final transitionApproach = _buildApproach(
      transitionBondStrength: transitionBondStrength,
      hasGisinTransition: gisinTransitions.isNotEmpty,
      hasYongsinTransition: yongsinTransitions.isNotEmpty,
    );

    // ── ⑦ 핵심 전환점(keyTurningPointLabel) — 호전+대전환이 겹치는 첫
    // 전환점, 없으면 호전인 첫 전환점 ──
    var keyTurningPointLabel = '';
    final bestBig = classified.where((c) => c.direction == '호전' && c.changeLevel == '대전환').toList();
    if (bestBig.isNotEmpty) {
      keyTurningPointLabel = bestBig.first.label;
    } else if (yongsinTransitions.isNotEmpty) {
      keyTurningPointLabel = yongsinTransitions.first.label;
    }
    if (keyTurningPointLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산) — 호전+대전환 우선 채택',
          sourceValue: keyTurningPointLabel,
          rule: '호전이면서 대전환인 첫 전환점을 우선 채택, 없으면 호전인 첫 전환점 채택',
          judgment: '$keyTurningPointLabel 시기가 가장 주목할 전환점',
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
      if (yongsinTransitions.isNotEmpty) '${yongsinTransitions.map((c) => c.label).join(', ')} 시기의 순조로운 흐름',
      if (keyTurningPointLabel.isNotEmpty) '$keyTurningPointLabel 시기',
    ];
    final caution = <String>[
      if (gisinTransitions.isNotEmpty) '${gisinTransitions.map((c) => c.label).join(', ')} 시기의 신중한 대응',
      if (bigTransitionCount >= 3) '전환이 잦은 만큼 매번 새로운 환경에 적응하는 데 필요한 마음의 여유',
    ];
    if (favorable.isEmpty) favorable.add('현재의 흐름을 안정적으로 유지하는 환경');
    if (caution.isEmpty) caution.add('두드러진 전환점 리스크 신호는 확인되지 않음');

    final confidence = (profile.strength == null || profile.yongsin == null || classified.isEmpty)
        ? AnalysisConfidence.low
        : (keyTurningPointLabel.isEmpty && riskParts.isEmpty)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: 최종 판정에 실제로 쓰인 원시 수치 전체를
    // 개발자 검증용으로 남긴다 ──
    final interpretationContext = <String, String>{
      'bigTransitionCount': '$bigTransitionCount',
      'strengthVerdict': strengthVerdict,
      'yongsinElement': yongsinElement,
      'gisinElement': gisinElement,
      'yongsinTransitionCount': '${yongsinTransitions.length}',
      'gisinTransitionCount': '${gisinTransitions.length}',
      'turningPointsCondition': turningPointsCondition,
      'keyTurningPointLabel': keyTurningPointLabel,
    };

    return LifeTransitionsAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '인생 5대 전환점',
      coreEvidence: evidence,
      supportingEvidence: supportingEvidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      transitionPattern: transitionPattern,
      transitionBondStrength: transitionBondStrength,
      turningPointsCondition: turningPointsCondition,
      transitionRiskPattern: transitionRiskPattern,
      transitionApproach: transitionApproach,
      keyTurningPointLabel: keyTurningPointLabel,
    );
  }

  String _buildApproach({
    required String transitionBondStrength,
    required bool hasGisinTransition,
    required bool hasYongsinTransition,
  }) {
    final base = transitionBondStrength.startsWith('신강주도')
        ? '전환이 다가올 때마다 스스로 방향을 정해 앞장서서 헤쳐나가는 방식이'
        : transitionBondStrength.startsWith('신강안정')
        ? '큰 변화가 없을 때는 차분히 힘을 쌓아두고, 전환기가 오면 그 힘을 발판으로 삼는 방식이'
        : transitionBondStrength.startsWith('신약격동')
        ? '전환이 다가올 때 혼자 감당하기보다 주변의 도움을 적극적으로 요청하는 방식이'
        : transitionBondStrength.startsWith('신약적응')
        ? '변화의 속도를 서두르지 않고 천천히 적응해 나가는 방식이'
        : '상황에 맞춰 전환기를 대하는 태도를 유연하게 조절하는 방식이';
    final gisinNote = hasGisinTransition ? ' 좋고, 특히 기신과 맞닿은 시기에는 중요한 결정을 미리 앞당기거나 뒤로 미루는 유연함이 필요' : ' 좋음';
    final yongsinNote = hasYongsinTransition ? ', 용신과 맞닿은 전환점에서는 새로운 도전을 적극적으로 시도해볼 만함' : '';
    return '$base$gisinNote$yongsinNote';
  }
}

class _TransitionInfo {
  const _TransitionInfo({
    required this.entry,
    required this.changeLevel,
    required this.direction,
    required this.label,
  });

  final DaewoonEntry entry;
  final String changeLevel;
  final String direction;
  final String label;
}
