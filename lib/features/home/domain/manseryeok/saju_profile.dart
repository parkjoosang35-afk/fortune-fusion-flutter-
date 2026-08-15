/// [정통사주 80종 전용 신규 엔진] 사주 원국 단일 기준 데이터 객체.
///
/// 37번 지시 §6 "사주 원국 데이터 객체를 먼저 완성한다"에 대응한다.
/// 이 클래스는 **한 번 계산한 사주를 80종 전체가 공통으로 재사용**하기
/// 위한 불변(immutable) 값 객체다 — 80종 각각이 생년월일을 다시 계산하지
/// 않는다(§17 원칙).
///
/// [절대 경계] 이 파일은 신규 "정통사주 전용 만세력 엔진"
/// (`lib/features/home/domain/manseryeok/`) 소속이며, 기존 레거시
/// `/ai-fortune/saju/*`(`lib/features/fortune/saju/`, 해시 기반 명식 +
/// LLM 해석)와는 완전히 분리된 별개 네임스페이스다. 기존
/// `saju_engine.dart`(`SajuResult`)는 삭제/수정하지 않고 그대로 둔다 —
/// [SajuProfile]은 Phase 2~5에서 필요한 확장 필드(합충형파해/십이운성/
/// 지장간십신/신강신약/용희기구 등)를 갖춘 "상위 호환" 신규 모델이다.
library;

import 'manseryeok_policy.dart';

/// 사주 4주 중 하나(년/월/일/시)의 천간+지지 조합.
class Pillar {
  const Pillar({
    required this.stemHanja,
    required this.branchHanja,
    required this.stemKr,
    required this.branchKr,
    required this.stemElement,
    required this.stemYinYang,
    required this.branchElement,
    required this.branchYinYang,
    required this.jiaZiIndex,
  });

  /// 천간 한자(예: '甲').
  final String stemHanja;

  /// 지지 한자(예: '子').
  final String branchHanja;

  /// 천간 한글(예: '갑').
  final String stemKr;

  /// 지지 한글(예: '자').
  final String branchKr;

  /// 천간 오행(목/화/토/금/수).
  final String stemElement;

  /// 천간 음양(양/음).
  final String stemYinYang;

  /// 지지 오행(목/화/토/금/수).
  final String branchElement;

  /// 지지 음양(양/음).
  final String branchYinYang;

  /// 60갑자 순번(0~59, 갑자=0).
  final int jiaZiIndex;

  /// 한글 표기(예: "갑자").
  String get kr => '$stemKr$branchKr';

  /// 한자 표기(예: "甲子").
  String get hanja => '$stemHanja$branchHanja';

  @override
  String toString() => kr;
}

/// 출생 정보(계산 정책이 적용되기 전의 원본 입력값 보존).
class BirthInfo {
  const BirthInfo({
    required this.calendarType,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.isLeapMonth,
    required this.gender,
    this.birthPlace,
    this.utcOffsetMinutes = kstUtcOffsetMinutes,
  });

  /// 입력이 양력인지 음력인지.
  final CalendarInputType calendarType;

  /// 입력 연/월/일/시/분 — [calendarType]에 따라 양력 또는 음력 값.
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  /// 음력 입력일 때 윤달 여부(양력 입력이면 항상 false).
  final bool isLeapMonth;

  /// 'male' | 'female'.
  final String gender;

  /// 출생지 표기(선택, 예: "서울" | "New York, USA"). 해외 출생 확장용.
  final String? birthPlace;

  /// 출생지 표준시의 UTC 오프셋(분). 기본값은 KST(+540분).
  /// [manseryeok_policy.dart]의 시간대 정책 참고 — 이 값으로 입력된
  /// 벽시계 시각을 KST 벽시계 시각으로 환산한 뒤 만세력 계산에 투입한다.
  final int utcOffsetMinutes;
}

/// 오행 개수/강약 분석 결과 (Phase 2).
class FiveElementsProfile {
  const FiveElementsProfile({
    required this.stemCount,
    required this.branchCount,
    required this.hiddenStemCount,
    required this.totalCount,
    required this.dominant,
    required this.deficient,
    required this.isImbalanced,
  });

  /// 천간 4글자만의 오행 카운트.
  final Map<String, int> stemCount;

  /// 지지 4글자만의 오행 카운트(본기 기준, 지장간 미포함).
  final Map<String, int> branchCount;

