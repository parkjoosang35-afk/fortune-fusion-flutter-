// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper 디자인 핸드오프 · 데이터 빌더]
//
// [절대 원칙 — 재계산 금지] 이 파일은 사주를 다시 계산하지 않는다. 이미
// PHASE1~4(`JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4`)가
// 계산해 둔 [SajuProfile]/[SajuResult]와, 이미 각 카테고리
// Analyzer/NarrativeGenerator 또는 `JeontongNarrativeInterpreter`가 산출한
// 문장([JeontongDeepReportData] 또는 `paragraphs`)만 그대로 조회해
// [SajuResultData](Dawn Paper 디자인이 그리는 화면 모델)로 옮겨 담는다.
//
// [두 개의 실계산 파이프라인 → 하나의 SajuResultData]
// - Pipeline A(A01/A03~A10 10종): 이미 구조화된 [JeontongDeepReportData]가
//   있으므로 [buildSajuDawnResultDataFromDeepReport]를 호출한다.
// - Pipeline B(나머지 ~59종): `JeontongNarrativeInterpreter.paragraphs()`가
//   만든 평문 문단 목록(+선택적 [DeclarativeVerdict])만 있으므로
//   [buildSajuDawnResultDataFromParagraphs]를 호출한다. 이 경로는
//   personalitySentences/strengths/cautions 같은 구조를 갖지 못하므로,
//   문단 전체를 一(총평) 챕터에 배치하는 것으로 단순화한다(§ 아래
//   "열린 설계 질문 처리" 참고).
//
// [열린 설계 질문 처리 — 실용적 기본값 채택, 문서화]
// 1. 행운 요소(陸 · SIX)의 색·방향 데이터 소스: 이 코드베이스에는 최소
//    두 개의 실계산 소스가 있다 —
//      (a) `getLuckyItems(saju, rules)`(`saju_fortune_modules.dart`) —
//          **부족한(deficient)** 오행 기준, `lucky_items_rules.json` 실데이터.
//      (b) `SajuInterpreter.fullInterpretation().fiveElementsAnalysis
//          .recommendedColor/recommendedDirection` — **일간 자신의** 오행
//          기준, `day_master_rules.json`(color/direction 필드는 현재 데이터
//          상 비어 있음 — 확인 완료) 기반.
//    "행운 요소 — 부족한 오행을 보완하는 색/방향/숫자/아이템"이라는 디자인
//    의도(README §8)와 더 직접적으로 맞고, 실제 값이 채워져 있는 (a)를
//    기본 소스로 채택한다. (b)는 사용하지 않는다(추후 재검토 가능 — 이
//    주석에 명시적으로 기록해 둔다).
// 2. StoryChapter/StoryParagraph/StoryRun의 한자 하이라이트: 실계산 결과
//    중 어느 것도 "이 부분을 하이라이트하라"는 마크업을 만들어내지 않는다.
//    새 명리학적 판단 없이, 이미 만들어진 문장 문자열에서 한자(CJK
//    Unified Ideographs, U+4E00~U+9FFF) 구간을 스캔해 자동으로
//    `hanjaHighlight: true` 런으로 감싸는 순수 텍스트 처리 휴리스틱을
//    적용한다([_splitHanjaRuns]) — 이는 "판단"이 아니라 "표시 방식" 결정이다.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;

import '../../../../../core/utils/load_state.dart';
import '../../../domain/manseryeok/saju_profile.dart';
import '../../../domain/saju_engine.dart' show SajuResult;
import '../../../domain/interpretation/saju_profile_query.dart';
import '../../../domain/interpretation/term_translation.dart'
    show elementMeaningDictionary, describeTenGodPlain;
import '../../../domain/jeontong_eighty_matrix.dart';
import '../../../domain/jeontong_v3_report_mapping.dart'
    show kJeontongCategoryToReportPartNo;
import '../../../domain/saju_fortune_modules.dart' show getLuckyItems;
import '../../../domain/saju_fortune_rules.dart' show SajuFortuneRules;
import '../../../../fortune/saju_v3/domain/interpretation_result.dart'
    show InterpretationResult;
import '../../../../fortune/saju_v3/domain/narrative_result.dart'
    show NarrativeResult;
import '../../../../fortune/saju_v3/domain/saju_report.dart'
    show SajuReportResult, SajuReportPart;
import '../jeontong_deep_report_card.dart'
    show JeontongDeepReportData, DeclarativeVerdict;
import 'saju_dawn_data_models.dart';
import 'saju_dawn_ilgan_theme.dart';
import 'saju_dawn_tokens.dart';

// ============================================================
// 공개 진입점 2개 — Pipeline A / Pipeline B
// ============================================================

