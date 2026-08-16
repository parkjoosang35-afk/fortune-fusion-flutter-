/// [정통사주 80종 · PHASE1~4 → 레거시 해석계층 어댑터]
///
/// 사용자 지시(j6, 11개 조건) 대응: 이 파일은 **계산을 다시 하지 않는다**.
/// [SajuProfile](PHASE1~4 신규 만세력 엔진이 이미 계산 완료한 값)을 입력받아,
/// 기존 해석 계층(`saju_interpreter.dart`/`saju_life_modules.dart`/
/// `saju_fortune_modules.dart`)이 소비하는 레거시 [SajuResult] 타입으로
/// **순수 필드 매핑만** 수행한다.
///
/// [절대 금지] 이 파일 안에서 오행/십신/대운/신강신약/합충형파해/신살을
/// 새로 계산하지 않는다. 모든 값은 [SajuProfile]에 이미 계산되어 있는
/// 필드를 그대로(또는 단순 포맷 변환만) 가져다 쓴다.
///
/// [예외: getGongmang() 재호출] 공망 표기는 `saju_engine.dart`의
/// `getGongmang(dayGan, dayZhi)` 순수 함수를 그대로 재호출해서 만든다.
/// 이 함수는 "일간+일지 2글자"만 입력받는 결정론적 조회 함수로,
/// [SinsalEntry] 목록 안에 이미 같은 계산 결과(공망 발동 위치)가 들어있지만
/// 레거시 문자열 포맷(`'戌亥 (술해)'`)을 정확히 복원하려면 원본 함수를
/// 그대로 호출하는 것이 값 재계산이 아니라 "이미 검증된 순수 함수의
/// 재사용"에 해당한다(§4 "어댑터는 단순 변환 계층" 원칙 안에서 허용되는
/// 범위 — 새로운 명리 판정 로직이 아니라 기존 3종 신살과 동일한 재사용
/// 패턴).
library;

import '../saju_engine.dart'
    show
        SajuResult,
        SajuPillar,
        SajuDayMaster,
        SajuLuckPillar,
        ganImage,
        getGongmang;
import 'saju_profile.dart';

/// [Pillar](신규) → [SajuPillar](레거시) 순수 필드 매핑.
SajuPillar _toSajuPillar(Pillar p) => SajuPillar(
  gan: p.stemHanja,
  zhi: p.branchHanja,
  kr: p.kr,
  element: '${p.stemElement}-${p.branchElement}',
);

/// [StrengthProfile.verdict]('신강'|'중화'|'신약', 순수 한글) →
/// 레거시 `dayMasterStrength` 문자열 포맷('身强(신강)'|'中和(중화)'|
/// '身弱(신약)')으로 단순 포맷 변환(재계산 아님 — 이미 판정된 verdict
/// 값을 그대로 문자열로 감싸기만 함).
String _strengthVerdictToLegacyFormat(String verdict) {
  switch (verdict) {
    case '신강':
      return '身强(신강)';
    case '중화':
      return '中和(중화)';
    case '신약':
      return '身弱(신약)';
    default:
      // 알 수 없는 verdict가 들어오면(이론상 발생 불가 — StrengthEngine이
      // 3종만 반환) 원본 값을 그대로 노출해 조용히 삼키지 않는다.
      return verdict;
  }
}

/// 레거시 3종 신살(천을귀인/문창귀인/역마)의 [SinsalEntry.id] 고정값.
/// [SinsalEngine.analyze]가 `findSinsal()`(레거시 함수)을 그대로 재사용해
/// 만든 id이므로 이 값과 항상 일치한다(sinsal_engine.dart 참고).
const List<String> _legacyThreeSinsalIds = ['天乙貴人', '文昌貴人', '驛馬'];

/// [SajuProfile.sinsal](신규, 20+종 [SinsalEntry] 리스트)에서 레거시
/// 3종만 필터링해 `'${한자}(${한글})'` 문자열 리스트로 재구성한다.
/// (레거시 `List<String> sinsal` 필드 포맷 복원 — 새로운 판정 없음.)
List<String> _extractLegacySinsalStrings(List<SinsalEntry> entries) {
  final byId = {for (final e in entries) e.id: e};
  return [
    for (final id in _legacyThreeSinsalIds)
      if (byId.containsKey(id)) '$id(${byId[id]!.nameKr})',
  ];
}

/// [profile.daewoon](신규 [DaewoonEntry] 리스트) → 레거시
/// [SajuLuckPillar] 리스트로 순수 필드 매핑(재계산 없음).
List<SajuLuckPillar> _toLuckPillars(List<DaewoonEntry> daewoon) => [
  for (final d in daewoon)
    SajuLuckPillar(
      startAge: d.startAge,
      startYear: d.startYear,
      ganZhi: d.pillar.hanja,
      ganZhiKr: d.pillar.kr,
    ),
];