  /// 지장간까지 포함한 오행 카운트(가중치 적용, Phase 2에서 정의).
  final Map<String, double> hiddenStemCount;

  /// 천간+지지 단순 합산(기존 saju_engine.dart의 elementsCount와 동일 —
  /// 회귀 검증용으로 유지).
  final Map<String, int> totalCount;

  /// 과다(過多) 오행 목록(개수 기준 임계치 초과).
  final List<String> dominant;

  /// 부족(不足) 오행 목록(개수 0인 오행).
  final List<String> deficient;

  /// 편중(偏重) 여부 — 특정 오행이 없거나 지나치게 많은 경우.
  final bool isImbalanced;
}

/// 지지 하나에 대한 지장간 + 각 지장간의 십신을 함께 담는다(Phase 2 §8).
class HiddenStemEntry {
  const HiddenStemEntry({
    required this.branch,
    required this.stems,
  });

  /// 이 지장간이 속한 지지(년/월/일/시 중 어디인지는 상위 Map 키로 구분).
  final String branch;

  /// 여기(餘氣)/중기(中氣)/정기(正氣, 본기) 순서의 지장간 목록.
  /// `lunar` 패키지의 `ZHI_HIDE_GAN` 순서를 그대로 따른다(예: 丑 →
  /// [己(정기 아님, 패키지 순서상 첫 원소), 癸, 辛] — 정확한 여기/중기/
  /// 본기 라벨링은 [HiddenStemDetail.role]에서 명시한다).
  final List<HiddenStemDetail> stems;
}

/// 지장간 개별 항목 — 십신까지 계산된 상태.
class HiddenStemDetail {
  const HiddenStemDetail({
    required this.stemHanja,
    required this.stemKr,
    required this.role,
    required this.tenGod,
  });

  final String stemHanja;
  final String stemKr;

  /// '여기' | '중기' | '본기'.
  final String role;

  /// 이 지장간이 일간 기준으로 갖는 십신.
  final String tenGod;
}

/// 십이운성 결과(년/월/일/시 지지 각각에 대해, 일간 기준) — Phase 2 §10.
class TwelveStagesProfile {
  const TwelveStagesProfile({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
  });

  final String year;
  final String month;
  final String day;
  final String hour;

  Map<String, String> toMap() => {
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
      };
}

/// 합충형파해 관계 1건 — "어떤 글자 + 어떤 글자 + 어떤 관계 + 어느 위치"
/// 형태로 저장한다(37번 지시 §9).
class SajuRelationship {
  const SajuRelationship({
    required this.type,
    required this.characters,
    required this.positions,
    required this.resultElement,
  });

  /// 관계 종류. 예: '천간합' | '천간충' | '육합' | '삼합' | '방합' |
  /// '지지충' | '형' | '파' | '해' | '원진' | '귀문'.
  final String type;

  /// 관계를 이루는 한자 글자들(천간 또는 지지, 2~3글자).
  final List<String> characters;

  /// 각 글자가 원국에서 어느 위치(년간/월간/일간/시간/년지/월지/일지/시지)에
  /// 있었는지. [characters]와 순서가 대응한다.
  final List<String> positions;

  /// 합화(合化) 결과 오행(합충형파해 중 '합' 계열에만 존재, 없으면 빈 문자열).
  final String resultElement;
}

/// 신살 1건.
class SinsalEntry {
  const SinsalEntry({
    required this.id,
    required this.nameKr,
    required this.nameHanja,
    required this.basis,
    required this.foundOn,
  });

  /// 신살 고유 ID(sinsal_rules.json의 키와 일치).
  final String id;
  final String nameKr;
  final String nameHanja;

  /// 판정 기준(예: '일간' | '일지' | '년지').
  final String basis;

  /// 신살이 발견된 위치(년지/월지/일지/시지 등).
  final List<String> foundOn;
}

/// 신강/신약 정밀 분석 결과(Phase 3 §12) — 계산 과정을 디버깅할 수 있도록
/// 중간 결과까지 모두 보존한다.
class StrengthProfile {
  const StrengthProfile({
    required this.verdict,
    required this.score,
    required this.monthOrderScore,
    required this.rootScore,
    required this.supportScore,
    required this.controlScore,
    required this.drainScore,
    required this.detail,
  });

  /// '신강' | '중화' | '신약'.
  final String verdict;