/// [Pipeline A 전용] A01/A03~A10처럼 이미 [JeontongDeepReportData]로
/// 구조화된 실계산 콘텐츠가 있을 때 호출한다. 재계산 없음 — [content]의
/// 필드를 그대로 옮겨 담는다.
SajuResultData buildSajuDawnResultDataFromDeepReport({
  required JeontongCategoryEntry entry,
  required SajuProfile profile,
  required SajuResult saju,
  required SajuFortuneRules? fortuneRules,
  required JeontongDeepReportData content,
  required DateTime referenceDate,
  required String userRefId,
}) {
  return _build(
    entry: entry,
    profile: profile,
    saju: saju,
    fortuneRules: fortuneRules,
    referenceDate: referenceDate,
    userRefId: userRefId,
    oneLineSummary: content.oneLineSummary,
    isFortunate: content.isFortunate,
    personalityTitle: _sanitizeTitle(content.characteristicsTitle),
    personalitySentences: content.personalitySentences,
    strengths: content.strengths,
    cautions: content.cautions,
    generalGuidance: content.generalGuidance,
    daewoonFlowLines: content.daewoonFlow,
    finalSummary: content.finalSummary,
  );
}

/// [Pipeline B 전용] 나머지 ~59종처럼 `JeontongNarrativeInterpreter
/// .paragraphs()`가 만든 평문 문단만 있을 때 호출한다. [verdict]는
/// [kJeontongGroup1BinaryCategoryIds]/[kJeontongGroup2TimingCategoryIds]에
/// 속한 카테고리에서 `_buildGroup1Verdict`/`_buildGroup2Verdict`가 조합한
/// 값을 그대로 넘긴다(선택, 없으면 문단 첫 줄로 대체).
SajuResultData buildSajuDawnResultDataFromParagraphs({
  required JeontongCategoryEntry entry,
  required SajuProfile profile,
  required SajuResult saju,
  required SajuFortuneRules? fortuneRules,
  required List<String> paragraphs,
  DeclarativeVerdict? verdict,
  required DateTime referenceDate,
  required String userRefId,
}) {
  final oneLineSummary = verdict?.summary ??
      (paragraphs.isNotEmpty ? paragraphs.first : entry.title);
  final isFortunate = verdict?.isFortunate ?? true;
  // Pipeline B는 personalitySentences/strengths/cautions 구조가 없으므로,
  // 문단 전체를 一(총평) 챕터에 배치한다(§ 파일 상단 "열린 설계 질문 처리" 2번).
  return _build(
    entry: entry,
    profile: profile,
    saju: saju,
    fortuneRules: fortuneRules,
    referenceDate: referenceDate,
    userRefId: userRefId,
    oneLineSummary: oneLineSummary,
    isFortunate: isFortunate,
    personalityTitle: '총평 · 타고난 흐름',
    personalitySentences: paragraphs,
    strengths: const [],
    cautions: const [],
    generalGuidance: const [],
    daewoonFlowLines: const [],
    finalSummary: const [],
  );
}

