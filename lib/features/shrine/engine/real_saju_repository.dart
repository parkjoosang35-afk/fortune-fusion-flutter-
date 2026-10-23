// 신당(THE SHRINE) 정통사주 연동 — 후보 A 확정(로컬 만세력 엔진, 서버
// saju-renewal API 미사용) 구현체.
//
// [설계 원칙 — shrine_engine.dart 상단 주석과 동일]
//  신당은 사주를 계산하지 않는다. 이 클래스는 신통방통이 이미 보유한
//  검증된 로컬 PHASE1~4 만세력 엔진([JeontongReportBuilder])과 그 해석
//  계층([SajuInterpreter])을 호출해 값을 "변환"만 한다 — 새로운 명리
//  판정 로직을 추가하지 않는다.
//
// [사용자 확정 사항] "후보 A — 앱 내 로컬 만세력 엔진(무료, 즉시 계산)"
//  을 채택했다. 서버 saju-renewal API는 호출하지 않는다.
//
// [주제 ↔ 해석 함수 매핑 — 사용자에게 제시하고 승인받은 매핑안]
//  money ← WealthInterpretation (interpretWealth)        — 정재/편재 개수 + 신강신약
//  love  ← LoveInterpretation   (interpretLove)           — 배우자성 개수
//  fate  ← CareerInterpretation + DayMasterInterpretation — 관인상생/식상격/무관무인
//  flow  ← CurrentLuckInterpretation (interpretCurrentLuck) — 현재 대운 간지
//  score는 verdict/structure 문자열을 등급별 점수 구간으로 매핑한다.
//  strengths/cautions는 SajuInterpreter.interpretDayMaster()가 이미
//  생성하는 strengths/weaknesses를 그대로 재사용한다(새로 만들지 않음).
import '../../home/domain/jeontong_eighty_report_builder.dart';
import '../../home/domain/saju_engine.dart' as legacy;
import '../../home/domain/saju_interpreter.dart';
import 'shrine_engine.dart' as shrine;

/// 레거시 [legacy.SajuResult.fiveElementsCount]는 한글 키('목'/'화'/'토'/
/// '금'/'수')를 쓰지만, 신당 [shrine.SajuResult.elements]는 한자 키
/// ('木'/'火'/'土'/'金'/'水')를 쓴다(웹 shrine-engine.js SAMPLES와 동일
/// 스펙). 새 값을 계산하지 않고 키 표기만 바꾸는 순수 변환.
const Map<String, String> _elementHanja = {
  '목': '木',
  '화': '火',
  '토': '土',
  '금': '金',
  '수': '水',
};

/// 레거시 [legacy.SajuDayMaster.element](한글 '목'/'화'/'토'/'금'/'수')
/// → 신당 한자 키.
String _dayElementHanja(String krElement) => _elementHanja[krElement] ?? krElement;

/// WealthInterpretation.verdict(5단계) → 0~1 점수 구간.
/// 신당 recommend()는 score >= .6 이고 note가 있어야 추천하므로, "재물
/// 기운이 뚜렷하다"고 판정되는 두 verdict(재왕신강/신강용재)만 .6 이상을
/// 받도록 구간을 나눴다 — 새 명리 판정이 아니라 이미 나온 verdict 문자열을
/// 점수 구간에 배치하는 표시용 변환이다.
double _moneyScore(String verdict) {
  switch (verdict) {
    case '재왕신강':
      return .88;
    case '신강용재':
      return .66;
    case '재다신약':
      return .52;
    case '재약신약':
      return .38;
    case '무재격':
    default:
      return .2;
  }
}

/// LoveInterpretation.count(배우자성 개수) → 0~1 점수 구간.
/// count==1(정식·안정된 인연)을 가장 뚜렷한 근거로 보아 최고점을 준다.
double _loveScore(int spouseCount) {
  switch (spouseCount) {
    case 1:
      return .84;
    case 2:
      return .7;
    case 0:
      return .45;
    default:
      return .58; // 3개 이상 — 과다, 근거는 있으나 1개보다는 낮게
  }
}