  /// 종합 점수(0.0~1.0, 높을수록 신강).
  final double score;

  /// 월령(月令) 득실 점수 — 일간이 월지에서 득령했는지.
  final double monthOrderScore;

  /// 통근(通根) 점수 — 일간이 지지에 뿌리를 내렸는지.
  final double rootScore;

  /// 생조(生助) 점수 — 비겁+인성의 조력.
  final double supportScore;

  /// 극제(剋制) 점수 — 관살의 억제.
  final double controlScore;

  /// 설기(泄氣) 점수 — 식상+재성의 기운 유출.
  final double drainScore;

  /// 디버깅용 상세 로그(계산 과정 문자열 목록).
  final List<String> detail;
}

/// 용신/희신/기신/구신 분석 결과(Phase 3 §13).
class YongsinProfile {
  const YongsinProfile({
    required this.method,
    required this.yongsin,
    required this.heesin,
    required this.gisin,
    required this.gusin,
    required this.reasoning,
  });

  /// 판단 방식('억부' | '조후' | '억부+조후').
  final String method;

  final String yongsin;
  final String heesin;
  final String gisin;
  final String gusin;

  /// 판단 근거 설명(추적 가능성 확보 — 37번 지시 §13).
  final String reasoning;
}

/// 대운 1건(Phase 4 §14) — 패키지 네이티브 계산 결과를 그대로 감싼다.
class DaewoonEntry {
  const DaewoonEntry({
    required this.index,
    required this.startAge,
    required this.startYear,
    required this.pillar,
    required this.tenGodStem,
    required this.tenGodBranch,
  });

  final int index;
  final int startAge;
  final int startYear;
  final Pillar pillar;
  final String tenGodStem;
  final String tenGodBranch;
}

/// 세운 1건(Phase 4 §15).
class SewoonEntry {
  const SewoonEntry({
    required this.year,
    required this.pillar,
    required this.tenGodStem,
    required this.tenGodBranch,
  });

  final int year;
  final Pillar pillar;
  final String tenGodStem;
  final String tenGodBranch;
}

/// 월운 1건(Phase 4 §16).
class WolwoonEntry {
  const WolwoonEntry({
    required this.year,
    required this.month,
    required this.pillar,
    required this.tenGodStem,
    required this.tenGodBranch,
    required this.jieQiName,
  });

  final int year;
  final int month;
  final Pillar pillar;
  final String tenGodStem;
  final String tenGodBranch;

  /// 이 월주가 시작되는 절기 이름(예: '입춘', '경칩').
  final String jieQiName;
}

/// [SajuProfile] — 정통사주 80종의 단일 기준 데이터.
///
/// 37번 지시 §6의 필드 목록을 그대로 반영한다. Phase 1에서는
/// birthInfo/pillars/기본 파생값까지만 채우고, Phase 2~4에서 나머지
/// 필드(오행/십신/지장간/합충형파해/십이운성/신살/신강신약/용희기구/
/// 대운/세운/월운)를 점진적으로 채운다 — 이 클래스는 처음부터 전체
/// 필드를 nullable로 선언해, 아직 계산되지 않은 단계에서는 null을
/// 유지하고 계산이 끝난 단계부터 값이 채워지는 방식으로 설계한다.
class SajuProfile {
  const SajuProfile({
    required this.engineVersion,
    required this.birthInfo,
    required this.solarDate,
    required this.lunarDate,
    required this.lunarLeapMonth,
    required this.utcOffsetMinutes,
    required this.ziHourPolicy,
    required this.daewoonStartPrecision,
    required this.yearPillar,
    required this.monthPillar,
    required this.dayPillar,
    required this.hourPillar,
    this.fiveElements,
    this.hiddenStems,
    this.tenGods,
    this.twelveStages,
    this.relationships,
    this.sinsal,
    this.strength,
    this.yongsin,
    this.daewoon,
    this.sewoon,
    this.wolwoon,
  });

  // ── 엔진 버전(37번 지시 §8 대응 — jeontong_saju 전용 버전 네임스페이스) ──
  final String engineVersion;

  // ── 출생/캘린더 정보 ──
  final BirthInfo birthInfo;

  /// 양력 날짜 문자열(YYYY-MM-DD HH:mm, KST 벽시계 기준으로 정규화된 값).
  final String solarDate;