/// [Pipeline C — saju_v3 백엔드 연동 전용] 6차 지시서 이후 실제 운영
/// 화면([JeontongV3ReportView])이 쓰는 것과 동일한 세 응답
/// ([SajuReportResult]/[InterpretationResult]/[NarrativeResult])을 그대로
/// 조회해 Dawn Paper 4챕터(肆)에 배치한다.
///
/// [재계산 금지 — 재확인] 사주 8글자/오행분포/대운/행운요소(壹·貳·參·陸)는
/// saju_v3가 별도로 구조화해 내려주지 않으므로(9-PART는 순수 텍스트),
/// 이 함수도 다른 두 파이프라인과 동일하게 이미 계산된 [SajuProfile]/
/// [SajuResult](PHASE1~4 — 같은 생년월일시 입력에 대해 항상 결정론적으로
/// 동일한 값)를 그대로 조회한다. **오직 肆(사주풀이) 4챕터의 문장만**
/// saju_v3 응답으로 교체한다 — 이것이 "결과 페이지 디자인 리뉴얼"과
/// "6차 지시서가 확정한 실제 백엔드(saju_v3) 사용" 두 지시를 모두
/// 만족시키는 유일한 지점이다.
///
/// [챕터 배치 규칙]
/// - 一(총평): narrative(이야기형 줄글)가 성공했으면 그 [NarrativeResult.text]
///   전체를 최우선으로 쓴다(사용자가 실제로 겪은 "관계 구조 JSON 노출"
///   버그의 근본 수정과 동일한 우선순위 — [JeontongV3ReportView]가 이미
///   증명한 패턴). narrative가 없으면, [kJeontongCategoryToReportPartNo]로
///   찾은 대응 PART의 paras를 [_humanizeFallbackPara]와 동일한 원칙으로
///   정리해 대신 쓴다. 대응 PART도 없으면(건강/궁합/개운 20종) interpret
///   headline/sections만으로 채운다.
/// - 二(강점과 조심할 점): interpret().sections에서 key=="strength"인
///   섹션의 body를 doList로, key=="caution"인 섹션의 body를 avoidList로
///   쓴다(ai_layer/interpret_service.py의 `_fallback()`과 qa_check.py가
///   LLM 경로·룰 폴백 경로 모두에서 이 두 key를 갖도록 강제하므로 항상
///   신뢰 가능 — § 실사용자 스크린 녹화로 "강점"에 엉뚱한 행운 팁이
///   노출되던 오매핑 버그를 수정). interpret().actions(행운 색상/음식/
///   방향 활용 팁)는 이 챕터가 아니라 陸(행운요소) 근처 보조 정보로만
///   쓰고, 강점/조심할 점 판정에는 더 이상 섞지 않는다.
/// - 三(대운의 흐름): PART7("인생 흐름") 텍스트가 있으면 그것을, 없으면
///   로컬 [SajuProfile.daewoon] 기반 문장(기존 헬퍼가 이미 만들던 형태와
///   동일한 형식)으로 대체한다. 타임라인 노드는 항상 로컬 계산 그대로.
/// - 四(실전 조언·맺음말): interpret().closing + 9번(종합분석) PART를 합친다.
///
/// [정통사주 로딩 개선 — Dawn Paper를 스켈레톤 호스트로 전환] 이전에는
/// [report]가 이미 성공(non-null)했을 때만 호출됐다(호출부의
/// `showDawnPaper = reportState.isSuccess` 게이트). 이제 Dawn Paper 자체가
/// 로딩 단계부터 렌더링되어야 하므로, 세 응답을 값이 아니라
/// [LoadState]로 받아 "아직 로딩 중"/"실패"를 챕터별로 구분해 표시할 수
/// 있게 한다 — 壹·貳·參·陸·柒(로컬 계산)은 이 상태와 무관하게 항상 즉시
/// 채워지고, 오직 肆(사주풀이 챕터)와 伍(실전 조언)만 이 상태를 참조한다.
SajuResultData buildSajuDawnResultDataFromV3Report({
  required JeontongCategoryEntry entry,
  required SajuProfile profile,
  required SajuResult saju,
  required SajuFortuneRules? fortuneRules,
  required LoadState<SajuReportResult> reportState,
  required LoadState<InterpretationResult> interpretState,
  required LoadState<NarrativeResult> narrativeState,
  required DateTime referenceDate,
  required String userRefId,
}) {
  final report = reportState.isSuccess ? reportState.data : null;
  final interpret = interpretState.isSuccess ? interpretState.data : null;
  final narrative = narrativeState.isSuccess ? narrativeState.data : null;

  final focusPartNo = kJeontongCategoryToReportPartNo[entry.id];
  SajuReportPart? findPart(int no) {
    if (report == null) return null;
    for (final p in report.report.parts) {
      if (p.no == no) return p;
    }
    return null;
  }

  final focusPart = focusPartNo == null ? null : findPart(focusPartNo);
  final part7 = findPart(7); // 인생 흐름(대운)
  final part9 = findPart(9); // 종합 분석

  final narrativeText = narrative?.text.trim();
  final hasNarrative = narrativeText != null && narrativeText.isNotEmpty;

  // 一(총평) — narrative 최우선 → focusPart paras → interpret만.
  final List<String> summarySentences;
  if (hasNarrative) {
    summarySentences = narrativeText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  } else if (focusPart != null && focusPart.paras.isNotEmpty) {
    summarySentences =
        focusPart.paras.map(_humanizeFallbackPara).toList();
  } else if (interpret != null && interpret.headline.isNotEmpty) {
    summarySentences = [interpret.headline];
  } else {
    summarySentences = const [];
  }
  // [로딩/에러 판정 — § 파일 상단] 문장이 이미 채워졌으면 소스가 무엇이든
  // ready. 비어 있는데 관련 응답 중 하나라도 아직 진행 중이면 loading.
  // 전부(narrative+report+interpret) 실패로 끝났으면 error.
  final chapter1Status = _sectionStatus(
    hasContent: summarySentences.isNotEmpty,
    sources: [narrativeState, reportState, interpretState],
  );

  // 二(강점과 조심할 점) — interpret().sections에서 key=="strength"/
  // "caution"인 섹션의 body를 각각 doList/avoidList로 쓴다(§ 위 주석).
  List<String> sectionBody(String key) {
    if (interpret == null) return const [];
    for (final s in interpret.sections) {
      if (s.key == key) return s.body;
    }
    return const [];
  }

  final strengthItems = sectionBody('strength');
  final cautionItems = sectionBody('caution');
  final chapter2Status = _sectionStatus(
    hasContent: strengthItems.isNotEmpty || cautionItems.isNotEmpty,
    sources: [interpretState],
  );

  // 三(대운의 흐름) — PART7(인생 흐름) 우선, 없으면 로컬 daewoon 헬퍼.
  // [항상 ready] 로컬 [SajuProfile.daewoon] 폴백이 항상 존재하므로(§ 파일
  // 상단 주석) report 상태와 무관하게 이 챕터는 절대 로딩/에러로 표시되지
  // 않는다 — 대운 타임라인과 마찬가지로 0ms에 확정되는 데이터다.
  final daewoonFlowLines = (part7 != null && part7.paras.isNotEmpty)
      ? part7.paras.map(_humanizeFallbackPara).toList()
      : _localDaewoonFlowLines(profile);
  const chapter3Status = DawnSectionStatus.ready;

  // 四(실전 조언·맺음말) — interpret().closing + PART9(종합 분석).
  final finalSummaryLines = <String>[
    if (interpret != null && interpret.hasClosing) interpret.closing,
    if (part9 != null) ...part9.paras.map(_humanizeFallbackPara),
  ];
  final chapter4Status = _sectionStatus(
    hasContent: finalSummaryLines.isNotEmpty,
    sources: [interpretState, reportState],
  );

  return _build(
    entry: entry,
    profile: profile,
    saju: saju,
    fortuneRules: fortuneRules,
    referenceDate: referenceDate,
    userRefId: userRefId,
    oneLineSummary: summarySentences.isNotEmpty
        ? summarySentences.first
        : entry.title,
    isFortunate: true,
    personalityTitle: interpret?.headline.isNotEmpty == true
        ? interpret!.headline
        : '총평 · 타고난 흐름',
    personalitySentences: summarySentences,
    strengths: strengthItems,
    cautions: cautionItems,
    generalGuidance: const [],
    daewoonFlowLines: daewoonFlowLines,
    finalSummary: finalSummaryLines,
    chapterStatuses: [
      chapter1Status,
      chapter2Status,
      chapter3Status,
      chapter4Status,
    ],
    // [伍(실전 조언) 섹션] doList/avoidList=strengths/cautions=
    // interpret().sections(key strength/caution)와 소스가 완전히
    // 동일하므로 챕터 二와 같은 상태를 공유한다.
    adviceStatus: chapter2Status,
  );
}

