// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper 디자인 핸드오프] 실데이터 매핑 레이어.
//
// [절대 원칙 — 재계산 금지] 이 파일은 사주를 계산하지 않는다. 오직 이미
// PHASE1~4 실계산 파이프라인(JeontongReportBuilder.
// buildProfileAndSajuResultViaPhase1to4)과 그 위의 해석 계층
// (SajuInterpreter.fullInterpretation, 9종 CategoryAnalyzer/
// NarrativeGenerator, runJeontongCategory)이 "이미 만들어 둔" 결과 객체
// (SajuProfile/SajuResult/SajuFullInterpretation/JeontongDeepReportData/
// List<String> paragraphs/LuckyItemsResult)만 입력으로 받아, Dawn Paper
// 디자인 핸드오프의 [SajuResultData] 모양으로 "필드만 옮겨 담는다".
//
// [호출부 분기 — 기존 jeontong_eighty_result_screen.dart의 이미 검증된
// switch-case 로직을 그대로 재사용] 이 화면은 9개 카테고리(A01/A03~A10)에서
// 전용 Analyzer/NarrativeGenerator → [JeontongDeepReportData]를 만들고,
// 나머지 ~60개 카테고리에서는 SajuFullInterpretation +
// JeontongNarrativeInterpreter.paragraphs()로 문단 리스트를 만든다. 그
// 분기 로직 자체(어떤 카테고리가 어떤 Analyzer를 쓰는지)는 이 파일이
// 중복 구현하지 않는다 — 호출부(결과 화면)가 이미 그 분기를 마친 뒤
// 결과 객체만 아래 두 함수 중 하나에 넘긴다. 이렇게 하면 400줄이 넘는
// 기존 switch-case를 복제하지 않고도 새 화면과 기존 화면이 동일한 실계산
// 경로를 공유한다.
// ============================================================

import '../../../domain/interpretation/saju_profile_query.dart';
import '../../../domain/interpretation/term_translation.dart';
import '../../../domain/jeontong_eighty_matrix.dart';
import '../../../domain/manseryeok/saju_profile.dart';
import '../../../domain/saju_engine.dart' show SajuResult;
import '../../../domain/saju_fortune_modules.dart' show getLuckyItems;
import '../../../domain/saju_fortune_rules.dart' show SajuFortuneRules;
import '../../../domain/saju_interpreter.dart' show SajuFullInterpretation;
import '../jeontong_deep_report_card.dart' show JeontongDeepReportData;
import 'saju_dawn_data_models.dart';
import 'saju_dawn_ilgan_theme.dart';
import 'saju_dawn_tokens.dart';

// ============================================================
// 공개 API — 결과 화면이 호출하는 진입점 2개.
// ============================================================

/// [9개 특화 카테고리 전용 — A01/A03~A10] 호출부가 이미 만들어 둔
/// [JeontongDeepReportData]를 [SajuResultData]로 옮겨 담는다.
SajuResultData buildSajuDawnDataForSpecialCategory({
  required JeontongCategoryEntry entry,
  required SajuResult saju,
  required SajuProfile profile,
  required SajuFortuneRules rules,
  required JeontongDeepReportData data,
  DateTime? referenceDate,
  DateTime? birthDateTimeUtc,
  String? gender,
  bool? isLunar,
}) {
  final refDate = referenceDate ?? DateTime.now();
  final subtitle = _shortSubtitle(data.oneLineSummary);
  final chapters = _chaptersFromDeepReportData(data);
  return SajuResultData(
    categoryCode: entry.id,
    categoryHanja: entry.major.hanja,
    categoryGroup: _categoryGroupLabel(entry),
    title: entry.title,
    subtitle: subtitle,
    timePillar: _toDawnPillar(profile.hourPillar, 'hour', profile),
    dayPillar: _toDawnPillar(profile.dayPillar, 'day', profile),
    monthPillar: _toDawnPillar(profile.monthPillar, 'month', profile),
    yearPillar: _toDawnPillar(profile.yearPillar, 'year', profile),
    ilgan: _ilganTypeOf(profile),
    ilganDescription: data.personalitySentences.isNotEmpty
        ? data.personalitySentences.first
        : _ilganDescriptionFallback(profile),
    ohaengCounts: _toOhaengCounts(profile),
    ohaengDiagnosis: _ohaengDiagnosis(profile),
    balanceScore: _balanceScore(profile),
    chapters: chapters,
    daeunTimeline: _buildDaeunTimeline(profile, refDate),
    doList: data.strengths,
    avoidList: data.cautions,
    lucky: _buildLuckyItems(saju, rules),
    related: _buildRelated(entry),
    userRefId: _buildUserRefId(
      categoryCode: entry.id,
      birthDateTimeUtc: birthDateTimeUtc,
      gender: gender,
      isLunar: isLunar,
    ),
  );
}

