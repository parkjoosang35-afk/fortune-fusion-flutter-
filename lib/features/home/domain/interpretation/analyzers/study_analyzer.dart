/// [정통사주 69종 개인화 해석 엔진 — 9단계] A09 평생 학업·시험운
/// Analyzer.
///
/// 레거시 `getLifeStudy()`가 인성(정인+편인) 개수와 문창귀인(文昌貴人)
/// 보유 여부 두 신호만으로 5개 고정 문장(학업최상형/시험운발동형/학구형/
/// 안정형/실전형) 중 하나를 골라 반환하고, 신강신약·문창귀인이 걸린
/// 위치·다른 학업 관련 신살(역마)·용신/기신·대운을 전혀 참조하지 않던
/// 방식을 폐기한다. 대신 [SajuProfile]의 십신 분포·신강신약·문창귀인이
/// 걸린 자리·신살·용신/기신·대운을 A06/A07/A08과 동일한 설계 원칙으로
/// 직접 조회해 학업·시험운 구조를 매번 새로 판정한다(§4 "문장이 아니라
/// 분석을 개인화").
///
/// [십신 배정 근거 — 레거시와 동일하게 유지, §0 계산 원칙 보존] 인성
/// (印星, 정인·편인, 生我者=나를 낳아준 존재)은 수용력·이해력·학문의
/// 별로 보고, 문창귀인(文昌貴人)은 전통 명리학에서 학문·시험·저술·
/// 자격증에 유리한 대표적 길신으로 본다. 두 신호를 조합하는 것은 A08
/// 이전 레거시 원칙과 동일하되(§0 계산 원칙 보존), 여기서는 이를 매번
/// 새로 판정하는 구조로 확장한다.
///
/// [A06/A07/A08과의 구조적 차이 — 중요] A06은 일지(배우자궁), A07은
/// 시지(자녀궁), A08은 월지(부모형제궁)라는 "고정된 궁 위치"를 고유
/// 근거로 채택했다. A09는 그런 고정 궁 개념이 없다 — 문창귀인이라는
/// 신살 자체가 이미 학업·시험 전용 신호이므로, 이 Analyzer는 그
/// 문창귀인이 원국의 어느 자리(년지/월지/일지/시지)에 실제로 걸렸는지를
/// [A09 고유 근거]로 채택한다. 자리마다 상징하는 인생 시기(년지=유년·
/// 조상운, 월지=청소년·학창시절, 일지=성인기·자기주도 학습, 시지=말년·
/// 자녀세대 학업)가 다르므로, 문창귀인의 실제 위치에 따라 서술이
/// 달라진다 — 다른 카테고리는 이 관점으로 문창귀인을 조회하지 않는다.
///
/// 사용 데이터(§10 requiredData):
/// - 십신 7위치(tenGods) — 인성(학업성) 개수
/// - 신강신약(strength) — 학업 몰입을 감당하는 그릇의 크기
/// - 신살(sinsal) — 문창귀인 보유 여부 및 걸린 위치, 역마(유학형 학업)
/// - 신살(sinsal) — 문창귀인 자리에 걸린 공망/겁살/재살 리스크 신호
/// - 용신/기신(yongsin) — 학업운이 좋아지는/나빠지는 조건
/// - 대운(daewoon) — 학업·시험 성과가 정점에 이르는 실제 시기
///
/// 사용하지 않는 데이터(§10 excludedData): 세운/월운(올해·이번달 단위는
/// C/D그룹이 담당), 배우자운(A06)·자녀운(A07)·부모형제운(A08, 각각
/// 다른 육친성/궁 위치 사용).
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../category_analyzer.dart';
import '../saju_profile_query.dart';
import 'study_analysis.dart';

/// 문창귀인이 걸렸을 때 리스크로 채택하는 신살 nameKr 목록
/// (sinsal_engine.dart가 실제로 산출하는 nameKr과 일치, A07/A08과 동일
/// 목록을 문창귀인 위치 관점으로 재사용).
const Set<String> _studyRiskSinsalNames = {'공망', '겁살', '재살'};

/// 원국 4개 지지 위치 라벨이 상징하는 인생 시기(전통 명리학 근인/시지
/// 해석의 보편 관행 — 년지=유년·조상운, 월지=청소년·학창시절, 일지=
/// 성인기·자기주도, 시지=말년·자녀세대. 신규 계산이 아니라 각 위치가
/// 상징하는 시기에 대한 해석 콘텐츠 매핑).
const Map<String, String> _lifeStageByPosition = {
  '년지': '어린 시절·조상의 음덕과 관련된 학업 기반',
  '월지': '청소년기·학창시절의 학업 몰입',
  '일지': '성인이 된 이후 스스로 만들어가는 학습·자격 취득',
  '시지': '늦은 시기의 학업 성취나 자녀 세대의 학업운',
};