/// [정통사주 로딩 개선 — 섹션 상태 판정 공용 헬퍼] 이미 문장이 채워졌으면
/// (source 무관) 항상 ready. 비어 있는데 관련 [LoadState] 중 하나라도
/// 아직 initial/loading이면 loading(=더 기다리면 채워질 가능성 있음).
/// 관련 소스가 전부 error로 끝났으면 error(=재시도가 필요함을 사용자에게
/// 알려야 함). 그 외(예: sources가 비어 있는 이론상 불가능한 경우)는
/// 안전하게 loading으로 취급한다.
DawnSectionStatus _sectionStatus({
  required bool hasContent,
  required List<LoadState> sources,
}) {
  if (hasContent) return DawnSectionStatus.ready;
  if (sources.any((s) => s.isLoading || s.isInitial)) {
    return DawnSectionStatus.loading;
  }
  if (sources.isNotEmpty && sources.every((s) => s.isError)) {
    return DawnSectionStatus.error;
  }
  return DawnSectionStatus.loading;
}

/// [순수 텍스트 처리 — jeontong_v3_report_view.dart의 동일 함수와 로직
/// 복제] rule_fallback 리포트의 일부 PART가 `f"레이블: {json...}"` 형태로
/// 원본 딕셔너리를 그대로 문자열에 박아 보낼 때, 그 JSON 중괄호 이후를
/// 잘라내고 안내 문구로 바꾼다. private 함수라 원본 파일에서 import할
/// 수 없어(다른 파일의 top-level private) 동일 원칙으로 이 파일에도
/// 둔다 — 새 판단이 아니라 이미 검증된 화면 표시 휴리스틱의 재사용이다.
String _humanizeFallbackPara(String p) {
  final braceIdx = p.indexOf('{');
  if (braceIdx <= 0) return p;
  final head = p.substring(0, braceIdx).trimRight();
  if (!head.endsWith(':')) return p;
  final label = head.substring(0, head.length - 1).trim();
  if (label.isEmpty) return p;
  return '$label 데이터를 계산해 반영했어요(자세한 문장은 곧 업데이트돼요).';
}

/// [로컬 폴백 — 재계산 없음] saju_v3 PART7이 비어 있을 때만 쓰는, 이미
/// [SajuProfile.daewoon]에 계산돼 있는 대운 목록을 문장으로만 옮기는
/// 최소 헬퍼. `_fallback_report`의 "대운 N구간: 간지" 형식과 동일한
/// 수준의 단순 나열이다(새 명리학적 해석 없음).
List<String> _localDaewoonFlowLines(SajuProfile profile) {
  final list = profile.daewoon;
  if (list == null || list.isEmpty) return const [];
  final sorted = [...list]..sort((a, b) => a.startAge.compareTo(b.startAge));
  return [
    for (final d in sorted)
      '${d.startAge}세부터 — ${d.pillar.hanja}(${d.pillar.kr}) 대운',
  ];
}