/// [~60개 나머지 카테고리 전용] 호출부가 이미 만들어 둔
/// [SajuFullInterpretation] + [JeontongNarrativeInterpreter.paragraphs]
/// 결과(문단 리스트)를 [SajuResultData]로 옮겨 담는다.
SajuResultData buildSajuDawnDataForFallbackCategory({
  required JeontongCategoryEntry entry,
  required SajuResult saju,
  required SajuProfile profile,
  required SajuFortuneRules rules,
  required SajuFullInterpretation interp,
  required List<String> paragraphs,
  DateTime? referenceDate,
  DateTime? birthDateTimeUtc,
  String? gender,
  bool? isLunar,
}) {
  final refDate = referenceDate ?? DateTime.now();
  final firstParagraph = paragraphs.isNotEmpty
      ? paragraphs.first
      : interp.dayMasterAnalysis.nature;
  final subtitle = _shortSubtitle(firstParagraph);
  final chapters = _chaptersFromInterpretation(interp, paragraphs);
  return SajuResultData(
    categoryCode: entry.id,
    categoryHanja: entry.major.hanja,
    categoryGroup: _categoryGroupLabel(entry),
    title: entry.title,
    subtitle: subtitle,
    timePillar: _toDawnPillar(profile.hourPillar, 'hour', profile),
    dayPillar: _toDawnPillar(profile.dayPillar, 'day', profile),
    monthPillar: _toDawnPillar(profile.monthPillar, 'month', profile),
    yearPillar: _toDawnPillar(profile.yearPillar, 'year', profile),
    ilgan: _ilganTypeOf(profile),
    ilganDescription: interp.dayMasterAnalysis.nature,
    ohaengCounts: _toOhaengCounts(profile),
    ohaengDiagnosis: _ohaengDiagnosis(profile),
    balanceScore: _balanceScore(profile),
    chapters: chapters,
    daeunTimeline: _buildDaeunTimeline(profile, refDate),
    doList: interp.dayMasterAnalysis.strengths,
    avoidList: interp.dayMasterAnalysis.weaknesses,
    lucky: _buildLuckyItems(saju, rules),
    related: _buildRelated(entry),
    userRefId: _buildUserRefId(
      categoryCode: entry.id,
      birthDateTimeUtc: birthDateTimeUtc,
      gender: gender,
      isLunar: isLunar,
    ),
  );
}

// ============================================================
// 공통 필드 매핑 헬퍼 — 순수 조회/포맷 변환만 수행(재계산 없음).
// ============================================================

/// [manseryeok/saju_profile.dart]의 실계산 [Pillar] → Dawn Paper
/// [SajuDawnPillar]로 순수 필드 매핑. `stemTip`/`branchTip`은 이미
/// PHASE2가 계산해 둔 [SajuProfile.tenGods] 맵을 조회만 한다(새 판정 없음).
SajuDawnPillar _toDawnPillar(Pillar p, String posKey, SajuProfile profile) {
  return SajuDawnPillar(
    stemHanja: p.stemHanja,
    stemHangul: '${p.stemKr}${p.stemElement}',
    stemElement: _elementFromKorean(p.stemElement),
    stemTip: _stemTip(posKey, profile),
    branchHanja: p.branchHanja,
    branchHangul: '${p.branchKr}${p.branchElement}',
    branchElement: _elementFromKorean(p.branchElement),
    branchTip: _branchTip(posKey, profile),
  );
}

