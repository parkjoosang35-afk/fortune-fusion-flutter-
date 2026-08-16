/// [정통사주 69종 개인화 해석 엔진 — 3단계] A03 평생재물운 Analyzer.
///
/// 사용자 최종 지시 §23 "3단계"에 대응. 레거시 `getLifeWealth()`가
/// `interp.wealthFortune.verdict` 문자열 하나로 5개짜리 고정 테이블
/// (`_assetStyleByVerdict`)을 룩업하던 방식을 폐기하고, [SajuProfile]의
/// 십신 분포·신강신약·용신/기신·대운을 직접 계산해 재물 구조를 매번
/// 새로 판정한다(§4 "문장이 아니라 분석을 개인화").
///
/// 사용 데이터(§10 requiredData):
/// - 십신 7위치(tenGods) — 재성(정재/편재) 개수, 겁재 개수
/// - 신강신약(strength) — 재물을 감당할 그릇의 크기
/// - 용신/기신(yongsin) — 재물이 좋아지는/나빠지는 조건
/// - 대운(daewoon) — 재물이 정점에 이르는 실제 시기
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C02/D04 등이 담당). 건강/직업 관련 신살(A05/A04가 담당).
library;

import '../../manseryeok/saju_profile.dart';
import '../../saju_engine.dart' show ke;
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'wealth_analysis.dart';

class WealthAnalyzer extends CategoryAnalyzer<WealthAnalysis> {
  const WealthAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A03',
    categoryPurpose: '평생에 걸친 재물의 구조(정재/편재 비중)와 그릇의 크기, 리스크를 분석',
    requiredData: ['십신 분포(재성/비겁)', '신강신약', '용신/기신', '대운'],
    analysisRules: [
      '정재+편재 개수와 정관+편관/정인+편인 개수를 조합해 재물 구조(wealthPattern) 판정',
      '신강신약 × 재성 개수 조합으로 재물을 감당할 그릇의 크기(wealthStrength) 판정',
      '정재 vs 편재 우세 비교로 고정수입형/유동수입형(incomePattern) 판정',
      '겁재 개수 및 기신이 재성인지 여부로 재물 리스크(riskPattern) 판정',
      '대운 목록에서 재성 범주이거나 용신 오행을 포함하는 대운을 재물 정점 시기로 판정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '건강 관련 신살'],
    outputStructure: ['재물 구조', '그릇의 크기', '수입 패턴', '리스크', '자산 운용 스타일', '정점 대운'],
  );