// ============================================================
// 공통 코어 — 위 두 진입점이 정규화한 필드를 SajuResultData로 조립.
// ============================================================

SajuResultData _build({
  required JeontongCategoryEntry entry,
  required SajuProfile profile,
  required SajuResult saju,
  required SajuFortuneRules? fortuneRules,
  required DateTime referenceDate,
  required String userRefId,
  required String oneLineSummary,
  required bool isFortunate,
  required String personalityTitle,
  required List<String> personalitySentences,
  required List<String> strengths,
  required List<String> cautions,
  required List<String> generalGuidance,
  required List<String> daewoonFlowLines,
  required List<String> finalSummary,
  // [정통사주 로딩 개선] Pipeline A/B는 이미 동기 계산된 값만 다루므로
  // 4챕터 모두 ready(기본값)다. Pipeline C(saju_v3)만 실제로 다른 값을
  // 넘긴다.
  List<DawnSectionStatus> chapterStatuses = const [
    DawnSectionStatus.ready,
    DawnSectionStatus.ready,
    DawnSectionStatus.ready,
    DawnSectionStatus.ready,
  ],
  DawnSectionStatus adviceStatus = DawnSectionStatus.ready,
}) {
  final ilganTheme =
      IlganTheme.ofHanja(profile.dayPillar.stemHanja) ??
      IlganTheme.of(IlganType.gap);

  return SajuResultData(
    categoryCode: entry.id,
    categoryHanja: entry.major.hanja,
    categoryGroup: _buildCategoryGroup(entry),
    title: entry.title,
    subtitle: entry.major.description,
    timePillar: _toDawnPillar(profile, 'hour', profile.hourPillar),
    dayPillar: _toDawnPillar(profile, 'day', profile.dayPillar),
    monthPillar: _toDawnPillar(profile, 'month', profile.monthPillar),
    yearPillar: _toDawnPillar(profile, 'year', profile.yearPillar),
    ilgan: ilganTheme.type,
    ilganDescription: _buildIlganDescription(ilganTheme, personalitySentences),
    ohaengCounts: _buildOhaengCounts(profile.fiveElements),
    ohaengDiagnosis: _buildOhaengDiagnosis(profile.fiveElements),
    balanceScore: _buildBalanceScore(profile.fiveElements),
    chapters: _buildChapters(
      personalityTitle: personalityTitle,
      personalitySentences: personalitySentences,
      strengths: strengths,
      cautions: cautions,
      daewoonFlowLines: daewoonFlowLines,
      generalGuidance: generalGuidance,
      finalSummary: finalSummary,
      chapterStatuses: chapterStatuses,
    ),
    daeunTimeline: _buildDaeunTimeline(profile, referenceDate),
    doList: strengths,
    avoidList: cautions,
    adviceStatus: adviceStatus,
    lucky: _buildLucky(saju, fortuneRules, profile),
    related: _buildRelated(entry),
    userRefId: userRefId,
  );
}

// ============================================================
// ① 사주 8글자 → SajuDawnPillar (+ 탭 툴팁 텍스트)
// ============================================================

const Map<String, String> _posLabel = {
  'year_gan': '년간',
  'month_gan': '월간',
  'day_gan': '일간',
  'hour_gan': '시간',
  'year_zhi': '년지',
  'month_zhi': '월지',
  'day_zhi': '일지',
  'hour_zhi': '시지',
};

SajuDawnPillar _toDawnPillar(SajuProfile profile, String posKey, Pillar p) {
  final stemEl = _elementFromKr(p.stemElement);
  final branchEl = _elementFromKr(p.branchElement);
  return SajuDawnPillar(
    stemHanja: p.stemHanja,
    stemHangul: '${p.stemKr}${p.stemElement}',
    stemElement: stemEl,
    stemTip: _tenGodTip(profile, '${posKey}_gan', p.stemKr, p.stemHanja),
    branchHanja: p.branchHanja,
    branchHangul: '${p.branchKr}${p.branchElement}',
    branchElement: branchEl,
    branchTip: _tenGodTip(profile, '${posKey}_zhi', p.branchKr, p.branchHanja),
  );
}

/// 탭 인터랙션 툴팁(README §4 "일지 · 술토(戌土) — 편재, 나의 무대") —
/// 이미 PHASE2가 계산해 둔 [SajuProfile.tenGods]를 조회만 한다(재계산 없음).
/// 일간(day_gan) 자신은 십신이 없으므로(자기 자신 기준) 별도 문구를 쓴다.
String _tenGodTip(SajuProfile profile, String key, String hangul, String hanja) {
  final label = _posLabel[key] ?? key;
  if (key == 'day_gan') {
    return '$label · $hangul($hanja) — 나의 본질(일간)';
  }
  final tenGod = profile.tenGods?[key];
  if (tenGod == null || tenGod.isEmpty) {
    return '$label · $hangul($hanja)';
  }
  return '$label · $hangul($hanja) — $tenGod, ${describeTenGodPlain(tenGod)}';
}