  /// 음력 날짜 문자열(패키지 `Lunar.toString()` 그대로, 윤달이면 '闰' 포함).
  final String lunarDate;

  /// 음력 윤달 여부(계산에 실제 반영된 값 — birthInfo.isLeapMonth와
  /// 다를 수 있음: 예컨대 양력 입력을 음력으로 환산했을 때 그 달이
  /// 마침 윤달인 경우는 없으므로 통상 birthInfo와 일치하지만, 별도
  /// 필드로 분리해 계산 결과를 명시적으로 보존한다).
  final bool lunarLeapMonth;

  /// 실제 계산에 사용된 시간대 오프셋(분) — [BirthInfo.utcOffsetMinutes]
  /// 그대로 보존(추적성).
  final int utcOffsetMinutes;

  /// 이 프로필 계산에 적용된 자시 정책.
  final ZiHourPolicy ziHourPolicy;

  /// 이 프로필 계산에 적용된 대운 시작시점 정밀도 정책.
  final DaewoonStartPrecision daewoonStartPrecision;

  // ── 사주 8글자 ──
  final Pillar yearPillar;
  final Pillar monthPillar;
  final Pillar dayPillar;
  final Pillar hourPillar;

  // ── Phase 2: 원국 분석 ──
  final FiveElementsProfile? fiveElements;

  /// key: 'year' | 'month' | 'day' | 'hour'.
  final Map<String, HiddenStemEntry>? hiddenStems;

  /// key: 'year_gan' | 'month_gan' | 'hour_gan' | 'year_zhi' | 'month_zhi' |
  /// 'day_zhi' | 'hour_zhi' (기존 saju_engine.dart tenGods 키와 동일 —
  /// 회귀 방지). 지장간 기반 십신은 [hiddenStems]의 각 항목에서 조회한다.
  final Map<String, String>? tenGods;

  final TwelveStagesProfile? twelveStages;

  /// 합충형파해 전체 목록.
  final List<SajuRelationship>? relationships;

  final List<SinsalEntry>? sinsal;

  // ── Phase 3: 고급 분석 ──
  final StrengthProfile? strength;
  final YongsinProfile? yongsin;

  // ── Phase 4: 운의 흐름 ──
  final List<DaewoonEntry>? daewoon;
  final List<SewoonEntry>? sewoon;
  final List<WolwoonEntry>? wolwoon;

  /// 사주 8글자를 년/월/일/시 순서로 반환(합충형파해/신살 계산 시
  /// 위치 라벨링에 사용).
  Map<String, Pillar> get pillarsByPosition => {
        'year': yearPillar,
        'month': monthPillar,
        'day': dayPillar,
        'hour': hourPillar,
      };

  /// 일간(日干) — 십신/신강신약/용희기구 판정의 기준.
  String get dayStemHanja => dayPillar.stemHanja;

  SajuProfile copyWith({
    FiveElementsProfile? fiveElements,
    Map<String, HiddenStemEntry>? hiddenStems,
    Map<String, String>? tenGods,
    TwelveStagesProfile? twelveStages,
    List<SajuRelationship>? relationships,
    List<SinsalEntry>? sinsal,
    StrengthProfile? strength,
    YongsinProfile? yongsin,
    List<DaewoonEntry>? daewoon,
    List<SewoonEntry>? sewoon,
    List<WolwoonEntry>? wolwoon,
  }) {
    return SajuProfile(
      engineVersion: engineVersion,
      birthInfo: birthInfo,
      solarDate: solarDate,
      lunarDate: lunarDate,
      lunarLeapMonth: lunarLeapMonth,
      utcOffsetMinutes: utcOffsetMinutes,
      ziHourPolicy: ziHourPolicy,
      daewoonStartPrecision: daewoonStartPrecision,
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
      fiveElements: fiveElements ?? this.fiveElements,
      hiddenStems: hiddenStems ?? this.hiddenStems,
      tenGods: tenGods ?? this.tenGods,
      twelveStages: twelveStages ?? this.twelveStages,
      relationships: relationships ?? this.relationships,
      sinsal: sinsal ?? this.sinsal,
      strength: strength ?? this.strength,
      yongsin: yongsin ?? this.yongsin,
      daewoon: daewoon ?? this.daewoon,
      sewoon: sewoon ?? this.sewoon,
      wolwoon: wolwoon ?? this.wolwoon,
    );
  }
}
