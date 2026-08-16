/// [정통사주 80종 전용 신규 엔진] PHASE 3 고급 명리 분석 오케스트레이터.
///
/// 37번 지시 §12/§13에 대응한다. PHASE 2까지 완료된 [SajuProfile]
/// (fiveElements/hiddenStems/tenGods가 채워진 상태)을 입력받아,
/// [StrengthEngine](신강신약)과 [YongsinEngine](용신희신기신구신, 억부+
/// 조후 종합)을 순서대로 호출하고 결과를 [SajuProfile.copyWith]로 채워
/// 반환한다.
///
/// [필수 선행 조건] [baseProfile]은 반드시 [Phase2AnalysisEngine.analyze]를
/// 거쳐 `fiveElements`/`hiddenStems`/`tenGods`가 이미 채워진 상태여야
/// 한다 — 이 엔진은 그 값들을 재계산하지 않고 그대로 재사용한다.
library;

import 'saju_profile.dart';
import 'strength_engine.dart' show StrengthEngine;
import 'yongsin_engine.dart' show YongsinEngine;

class Phase3AnalysisEngine {
  Phase3AnalysisEngine._();

  static SajuProfile analyze({required SajuProfile baseProfile}) {
    final fiveElements = baseProfile.fiveElements;
    final hiddenStems = baseProfile.hiddenStems;
    final tenGods = baseProfile.tenGods;

    if (fiveElements == null || hiddenStems == null || tenGods == null) {
      throw StateError(
        'Phase3AnalysisEngine.analyze()는 PHASE 2 결과'
        '(fiveElements/hiddenStems/tenGods)가 이미 채워진 SajuProfile을 '
        '요구합니다 — 먼저 Phase2AnalysisEngine.analyze()를 호출하세요.',
      );
    }

    final strength = StrengthEngine.analyze(
      dayPillar: baseProfile.dayPillar,
      monthPillar: baseProfile.monthPillar,
      tenGods: tenGods,
      hiddenStems: hiddenStems,
    );

    final yongsin = YongsinEngine.combine(
      dayPillar: baseProfile.dayPillar,
      monthPillar: baseProfile.monthPillar,
      strength: strength,
      fiveElements: fiveElements,
    );

    return baseProfile.copyWith(strength: strength, yongsin: yongsin);
  }
}
