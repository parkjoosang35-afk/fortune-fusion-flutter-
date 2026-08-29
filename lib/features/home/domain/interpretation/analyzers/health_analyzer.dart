/// [정통사주 69종 개인화 해석 엔진 — 5단계] A05 평생 건강운 Analyzer.
///
/// 레거시 `SajuInterpreter.interpretHealth()`가 오행 5개(목화토금수)를
/// 기계적으로 순회하며 "개수≥3이면 과다 경고, 개수=0이면 부재 경고"만
/// 생성하고, 신강신약·용신/기신·신살·대운을 전혀 참조하지 않던 방식을
/// 폐기한다. 대신 [SajuProfile]의 오행 편중(dominant/deficient)·
/// 신강신약(strength)·건강 관련 신살(양인/백호/육해/겁살)·용신/기신·
/// 대운을 A01/A03/A04와 동일한 설계 원칙으로 직접 조회해 건강 구조를
/// 매번 새로 판정한다(§4 "문장이 아니라 분석을 개인화").
///
/// 사용 데이터(§10 requiredData):
/// - 오행 과다/부족(fiveElements.dominant/deficient) — 어느 장기 계통이
///   취약한지(`five_elements_rules.json`의 organ/excess/lack 고정표 조회)
/// - 신강신약(strength) — 타고난 체력·회복력 그릇의 크기
/// - 신살(sinsal) — 양인살/백호대살/육해살/겁살 등 건강 리스크 신호
/// - 용신/기신(yongsin) — 건강이 좋아지는/나빠지는 오행 조건
/// - 대운(daewoon) — 건강 주의가 필요한 실제 시기
/// - 일간(dayPillar) — 부족 오행이 없을 때 일간 오행 기준 보양 음식 조회
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C/D그룹이 담당), 특정 질병명 진단(의학적 진단이 아니라 전통 명리학
/// 관점의 체질 경향 서술 — `DisclaimerTag.medical` 고지 대상).
library;

import '../../manseryeok/saju_profile.dart';
import '../../saju_engine.dart' show ganElement;
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'health_analysis.dart';

/// 오행(목화토금수)별 장기 계통 — `assets/jeontong/rules/
/// five_elements_rules.json`의 `organ` 필드를 그대로 옮긴 전통 고정표
/// (career_analyzer.dart의 `_careerFitByDayGan`와 동일한 성격 — 신규
/// 판정 공식이 아니라 이미 앱에 존재하는 전통 고정 데이터의 재사용).
/// [CategoryAnalyzer.analyze]는 동기 함수라 rootBundle의 비동기 asset
/// 로드를 쓸 수 없으므로 "고정표를 코드에 직접 선언"하는 기존 패턴을
/// 따른다.
const Map<String, List<String>> _organByElement = {
  '목': ['간', '담', '눈', '근육'],
  '화': ['심장', '소장', '혀', '혈액'],
  '토': ['비장', '위', '입', '살'],
  '금': ['폐', '대장', '코', '피부'],
  '수': ['신장', '방광', '귀', '뼈'],
};

/// 오행별 "과다시" 증상 — `five_elements_rules.json`의 `excess` 필드.
const Map<String, String> _excessSymptomByElement = {
  '목': '고집, 분노, 간·눈 질환, 자기중심적',
  '화': '다혈질, 성급함, 심혈관 질환, 불면',
  '토': '게으름, 살찜, 소화불량, 답답함',
  '금': '차가움, 냉정, 폐·피부 질환, 완벽주의',
  '수': '우울, 공포, 신장 질환, 냉증',
};

/// 오행별 "부족시" 증상 — `five_elements_rules.json`의 `lack` 필드.
const Map<String, String> _lackSymptomByElement = {
  '목': '우유부단, 결단력 부족, 근육 약함, 봄철 컨디션 저하',
  '화': '우울, 소심, 순환 장애, 겨울 취약',
  '토': '소화 약함, 근심, 신뢰 부족, 살 안 붙음',
  '금': '결단력 부족, 호흡기 약함, 우울',
  '수': '체력 저하, 정력 약함, 지구력 부족',
};

/// 오행별 보양 음식 — `five_elements_rules.json`의 `food_good` 필드.
const Map<String, List<String>> _goodFoodByElement = {
  '목': ['녹색 채소', '신맛 과일', '매실', '레몬'],
  '화': ['적색 식품', '쓴맛 음식', '토마토', '자몽'],
  '토': ['황색 식품', '단맛 음식', '단호박', '고구마'],
  '금': ['백색 식품', '매운맛 음식', '배', '무'],
  '수': ['흑색 식품', '짠맛 음식', '검은콩', '해조류'],
};

/// 건강 리스크와 직결되는 신살 nameKr 목록(sinsal_rules.json 전수조사
/// §11 결과 — 羊刃/白虎/六害/劫殺이 "수술·사고·지병·급변" 등 신체 리스크를
/// 명시하는 4종. sinsal_engine.dart가 실제로 계산하는 nameKr과 일치시킨다:
/// 양인살(羊刃), 백호대살(白虎), 육해살(12신살 중 하나), 겁살(12신살 중
/// 하나)).
const Set<String> _healthRiskSinsalNames = {'양인살', '백호대살', '육해살', '겁살'};

class HealthAnalyzer extends CategoryAnalyzer<HealthAnalysis> {
  const HealthAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A05',
    categoryPurpose: '평생에 걸친 타고난 체질의 편중 구조와 취약 장기 계통, 건강 리스크 신호를 분석',
    requiredData: ['오행 과다/부족', '신강신약', '신살(양인/백호/육해/겁살)', '용신/기신', '대운', '일간'],
    analysisRules: [
      '오행 dominant/deficient 개수 조합으로 체질 편중 구조(healthConstitutionPattern) 판정',
      '신강신약 × 오행 편중 여부 조합으로 체력·회복력 그릇의 크기(healthVitality) 판정',
      'dominant/deficient 오행을 organ 고정표에 매핑해 취약 장기 계통(vulnerableOrgans) 도출',
      '건강 관련 신살(양인/백호/육해/겁살) 존재 + 기신 오행 강도 조합으로 리스크(healthRiskPattern) 판정',
      '부족 오행(우선) 또는 일간 오행 기준 food_good 고정표에서 보양 음식(recommendedCare) 조회',
      '대운 목록에서 기신 오행을 포함하는 대운을 건강 주의 시기로 판정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '특정 질병명 진단(의학적 진단 아님)'],
    outputStructure: ['체질 편중 구조', '체력·회복력', '취약 장기', '리스크', '보양법', '주의 대운'],
  );

  @override
  HealthAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);

    // ── ① 오행 과다/부족 집계(원국 8글자 기준, PHASE2 계산값 그대로 조회) ──
    final fiveElements = profile.fiveElements;
    final dominantElements = fiveElements?.dominant ?? const [];
    final deficientElements = fiveElements?.deficient ?? const [];
    final isImbalanced = fiveElements?.isImbalanced ?? false;
    evidence.add(
      AnalysisEvidence(
        sourceField: 'fiveElements.dominant/deficient/isImbalanced',
        sourceValue:
            '과다=$dominantElements, 부족=$deficientElements, 편중=$isImbalanced',
        rule: '8글자 중 3개 이상이면 과다, 0개면 부족으로 판정(PHASE2 계산값)',
        judgment: isImbalanced ? '오행이 한쪽으로 편중된 구조' : '오행이 비교적 고르게 분포된 구조',
        interpretationRole: InterpretationRole.primary,
        weight: 0.9,
      ),
    );

    // ── ② 체질 편중 구조(healthConstitutionPattern) — dominant/deficient
    // 개수 "조합"을 하나의 유형으로 종합 판정(레거시처럼 오행별 경고
    // 문자열을 단순 나열하지 않음) ──
    final String healthConstitutionPattern;
    if (dominantElements.length >= 2 && deficientElements.length >= 2) {
      healthConstitutionPattern =
          '복합편중형 — 여러 오행이 과다·결핍으로 동시에 치우쳐 몸의 균형 관리가 특히 중요한 구조';
    } else if (dominantElements.length >= 2) {
      healthConstitutionPattern =
          '다중과다형 — 두 가지 이상의 기운이 함께 넘쳐 그 계통에 부담이 쌓이기 쉬운 구조';
    } else if (dominantElements.length == 1 && deficientElements.isNotEmpty) {
      healthConstitutionPattern =
          '단일편중형 — 특정 기운은 넘치고 다른 기운은 부족해 대비되는 두 계통을 함께 살펴야 하는 구조';
    } else if (dominantElements.length == 1) {
      healthConstitutionPattern = '단일과다형 — 하나의 기운이 두드러지게 강해 그 계통의 관리가 관건인 구조';
    } else if (deficientElements.length >= 2) {
      healthConstitutionPattern = '복합결핍형 — 두 가지 이상의 기운이 원국에 없어 보완이 필요한 구조';
    } else if (deficientElements.length == 1) {
      healthConstitutionPattern = '단일결핍형 — 특정 기운 하나가 원국에 없어 그 계통이 상대적으로 약한 구조';
    } else {
      healthConstitutionPattern = '오행균형형 — 다섯 기운이 고르게 갖춰져 있어 전반적으로 안정적인 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'dominantElements.length/deficientElements.length 조합',
        sourceValue:
            '과다개수=${dominantElements.length}, 부족개수=${deficientElements.length}',
        rule:
            '과다≥2&부족≥2→복합편중형 / 과다≥2→다중과다형 / 과다=1&부족≥1→단일편중형 / 과다=1→단일과다형 / '
            '부족≥2→복합결핍형 / 부족=1→단일결핍형 / 그외→오행균형형',
        judgment: healthConstitutionPattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ③ 신강신약 × 오행 편중 → 체력·회복력 그릇의 크기(healthVitality) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String healthVitality;
    if (strengthVerdict == '신강' && !isImbalanced) {
      healthVitality = '신강균형(身强均衡) — 타고난 체력이 좋고 오행도 고르게 갖춰 회복력이 뛰어난 편';
    } else if (strengthVerdict == '신강' && isImbalanced) {
      healthVitality = '신강편중(身强偏重) — 힘은 좋으나 특정 기운에 쏠려 있어 한쪽 계통에 무리가 가기 쉬움';
    } else if (strengthVerdict == '신약' && isImbalanced) {
      healthVitality = '신약편중(身弱偏重) — 체력 그릇 자체가 작은 데다 오행까지 치우쳐 있어 꾸준한 관리가 필요';
    } else if (strengthVerdict == '신약') {
      healthVitality = '신약보양(身弱補養) — 무리하기보다 충분한 휴식과 보양으로 체력을 채워가는 편이 유리';
    } else {
      healthVitality = '중화안정(中和安定) — 체력과 오행 모두 큰 치우침 없이 안정적인 편';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + fiveElements.isImbalanced',
          sourceValue: '$strengthVerdict, 편중=$isImbalanced',
          rule: '신강+균형→신강균형 / 신강+편중→신강편중 / 신약+편중→신약편중 / 신약→신약보양 / 중화→중화안정',
          judgment: healthVitality,
          interpretationRole: InterpretationRole.strength,
          weight: 0.85,
        ),
      );
    }

    // ── ④ 취약 장기 계통(vulnerableOrgans) — dominant/deficient 오행을
    // organ 고정표에 매핑(사람마다 dominant/deficient 오행 자체가 달라
    // 이 목록도 자연히 개인화된다) ──
    final vulnerableOrgans = <String>{
      for (final el in dominantElements) ..._organByElement[el] ?? const [],
      for (final el in deficientElements) ..._organByElement[el] ?? const [],
    }.toList();
    if (vulnerableOrgans.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField:
              'dominant/deficient → organ 고정표(five_elements_rules.json)',
          sourceValue:
              '과다오행=$dominantElements, 부족오행=$deficientElements → $vulnerableOrgans',
          rule: '과다·부족 오행 각각을 전통 오행-장기 대응표에 매핑',
          judgment: '${vulnerableOrgans.join(', ')} 계통을 특히 챙길 필요',
          interpretationRole: InterpretationRole.supporting,
          weight: 0.7,
        ),
      );
    }

    // ── §5 개인화 강화: 같은 healthConstitutionPattern이라도 실제로
    // "어느" 오행이 과다/부족인지, 그 오행의 excess/lack 증상 문구
    // 자체가 사람마다 달라진다는 것을 supportingEvidence로 기록 ──
    final supportingEvidence = <AnalysisEvidence>[
      AnalysisEvidence(
        sourceField: '과다 오행별 excess 증상(five_elements_rules.json)',
        sourceValue: dominantElements.isEmpty
            ? '없음'
            : dominantElements
                  .map((e) => '$e: ${_excessSymptomByElement[e]}')
                  .join(' / '),
        rule: '같은 healthConstitutionPattern이라도 실제 과다 오행 종류는 사람마다 다름(§5)',
        judgment: dominantElements.isEmpty
            ? '두드러지게 과다한 오행 없음'
            : '${dominantElements.join(', ')} 기운 과다에 따른 세부 증상 경향',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.45,
      ),
      AnalysisEvidence(
        sourceField: '부족 오행별 lack 증상(five_elements_rules.json)',
        sourceValue: deficientElements.isEmpty
            ? '없음'
            : deficientElements
                  .map((e) => '$e: ${_lackSymptomByElement[e]}')
                  .join(' / '),
        rule: '같은 healthConstitutionPattern이라도 실제 부족 오행 종류는 사람마다 다름(§5)',
        judgment: deficientElements.isEmpty
            ? '원국에 없는 오행 없음'
            : '${deficientElements.join(', ')} 기운 부족에 따른 세부 증상 경향',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.45,
      ),
    ];

    // ── ⑤ 건강 관련 신살(양인/백호/육해/겁살) — 실제 원국에서 발견된
    // 것만 채택(전통 고정표 대조, §16 "가짜 근거 금지"와 동일 원칙) ──
    final sinsalList = profile.sinsal ?? const [];
    final foundHealthSinsal = sinsalList
        .where(
          (s) =>
              _healthRiskSinsalNames.contains(s.nameKr) && s.foundOn.isNotEmpty,
        )
        .map((s) => s.nameKr)
        .toSet()
        .toList();
    if (foundHealthSinsal.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'sinsal(양인살/백호대살/육해살/겁살)',
          sourceValue: foundHealthSinsal.join(', '),
          rule: '원국에 실제로 발견된 건강 관련 신살만 채택(전통 고정표 대조)',
          judgment: '${foundHealthSinsal.join(', ')}(이)가 건강상 특이 신호로 작용',
          interpretationRole: InterpretationRole.caution,
          weight: 0.6,
        ),
      );
    }

    // ── ⑥ 기신 오행 강도(gisinCount) — 건강 리스크의 핵심 축 ──
    final gisinElement = profile.yongsin?.gisin ?? '';
    final gisinCount = q.gisinCount;
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    final yongsinRooted = q.yongsinRooted;

    // ── ⑦ 리스크(healthRiskPattern) — 건강신살 + 기신강도 + 편중을 종합 ──
    final riskParts = <String>[];
    if (foundHealthSinsal.isNotEmpty) {
      riskParts.add(
        '${foundHealthSinsal.join(', ')}이(가) 있어 급작스러운 사고·수술·지병에 대한 대비가 필요',
      );
    }
    if (gisinElement.isNotEmpty && gisinCount >= 2) {
      final gisinOrgan = _organByElement[gisinElement] ?? const [];
      riskParts.add(
        '기신인 $gisinElement 기운이 원국에 $gisinCount개나 있어 ${gisinOrgan.isNotEmpty ? gisinOrgan.join(', ') : gisinElement} 계통에 부담이 쌓이기 쉬움',
      );
    }
    if (isImbalanced && dominantElements.isNotEmpty) {
      riskParts.add(
        '${dominantElements.join(', ')} 기운이 과다해 해당 계통의 만성적인 부담에 유의',
      );
    }
    final healthRiskPattern = riskParts.isEmpty
        ? '두드러진 건강상 리스크 신호는 확인되지 않음'
        : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '건강신살 + 기신오행강도 + 오행편중 조합',
          sourceValue:
              '신살=$foundHealthSinsal, 기신=$gisinElement($gisinCount개), 편중=$isImbalanced',
          rule: '건강신살 존재 / 기신오행≥2개 / 오행과다 각각을 리스크 신호로 채택 후 종합',
          judgment: healthRiskPattern,
          interpretationRole: InterpretationRole.caution,
          weight: 0.75,
        ),
      );
    }

    // ── ⑧ 보양법(recommendedCare) — 부족 오행 우선, 없으면 일간 오행
    // 기준 food_good 고정표 조회 ──
    final dayGan = profile.dayPillar.stemHanja;
    final dayElement = ganElement[dayGan]?.$1 ?? q.dayElement;
    final careBaseElement = deficientElements.isNotEmpty
        ? deficientElements.first
        : dayElement;
    final recommendedCare = _goodFoodByElement[careBaseElement] ?? const [];
    if (recommendedCare.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField:
              '부족오행(우선) 또는 일간오행 → food_good 고정표(five_elements_rules.json)',
          sourceValue:
              '기준오행=$careBaseElement(${deficientElements.isNotEmpty ? "부족오행" : "일간오행"})',
          rule: '부족한 오행이 있으면 그 오행을 보충하는 음식을, 없으면 일간 오행에 맞는 음식을 조회',
          judgment: '${recommendedCare.join(', ')} 등을 챙기면 도움',
          interpretationRole: InterpretationRole.supporting,
          weight: 0.5,
        ),
      );
    }

    // ── ⑨ 건강 주의 대운(healthCautionDaewoonLabel) — PHASE4 실계산만
    // 사용, 기신 오행을 포함하는 첫 대운 채택 ──
    var healthCautionDaewoonLabel = '';
    final daewoonList = profile.daewoon ?? const [];
    for (final d in daewoonList) {
      if (gisinElement.isNotEmpty && q.daewoonCarriesElement(d, gisinElement)) {
        healthCautionDaewoonLabel =
            '${d.startAge}세(${d.startYear}년)부터 시작된 ${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운';
        break;
      }
    }
    if (healthCautionDaewoonLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산)',
          sourceValue: healthCautionDaewoonLabel,
          rule: '대운의 천간/지지 오행이 기신 오행을 포함하는 첫 대운 채택',
          judgment: '$healthCautionDaewoonLabel 시기에 건강 관리에 특히 유의할 필요',
          interpretationRole: InterpretationRole.timing,
          weight: 0.75,
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
    // 용신 뿌리 여부(§5 세부 근거) — 같은 healthVitality라도 용신이
    // 원국에 실제로 뿌리내렸는지는 사람마다 다름.
    if (yongsinElement.isNotEmpty) {
      supportingEvidence.add(
        AnalysisEvidence(
          sourceField: 'yongsinRooted(용신 오행의 원국 실재 여부)',
          sourceValue: '용신=$yongsinElement, 원국뿌리=$yongsinRooted',
          rule: '용신 오행이 원국(천간+지지 본기)에 실제로 있는지 조회(§5 세부 근거)',
          judgment: yongsinRooted
              ? '용신 $yongsinElement 기운이 원국에 뿌리내려 있어 회복 탄력성이 좋은 편'
              : '용신 $yongsinElement 기운이 원국에 없어 외부(대운 등)에서 보완이 필요',
          interpretationRole: InterpretationRole.supporting,
          weight: 0.4,
        ),
      );
    }

    // ── 좋은 흐름 / 주의 흐름 ──
    final favorable = <String>[
      if (yongsinElement.isNotEmpty) '$yongsinElement 기운을 보완하는 환경·습관·시기',
      if (recommendedCare.isNotEmpty)
        '${recommendedCare.take(3).join(', ')} 등으로 부족한 기운을 채우는 관리',
      if (!isImbalanced) '오행이 고르게 갖춰져 있어 무리하지 않으면 안정적으로 유지되는 체질',
    ];
    final caution = <String>[
      if (foundHealthSinsal.isNotEmpty)
        '${foundHealthSinsal.join(', ')} 신호에 따른 사고·수술·만성질환 예방',
      if (gisinElement.isNotEmpty && gisinCount >= 2)
        '$gisinElement 기운이 강해지는 환경·시기에 대한 절제',
      if (healthCautionDaewoonLabel.isNotEmpty)
        '$healthCautionDaewoonLabel 시기의 건강검진·컨디션 관리',
    ];
    if (favorable.isEmpty) favorable.add('현재의 체질을 안정적으로 유지하는 생활 습관');
    if (caution.isEmpty) caution.add('두드러진 건강상 리스크 신호는 확인되지 않음');

    final confidence =
        (profile.strength == null ||
            profile.yongsin == null ||
            fiveElements == null)
        ? AnalysisConfidence.low
        : (foundHealthSinsal.isEmpty && riskParts.isEmpty)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: 최종 판정에 실제로 쓰인 원시 수치 전체를
    // 개발자 검증용으로 남긴다 ──
    final interpretationContext = <String, String>{
      'dominantElements': dominantElements.join(','),
      'deficientElements': deficientElements.join(','),
      'isImbalanced': '$isImbalanced',
      'strengthVerdict': strengthVerdict,
      'yongsinElement': yongsinElement,
      'yongsinRooted': '$yongsinRooted',
      'gisinElement': gisinElement,
      'gisinCount': '$gisinCount',
      'foundHealthSinsal': foundHealthSinsal.join(','),
      'careBaseElement': careBaseElement,
      'dayGan': dayGan,
      'healthCautionDaewoonLabel': healthCautionDaewoonLabel,
    };

    return HealthAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 건강운',
      coreEvidence: evidence,
      supportingEvidence: supportingEvidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      healthConstitutionPattern: healthConstitutionPattern,
      healthVitality: healthVitality,
      vulnerableOrgans: vulnerableOrgans,
      healthRiskPattern: healthRiskPattern,
      recommendedCare: recommendedCare,
      healthCautionDaewoonLabel: healthCautionDaewoonLabel,
    );
  }
}
