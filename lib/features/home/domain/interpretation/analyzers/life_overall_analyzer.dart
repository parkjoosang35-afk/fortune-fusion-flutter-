/// [정통사주 69종 개인화 해석 엔진 — 2단계] A01 평생총운 Analyzer.
///
/// 사용자 최종 지시 §23/§24에 따라 가장 먼저 완성해야 하는 "기준 모델".
/// §4 "문장을 개인화하는 것이 아니라 분석을 개인화한다"에 따라, 아래
/// 순서로 실제 [SajuProfile] 데이터를 종합해 먼저 구조화된 판단을
/// 내리고, 그 판단의 근거를 [AnalysisEvidence]로 하나하나 기록한다.
///
/// 사용 데이터(§10 requiredData):
/// - 일간(dayPillar) 오행/음양 — 타고난 기본 성향의 뿌리
/// - 십신 7개 위치(tenGods) + 지장간 십신(hiddenStems) — 어떤 기운이
///   삶 전반에서 가장 강하게 반복되는지(중심 기운)
/// - 신강신약(strength) — 스스로 밀어붙이는 힘 vs 주변 도움이 필요한 힘
/// - 용신/기신(yongsin) — 삶이 편해지는 조건 vs 힘들어지는 조건
/// - 오행 과다/부족(fiveElements) — 타고난 기운의 편중
/// - 신살(sinsal) — 특이 기운(천을귀인/괴강살/양인살 등)
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(오늘·올해 단위 -
/// A01은 "평생" 관점이므로 특정 연도 단위 흐름은 다루지 않는다. 그 역할은
/// B/C/D 그룹 카테고리가 담당한다).
library;

import '../../manseryeok/saju_profile.dart';
import '../../manseryeok/strength_engine.dart' show tenGodCategoryOf;
import '../../saju_engine.dart' show ganElement;
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import 'life_overall_analysis.dart';

/// 일간(10천간) 고유의 타고난 기본 성향 — 명리학 문헌에서 통용되는
/// 갑을병정무기경신임계 10천간의 보편적 상징을 서술한 고정표
/// (assets/jeontong/rules/day_master_rules.json의 'nature' 필드와 같은
/// 성격의 전통 고정 지식이며, 개인별 랜덤 요소가 없다 — sinsal_engine.dart
/// 등이 이미 채택한 "전통 고정표를 코드에 직접 선언"하는 패턴을 따른다).
const Map<String, String> _dayGanNature = {
  '甲': '큰 나무처럼 곧게 뻗어나가려는 기운 — 리더십과 주관이 뚜렷함',
  '乙': '풀·덩굴처럼 부드럽게 감기며 자라는 기운 — 유연함과 생명력이 강함',
  '丙': '태양처럼 밝고 뜨겁게 드러나는 기운 — 표현력과 열정이 강함',
  '丁': '촛불·별빛처럼 은은하게 밝히는 기운 — 섬세함과 배려심이 강함',
  '戊': '큰 산처럼 묵직하게 자리를 지키는 기운 — 신뢰감과 포용력이 강함',
  '己': '넓은 들판처럼 만물을 품는 기운 — 온화함과 중재력이 강함',
  '庚': '무쇠·바위처럼 단단하고 결단력 있는 기운 — 추진력과 의리가 강함',
  '辛': '보석·칼날처럼 정교하고 예리한 기운 — 섬세함과 미적 감각이 강함',
  '壬': '큰 강·바다처럼 넓게 흐르는 기운 — 포용력과 지혜가 강함',
  '癸': '이슬·빗물처럼 조용히 스며드는 기운 — 섬세함과 통찰력이 강함',
};

class LifeOverallAnalyzer extends CategoryAnalyzer<LifeOverallAnalysis> {
  const LifeOverallAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A01',
    categoryPurpose: '평생에 걸쳐 반복되는 중심 기운과 타고난 성향 전체 구조를 분석',
    requiredData: ['일간', '십신 분포', '신강신약', '용신/기신', '오행 과다·부족', '신살'],
    analysisRules: [
      '십신 7개 위치를 5대 범주(비겁/식상/재성/관살/인성)로 집계해 가장 많은 범주를 중심 기운으로 판정',
      '일간 오행 고정표로 타고난 기본 성향 서술',
      '신강신약 판정으로 스스로 밀어붙이는 힘/주변 도움이 필요한 힘 판정',
      '용신 오행이 살아나는 조건을 좋은 흐름으로, 기신 오행이 강해지는 조건을 주의 흐름으로 매핑',
      '오행 부족/신살 존재 여부로 신뢰도(confidence) 조정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '오늘 일진'],
    outputStructure: [
      '중심 기운',
      '인생 테마',
      '타고난 성향',
      '강점',
      '약점',
      '좋은 흐름',
      '주의 흐름',
      '종합결론',
    ],
  );

  @override
  LifeOverallAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];

    final dayGan = profile.dayPillar.stemHanja;
    final dayElement = ganElement[dayGan]!.$1;
    final dayYinYang = ganElement[dayGan]!.$2;
    evidence.add(
      AnalysisEvidence(
        sourceField: 'dayPillar.stemHanja',
        sourceValue: '$dayGan(${profile.dayPillar.stemKr})',
        rule: '일간 오행/음양 고정표 조회',
        judgment: '$dayElement 기운, $dayYinYang의 성질',
        interpretationRole: InterpretationRole.primary,
        weight: 0.9,
      ),
    );

    // ── ① 중심 기운(십신 5대 범주 집계) ──
    final categoryCount = <String, int>{
      '비겁': 0,
      '식상': 0,
      '재성': 0,
      '관살': 0,
      '인성': 0,
    };
    final tenGods = profile.tenGods;
    if (tenGods != null) {
      for (final g in tenGods.values) {
        final cat = tenGodCategoryOf(g);
        if (categoryCount.containsKey(cat))
          categoryCount[cat] = categoryCount[cat]! + 1;
      }
    }
    final hiddenStems = profile.hiddenStems;
    if (hiddenStems != null) {
      for (final entry in hiddenStems.values) {
        for (final d in entry.stems) {
          final cat = tenGodCategoryOf(d.tenGod);
          if (categoryCount.containsKey(cat))
            categoryCount[cat] = categoryCount[cat]! + 1;
        }
      }
    }
    var dominantCategory = '균형';
    var dominantCount = 0;
    for (final e in categoryCount.entries) {
      if (e.value > dominantCount) {
        dominantCount = e.value;
        dominantCategory = e.key;
      }
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'tenGods + hiddenStems(십신 7위치+지장간)',
        sourceValue: categoryCount.toString(),
        rule: '십신을 5대 범주로 집계해 최다 범주를 중심 기운으로 판정',
        judgment: dominantCount > 0
            ? '$dominantCategory 중심 ($dominantCount회)'
            : '특정 기운으로 치우치지 않은 균형형',
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ② 신강신약 ──
    final strength = profile.strength;
    final strengthVerdict = strength?.verdict ?? '중화';
    if (strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict/score',
          sourceValue:
              '${strength.verdict}(score=${strength.score.toStringAsFixed(2)})',
          rule: 'score≥0.6 신강 / score≤0.4 신약 / 그 사이 중화',
          judgment: strengthVerdict == '신강'
              ? '스스로의 힘으로 밀어붙이는 추진력이 강함'
              : strengthVerdict == '신약'
              ? '주변 환경·사람의 도움을 받을 때 힘이 커짐'
              : '상황에 따라 유연하게 대응하는 균형감',
          interpretationRole: InterpretationRole.strength,
          weight: 0.85,
        ),
      );
    }

    // ── ③ 용신/기신 ──
    final yongsin = profile.yongsin;
    final yongsinElement = yongsin?.yongsin ?? '';
    final gisinElement = yongsin?.gisin ?? '';
    if (yongsin != null && yongsinElement.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'yongsin.yongsin/gisin',
          sourceValue: '용신=$yongsinElement, 기신=$gisinElement',
          rule: yongsin.reasoning,
          judgment:
              '$yongsinElement 기운이 살아날 때 삶이 편해지고, $gisinElement 기운이 강해질 때 힘들어짐',
          interpretationRole: InterpretationRole.primary,
          weight: 0.95,
        ),
      );
    }

    // ── ④ 오행 과다/부족 ──
    final fiveElements = profile.fiveElements;
    final dominantElements = fiveElements?.dominant ?? const [];
    final deficientElements = fiveElements?.deficient ?? const [];
    if (fiveElements != null && fiveElements.isImbalanced) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'fiveElements.dominant/deficient',
          sourceValue: '과다=$dominantElements, 부족=$deficientElements',
          rule: '8글자 중 3개 이상이면 과다, 0개면 부족으로 판정',
          judgment: dominantElements.isNotEmpty && deficientElements.isNotEmpty
              ? '$dominantElements 기운은 넘치고 $deficientElements 기운은 부족한 편중 구조'
              : dominantElements.isNotEmpty
              ? '$dominantElements 기운이 두드러지게 강한 구조'
              : '$deficientElements 기운이 원국에 없는 구조',
          interpretationRole: InterpretationRole.supporting,
          weight: 0.6,
        ),
      );
    }

    // ── ⑤ 신살 ──
    final sinsalList = profile.sinsal ?? const [];
    final notableSinsal = sinsalList
        .where((s) => s.foundOn.isNotEmpty)
        .map((s) => s.nameKr)
        .toSet()
        .toList();
    if (notableSinsal.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'sinsal',
          sourceValue: notableSinsal.join(', '),
          rule: '원국에 실제로 발견된 신살만 채택(전통 고정표 대조)',
          judgment: '${notableSinsal.join(', ')}(이)가 인생의 특이 기운으로 작용',
          interpretationRole: InterpretationRole.supporting,
          weight: 0.5,
        ),
      );
    }

    // ── 종합: 인생 테마 ──
    final lifeTheme = _buildLifeTheme(
      dayElement: dayElement,
      dominantCategory: dominantCategory,
      strengthVerdict: strengthVerdict,
    );

    // ── 좋은 흐름/주의 흐름 ──
    final favorable = <String>[];
    final caution = <String>[];
    if (yongsinElement.isNotEmpty) {
      favorable.add('$yongsinElement 기운이 강해지는 시기·환경·관계');
    }
    if (dominantCategory != '균형') {
      favorable.add('$dominantCategory 기운을 살릴 수 있는 활동·역할');
    }
    if (gisinElement.isNotEmpty) {
      caution.add('$gisinElement 기운이 지나치게 강해지는 시기·환경');
    }
    if (deficientElements.isNotEmpty) {
      caution.add('${deficientElements.join(', ')} 기운이 필요한 상황에서의 대비 부족');
    }
    if (favorable.isEmpty) favorable.add('원국의 중심 기운이 안정적으로 유지되는 환경');
    if (caution.isEmpty) caution.add('특별히 두드러진 위험 신호는 확인되지 않음');

    // ── 강점/약점(결과 페이지 ③ 재료) ──
    final strengths = <String>[
      _dayGanNature[dayGan] ?? '고유한 타고난 기운',
      if (strengthVerdict == '신강') '스스로 결정하고 추진하는 힘',
      if (strengthVerdict == '신약') '주변 도움을 잘 받아들이는 유연함',
      if (dominantCategory != '균형') '$dominantCategory 관련 재능·성향',
    ];
    final weaknesses = <String>[
      if (gisinElement.isNotEmpty) '$gisinElement 기운이 강해질 때 나타나는 불균형',
      if (deficientElements.isNotEmpty)
        '${deficientElements.join(', ')} 기운 부족으로 인한 취약점',
      if (dominantElements.length >= 2) '여러 오행이 한쪽으로 몰려 있어 생기는 편중',
    ];
    if (weaknesses.isEmpty) weaknesses.add('두드러진 약점보다는 전반적으로 균형 잡힌 구조');

    // ── 신뢰도: 근거가 빈약하면 낮춘다(§15 억지 개인화 금지의 반대편 —
    // 근거 부족을 숨기지 않고 명시적으로 낮은 신뢰도로 표시) ──
    final confidence = (strength == null || yongsin == null)
        ? AnalysisConfidence.low
        : (notableSinsal.isEmpty && !((fiveElements?.isImbalanced) ?? false))
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: "왜 이런 결과가 나왔는가"를 개발자가 즉시
    // 확인할 수 있도록 이 판정에 실제로 쓰인 원시 수치를 남긴다(사용자
    // 노출용이 아니라 100명 검증 테스트가 "같은 dominantCategory라도
    // 내부 수치가 다른지"를 비교할 근거) ──
    final interpretationContext = <String, String>{
      'dayGan': dayGan,
      'dayElement': dayElement,
      'categoryCount': categoryCount.toString(),
      'dominantCategory': dominantCategory,
      'dominantCount': '$dominantCount',
      'strengthVerdict': strengthVerdict,
      'strengthScore': strength?.score.toStringAsFixed(3) ?? '',
      'yongsinElement': yongsinElement,
      'gisinElement': gisinElement,
      'dominantElements': dominantElements.join(','),
      'deficientElements': deficientElements.join(','),
      'notableSinsal': notableSinsal.join(','),
    };

    return LifeOverallAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 총운',
      coreEvidence: evidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null, // A01은 세운/월운 무관 카테고리(§10 excludedData).
      confidence: confidence,
      dominantTenGodCategory: dominantCategory,
      lifeTheme: lifeTheme,
      coreNatureDescription: _dayGanNature[dayGan] ?? '고유한 타고난 기운을 지님',
      notableSinsal: notableSinsal,
      dominantElements: dominantElements,
      deficientElements: deficientElements,
      strengthVerdict: strengthVerdict,
      yongsinElement: yongsinElement,
      gisinElement: gisinElement,
      strengths: strengths,
      weaknesses: weaknesses,
    );
  }

  String _buildLifeTheme({
    required String dayElement,
    required String dominantCategory,
    required String strengthVerdict,
  }) {
    const categoryTheme = {
      '비겁': '스스로의 힘과 동료·경쟁 속에서 성장하는 삶',
      '식상': '재능과 표현으로 길을 만들어가는 삶',
      '재성': '활동과 성과를 통해 결실을 쌓아가는 삶',
      '관살': '책임과 시련 속에서 단단해지는 삶',
      '인성': '배움과 인복을 바탕으로 넓어지는 삶',
      '균형': '여러 기운이 고르게 어우러지는 삶',
    };
    final theme = categoryTheme[dominantCategory] ?? '다채로운 흐름의 삶';
    final strengthNote = strengthVerdict == '신강'
        ? '스스로 주도하며'
        : strengthVerdict == '신약'
        ? '주변과 함께하며'
        : '유연하게 균형을 잡으며';
    return '$dayElement 기운을 타고나 $strengthNote $theme';
  }
}