class StudyAnalyzer extends CategoryAnalyzer<StudyAnalysis> {
  const StudyAnalyzer();

  @override
  CategoryMetadata get metadata => const CategoryMetadata(
    categoryId: 'A09',
    categoryPurpose: '평생에 걸친 학업 몰입도와 시험운의 구조, 문창귀인이 걸린 자리의 의미를 분석',
    requiredData: ['십신 분포(인성)', '신강신약', '신살(문창귀인/역마/공망/겁살/재살)', '용신/기신', '대운'],
    analysisRules: [
      '인성(학업성) 개수 + 문창귀인 보유 여부를 조합해 학업 구조(studyPattern) 5단계 판정',
      '신강신약 × 인성 개수 조합으로 학업 몰입을 감당하는 방식(studyBondStrength) 판정',
      '문창귀인이 걸린 위치(년지/월지/일지/시지) 조회로 학업운이 두드러지는 인생 시기(munchangPositionCondition) 판정',
      '문창귀인 위치에 걸린 신살(공망/겁살/재살) + 인성·문창귀인 부재 여부를 조합해 리스크(studyRiskPattern) 판정',
      '대운 목록에서 인성 범주이거나 용신 오행을 포함하는 대운을 학업·시험 정점 시기로 판정',
    ],
    excludedData: ['세운(올해)', '월운(이번 달)', '배우자운(A06 담당)', '자녀운(A07 담당)', '부모형제운(A08 담당)'],
    outputStructure: ['학업 구조', '학업 몰입 방식', '문창귀인 위치 의미', '리스크', '학업 접근법', '정점 대운'],
  );

  @override
  StudyAnalysis analyze(SajuProfile profile, {DateTime? referenceDate}) {
    final evidence = <AnalysisEvidence>[];
    final q = SajuProfileQuery(profile);

    // ── ① 인성(학업성) 개수 집계(원국 본기 + 지장간 포함) + 문창귀인
    // 보유 여부·위치 조회 ──
    final categoryCounts = q.tenGodCategoryCounts(includeHiddenStems: true);
    final studyGodCount = categoryCounts['인성'] ?? 0;
    final sinsalList = profile.sinsal ?? const [];
    final munchangEntries = sinsalList.where((s) => s.nameKr == '문창귀인').toList();
    final hasMunchang = munchangEntries.isNotEmpty && munchangEntries.any((s) => s.foundOn.isNotEmpty);
    final munchangPositions = hasMunchang
        ? munchangEntries.expand((s) => s.foundOn).toSet().toList()
        : <String>[];
    evidence.add(
      AnalysisEvidence(
        sourceField: 'tenGods+hiddenStems(5대범주 집계) + sinsal(문창귀인)',
        sourceValue: '인성(학업성)=$studyGodCount, 문창귀인=${hasMunchang ? '보유(${munchangPositions.join(',')})' : '없음'}',
        rule: '인성=學文·문서·수용력, 문창귀인=전통 명리학 대표 학업·시험 신살로 채택(레거시 getLifeStudy 원칙 계승)',
        judgment: '인성 개수와 문창귀인 보유 여부를 기준으로 학업 구조 1차 판정',
        interpretationRole: InterpretationRole.primary,
        weight: 0.7,
      ),
    );

    // ── ② 학업 구조(studyPattern) — 레거시 5단계 조합 판정을 'A — B'
    // 라벨 형식으로 확장(§4) ──
    final String studyPattern;
    if (studyGodCount >= 2 && hasMunchang) {
      studyPattern = '학업최상형(學業最上型) — 학문을 받아들이는 힘과 시험 운이 함께 갖춰져 학업 성과가 가장 두드러지는 구조';
    } else if (hasMunchang) {
      studyPattern = '시험운발동형(試驗運發動型) — 평소 학업량과 무관하게 시험·자격증 같은 결정적 순간에 유독 운이 따르는 구조';
    } else if (studyGodCount >= 2) {
      studyPattern = '학구형(學究型) — 꾸준한 학습과 깊이 있는 이해력으로 실력을 쌓아가는 구조';
    } else if (studyGodCount == 1) {
      studyPattern = '안정형(安定型) — 무리하지 않는 속도로 안정적으로 학업을 이어가는 구조';
    } else {
      studyPattern = '실전형(實戰型) — 이론 공부보다 몸으로 부딪히며 배우는 실전 경험이 더 잘 맞는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'studyGodCount(인성 개수) + hasMunchang(문창귀인 보유)',
        sourceValue: '인성=$studyGodCount, 문창귀인=$hasMunchang',
        rule: '인성≥2&문창귀인→학업최상형 / 문창귀인만→시험운발동형 / 인성≥2→학구형 / 인성=1→안정형 / 인성=0→실전형',
        judgment: studyPattern,
        interpretationRole: InterpretationRole.primary,
        weight: 1.0,
      ),
    );