/// CareerInterpretation.structure(4단계) → 0~1 점수 구간.
/// 구조가 뚜렷할수록(관인상생/식상격처럼 확실한 격이 잡힐수록) 높은 점수.
double _fateScore(String structure) {
  switch (structure) {
    case '관인상생(官印相生)':
      return .82;
    case '식상격':
      return .74;
    case '무관무인':
      return .6;
    case '혼합격':
    default:
      return .48;
  }
}

/// CurrentLuckInterpretation — message가 있으면(대운 정보 정상 계산됨)
/// 흐름 주제는 항상 유의미한 근거가 있다고 본다.
double _flowScore(CurrentLuckInterpretation luck) => luck.message == null ? 0 : .72;

/// [후보 A] 신통방통 로컬 PHASE1~4 만세력 엔진을 그대로 호출하는 신당
/// SajuRepository 구현체. 서버 API 호출이 없으므로 즉시(동기적으로 가까운
/// 속도) 계산되고, 네트워크 실패 개념이 없다 — birth 파싱 실패/엔진 예외만
/// null로 귀결된다.
///
/// [성별 처리] 신당 ShrineState에는 성별 필드가 없다(웹 프로토타입도
/// 성별을 묻지 않음). CareerInterpretation/DayMasterInterpretation/
/// CurrentLuckInterpretation은 성별과 무관하지만, LoveInterpretation(배우자성)
/// 은 성별에 따라 재성/관성 중 무엇을 볼지가 달라진다. 신당에서 성별을
/// 새로 묻는 것은 설계 범위 밖이므로, [defaultGender](기본 'female' —
/// 신당 메인 캐릭터가 여성 손님을 상정한 샘플 데이터와 동일 기준)를
/// 받아 사용한다. 추후 신당이 신통방통 로그인 회원과 연결되면(ConnectScreen
/// 경로) 실제 [UserModel.gender]를 주입할 수 있도록 생성자 파라미터로
/// 노출해 둔다.
class RealSajuRepository implements shrine.SajuRepository {
  RealSajuRepository({this.defaultGender = 'female'});

  /// 'male' | 'female'. ConnectScreen으로 회원이 연결된 경우 실제
  /// UserModel.gender를 변환해 넘겨줄 수 있다(app.dart에서 주입).
  final String defaultGender;