/// 천간 위치([posKey] = 'year'|'month'|'day'|'hour')의 십신 라벨.
/// 일주 천간(일간)은 십신 개념이 없으므로("나 자신") 고정 문구를 쓴다
/// (기존 [SajuProfile.tenGods] 맵도 `day_gan` 키를 갖지 않는다 — 동일 원칙).
String _stemTip(String posKey, SajuProfile profile) {
  if (posKey == 'day') return '일간(나 자신)';
  final tenGod = profile.tenGods?['${posKey}_gan'];
  return tenGod ?? '';
}

/// 지지 위치의 십신 라벨(일지 포함 — [SajuProfile.tenGods]는 `day_zhi`
/// 키를 갖는다).
String _branchTip(String posKey, SajuProfile profile) {
  final tenGod = profile.tenGods?['${posKey}_zhi'];
  return tenGod ?? '';
}

/// 실계산 한글 오행 문자열('목'/'화'/'토'/'금'/'수') → 표시 전용 enum.
SajuDawnElement _elementFromKorean(String? k) {
  switch (k) {
    case '목':
      return SajuDawnElement.wood;
    case '화':
      return SajuDawnElement.fire;
    case '토':
      return SajuDawnElement.earth;
    case '금':
      return SajuDawnElement.metal;
    case '수':
      return SajuDawnElement.water;
    default:
      return SajuDawnElement.earth;
  }
}

/// [SajuProfile.dayPillar.stemHanja](실계산 일간 한자) → [IlganType].
/// 조회 실패는 이론상 불가능하다(10천간 중 하나가 항상 반환됨) — 방어적
/// 기본값(甲)만 유지한다.
IlganType _ilganTypeOf(SajuProfile profile) {
  final theme = IlganTheme.ofHanja(profile.dayPillar.stemHanja);
  return theme?.type ?? IlganType.gap;
}

/// [JeontongDeepReportData.personalitySentences]가 비어 있는 방어적
/// 상황에서만 쓰이는 최소 폴백 — 오행 진단문을 재사용한다(새 문장 생성 없음).
String _ilganDescriptionFallback(SajuProfile profile) => _ohaengDiagnosis(profile);

/// [SajuProfile.fiveElements.totalCount](이미 계산됨) → 표시용 enum 맵.
Map<SajuDawnElement, int> _toOhaengCounts(SajuProfile profile) {
  final total = profile.fiveElements?.totalCount ?? const <String, int>{};
  return {
    for (final el in const ['목', '화', '토', '금', '수'])
      _elementFromKorean(el): total[el] ?? 0,
  };
}

/// [SajuProfile.fiveElements.dominant]/[deficient](이미 계산됨) +
/// [elementMeaningDictionary](고정 사전, term_translation.dart)로 진단
/// 문장을 조합한다 — 새 명리 판단 없음, 이미 산출된 과다/부족 오행에
/// 고정 사전 문구를 붙이기만 한다.
String _ohaengDiagnosis(SajuProfile profile) {
  final fe = profile.fiveElements;
  if (fe == null) return '오행의 흐름을 살펴보고 있어요.';
  final parts = <String>[];
  if (fe.deficient.isNotEmpty) {
    final el = fe.deficient.first;
    final chain = elementMeaningDictionary[el];
    parts.add(
      '$el(${chain?.plainKorean ?? el}) 기운이 부족한 편이라 이 부분을 보완하면 좋아요',
    );
  }
  if (fe.dominant.isNotEmpty) {
    final el = fe.dominant.first;
    final chain = elementMeaningDictionary[el];
    parts.add('$el(${chain?.plainKorean ?? el}) 기운이 두드러진 편이에요');
  }
  if (parts.isEmpty) return '오행이 고르게 분포된 균형 잡힌 사주예요.';
  return '${parts.join('. ')}.';
}