SajuDawnElement _elementFromKr(String kr) {
  switch (kr) {
    case '목':
    case '木':
      return SajuDawnElement.wood;
    case '화':
    case '火':
      return SajuDawnElement.fire;
    case '토':
    case '土':
      return SajuDawnElement.earth;
    case '금':
    case '金':
      return SajuDawnElement.metal;
    case '수':
    case '水':
      return SajuDawnElement.water;
    default:
      return SajuDawnElement.earth;
  }
}

// ============================================================
// ③ 오행 분포 — FiveElementsProfile 조회만(재계산 없음).
// ============================================================

Map<SajuDawnElement, int> _buildOhaengCounts(FiveElementsProfile? fe) {
  final counts = fe?.totalCount ?? const <String, int>{};
  return {
    for (final el in SajuDawnElement.values)
      el: counts[el.hangul] ?? 0,
  };
}

String _buildOhaengDiagnosis(FiveElementsProfile? fe) {
  if (fe == null) return '오행 분포를 계산할 데이터가 아직 준비되지 않았습니다.';
  final dominant = fe.dominant;
  final deficient = fe.deficient;
  final parts = <String>[];
  if (dominant.isNotEmpty) {
    final hanjaJoined = dominant.map((e) => _elementFromKr(e).hanja).join('·');
    parts.add('${dominant.join('·')}($hanjaJoined) 기운이 넘치고');
  }
  if (deficient.isNotEmpty) {
    parts.add('${deficient.join('·')}는 부족합니다');
  }
  if (parts.isEmpty) return '오행이 비교적 고르게 분포되어 있습니다.';
  return '${parts.join(', ')}.';
}

/// [균형 점수 — 파생 통계, 새 명리학적 판단 아님] 5개 오행 중 "과다/부족"
/// 어느 쪽에도 속하지 않는(=적당한) 오행의 비율을 %로 환산한다. 예:
/// 과다 2개 + 부족 1개면 적당 2개 → 2/5*100 = 40%(디자인 핸드오프
/// 샘플 데이터의 "40 (%)"와 우연히 일치하는 값 — 원본 [FiveElementsProfile
/// .dominant]/[.deficient] 리스트를 그대로 조회해 만든 비율일 뿐, 원국을
/// 다시 판단하지 않는다).
int _buildBalanceScore(FiveElementsProfile? fe) {
  if (fe == null) return 0;
  final imbalanced = fe.dominant.length + fe.deficient.length;
  final balanced = (5 - imbalanced).clamp(0, 5);
  return ((balanced / 5) * 100).round();
}

// ============================================================
// 肆(FOUR) 사주 풀이 4챕터 — 이미 산출된 문장을 배치만(재계산 없음).
// ============================================================

String _sanitizeTitle(String raw) {
  return raw.replaceFirst(RegExp(r'^[①②③④⑤⑥⑦⑧⑨⑩]\s*'), '');
}

List<StoryChapter> _buildChapters({
  required String personalityTitle,
  required List<String> personalitySentences,
  required List<String> strengths,
  required List<String> cautions,
  required List<String> daewoonFlowLines,
  required List<String> generalGuidance,
  required List<String> finalSummary,
  // [정통사주 로딩 개선] Pipeline A/B는 항상 4개 모두 ready를 넘긴다
  // (기본값) — 이미 동기 계산된 문장만 다루므로 "준비되지 않음" 문구가
  // 나올 일이 없다. Pipeline C(saju_v3)만 loading/error를 실제로 넘긴다.
  List<DawnSectionStatus> chapterStatuses = const [
    DawnSectionStatus.ready,
    DawnSectionStatus.ready,
    DawnSectionStatus.ready,
    DawnSectionStatus.ready,
  ],
}) {
  // [loading/error일 때 플레이스홀더 문구 억제] "아직 ○○이 준비되지
  // 않았습니다"는 챕터 위젯이 스켈레톤/에러 뷰를 그리지 않는 ready 상태
  // (Pipeline A/B의 정말로 빈 결과, 또는 saju_v3가 성공했지만 우연히 빈
  // 문자열을 준 극단적 케이스)에서만 의미가 있다. loading/error 상태에서는
  // 문단을 비워 두어 [SajuDawnStoryChapters]가 스켈레톤/에러 뷰를 그리도록
  // 한다(문구 두 개가 동시에 보이는 것을 방지).
  bool isPending(int i) => chapterStatuses[i] != DawnSectionStatus.ready;

  return [
    StoryChapter(
      chapterNum: '一',
      title: personalityTitle,
      paragraphs: isPending(0)
          ? const []
          : _toParagraphs(
              personalitySentences.isEmpty
                  ? const ['아직 풀이할 문장이 준비되지 않았습니다.']
                  : personalitySentences,
            ),
      status: chapterStatuses[0],
    ),
    StoryChapter(
      chapterNum: '二',
      title: '강점과 조심할 점',
      paragraphs: isPending(1)
          ? const []
          : _toParagraphs([
              if (strengths.isNotEmpty) '강점 — ${strengths.join(' / ')}',
              if (cautions.isNotEmpty) '조심할 점 — ${cautions.join(' / ')}',
              if (strengths.isEmpty && cautions.isEmpty) '아직 정리된 강점·주의점이 없습니다.',
            ]),
      status: chapterStatuses[1],
    ),
    StoryChapter(
      chapterNum: '三',
      title: '대운의 흐름 · 시기별 전개',
      // [항상 ready — § buildSajuDawnResultDataFromV3Report 주석] 로컬
      // daewoon 폴백이 항상 있으므로 이 챕터는 isPending(2)가 될 일이
      // 없다(chapterStatuses[2]는 늘 ready로 전달됨). 방어적으로 isPending
      // 검사는 유지한다.
      paragraphs: isPending(2)
          ? const []
          : _toParagraphs(
              daewoonFlowLines.isEmpty
                  ? const ['대운 정보가 아직 준비되지 않았습니다.']
                  : daewoonFlowLines,
            ),
      includeTimeline: true,
      status: chapterStatuses[2],
    ),
    StoryChapter(
      chapterNum: '四',
      title: '실전 조언 · 맺음말',
      paragraphs: isPending(3)
          ? const []
          : _toParagraphs([
              ...generalGuidance,
              ...finalSummary,
              if (generalGuidance.isEmpty && finalSummary.isEmpty) '아직 맺음말이 준비되지 않았습니다.',
            ]),
      status: chapterStatuses[3],
    ),
  ];
}