  @override
  Future<shrine.SajuResult?> fetch({
    required String birth,
    String? time,
    String calendar = '양력',
  }) async {
    // 웹 프로토타입과 동일: 생년월일이 없으면 계산하지 않는다(엔진이 주지
    // 않는 값은 null → 화면에서 생략. 지어내지 않는다 — shrine_engine.dart
    // 상단 원칙).
    if (birth.isEmpty) return null;

    // InfoScreen/ConnectScreen이 쓰는 'YYYY.MM.DD' 포맷을 파싱한다.
    final parts = birth.split('.');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final hourUnknown = time == null || time == '모름';
    int hour = 12, minute = 0;
    if (!hourUnknown) {
      final tParts = time.split(':');
      if (tParts.length == 2) {
        hour = int.tryParse(tParts[0]) ?? 12;
        minute = int.tryParse(tParts[1]) ?? 0;
      }
    }

    try {
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: DateTime(year, month, day, hour, minute),
        gender: defaultGender,
        // 신당은 음력 입력 UI가 없다(InfoScreen은 항상 "양력 기준" 안내).
        isLunar: false,
        referenceDate: DateTime.now(),
      );
      final legacySaju = built.saju;

      // SajuRules가 아직 preload되지 않았으면(main.dart의 fire-and-forget
      // 로드가 끝나기 전) 해석 계층을 호출할 수 없다 — 이 경우 원국
      // 정보만이라도 반환하고 해석(topics/temperament/strengths)은 비운다.
      final rules = SajuRules.cachedOrNull;
      if (rules == null) {
        return _toShrineResult(legacySaju, hourUnknown: hourUnknown);
      }

      final dayMaster = SajuInterpreter.interpretDayMaster(legacySaju, rules);
      final wealth = SajuInterpreter.interpretWealth(legacySaju);
      final career = SajuInterpreter.interpretCareer(legacySaju, rules);
      final love = SajuInterpreter.interpretLove(legacySaju);
      final currentLuck = SajuInterpreter.interpretCurrentLuck(
        legacySaju,
        rules,
      );

      return _toShrineResult(
        legacySaju,
        hourUnknown: hourUnknown,
        dayMaster: dayMaster,
        wealth: wealth,
        career: career,
        love: love,
        currentLuck: currentLuck,
      );
    } catch (_) {
      // [엔진 경계 원칙] 신당은 계산 실패를 화면에서 지어내지 않는다 —
      // null을 반환하면 SajuScreen이 "사주를 불러오지 못했습니다" 안내로
      // 자연스럽게 폴백한다(screens_v3.dart _SajuState 기존 분기).
      return null;
    }
  }

  shrine.SajuResult _toShrineResult(
    legacy.SajuResult s, {
    required bool hourUnknown,
    DayMasterInterpretation? dayMaster,
    WealthInterpretation? wealth,
    CareerInterpretation? career,
    LoveInterpretation? love,
    CurrentLuckInterpretation? currentLuck,
  }) {
    final pillars = <String, String?>{
      'year': '${s.pillars['year']!.gan}${s.pillars['year']!.zhi}',
      'month': '${s.pillars['month']!.gan}${s.pillars['month']!.zhi}',
      'day': '${s.pillars['day']!.gan}${s.pillars['day']!.zhi}',
      'hour': hourUnknown
          ? null
          : '${s.pillars['hour']!.gan}${s.pillars['hour']!.zhi}',
    };

    final elements = <String, int>{
      for (final e in s.fiveElementsCount.entries)
        (_elementHanja[e.key] ?? e.key): e.value,
    };
    // 신당 화면(SajuScreen)은 木火土金水 5개 막대를 모두 그리므로, 엔진이
    // 0개로 계산한 오행도 0으로 명시해 둔다(키 누락 시 막대가 사라지지
    // 않도록).
    for (final hanja in _elementHanja.values) {
      elements.putIfAbsent(hanja, () => 0);
    }

    final topics = <String, shrine.TopicReading>{};
    if (wealth != null) {
      topics['money'] = shrine.TopicReading(_moneyScore(wealth.verdict), wealth.message);
    }
    if (love != null) {
      topics['love'] = shrine.TopicReading(_loveScore(love.count), love.message);
    }
    if (career != null) {
      topics['fate'] = shrine.TopicReading(_fateScore(career.structure), career.message);
    }
    if (currentLuck != null) {
      topics['flow'] = shrine.TopicReading(_flowScore(currentLuck), currentLuck.message);
    }

    return shrine.SajuResult(
      pillars: pillars,
      dayStem: s.dayMaster.kr,
      dayElement: _dayElementHanja(s.dayMaster.element),
      dayLabel: dayMaster != null
          ? '${dayMaster.title} · ${dayMaster.nature}'
          : '${s.dayMaster.kr}(${s.dayMaster.image})',
      elements: elements,
      temperament: dayMaster?.personality,
      // [재사용 원칙] 새로 만들지 않고 SajuInterpreter.interpretDayMaster()가
      // 이미 생성한 strengths/weaknesses를 그대로 옮긴다.
      strengths: dayMaster?.strengths ?? const [],
      cautions: dayMaster?.weaknesses ?? const [],
      topics: topics,
      hourUnknown: hourUnknown,
      source: 'STB_SAJU_ENGINE',
    );
  }
}