  @override
  WealthAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);

    // ── ① 재성/비겁/인성 개수 집계(원국 본기 + 지장간 포함) ──
    final categoryCounts = q.tenGodCategoryCounts(includeHiddenStems: true);
    final wealthCount = categoryCounts['재성'] ?? 0;
    final officerCount = categoryCounts['관살'] ?? 0;
    final printerCount = categoryCounts['인성'] ?? 0;
    final biCount = categoryCounts['비겁'] ?? 0;
    evidence.add(
      AnalysisEvidence(
        sourceField: 'tenGods+hiddenStems(5대범주 집계)',
        sourceValue: categoryCounts.toString(),
        rule: '재성=$wealthCount, 관살=$officerCount, 인성=$printerCount, 비겁=$biCount',
        judgment: '재성 개수를 기준으로 재물 구조 1차 판정',
      ),
    );

    // ── ② 재물 구조(wealthPattern) ──
    final String wealthPattern;
    if (wealthCount >= 2 && officerCount >= 1) {
      wealthPattern = '재관쌍미(財官雙美) — 재물과 명예가 함께 따르는 구조';
    } else if (wealthCount >= 2 && printerCount == 0) {
      wealthPattern = '재성 편중 — 재물 활동은 활발하나 관리·저축 기능이 약한 구조';
    } else if (wealthCount == 0 && printerCount >= 2) {
      wealthPattern = '인다무재(印多無財) — 재물보다 명예·학문에 강점이 있는 구조';
    } else if (wealthCount == 0) {
      wealthPattern = '무재격(無財格) — 재물 자체보다 기술·자격·지식으로 성과를 내는 구조';
    } else {
      wealthPattern = '균형형 — 재성이 다른 범주와 고르게 섞인 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'wealthCount/officerCount/printerCount 조합',
        sourceValue: '재성=$wealthCount, 관살=$officerCount, 인성=$printerCount',
        rule: '재성≥2&관살≥1→재관쌍미 / 재성≥2&인성=0→재성편중 / 재성=0&인성≥2→인다무재 / 재성=0→무재격 / 그외→균형형',
        judgment: wealthPattern,
      ),
    );

    // ── ③ 신강신약 × 재성 개수 → 그릇의 크기(wealthStrength) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String wealthStrength;
    if (strengthVerdict == '신강' && wealthCount >= 2) {
      wealthStrength = '재왕신강(財旺身强) — 재물을 다스릴 힘이 충분해 사업 확장에 유리';
    } else if (strengthVerdict == '신강' && wealthCount <= 1) {
      wealthStrength = '신강용재(身强用財) — 힘은 있으나 재성이 적어 재물 활용 여지가 남는 구조';
    } else if (strengthVerdict == '신약' && wealthCount >= 2) {
      wealthStrength = '재다신약(財多身弱) — 재물 기회는 많으나 감당할 힘이 부족해 무리한 확장은 위험';
    } else if (strengthVerdict == '신약') {
      wealthStrength = '재약신약(財弱身弱) — 큰 재물보다 안정적으로 지키는 쪽이 유리';
    } else {
      wealthStrength = '중화용재(中和用財) — 상황에 맞춰 유연하게 재물을 운용할 수 있는 구조';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + 재성 개수',
          sourceValue: '$strengthVerdict, 재성=$wealthCount',
          rule: '신강+재성많음→재왕신강 / 신강+재성적음→신강용재 / 신약+재성많음→재다신약 / 신약→재약신약 / 중화→중화용재',
          judgment: wealthStrength,
        ),
      );
    }

    // ── ④ 정재 vs 편재 → 수입 패턴(incomePattern) ──
    final jeongjaeCount = q
        .occurrencesOfCategory('재성', includeHiddenStems: true)
        .where((o) => o.tenGod == '정재')
        .length;
    final pyeonjaeCount = q
        .occurrencesOfCategory('재성', includeHiddenStems: true)
        .where((o) => o.tenGod == '편재')
        .length;
    final String incomePattern;
    if (jeongjaeCount > pyeonjaeCount) {
      incomePattern = '정재 우세 — 월급·정기수입처럼 예측 가능한 고정 수입 구조';
    } else if (pyeonjaeCount > jeongjaeCount) {
      incomePattern = '편재 우세 — 사업·투자처럼 변동성이 크지만 기회가 많은 유동 수입 구조';
    } else if (jeongjaeCount == 0 && pyeonjaeCount == 0) {
      incomePattern = '재성 부재 — 정기수입보다 재능·자격 기반의 비정형 수입 구조';
    } else {
      incomePattern = '정재·편재 균형 — 고정 수입과 유동 수입을 함께 갖춘 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: '정재/편재 occurrence 개수',
        sourceValue: '정재=$jeongjaeCount, 편재=$pyeonjaeCount',
        rule: '정재>편재→정재우세 / 편재>정재→편재우세 / 둘다0→재성부재 / 동률→균형',
        judgment: incomePattern,
      ),
    );

    // ── ⑤ 리스크(riskPattern): 겁재 개수 + 기신=재성 여부 ──
    final gyeopjaeCount = q
        .occurrencesOfCategory('비겁', includeHiddenStems: true)
        .where((o) => o.tenGod == '겁재')
        .length;
    final gisin = profile.yongsin?.gisin ?? '';
    final wealthElement = jeongjaeCount + pyeonjaeCount > 0 ? _wealthElementOf(q) : '';
    final gisinIsWealth = gisin.isNotEmpty && wealthElement.isNotEmpty && gisin == wealthElement;
    final riskParts = <String>[];
    if (gyeopjaeCount >= 2) {
      riskParts.add('겁재가 $gyeopjaeCount개로 많아 동업·보증·투자 동참에서 재물이 새어나갈 위험');
    }
    if (gisinIsWealth) {
      riskParts.add('기신이 재성 오행($gisin)과 겹쳐, 재물 욕심이 과할 때 오히려 손실로 이어지기 쉬움');
    }
    final riskPattern = riskParts.isEmpty
        ? '두드러진 재물 리스크 신호는 확인되지 않음'
        : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '겁재 개수 + yongsin.gisin vs 재성오행',
          sourceValue: '겁재=$gyeopjaeCount, 기신=$gisin, 재성오행=$wealthElement',
          rule: '겁재≥2 또는 기신=재성오행이면 리스크 서술 추가',
          judgment: riskPattern,
        ),
      );
    }

    // ── ⑥ 자산 운용 스타일(assetManagementStyle) ──
    final assetManagementStyle = _buildAssetStyle(
      wealthStrength: wealthStrength,
      incomePattern: incomePattern,
      gyeopjaeCount: gyeopjaeCount,
    );

    // ── ⑦ 재물 정점 대운(wealthPeakDaewoonLabel) — PHASE4 실계산만 사용 ──
    var wealthPeakDaewoonLabel = '';
    final daewoonList = profile.daewoon ?? const [];
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    for (final d in daewoonList) {
      final matchesCategory = q.daewoonMatchesCategory(d, '재성');
      final carriesYongsin = yongsinElement.isNotEmpty && q.daewoonCarriesElement(d, yongsinElement);
      if (matchesCategory || carriesYongsin) {
        wealthPeakDaewoonLabel =
            '${d.startAge}세(${d.startYear}년)부터 시작된 ${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운';
        break;
      }
    }
    if (wealthPeakDaewoonLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산)',
          sourceValue: wealthPeakDaewoonLabel,
          rule: '대운의 천간/지지 십신이 재성 범주이거나 용신 오행을 포함하는 첫 대운 채택',
          judgment: '$wealthPeakDaewoonLabel 시기에 재물운이 가장 활발해질 가능성',
        ),
      );
    }

    // ── 좋은 흐름 / 주의 흐름 ──
    final favorable = <String>[
      if (jeongjaeCount + pyeonjaeCount > 0) '$incomePattern 성향을 살릴 수 있는 환경',
      if (wealthPeakDaewoonLabel.isNotEmpty) '$wealthPeakDaewoonLabel 시기',
      if (yongsinElement.isNotEmpty) '$yongsinElement 기운이 강해지는 시기·투자처',
    ];
    final caution = <String>[
      if (gyeopjaeCount >= 2) '동업·보증·공동투자에 대한 신중한 접근',
      if (gisinIsWealth) '욕심을 앞세운 무리한 투자·확장',
      if (wealthCount == 0) '단기간에 큰 재물을 노리는 시도보다 꾸준한 축적',
    ];
    if (favorable.isEmpty) favorable.add('현재의 재물 구조를 안정적으로 유지하는 환경');
    if (caution.isEmpty) caution.add('두드러진 재물 리스크 신호는 확인되지 않음');

    final confidence = (profile.strength == null || profile.yongsin == null)
        ? AnalysisConfidence.low
        : (wealthPeakDaewoonLabel.isEmpty && riskParts.isEmpty)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    return WealthAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 재물운',
      coreEvidence: evidence,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      wealthPattern: wealthPattern,
      wealthStrength: wealthStrength,
      incomePattern: incomePattern,
      riskPattern: riskPattern,
      assetManagementStyle: assetManagementStyle,
      wealthPeakDaewoonLabel: wealthPeakDaewoonLabel,
    );
  }

  /// 재성(정재/편재)의 오행 — 일간이 극(剋)하는 오행이다
  /// (saju_engine.dart의 표준 오행 상극표 `ke` 재사용, 재계산 아님).
  String _wealthElementOf(SajuProfileQuery q) => ke[q.dayElement] ?? '';

  String _buildAssetStyle({
    required String wealthStrength,
    required String incomePattern,
    required int gyeopjaeCount,
  }) {
    final base = wealthStrength.startsWith('재왕신강')
        ? '사업·투자 확대가 가능한 편이나'
        : wealthStrength.startsWith('재다신약')
        ? '무리한 확장보다 안정형 자산 위주로 접근하는 편이'
        : wealthStrength.startsWith('재약신약')
        ? '저축·현금성 자산 중심에 소액 분산투자를 곁들이는 편이'
        : wealthStrength.startsWith('신강용재')
        ? '정재·편재를 균형 있게 운용하는 편이'
        : '상황에 맞춰 유연하게 자산을 배분하는 편이';
    final incomeNote = incomePattern.startsWith('정재')
        ? ' 좋고, 고정수입 기반의 안정적 저축이 잘 맞음'
        : incomePattern.startsWith('편재')
        ? ' 좋고, 다만 변동성 큰 자산은 비중 조절이 필요함'
        : ' 좋음';
    final riskNote = gyeopjaeCount >= 2 ? ' — 특히 동업·공동명의 자산은 별도 관리가 필요함' : '';
    return '$base$incomeNote$riskNote';
  }
}
