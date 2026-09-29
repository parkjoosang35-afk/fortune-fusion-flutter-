// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper 디자인 핸드오프]
// 원본: design_handoff_saju_result.zip flutter_starter/data_models.dart
//
// [naming collision 회피] 원본의 `Pillar` 클래스는 이 프로젝트에 이미 존재하는
// `manseryeok/saju_profile.dart`의 `Pillar`(실계산 엔진의 핵심 데이터 모델,
// `pillar_board.dart` 등 다수 위젯이 참조 중)와 이름이 겹친다. 이 파일에서는
// `SajuDawnPillar`로 이름을 바꿔 완전히 격리한다 — 필드 구성은 원본과 100% 동일.
//
// [나머지 클래스] `DaeunNode`/`LuckyItems`/`LuckyColor`/`LuckyDirection`/
// `LuckyKeyword`/`RelatedFortune`/`StoryChapter`/`StoryParagraph`/`StoryRun`은
// 프로젝트 전체 grep 결과 이름 충돌이 없어 원본 이름 그대로 가져왔다.
//
// [실데이터 연동] `sampleSajuData`는 개발/프리뷰용 샘플로만 남겨두고, 실제
// 결과 화면은 `saju_dawn_data_builder.dart`가 `SajuFullInterpretation`/
// `SajuProfile`/`JeontongDeepReportData` 등 실계산 데이터를 조합해
// [SajuResultData]를 생성한다(재계산 없음 — 매핑만 수행).
// ============================================================

import 'saju_dawn_tokens.dart';
import 'saju_dawn_ilgan_theme.dart';

/// [정통사주 로딩 개선 — Dawn Paper를 스켈레톤 호스트로 전환] 肆(사주풀이)
/// 챕터와 伍(실전 조언) 섹션처럼 saju_v3 백엔드 3종 응답(report/interpret/
/// narrative)에 의존하는 영역의 상태. 壹·貳·參·陸·柒 섹션과 챕터 三(대운의
/// 흐름 — 로컬 [SajuProfile.daewoon] 폴백이 항상 있음)은 이 상태와 무관하게
/// 항상 즉시 표시된다(로컬 계산 0ms 원칙).
///
/// - [ready]: 실제 문장이 채워짐 — 그대로 렌더링.
/// - [loading]: 아직 관련 백엔드 응답이 오지 않음 — 스켈레톤(문단 모양 회색
///   블록) 렌더링, 기존 [_JeontongV3PartCard]/[_JeontongV3FocusDetail] 패턴과
///   동일한 톤.
/// - [error]: 관련 백엔드 호출이 모두 실패함 — 이 섹션만 에러 문구 +
///   재시도 버튼을 보여준다. 로컬 계산 섹션(壹·貳·參·陸·柒)은 이 상태와
///   무관하게 항상 정상 표시된다(부분 실패에도 화면 전체가 깨지지 않는다는
///   기존 원칙의 연장).
enum DawnSectionStatus { ready, loading, error }

class SajuResultData {
  final String categoryCode; // "A07"
  final String categoryHanja; // "命"
  final String categoryGroup; // "평생운 · 7번째 이야기"
  final String title; // "평생 자녀운"
  final String subtitle; // "자녀와의 인연..."

  final SajuDawnPillar timePillar; // 時
  final SajuDawnPillar dayPillar; // 日 (일간 포함)
  final SajuDawnPillar monthPillar; // 月
  final SajuDawnPillar yearPillar; // 年

  final IlganType ilgan;
  final String ilganDescription; // 성정 설명 문단

  final Map<SajuDawnElement, int> ohaengCounts;
  final String ohaengDiagnosis; // 진단문
  final int balanceScore; // 40 (%)

  final List<StoryChapter> chapters;
  final List<DaeunNode> daeunTimeline;

  final List<String> doList;
  final List<String> avoidList;

  /// [정통사주 로딩 개선 — Dawn Paper 스켈레톤 호스트] 伍(실전 조언) 섹션의
  /// 상태. [doList]/[avoidList]가 `interpret().actions` 응답에 의존하므로,
  /// Pipeline C(saju_v3)에서만 [DawnSectionStatus.loading]/[.error]가 될 수
  /// 있다. Pipeline A/B는 이미 동기 계산된 값이므로 항상 [.ready].
  final DawnSectionStatus adviceStatus;

  final LuckyItems lucky;
  final List<RelatedFortune> related;

  final String userRefId; // "#409670384"