/// [SajuProfile.fiveElements.totalCount](이미 계산됨) 값들의 편차로부터
/// 표시용 "균형 점수"(0~100)를 계산한다. 이것은 새로운 명리 판정이 아니라
/// — 기존 [_FiveElementBalance] 위젯이 이미 하던 것과 동일한 "표시 전용
/// 비율 계산"(count/maxCount)의 연장선으로, 5개 오행 개수가 이상적으로
/// 균등할 때(각 total/5개)를 100점, 한쪽으로 쏠릴수록 낮은 점수로 매핑하는
/// 순수 산술 변환일 뿐이다.
int _balanceScore(SajuProfile profile) {
  final counts = profile.fiveElements?.totalCount ?? const <String, int>{};
  if (counts.isEmpty) return 50;
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return 50;
  final idealAvg = total / 5;
  final deviation = counts.values.fold<double>(
    0,
    (a, c) => a + (c - idealAvg).abs(),
  );
  // 이론상 최대 편차(오행 한 곳에 전부 쏠렸을 때) = 2 * total.
  final maxDeviation = 2 * total;
  final score = 100 - (deviation / maxDeviation * 100);
  return score.clamp(0, 100).round();
}

/// [SajuProfile.daewoon](이미 계산된 대운 목록) + [SajuProfileQuery.
/// currentDaewoon](이미 존재하는 "현재 대운 찾기" 조회 함수, 재구현 없음)
/// → 타임라인 노드 목록으로 순수 변환. 트랙 상 위치([DaeunNode.position])는
/// 대운 시작 나이의 최소~최대 구간을 0.0~1.0으로 정규화한 것뿐, 새 판단이
/// 아니다.
List<DaeunNode> _buildDaeunTimeline(SajuProfile profile, DateTime referenceDate) {
  final list = profile.daewoon ?? const <DaewoonEntry>[];
  if (list.isEmpty) return const [];
  final ages = list.map((d) => d.startAge).toList();
  final minAge = ages.reduce((a, b) => a < b ? a : b);
  final maxAge = ages.reduce((a, b) => a > b ? a : b);
  final span = (maxAge - minAge) == 0 ? 1 : (maxAge - minAge);
  final current = SajuProfileQuery(profile).currentDaewoon(referenceDate);
  return [
    for (final d in list)
      DaeunNode(
        ageStart: d.startAge,
        hanja: d.pillar.hanja,
        position: (d.startAge - minAge) / span,
        active: current != null && current.index == d.index,
      ),
  ];
}

/// 나침반 방향 한글 라벨 → 라디안(§ [LuckyDirection.angle] 문서 주석
/// "남쪽 = π"와 일치하도록 북쪽=0을 기준으로 시계방향 배치). 표시 전용
/// 상수 테이블일 뿐 명리학적 판단이 아니다(방향 자체는 이미
/// `getLuckyItems()`가 실데이터로 결정).
const Map<String, double> _directionAngleTable = {
  '북쪽': 0,
  '북동쪽': 0.7853981634,
  '동쪽': 1.5707963268,
  '동남쪽': 2.3561944902,
  '남동쪽': 2.3561944902,
  '남쪽': 3.1415926536,
  '남서쪽': 3.9269908170,
  '서쪽': 4.7123889804,
  '북서쪽': 5.4977871438,
  '중앙': 0,
};

/// [SajuDawnColors]의 오행 5색과 1:1 대응하는 고정 hex 표기(표시 전용 —
/// [SajuDawnColors.wuxingColor]가 반환하는 [Color] 상수와 정확히 동일한
/// 값을 문자열로 중복 선언한 것뿐, 새로운 색상 판단이 아니다).
const Map<String, String> _elementHexTable = {
  '목': '#4A8F5C',
  '화': '#C4623E',
  '토': '#B89968',
  '금': '#8B857E',
  '수': '#3F6A8C',
};