List<StoryParagraph> _toParagraphs(List<String> lines) {
  final filtered = lines.where((l) => l.trim().isNotEmpty).toList();
  if (filtered.isEmpty) return const [];
  return [
    for (var i = 0; i < filtered.length; i++)
      StoryParagraph(runs: _splitHanjaRuns(filtered[i]), dropCap: i == 0),
  ];
}

/// [순수 텍스트 처리 휴리스틱 — 새 판단 없음] 문자열 안의 한자(CJK
/// Unified Ideographs) 연속 구간을 찾아 하이라이트 런으로 감싼다.
List<StoryRun> _splitHanjaRuns(String text) {
  final runs = <StoryRun>[];
  final buffer = StringBuffer();
  bool? currentIsHanja;

  void flush() {
    if (buffer.isEmpty) return;
    runs.add(StoryRun(buffer.toString(), hanjaHighlight: currentIsHanja ?? false));
    buffer.clear();
  }

  for (final rune in text.runes) {
    final isHanja = rune >= 0x4E00 && rune <= 0x9FFF;
    if (currentIsHanja != null && isHanja != currentIsHanja) flush();
    currentIsHanja = isHanja;
    buffer.writeCharCode(rune);
  }
  flush();
  return runs;
}

// ============================================================
// 챕터 三의 대운 타임라인(4노드) — SajuProfile.daewoon 조회만(재계산 없음).
// ============================================================

List<DaeunNode> _buildDaeunTimeline(SajuProfile profile, DateTime referenceDate) {
  final list = profile.daewoon;
  if (list == null || list.isEmpty) return const [];

  final sorted = [...list]..sort((a, b) => a.startAge.compareTo(b.startAge));
  final current = SajuProfileQuery(profile).currentDaewoon(referenceDate);
  final currentIndex = current == null
      ? 0
      : sorted.indexWhere((d) => d.index == current.index).clamp(0, sorted.length - 1);

  // 디자인 스펙(README §6 "트랙: 60dp 높이, 4개 노드")에 맞춰 현재 대운을
  // 중심으로 앞뒤 인접한 대운까지 최대 4개만 뽑는다.
  final int start = (currentIndex - 1)
      .clamp(0, math.max(0, sorted.length - 1))
      .toInt();
  final int end = (start + 4).clamp(0, sorted.length).toInt();
  final picked = sorted.sublist(start, end);

  final minAge = sorted.first.startAge;
  final maxAge = sorted.last.startAge;
  final span = (maxAge - minAge) == 0 ? 1 : (maxAge - minAge);

  return [
    for (final d in picked)
      DaeunNode(
        ageStart: d.startAge,
        hanja: d.pillar.hanja,
        position: ((d.startAge - minAge) / span).clamp(0.0, 1.0),
        active: current != null && d.index == current.index,
      ),
  ];
}

// ============================================================
// 陸(SIX) 행운 요소 — getLuckyItems() 실데이터 조회만(재계산 없음).
// § 파일 상단 "열린 설계 질문 처리" 1번 참고 — 부족 오행 기준 소스 채택.
// ============================================================