  const SajuResultData({
    required this.categoryCode,
    required this.categoryHanja,
    required this.categoryGroup,
    required this.title,
    required this.subtitle,
    required this.timePillar,
    required this.dayPillar,
    required this.monthPillar,
    required this.yearPillar,
    required this.ilgan,
    required this.ilganDescription,
    required this.ohaengCounts,
    required this.ohaengDiagnosis,
    required this.balanceScore,
    required this.chapters,
    required this.daeunTimeline,
    required this.doList,
    required this.avoidList,
    this.adviceStatus = DawnSectionStatus.ready,
    required this.lucky,
    required this.related,
    required this.userRefId,
  });

  IlganTheme get ilganTheme => IlganTheme.of(ilgan);
}

/// [naming collision 회피] 원본 `Pillar` → `SajuDawnPillar`로 개명.
class SajuDawnPillar {
  final String stemHanja; // "甲"
  final String stemHangul; // "갑목"
  final SajuDawnElement stemElement;
  final String stemTip; // 툴팁 텍스트

  final String branchHanja; // "戌"
  final String branchHangul; // "술토"
  final SajuDawnElement branchElement;
  final String branchTip;

  const SajuDawnPillar({
    required this.stemHanja,
    required this.stemHangul,
    required this.stemElement,
    required this.stemTip,
    required this.branchHanja,
    required this.branchHangul,
    required this.branchElement,
    required this.branchTip,
  });
}

class StoryChapter {
  final String chapterNum; // "一", "二", "三", "四"
  final String title; // "총평 · 뿌리 깊은 나무의 자리"
  final List<StoryParagraph> paragraphs;
  final bool includeTimeline; // 챕터 3만 true

  /// [정통사주 로딩 개선 — Dawn Paper 스켈레톤 호스트] 이 챕터의 문장이
  /// 의존하는 saju_v3 응답(report part/narrative/interpret)의 로딩 상태.
  /// 챕터 三(대운의 흐름)은 saju_v3 PART7이 없어도 로컬
  /// [SajuProfile.daewoon] 폴백 문장이 항상 있으므로 실질적으로 항상
  /// [DawnSectionStatus.ready]다. Pipeline A/B는 이미 동기 계산된 값만
  /// 다루므로 항상 [.ready].
  final DawnSectionStatus status;

  const StoryChapter({
    required this.chapterNum,
    required this.title,
    required this.paragraphs,
    this.includeTimeline = false,
    this.status = DawnSectionStatus.ready,
  });
}

/// 이야기 문단 — 부분 하이라이트를 위해 Runs로 표현
class StoryParagraph {
  final List<StoryRun> runs;
  final bool dropCap; // 첫 글자 드롭캡 여부

  const StoryParagraph({required this.runs, this.dropCap = false});
}

class StoryRun {
  final String text;
  final bool hanjaHighlight; // true면 갈색+연한 배경 하이라이트

  const StoryRun(this.text, {this.hanjaHighlight = false});
}

class DaeunNode {
  final int ageStart; // 1, 18, 38, 58
  final String hanja; // "계묘", "갑진" ...
  final double position; // 0.0~1.0 (트랙 상 위치)
  final bool active;

  const DaeunNode({
    required this.ageStart,
    required this.hanja,
    required this.position,
    this.active = false,
  });
}

class LuckyItems {
  final LuckyColor color;
  final LuckyDirection direction;
  final List<int> numbers;
  final LuckyKeyword keyword;

  const LuckyItems({
    required this.color,
    required this.direction,
    required this.numbers,
    required this.keyword,
  });
}

class LuckyColor {
  final String name; // "라벤더"
  final String hex; // "#B8A6D8"
  final String note; // "부드러운 보라 계열"
  const LuckyColor({
    required this.name,
    required this.hex,
    required this.note,
  });
}

class LuckyDirection {
  final String name; // "남쪽 · 南"
  final double angle; // 라디안, 남쪽 = π
  final String note; // "부족한 火 보완"
  const LuckyDirection({
    required this.name,
    required this.angle,
    required this.note,
  });
}

class LuckyKeyword {
  final String hanja; // "導"
  final String name; // "이끌 도"
  final String note; // "뒤에서 받쳐주는 힘"
  const LuckyKeyword({
    required this.hanja,
    required this.name,
    required this.note,
  });
}

class RelatedFortune {
  final String code; // "A06"
  final String name; // "평생 배우자·결혼운"
  final String? routeName;
  const RelatedFortune({required this.code, required this.name, this.routeName});
}