/// [getLuckyItems](saju_fortune_modules.dart, 이미 검증된 실계산 함수 —
/// `lucky_items_rules.json`의 `by_element_lack` 실데이터 조회)의 결과를
/// Dawn Paper [LuckyItems] 구조로 옮겨 담는다. 색상 hex/방향 각도만
/// 표시용으로 새로 매핑하고(고정 조회 테이블), 실제 "어떤 색/방향/숫자인지"
/// 판단은 전부 [getLuckyItems]가 이미 내린 값을 그대로 쓴다.
LuckyItems _buildLuckyItems(SajuResult saju, SajuFortuneRules rules) {
  final r = getLuckyItems(saju, rules);
  final colorName = r.colors.isNotEmpty ? r.colors.first : '';
  final directionName = r.directions.isNotEmpty ? r.directions.first : '';
  final keywordName = r.items.isNotEmpty ? r.items.first : r.lackElement;
  final elementEnum = _elementFromKorean(r.lackElement);
  return LuckyItems(
    color: LuckyColor(
      name: colorName,
      hex: _elementHexTable[r.lackElement] ?? '#B89968',
      note: '부족한 ${r.lackElement} 기운을 보완해줘요',
    ),
    direction: LuckyDirection(
      name: directionName,
      angle: _directionAngleTable[directionName] ?? 0,
      note: r.advice,
    ),
    numbers: r.numbers,
    keyword: LuckyKeyword(
      hanja: elementEnum.hanja,
      name: keywordName,
      note: r.advice,
    ),
  );
}

/// [柒 관련운세] 같은 대카테고리([JeontongEightyMatrix.groups]) 안의
/// 다른 소카테고리를 관련 운세로 제안한다 — 새 사전을 만들지 않고 기존
/// 카탈로그 구조를 그대로 재사용하는 동적 파생.
List<RelatedFortune> _buildRelated(JeontongCategoryEntry entry) {
  final group = JeontongEightyMatrix.groups.firstWhere(
    (g) => g.code == entry.major,
    orElse: () => JeontongEightyMatrix.groups.first,
  );
  final siblings = group.items.where((e) => e.id != entry.id).toList();
  if (siblings.isEmpty) return const [];
  return [
    for (final e in siblings.take(3)) RelatedFortune(code: e.id, name: e.title),
  ];
}

/// "{대카테고리 제목} · N번째 이야기" — [entry]가 속한 그룹 내 순번을
/// 그대로 사용한다(새 순번 부여 없음, 카탈로그 배열 순서 조회만).
String _categoryGroupLabel(JeontongCategoryEntry entry) {
  final group = JeontongEightyMatrix.groups.firstWhere(
    (g) => g.code == entry.major,
    orElse: () => JeontongEightyMatrix.groups.first,
  );
  final idx = group.items.indexWhere((e) => e.id == entry.id);
  final ordinal = idx >= 0 ? idx + 1 : 1;
  return '${entry.major.title} · $ordinal번째 이야기';
}

/// Hero 서브타이틀 — 이미 완성된 문장의 첫 절만 잘라 보여준다(새 문장
/// 생성 없음, 표시 공간에 맞춘 절단만).
String _shortSubtitle(String text, {int maxLen = 42}) {
  final firstClause = text.split(' — ').first.trim();
  if (firstClause.length <= maxLen) return firstClause;
  return '${firstClause.substring(0, maxLen)}…';
}

/// 문자열 리스트 → [StoryParagraph] 리스트. 챕터의 첫 문단에만 드롭캡을
/// 적용한다(README "챕터 드롭캡" 스펙 — 표시 전용 스타일링, 문장 자체는
/// 그대로).
List<StoryParagraph> _toParagraphs(List<String> lines) {
  final filtered = lines.where((l) => l.trim().isNotEmpty).toList();
  return [
    for (var i = 0; i < filtered.length; i++)
      StoryParagraph(runs: [StoryRun(filtered[i])], dropCap: i == 0),
  ];
}