const Map<String, double> _directionAngle = {
  '북쪽': 0,
  '북동쪽': math.pi / 4,
  '동쪽': math.pi / 2,
  '동남쪽': 3 * math.pi / 4,
  '남동쪽': 3 * math.pi / 4,
  '남쪽': math.pi,
  '남서쪽': 5 * math.pi / 4,
  '서쪽': 3 * math.pi / 2,
  '북서쪽': 7 * math.pi / 4,
  '중앙': 0,
};

const Map<String, String> _directionHanja = {
  '북쪽': '北',
  '북동쪽': '北東',
  '동쪽': '東',
  '동남쪽': '東南',
  '남동쪽': '東南',
  '남쪽': '南',
  '남서쪽': '南西',
  '서쪽': '西',
  '북서쪽': '北西',
  '중앙': '中央',
};

LuckyItems _buildLucky(
  SajuResult saju,
  SajuFortuneRules? rules,
  SajuProfile profile,
) {
  if (rules == null) {
    return const LuckyItems(
      color: LuckyColor(name: '-', hex: '#B89968', note: '데이터 준비 중'),
      direction: LuckyDirection(name: '-', angle: 0, note: ''),
      numbers: [],
      keyword: LuckyKeyword(hanja: '福', name: '복', note: ''),
    );
  }

  // 부족한(deficient) 오행 기준 실데이터(lucky_items_rules.json) — 재계산 없음.
  final lucky = getLuckyItems(saju, rules);
  final lackEl = _elementFromKr(lucky.lackElement);
  final colorName = lucky.colors.isNotEmpty ? lucky.colors.first : lackEl.hangul;
  final directionName = lucky.directions.isNotEmpty ? lucky.directions.first : '';
  final angle = _directionAngle[directionName] ?? 0.0;

  // 키워드는 용신(用神) 오행을 우선 사용하고, 용신이 없으면 부족 오행을
  // 그대로 재사용한다(§ 재계산 금지 — 이미 계산된 YongsinProfile 조회만).
  final yongsinEl = profile.yongsin?.yongsin;
  final keywordElKr = (yongsinEl != null && yongsinEl.isNotEmpty)
      ? yongsinEl
      : lucky.lackElement;
  final keywordEl = _elementFromKr(keywordElKr);
  final meaning = elementMeaningDictionary[keywordElKr];

  return LuckyItems(
    color: LuckyColor(
      name: colorName,
      hex: _toHex(lackEl.color),
      note: '부족한 ${lackEl.hangul}(${lackEl.hanja}) 기운을 보완',
    ),
    direction: LuckyDirection(
      name: directionName.isEmpty
          ? '-'
          : '$directionName · ${_directionHanja[directionName] ?? ''}',
      angle: angle,
      note: '부족한 ${lackEl.hangul} 기운 보완',
    ),
    numbers: lucky.numbers,
    keyword: LuckyKeyword(
      hanja: keywordEl.hanja,
      name: '${keywordEl.hangul} 기운',
      note: meaning?.plainKorean ?? '',
    ),
  );
}

String _toHex(Color c) {
  final value = c.toARGB32();
  return '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

// ============================================================
// 柒(SEVEN) 관련 운세 — 전용 연관관계 데이터가 없어(§ 열린 설계 질문),
// 동일 대카테고리(같은 major) 내 다른 소카테고리를 재사용한다.
// 재계산 없음 — 기존 JeontongEightyMatrix 카탈로그 조회만 사용.
// ============================================================

List<RelatedFortune> _buildRelated(JeontongCategoryEntry entry) {
  final group = JeontongEightyMatrix.groups.firstWhere(
    (g) => g.code == entry.major,
    orElse: () => JeontongMajorGroup(code: entry.major, items: const []),
  );
  final siblings = group.items.where((e) => e.id != entry.id).toList();
  return siblings
      .take(4)
      .map((e) => RelatedFortune(code: e.id, name: e.title))
      .toList();
}

// ============================================================
// 기타 헤더 필드 — 카탈로그 조회만(재계산 없음).
// ============================================================

String _buildCategoryGroup(JeontongCategoryEntry entry) {
  final group = JeontongEightyMatrix.groups.firstWhere(
    (g) => g.code == entry.major,
    orElse: () => JeontongMajorGroup(code: entry.major, items: const []),
  );
  final ordinal = group.items.indexWhere((e) => e.id == entry.id) + 1;
  final safeOrdinal = ordinal < 1 ? 1 : ordinal;
  return '${entry.major.title} · $safeOrdinal번째 이야기';
}

/// 壹(ONE) 일간 카드 본문 — [IlganTheme]의 정적 상징 카피 + 이미 계산된
/// 첫 성격 문장(있으면)만 덧붙인다(재계산 없음).
String _buildIlganDescription(IlganTheme theme, List<String> personalitySentences) {
  final extra = personalitySentences.isNotEmpty ? ' ${personalitySentences.first}' : '';
  return '${theme.hangul}(${theme.hanja}) · ${theme.symbolName}.$extra';
}
