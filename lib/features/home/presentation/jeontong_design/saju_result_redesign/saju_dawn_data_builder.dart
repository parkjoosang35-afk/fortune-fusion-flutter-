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

import '../../../domain/manseryeok/saju_profile.dart';
import '../../../domain/saju_engine.dart' show SajuResult;
import '../../../domain/interpretation/saju_profile_query.dart';
import '../../../domain/interpretation/term_translation.dart'
    show elementMeaningDictionary, describeTenGodPlain;
import '../../../domain/jeontong_eighty_matrix.dart';
import '../../../domain/saju_fortune_modules.dart' show getLuckyItems;
import '../../../domain/saju_fortune_rules.dart' show SajuFortuneRules;
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
    ),
    daeunTimeline: _buildDaeunTimeline(profile, referenceDate),
    doList: strengths,
    avoidList: cautions,
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
}) {
  return [
    StoryChapter(
      chapterNum: '一',
      title: personalityTitle,
      paragraphs: _toParagraphs(
        personalitySentences.isEmpty
            ? const ['아직 풀이할 문장이 준비되지 않았습니다.']
            : personalitySentences,
      ),
    ),
    StoryChapter(
      chapterNum: '二',
      title: '강점과 조심할 점',
      paragraphs: _toParagraphs([
        if (strengths.isNotEmpty) '강점 — ${strengths.join(' / ')}',
        if (cautions.isNotEmpty) '조심할 점 — ${cautions.join(' / ')}',
        if (strengths.isEmpty && cautions.isEmpty) '아직 정리된 강점·주의점이 없습니다.',
      ]),
    ),
    StoryChapter(
      chapterNum: '三',
      title: '대운의 흐름 · 시기별 전개',
      paragraphs: _toParagraphs(
        daewoonFlowLines.isEmpty
            ? const ['대운 정보가 아직 준비되지 않았습니다.']
            : daewoonFlowLines,
      ),
      includeTimeline: true,
    ),
    StoryChapter(
      chapterNum: '四',
      title: '실전 조언 · 맺음말',
      paragraphs: _toParagraphs([
        ...generalGuidance,
        ...finalSummary,
        if (generalGuidance.isEmpty && finalSummary.isEmpty) '아직 맺음말이 준비되지 않았습니다.',
      ]),
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