/// [referenceDate] 기준 "현재 대운"을 찾는다 — 레거시
/// `SajuEngine.calculate()`의 동일 로직(세는 나이, `startAge <= age <
/// startAge+10`)을 그대로 재사용한다(새 판정 기준 도입 아님, 단순 검색).
///
/// [birthYear]는 실제 계산에 사용된 양력 출생연도([profile.solarDate]에서
/// 추출) — [BirthInfo.year]는 입력이 음력일 경우 음력 연도일 수 있어
/// 그대로 쓰면 안 된다(레거시는 항상 양력 [year] 인자를 사용했으므로
/// 동일하게 양력 기준으로 맞춘다).
({int currentAge, SajuLuckPillar? currentLuck}) _resolveCurrentLuck({
  required List<SajuLuckPillar> luckPillars,
  required int birthYear,
  required DateTime referenceDate,
}) {
  final currentAge = referenceDate.year - birthYear + 1;
  SajuLuckPillar? currentLuck;
  for (final lp in luckPillars) {
    if (lp.startAge <= currentAge && currentAge < lp.startAge + 10) {
      currentLuck = lp;
      break;
    }
  }
  return (currentAge: currentAge, currentLuck: currentLuck);
}

/// **[핵심 어댑터]** 검증 완료된 PHASE1~4 [SajuProfile]을 입력받아,
/// 기존 운세 해석 계층이 그대로 소비할 수 있는 레거시 [SajuResult]로
/// 변환한다.
///
/// [계산 재실행 없음] 이 함수는 [profile]에 이미 채워진 값만 읽어서
/// 필드를 옮기거나(오행/십신/대운 등) 단순 포맷만 바꾼다(신강신약 문자열,
/// 신살 3종 필터링, 공망 문자열 재구성 — 모두 "이미 계산된 값의 표현
/// 변경"이지 "새 명리 판정"이 아니다).
///
/// [선행 조건] [profile]은 PHASE 2~4가 모두 완료된 상태여야 한다
/// (fiveElements/tenGods/sinsal/strength/daewoon이 모두 non-null).
/// 완료되지 않은 프로필을 넘기면 [StateError]를 던진다 — 이중 계산으로
/// 빈 값을 임의로 채우지 않는다.
///
/// [referenceDate]는 "현재 대운"을 판정하는 기준 시점(기본값
/// `DateTime.now()`) — 레거시 `SajuEngine.calculate(referenceDate: ...)`와
/// 동일한 역할.
SajuResult sajuResultFromProfile(
  SajuProfile profile, {
  DateTime? referenceDate,
}) {
  final fiveElements = profile.fiveElements;
  final tenGods = profile.tenGods;
  final sinsal = profile.sinsal;
  final strength = profile.strength;
  final daewoon = profile.daewoon;

  if (fiveElements == null ||
      tenGods == null ||
      sinsal == null ||
      strength == null ||
      daewoon == null) {
    throw StateError(
      'sajuResultFromProfile(): PHASE2~4가 완료되지 않은 SajuProfile입니다 '
      '(fiveElements/tenGods/sinsal/strength/daewoon 중 null 존재). '
      'Phase2AnalysisEngine → Phase3AnalysisEngine → Phase4AnalysisEngine '
      '순서로 먼저 완료하세요.',
    );
  }

  final dayPillar = profile.dayPillar;
  final dayGan = dayPillar.stemHanja;
  final dayZhi = dayPillar.branchHanja;

  final luckPillars = _toLuckPillars(daewoon);

  // 실제 계산에 쓰인 양력 출생연도 — profile.solarDate 형식은
  // 'YYYY-MM-DD HH:mm'로 고정되어 있다(ManseryeokCoreEngine 참고).
  final birthYear = int.parse(profile.solarDate.substring(0, 4));
  final luck = _resolveCurrentLuck(
    luckPillars: luckPillars,
    birthYear: birthYear,
    referenceDate: referenceDate ?? DateTime.now(),
  );

  return SajuResult(
    gender: profile.birthInfo.gender,
    birthSolar: profile.solarDate,
    birthLunar: profile.lunarDate,
    pillars: {
      'year': _toSajuPillar(profile.yearPillar),
      'month': _toSajuPillar(profile.monthPillar),
      'day': _toSajuPillar(profile.dayPillar),
      'hour': _toSajuPillar(profile.hourPillar),
    },
    dayMaster: SajuDayMaster(
      gan: dayGan,
      kr: dayPillar.stemKr,
      element: dayPillar.stemElement,
      yinYang: dayPillar.stemYinYang,
      image: ganImage[dayGan]!,
    ),
    dayMasterStrength: _strengthVerdictToLegacyFormat(strength.verdict),
    fiveElementsCount: fiveElements.totalCount,
    tenGods: tenGods,
    sinsal: _extractLegacySinsalStrings(sinsal),
    gongmang: getGongmang(dayGan, dayZhi),
    luckPillars: luckPillars,
    currentAge: luck.currentAge,
    currentLuck: luck.currentLuck,
  );
}
