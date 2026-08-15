/// [정통사주 80종 전용 신규 엔진] PHASE 2 원국 분석 오케스트레이터.
///
/// 37번 지시 §6 "SajuProfile 데이터 객체 ... 80종의 단일 기준 데이터"에
/// 대응한다. [ManseryeokCoreEngine.buildProfileWithCore]가 만든 PHASE 1
/// 결과([SajuProfile] + [ManseryeokCoreResult])를 입력받아, PHASE 2의
/// 5개 하위 엔진(오행/지장간+십신/십이운성/합충형파해/신살)을 순서대로
/// 호출하고 그 결과를 [SajuProfile.copyWith]로 채워 완성된 프로필을
/// 반환한다.
///
/// [절대 원칙] 이 파일 자체는 어떤 계산 로직도 새로 정의하지 않는다 —
/// 오직 이미 검증된 5개 엔진(`FiveElementsEngine`/`HiddenStemsEngine`/
/// `TwelveStagesEngine`/`RelationshipsEngine`/`SinsalEngine`)을 순서대로
/// 호출해 결과를 조립하는 배선(wiring) 역할만 한다.
library;

import 'five_elements_engine.dart' show FiveElementsEngine;
import 'hidden_stems_engine.dart' show HiddenStemsEngine;
import 'manseryeok_core_engine.dart' show ManseryeokCoreResult;
import 'relationships_engine.dart' show RelationshipsEngine;
import 'saju_profile.dart';
import 'sinsal_engine.dart' show SinsalEngine;
import 'twelve_stages_engine.dart' show TwelveStagesEngine;

class Phase2AnalysisEngine {
  Phase2AnalysisEngine._();

  /// [baseProfile]은 PHASE 1에서 만들어진 사주 8글자까지 채워진
  /// [SajuProfile]이어야 하고, [core]는 같은 계산에서 나온
  /// [ManseryeokCoreResult](십이운성 계산에 필요한 `eightChar` 보유)여야
  /// 한다 — 반드시 [ManseryeokCoreEngine.buildProfileWithCore] 한 번의
  /// 호출에서 나온 짝을 그대로 전달해야 재계산 없이 일관된 결과가 나온다.
  static SajuProfile analyze({
    required SajuProfile baseProfile,
    required ManseryeokCoreResult core,
  }) {
    final yearPillar = baseProfile.yearPillar;
    final monthPillar = baseProfile.monthPillar;
    final dayPillar = baseProfile.dayPillar;
    final hourPillar = baseProfile.hourPillar;
    final dayStemHanja = baseProfile.dayStemHanja;

    final fiveElements = FiveElementsEngine.analyze(
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );

    final hiddenStems = HiddenStemsEngine.analyze(
      dayStemHanja: dayStemHanja,
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );

    final tenGods = HiddenStemsEngine.analyzeStemAndBranchTenGods(
      dayStemHanja: dayStemHanja,
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );

    final twelveStages = TwelveStagesEngine.analyze(core.eightChar);

    final relationships = RelationshipsEngine.analyze(
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );

    final sinsal = SinsalEngine.analyze(
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );

    return baseProfile.copyWith(
      fiveElements: fiveElements,
      hiddenStems: hiddenStems,
      tenGods: tenGods,
      twelveStages: twelveStages,
      relationships: relationships,
      sinsal: sinsal,
    );
  }
}