    // ── ③ 신강신약 × 인성 개수 → 학업 몰입을 감당하는 방식
    // (studyBondStrength) ──
    final strengthVerdict = profile.strength?.verdict ?? '중화';
    final String studyBondStrength;
    if (strengthVerdict == '신강' && studyGodCount >= 2) {
      studyBondStrength = '신강왕인(身强旺印) — 힘도 있고 학업 수용력도 두터워 어려운 과정도 스스로 밀어붙여 끝내는 편';
    } else if (strengthVerdict == '신강') {
      studyBondStrength = '신강자학(身强自學) — 힘이 있어 인성이 적어도 스스로 계획을 세워 공부해 나가는 편';
    } else if (strengthVerdict == '신약' && studyGodCount >= 1) {
      studyBondStrength = '신약의학(身弱依學) — 좋은 스승·환경의 도움을 받을 때 학업 몰입도가 특히 높아지는 편';
    } else if (strengthVerdict == '신약') {
      studyBondStrength = '신약분산(身弱分散) — 힘이 약한데 학업성도 부족해 한 과목에 오래 집중하기보다 짧게 끊어 공부하는 편이 유리';
    } else {
      studyBondStrength = '중화학구(中和學究) — 상황에 맞춰 학습 강도를 유연하게 조절하는 편';
    }
    if (profile.strength != null) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'strength.verdict + 인성 개수',
          sourceValue: '$strengthVerdict, 인성=$studyGodCount',
          rule: '신강+인성많음→신강왕인 / 신강+인성적음→신강자학 / 신약+인성있음→신약의학 / 신약+인성없음→신약분산 / 중화→중화학구',
          judgment: studyBondStrength,
          interpretationRole: InterpretationRole.strength,
          weight: 0.9,
        ),
      );
    }

    // ── ④ [A09 고유 근거] 문창귀인이 걸린 위치(munchangPositionCondition)
    // — 자리마다 상징하는 인생 시기가 다름(신규 계산이 아니라 이미 계산된
    // 문창귀인 위치를 시기 해석 콘텐츠와 매핑) ──
    final String munchangPositionCondition;
    if (hasMunchang) {
      final stageDescs = munchangPositions
          .map((p) => '$p(${_lifeStageByPosition[p] ?? '해당 시기'})')
          .join(', ');
      munchangPositionCondition = '문창귀인 발동 — $stageDescs 자리에 문창귀인이 걸려, 해당 시기의 학업·시험에서 유독 운이 따르는 구조';
    } else {
      munchangPositionCondition = '문창귀인 미발동 — 원국에 문창귀인이 나타나지 않아, 특정 시기의 시험운보다 꾸준한 노력으로 성과를 쌓아가는 구조';
    }
    evidence.add(
      AnalysisEvidence(
        sourceField: 'sinsal(문창귀인 위치, PHASE2 실계산)',
        sourceValue: hasMunchang ? munchangPositions.join(',') : '없음',
        rule: '문창귀인이 걸린 위치(년지/월지/일지/시지)를 그 자리가 상징하는 인생 시기 해석 콘텐츠와 매핑',
        judgment: munchangPositionCondition,
        interpretationRole: InterpretationRole.relationship,
        weight: 0.85,
      ),
    );

    // ── §5 개인화 강화: 같은 studyPattern이라도 문창귀인이 걸린 실제
    // 위치·개수는 사람마다 다르다는 것을 supportingEvidence로 기록.
    // 역마살(유학형 학업) 보유 여부도 함께 추적 ──
    final yeokmaEntries = sinsalList
        .where((s) => s.nameKr == '역마살' || s.nameKr == '역마')
        .expand((s) => s.foundOn)
        .toSet()
        .toList();
    final supportingEvidence = <AnalysisEvidence>[
      AnalysisEvidence(
        sourceField: '문창귀인 위치 상세 목록',
        sourceValue: munchangPositions.isEmpty ? '없음' : munchangPositions.join(', '),
        rule: '같은 studyPattern이라도 문창귀인이 걸린 실제 위치/개수는 사람마다 다름(§5)',
        judgment: munchangPositions.isEmpty ? '문창귀인 없음' : '${munchangPositions.length}개 자리에 문창귀인 확인',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.4,
      ),
      AnalysisEvidence(
        sourceField: '역마(살) 보유 여부',
        sourceValue: yeokmaEntries.isEmpty ? '없음' : yeokmaEntries.join(', '),
        rule: '역마는 이동·해외·유학과 관련된 신살로, 학업 중 유학·해외 활동 경향을 보여주는 보조 근거(§5)',
        judgment: yeokmaEntries.isEmpty ? '역마 관련 신호 없음' : '${yeokmaEntries.join(', ')} 자리에 역마 확인 — 해외·유학형 학업 경향',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.3,
      ),
    ];

    // ── ⑤ 리스크(studyRiskPattern): 문창귀인 위치에 걸린 공망/겁살/재살
    // + 인성·문창귀인 부재 여부 ──
    final foundStudyRiskSinsal = sinsalList
        .where(
          (s) =>
              _studyRiskSinsalNames.contains(s.nameKr) &&
              s.foundOn.any((pos) => munchangPositions.contains(pos)),
        )
        .map((s) => s.nameKr)
        .toSet()
        .toList();
    final riskParts = <String>[];
    if (hasMunchang && foundStudyRiskSinsal.contains('공망')) {
      riskParts.add('문창귀인이 걸린 자리에 공망이 겹쳐, 시험운이 있어도 실제 결과로 이어지기까지 시간이 걸릴 수 있음');
    }
    if (hasMunchang && foundStudyRiskSinsal.contains('겁살')) {
      riskParts.add('문창귀인이 걸린 자리에 겁살이 겹쳐, 시험·발표 직전에 예기치 못한 변수가 생기지 않도록 미리 대비하는 것이 좋음');
    }
    if (hasMunchang && foundStudyRiskSinsal.contains('재살')) {
      riskParts.add('문창귀인이 걸린 자리에 재살이 겹쳐, 시험 과정에서 구설이나 절차상 문제에 유의할 필요');
    }
    if (studyGodCount == 0 && !hasMunchang) {
      riskParts.add('인성도 문창귀인도 원국에 나타나지 않아 이론 학습보다 실무·현장 경험을 통한 성장이 더 유리한 편');
    }
    final studyRiskPattern = riskParts.isEmpty ? '두드러진 학업·시험운 리스크 신호는 확인되지 않음' : riskParts.join(' / ');
    if (riskParts.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: '신살(문창귀인 위치 공망/겁살/재살) + 인성·문창귀인 부재 조합',
          sourceValue: '신살=$foundStudyRiskSinsal, 인성=$studyGodCount, 문창귀인=$hasMunchang',
          rule: '문창귀인 위치에 공망/겁살/재살 존재 또는 인성=0&문창귀인 없음을 리스크 신호로 채택 후 종합',
          judgment: studyRiskPattern,
          interpretationRole: InterpretationRole.caution,
          weight: 0.7,
        ),
      );
    }
    // 문창귀인 자리 신살 발견 여부 자체는 항상 세부 근거로 남긴다(§5).
    supportingEvidence.add(
      AnalysisEvidence(
        sourceField: '문창귀인 위치 신살 존재 여부',
        sourceValue: foundStudyRiskSinsal.isEmpty ? '없음' : foundStudyRiskSinsal.join(', '),
        rule: '문창귀인 위치 신살 존재 여부는 리스크 판단과 별개로 항상 추적',
        judgment: foundStudyRiskSinsal.isEmpty ? '문창귀인 자리에 걸린 신살 없음' : '${foundStudyRiskSinsal.join(', ')} 보유',
        interpretationRole: InterpretationRole.supporting,
        weight: 0.3,
      ),
    );

    // ── ⑥ 학업 접근법(studyApproach) ──
    final studyApproach = _buildApproach(
      studyBondStrength: studyBondStrength,
      hasMunchang: hasMunchang,
      hasYeokma: yeokmaEntries.isNotEmpty,
    );

    // ── ⑦ 학업·시험 정점 대운(studyPeakDaewoonLabel) — PHASE4 실계산만
    // 사용(인성 범주 또는 용신 오행 매칭) ──
    var studyPeakDaewoonLabel = '';
    final daewoonList = profile.daewoon ?? const [];
    final yongsinElement = profile.yongsin?.yongsin ?? '';
    for (final d in daewoonList) {
      final matchesStudy = q.daewoonMatchesCategory(d, '인성');
      final carriesYongsin = yongsinElement.isNotEmpty && q.daewoonCarriesElement(d, yongsinElement);
      if (matchesStudy || carriesYongsin) {
        studyPeakDaewoonLabel =
            '${d.startAge}세(${d.startYear}년)부터 시작된 ${d.pillar.stemKr}${d.pillar.branchKr}(${d.pillar.stemHanja}${d.pillar.branchHanja}) 대운';
        break;
      }
    }
    if (studyPeakDaewoonLabel.isNotEmpty) {
      evidence.add(
        AnalysisEvidence(
          sourceField: 'daewoon(PHASE4 실계산)',
          sourceValue: studyPeakDaewoonLabel,
          rule: '대운의 천간/지지 십신이 인성 범주이거나 용신 오행을 포함하는 첫 대운 채택',
          judgment: '$studyPeakDaewoonLabel 시기에 학업·시험 성과가 가장 활발해질 가능성',
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
      if (hasMunchang) '문창귀인이 발동해 시험·자격증처럼 결정적 순간에 운이 따르는 환경',
      if (studyPeakDaewoonLabel.isNotEmpty) '$studyPeakDaewoonLabel 시기',
      if (yongsinElement.isNotEmpty) '$yongsinElement 기운이 강해지는 시기·학습 환경',
    ];
    final caution = <String>[
      if (foundStudyRiskSinsal.isNotEmpty) '${foundStudyRiskSinsal.join(', ')} 신호에 따른 시험·발표 시기 대비',
      if (studyGodCount == 0 && !hasMunchang) '이론 학습에 대한 부담이 상대적으로 클 수 있는 만큼 실무 경험으로 보완하는 마음가짐',
      if (!hasMunchang && studyGodCount <= 1) '학업 성과가 꾸준한 노력에 비례해 더디게 나타날 수 있는 점',
    ];
    if (favorable.isEmpty) favorable.add('현재의 학업 구조를 안정적으로 유지하는 환경');
    if (caution.isEmpty) caution.add('두드러진 학업·시험운 리스크 신호는 확인되지 않음');

    final confidence = (profile.strength == null || profile.yongsin == null)
        ? AnalysisConfidence.low
        : (studyPeakDaewoonLabel.isEmpty && riskParts.isEmpty && !hasMunchang)
        ? AnalysisConfidence.medium
        : AnalysisConfidence.high;

    // ── §16 결과 추적성: 최종 판정에 실제로 쓰인 원시 수치 전체를
    // 개발자 검증용으로 남긴다 ──
    final interpretationContext = <String, String>{
      'studyGodCount': '$studyGodCount',
      'hasMunchang': '$hasMunchang',
      'munchangPositions': munchangPositions.join(','),
      'strengthVerdict': strengthVerdict,
      'yongsinElement': yongsinElement,
      'foundStudyRiskSinsal': foundStudyRiskSinsal.join(','),
      'yeokmaPositions': yeokmaEntries.join(','),
      'studyPeakDaewoonLabel': studyPeakDaewoonLabel,
    };

    return StudyAnalysis(
      categoryId: metadata.categoryId,
      categoryName: '평생 학업·시험운',
      coreEvidence: evidence,
      supportingEvidence: supportingEvidence,
      interpretationContext: interpretationContext,
      favorableConditions: favorable,
      cautionConditions: caution,
      timing: null,
      confidence: confidence,
      studyPattern: studyPattern,
      studyBondStrength: studyBondStrength,
      munchangPositionCondition: munchangPositionCondition,
      studyRiskPattern: studyRiskPattern,
      studyApproach: studyApproach,
      studyPeakDaewoonLabel: studyPeakDaewoonLabel,
    );
  }

  String _buildApproach({
    required String studyBondStrength,
    required bool hasMunchang,
    required bool hasYeokma,
  }) {
    final base = studyBondStrength.startsWith('신강왕인')
        ? '스스로 학습 계획을 세워 밀어붙이는 방식이'
        : studyBondStrength.startsWith('신강자학')
        ? '남의 도움 없이도 혼자 계획을 세워 공부해 나가는 방식이'
        : studyBondStrength.startsWith('신약의학')
        ? '좋은 스승·학원·스터디 그룹의 도움을 적극적으로 받는 방식이'
        : studyBondStrength.startsWith('신약분산')
        ? '한 번에 오래 붙잡고 있기보다 짧게 끊어서 반복하는 방식이'
        : '상황에 맞춰 학습 강도와 방식을 유연하게 조절하는 편이';
    final munchangNote = hasMunchang ? ' 좋고, 특히 실제 시험·발표 일정이 다가올 때 유독 집중력이 오르는 편' : ' 좋음';
    final yeokmaNote = hasYeokma ? ', 해외 연수나 유학처럼 환경을 바꾸는 학습 방식도 잘 맞을 수 있음' : '';
    return '$base$munchangNote$yeokmaNote';
  }
}
