/// [정통사주 69종 개인화 해석 엔진 — 4단계] A04 평생 직업·명예운 Analyzer.
///
/// 레거시 `SajuInterpreter.interpretCareer()`가 관성(정관+편관)/인성(정인+
/// 편인)/식상(식신+상관) 개수만으로 4개 고정 문장(관인상생/식상격/무관무인/
/// 혼합격) 중 하나를 골라 반환하던 방식을 폐기하고, [SajuProfile]의 십신
/// 분포·신강신약·용신/기신·대운을 A03(WealthAnalyzer)과 동일한 설계 원칙으로
/// 직접 조회해 직업 구조를 매번 새로 판정한다(§4 "문장이 아니라 분석을
/// 개인화").
///
/// 사용 데이터(§10 requiredData):
/// - 십신 7위치(tenGods) — 관살(정관/편관)·인성(정인/편인)·식상(식신/상관)·
///   비겁 개수
/// - 신강신약(strength) — 관살(직무·책임)을 감당할 그릇의 크기
/// - 용신/기신(yongsin) — 직업운이 좋아지는/나빠지는 조건
/// - 대운(daewoon) — 직업·명예가 정점에 이르는 실제 시기
/// - 일간(dayPillar) — `day_master_rules.json`의 career_fit 고정표 조회용
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C03/D02 등이 담당). 재물 그릇 크기 자체(A03이 담당, 단 재성/식상 조합은
/// 함께 조회해 careerPattern 세분화에 사용).
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'career_analysis.dart';

/// 일간(10천간)별 어울리는 직업 분야 — `assets/jeontong/rules/
/// day_master_rules.json`의 `career_fit` 필드를 그대로 옮긴 전통 고정표
/// (life_overall_analyzer.dart의 `_dayGanNature`와 동일한 성격 — 신규
/// 판정 공식이 아니라 이미 앱에 존재하는 전통 고정 데이터의 재사용).
/// [CategoryAnalyzer.analyze]는 동기 함수라 rootBundle의 비동기 asset 로드를
/// 쓸 수 없으므로, `saju_f_group_modules.dart`의 `_businessItemsByElement`가
/// 채택한 것과 동일한 "고정표를 코드에 직접 선언" 패턴을 따른다.
const Map<String, List<String>> _careerFitByDayGan = {
  '甲': ['창업가', '교육자', '건축가', '정치인', '임원', '농업·임업'],
  '乙': ['예술가', '디자이너', '상담가', '영업', '서비스업', '화훼·원예'],
  '丙': ['방송인', '정치인', 'CEO', '교육자', '예술가', '홍보'],
  '丁': ['연구원', '작가', '의사', '상담사', '종교인', 'IT 개발자'],
  '戊': ['부동산', '건설', '금융', '공무원', '관리자', '농업'],
  '己': ['교사', '간호', '회계', '요식업', '농업', '인사'],
  '庚': ['군인', '경찰', '법조', '스포츠', '제조업', '외과의'],
  '辛': ['디자이너', '보석세공', '의료', '법조', 'IT', '예술'],
  '壬': ['무역', '외교', '금융', 'IT', '물류', '학자'],
  '癸': ['작가', '예술가', '상담사', '종교', '요식업', '학자'],
};

class CareerAnalyzer extends CategoryAnalyzer<CareerAnalysis> {
  const CareerAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A04',
    categoryPurpose: '평생에 걸친 직업의 구조(조직/독립/전문성)와 명예운, 어울리는 분야를 분석',
    requiredData: ['십신 분포(관살/인성/식상/비겁)', '신강신약', '용신/기신', '대운', '일간'],
    analysisRules: [
      '관살+인성+식상 개수 조합으로 직업 구조(careerPattern) 판정',
      '신강신약 × 관살 개수 조합으로 직무·책임을 감당할 그릇의 크기(careerStrength) 판정',
      '인성 vs 식상 우세 비교로 조직형/독립형 등 일하는 방식(workStyle) 판정',
      '일간 오행 고정표(career_fit)에서 어울리는 분야(suitableFields) 조회',
      '상관견관/관살혼잡 등 조합으로 직업 리스크(careerRiskPattern) 판정',
      '대운 목록에서 관살 범주이거나 용신 오행을 포함하는 대운을 직업·명예 정점 시기로 판정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '재물 그릇 크기 자체(A03 담당)'],
    outputStructure: ['직업 구조', '그릇의 크기', '일하는 방식', '어울리는 분야', '리스크', '정점 대운'],
  );

  @override
  CareerAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);

    // ── ① 관살/인성/식상/비겁 개수 집계(원국 본기 + 지장간 포함) ──
    final categoryCounts = q.tenGodCategoryCounts(includeHiddenStems: true);
    final officerCount = categoryCounts['관살'] ?? 0;
    final printerCount = categoryCounts['인성'] ?? 0;
    final outputCount = categoryCounts['식상'] ?? 0;
    final biCount = categoryCounts['비겁'] ?? 0;
    final wealthCount = categoryCounts['재성'] ?? 0;
    evidence.add(
      AnalysisEvidence(
        sourceField: 'tenGods+hiddenStems(5대범주 집계)',
        sourceValue: categoryCounts.toString(),
        rule:
            '관살=$officerCount, 인성=$printerCount, 식상=$outputCount, 비겁=$biCount',
        judgment: '관살/인성/식상 조합을 기준으로 직업 구조 1차 판정',
        interpretationRole: InterpretationRole.primary,
        weight: 0.7,
      ),
    );

    // ── ② 직업 구조(careerPattern) — 레거시 4분류를 재성/식상까지
    // 포함해 세분화한다 ──
    final String careerPattern;
    if (officerCount >= 2 && printerCount >= 1) {
      careerPattern = '관인상생(官印相生) — 공직·조직 내 안정적 성장과 명예가 함께 따르는 구조';
    } else if (officerCount >= 2 && printerCount == 0 && biCount >= 1) {
      careerPattern = '살인상생 미비형(殺重身輕) — 책임·부담은 크나 이를 완충할 인성이 약해 스스로 버텨야 하는 구조';
    } else if (outputCount >= 2 && wealthCount >= 1) {
      careerPattern = '식상생재(食傷生財) — 재능·표현을 결과물로 연결해 수익을 만드는 구조';
    } else if (outputCount >= 2) {
      careerPattern = '식상격(食傷格) — 표현·창작·기획으로 자기 재능을 드러내는 구조';
    } else if (officerCount == 0 && printerCount == 0) {
      careerPattern = '무관무인(無官無印) — 조직보다 독립·자영업·전문가 노선이 잘 맞는 구조';
    } else if (officerCount >= 2 && printerCount >= 2) {
      careerPattern = '관인균형(官印均衡) — 조직 내 규율과 학문적 전문성을 함께 갖춘 구조';
    } else {
      careerPattern = '혼합형 — 조직과 독립 활동을 시기별로 병행할 수 있는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'officerCount/printerCount/outputCount/wealthCount 조합',
        sourceValue:
            '관살=$officerCount, 인성=$printerCount, 식상=$outputCount, 재성=$wealthCount',
        rule:
            '관살≥2&인성≥1→관인상생 / 관살≥2&인성=0&비겁≥1→살중신경 / 식상≥2&재성≥1→식상생재 / '
            '식상≥2→식상격 / 관살=0&인성=0→무관무인 / 관살≥2&인성≥2→관인균형 / 그외→혼합형',
        judgment: careerPattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ③ 신강신약 × 관살 개수 → 그릇의 크기(careerStrength) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String careerStrength;
    if (strengthVerdict == '신강' && officerCount >= 2) {
      careerStrength = '신강용관(身强用官) — 책임과 부담을 감당할 힘이 충분해 승진·요직에 유리';
    } else if (strengthVerdict == '신강' && officerCount <= 1) {
      careerStrength = '신강경관(身强輕官) — 힘은 있으나 관살이 적어 스스로 방향을 만들어야 하는 구조';
    } else if (strengthVerdict == '신약' && officerCount >= 2) {
      careerStrength = '관다신약(官多身弱) — 책임·업무가 많아 쉽게 지칠 수 있어 완급 조절이 중요';
    } else if (strengthVerdict == '신약') {
      careerStrength = '신약보좌(身弱補佐) — 혼자보다 좋은 조직·상사·동료의 도움을 받을 때 힘이 커짐';
    } else {
      careerStrength = '중화용관(中和用官) — 상황에 맞춰 유연하게 직무 강도를 조절할 수 있는 구조';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + 관살 개수',
          sourceValue: '$strengthVerdict, 관살=$officerCount',
          rule:
              '신강+관살많음→신강용관 / 신강+관살적음→신강경관 / 신약+관살많음→관다신약 / 신약→신약보좌 / 중화→중화용관',
          judgment: careerStrength,
          interpretationRole: InterpretationRole.strength,
          weight: 0.95,
        ),
      );
    }

    // ── ④ 인성 vs 식상 → 일하는 방식(workStyle) ──
    final String workStyle;
    if (printerCount > outputCount && officerCount >= 1) {
      workStyle = '조직형 — 체계와 규율이 있는 조직 안에서 안정적으로 성장하는 방식';
    } else if (outputCount > printerCount) {
      workStyle = '독립·창작형 — 스스로 기획하고 표현하며 성과를 만드는 방식';
    } else if (printerCount == 0 && outputCount == 0) {
      workStyle = '실무 중심형 — 이론보다 직접 부딪히며 배우고 성장하는 방식';
    } else {
      workStyle = '균형형 — 조직 생활과 독립적 활동을 함께 병행하는 방식';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: '인성/식상/관살 조합',
        sourceValue: '인성=$printerCount, 식상=$outputCount, 관살=$officerCount',
        rule: '인성>식상&관살≥1→조직형 / 식상>인성→독립창작형 / 인성=0&식상=0→실무중심형 / 그외→균형형',
        judgment: workStyle,
        interpretationRole: InterpretationRole.secondary,
        weight: 0.6,
      ),
    );

    // ── §5 개인화 강화: 관인상생 등 같은 careerPattern으로 묶이더라도
    // 사람마다 실제 관살/인성/식상/비겁 조성 비율이 다르다는 것을
    // supportingEvidence로 별도 기록 ──
    final supportingEvidence = <AnalysisEvidence>[
      AnalysisEvidence(
        sourceField: '관살/인성/식상/비겁/재성 세부 개수',
        sourceValue:
            '관살=$officerCount, 인성=$printerCount, 식상=$outputCount, 비겁=$biCount, 재성=$wealthCount',
        rule: '같은 careerPattern이라도 세부 조성 비율은 사람마다 다름(§5)',
        judgment: '관살:인성:식상 비율 $officerCount:$printerCount:$outputCount',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.4,
      ),
    ];

    // 정관 vs 편관 우세(A03의 정재/편재 대응) — 공직·정통 조직 vs 특수
    // 분야·개혁적 조직 성향 차이를 세부 근거로 기록.
    final jeongGwanCount = q
        .occurrencesOfCategory('관살', includeHiddenStems: true)
        .where((o) => o.tenGod == '정관')
        .length;
    final pyeonGwanCount = q
        .occurrencesOfCategory('관살', includeHiddenStems: true)
        .where((o) => o.tenGod == '편관')
        .length;
    supportingEvidence.add(
      AnalysisEvidence(
        sourceField: '정관/편관 occurrence 개수',
        sourceValue: '정관=$jeongGwanCount, 편관=$pyeonGwanCount',
        rule: '정관 우세=정통 조직·공직 성향, 편관 우세=특수분야·개혁적 조직 성향(§5 세부 근거)',
        judgment: jeongGwanCount > pyeonGwanCount
            ? '정관 우세($jeongGwanCount:$pyeonGwanCount) — 정통 조직·공직 성향'
            : pyeonGwanCount > jeongGwanCount
            ? '편관 우세($jeongGwanCount:$pyeonGwanCount) — 특수분야·개혁적 조직 성향'
            : '정관·편관 균형($jeongGwanCount:$pyeonGwanCount)',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.35,
      ),
    );

    // ── ⑤ 어울리는 분야(suitableFields) — 일간 고정표 조회 ──
    final dayGan = profile.dayPillar.stemHanja;
    final suitableFields = _careerFitByDayGan[dayGan] ?? const [];
    if (suitableFields.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'dayPillar.stemHanja → career_fit 고정표',
          sourceValue: '$dayGan(${profile.dayPillar.stemKr})',
          rule: '일간 10천간별 전통 직업 적성 고정표 조회(day_master_rules.json)',
          judgment: '${suitableFields.join(', ')} 분야와 잘 맞는 기질',
          interpretationRole: InterpretationRole.supporting,
          weight: 0.5,
        ),
      );
    }

    // ── ⑥ 리스크(careerRiskPattern): 상관견관 + 관살혼잡 + 무관무인 ──
    final sangGwanCount = q
        .occurrencesOfCategory('식상', includeHiddenStems: true)
        .where((o) => o.tenGod == '상관')
        .length;
    final gisin = profile.yongsin?.gisin ?? '';
    final riskParts = <String>[];
    if (sangGwanCount >= 1 && officerCount >= 1) {
      riskParts.add('상관과 관살이 함께 있어(상관견관) 상사·조직과의 마찰이나 구설에 주의가 필요');
    }
    if (jeongGwanCount >= 1 && pyeonGwanCount >= 1) {
      riskParts.add('정관·편관이 혼재해(관살혼잡) 진로 방향이 자주 흔들릴 수 있음');
    }
    if (officerCount == 0 && printerCount == 0 && strengthVerdict == '신약') {
      riskParts.add('관살·인성이 모두 없고 힘도 약해 조직 안착에 시간이 걸릴 수 있음');
    }
    final careerRiskPattern = riskParts.isEmpty
        ? '두드러진 직업상 리스크 신호는 확인되지 않음'
        : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '상관+관살 / 정관+편관 혼재 / 무관무인+신약 조합',
          sourceValue:
              '상관=$sangGwanCount, 정관=$jeongGwanCount, 편관=$pyeonGwanCount, 신강신약=$strengthVerdict',
          rule: '상관≥1&관살≥1→상관견관 / 정관·편관 모두≥1→관살혼잡 / 관살=0&인성=0&신약→조직안착지연',
          judgment: careerRiskPattern,
          interpretationRole: InterpretationRole.caution,
          weight: 0.7,
        ),
      );
    }

    // ── ⑦ 직업·명예 정점 대운(careerPeakDaewoonLabel) — PHASE4
    // 실계산만 사용 ──
    var careerPeakDaewoonLabel = '';
    final daewoonList = profile.daewoon ?? const [];
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    for (final d in daewoonList) {
      final matchesCategory = q.daewoonMatchesCategory(d, '관살');
      final carriesYongsin =
          yongsinElement.isNotEmpty &&
          q.daewoonCarriesElement(d, yongsinElement);
      if (matchesCategory || carriesYongsin) {
        careerPeakDaewoonLabel =
            '${d.startAge}세(${d.startYear}년)부터 시작된 ${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운';
        break;
      }
    }
    if (careerPeakDaewoonLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산)',
          sourceValue: careerPeakDaewoonLabel,
          rule: '대운의 천간/지지 십신이 관살 범주이거나 용신 오행을 포함하는 첫 대운 채택',
          judgment: '$careerPeakDaewoonLabel 시기에 직업·명예운이 가장 활발해질 가능성',
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
      if (suitableFields.isNotEmpty)
        '${suitableFields.take(3).join(', ')} 분야에서 강점을 살릴 수 있는 환경',
      if (careerPeakDaewoonLabel.isNotEmpty) '$careerPeakDaewoonLabel 시기',
      if (yongsinElement.isNotEmpty) '$yongsinElement 기운이 강해지는 조직·역할',
    ];
    final caution = <String>[
      if (sangGwanCount >= 1 && officerCount >= 1) '상사·조직과의 의견 충돌에 대한 신중한 대응',
      if (jeongGwanCount >= 1 && pyeonGwanCount >= 1)
        '한 방향을 정하지 못하고 진로를 자주 바꾸는 것',
      if (officerCount == 0 && printerCount == 0)
        '조직 규율에 억지로 맞추려는 시도보다 독립적 노선 모색',
    ];
    if (favorable.isEmpty) favorable.add('현재의 직업 구조를 안정적으로 유지하는 환경');
    if (caution.isEmpty) caution.add('두드러진 직업상 리스크 신호는 확인되지 않음');

    final confidence = (profile.strength == null || profile.yongsin == null)
        ? AnalysisConfidence.low
        : (careerPeakDaewoonLabel.isEmpty && riskParts.isEmpty)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: 최종 판정에 실제로 쓰인 원시 수치 전체를
    // 개발자 검증용으로 남긴다 ──
    final interpretationContext = <String, String>{
      'officerCount': '$officerCount',
      'printerCount': '$printerCount',
      'outputCount': '$outputCount',
      'biCount': '$biCount',
      'wealthCount': '$wealthCount',
      'jeongGwanCount': '$jeongGwanCount',
      'pyeonGwanCount': '$pyeonGwanCount',
      'sangGwanCount': '$sangGwanCount',
      'strengthVerdict': strengthVerdict,
      'yongsinElement': yongsinElement,
      'gisinElement': gisin,
      'dayGan': dayGan,
      'careerPeakDaewoonLabel': careerPeakDaewoonLabel,
    };

    return CareerAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 직업·명예운',
      coreEvidence: evidence,
      supportingEvidence: supportingEvidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      careerPattern: careerPattern,
      careerStrength: careerStrength,
      workStyle: workStyle,
      suitableFields: suitableFields,
      careerRiskPattern: careerRiskPattern,
      careerPeakDaewoonLabel: careerPeakDaewoonLabel,
    );
  }
}