/// [JeontongDeepReportData](9개 특화 카테고리 전용, 이미 완성된 구조화
/// 데이터)를 肆(4) 챕터 구조로 재배치한다 — 새 문장 생성 없음, 이미 있는
/// 필드를 4개 슬롯에 나눠 담기만 한다.
List<StoryChapter> _chaptersFromDeepReportData(JeontongDeepReportData data) {
  return [
    StoryChapter(
      chapterNum: '一',
      title: '총평 · 이 사주의 뿌리',
      paragraphs: _toParagraphs([data.oneLineSummary]),
    ),
    StoryChapter(
      chapterNum: '二',
      title: '나의 타고난 결',
      paragraphs: _toParagraphs(data.personalitySentences),
    ),
    StoryChapter(
      chapterNum: '三',
      title: '흐르는 시간, 대운의 결',
      paragraphs: _toParagraphs(
        data.daewoonFlow.isNotEmpty
            ? data.daewoonFlow
            : const ['대운의 흐름을 함께 살펴봐요.'],
      ),
      includeTimeline: true,
    ),
    StoryChapter(
      chapterNum: '四',
      title: '마지막으로 전하는 말',
      paragraphs: _toParagraphs([
        ...data.generalGuidance,
        ...data.finalSummary,
      ]),
    ),
  ];
}

/// [SajuFullInterpretation](9종 공통 실계산 해석) + [paragraphs]
/// ([JeontongNarrativeInterpreter.paragraphs]가 이미 조합한 문단, 보통
/// 1~2개)를 肆(4) 챕터 구조로 재배치한다. 문단 수가 4챕터를 채우기엔
/// 부족하므로, 항상 채워져 있는 [SajuFullInterpretation]의 나머지 필드
/// (dayMasterAnalysis/currentLuckAnalysis)를 보조 재료로 함께 쓴다 — 전부
/// 이미 계산된 값의 재배치일 뿐 새 판단은 없다.
List<StoryChapter> _chaptersFromInterpretation(
  SajuFullInterpretation interp,
  List<String> paragraphs,
) {
  final core = paragraphs.isNotEmpty ? paragraphs.first : interp.dayMasterAnalysis.nature;
  final action = paragraphs.length > 1 ? paragraphs.sublist(1) : const <String>[];
  return [
    StoryChapter(
      chapterNum: '一',
      title: '총평 · 이 사주의 뿌리',
      paragraphs: _toParagraphs([core]),
    ),
    StoryChapter(
      chapterNum: '二',
      title: '나의 타고난 결',
      paragraphs: _toParagraphs([
        interp.dayMasterAnalysis.nature,
        interp.dayMasterAnalysis.personality,
      ]),
    ),
    StoryChapter(
      chapterNum: '三',
      title: '흐르는 시간, 지금의 대운',
      paragraphs: _toParagraphs([
        if (interp.currentLuckAnalysis.message != null)
          interp.currentLuckAnalysis.message!
        else
          '지금 대운의 흐름을 함께 살펴봐요.',
      ]),
      includeTimeline: true,
    ),
    StoryChapter(
      chapterNum: '四',
      title: '마지막으로 전하는 말',
      paragraphs: _toParagraphs(
        action.isNotEmpty ? action : interp.dayMasterAnalysis.careerFit,
      ),
    ),
  ];
}

// ============================================================
// 사용자 식별용 표시 참조번호 — 계산이 아니라 표시용 해시일 뿐이다.
// ============================================================

/// FNV-1a 32bit 해시(JS 세이프 — dart2js에서 64bit 정수 리터럴 컴파일
/// 오류를 피하기 위해 result_screen.dart의 `_jeontongSignatureFromInputs`
/// 와 동일한 알고리즘을 사용한다).
String _fnv1aHex(String input) {
  const int fnvPrime = 0x01000193;
  int hash = 0x811C9DC5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _buildUserRefId({
  required String categoryCode,
  DateTime? birthDateTimeUtc,
  String? gender,
  bool? isLunar,
}) {
  final seed = [
    categoryCode,
    birthDateTimeUtc?.millisecondsSinceEpoch.toString() ?? '',
    gender ?? '',
    isLunar?.toString() ?? '',
  ].join('|');
  return '#${_fnv1aHex(seed)}';
}
