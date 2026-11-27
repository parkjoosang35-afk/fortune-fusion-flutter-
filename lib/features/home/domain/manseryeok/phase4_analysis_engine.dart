/// [정통사주 80종 전용 신규 엔진] PHASE 4 대운/세운/월운 오케스트레이터.
///
/// 37번 지시 §14~§16에 대응한다. PHASE 3까지 완료된 [SajuProfile]
/// (strength/yongsin이 채워진 상태)을 입력받아, [DaewoonEngine]/
/// [SewoonEngine]/[WolwoonEngine]을 순서대로 호출하고 결과를
/// [SajuProfile.copyWith]로 채워 반환한다.
///
/// [필수 선행 조건] [core]는 반드시 이 [baseProfile]과 같은 계산에서
/// 나온 [ManseryeokCoreResult](대운/세운/월운 계산에 필요한 `eightChar`
/// 보유)여야 한다 — [ManseryeokCoreEngine.buildProfileWithCore] 한 번의
/// 호출에서 나온 짝을 그대로 전달해야 재계산 없이 일관된 결과가 나온다.
///
/// [세운/월운 계산 범위] 세운/월운은 이론상 무한한 연도에 대해 계산할 수
/// 있으므로(대운처럼 "9개 고정"이 불가능), 이 오케스트레이터는 다음
/// 기본 정책을 취한다.
/// - 대운: 기존 `saju_engine.dart`와 동일하게 9라운드(90년) 계산.
/// - 세운: [referenceDate]가 속한 대운 구간(10년) 전체를 계산 — 80종
///   콘텐츠가 "현재 대운 동안의 연도별 흐름"을 조회할 수 있도록 한다.
/// - 월운: [referenceDate]가 속한 연도 1개년의 12개월을 계산 — 80종
///   콘텐츠가 "올해의 월별 흐름"을 조회할 수 있도록 한다.
/// 더 넓은 범위가 필요하면 [SewoonEngine.analyzeYears]/
/// [WolwoonEngine.analyzeYear]를 직접 호출해 원하는 연도 범위를 조회할
/// 수 있다(이 오케스트레이터는 SajuProfile에 담을 "기본값"만 정의).
library;

import 'daewoon_engine.dart' show DaewoonEngine;
import 'manseryeok_core_engine.dart' show ManseryeokCoreResult;
import 'saju_profile.dart';
import 'sewoon_engine.dart' show SewoonEngine;
import 'wolwoon_engine.dart' show WolwoonEngine;

class Phase4AnalysisEngine {
  Phase4AnalysisEngine._();

  static SajuProfile analyze({
    required SajuProfile baseProfile,
    required ManseryeokCoreResult core,
    DateTime? referenceDate,
    int daewoonCount = 9,
  }) {
    if (baseProfile.strength == null || baseProfile.yongsin == null) {
      throw StateError(
        'Phase4AnalysisEngine.analyze()는 PHASE 3 결과'
        '(strength/yongsin)가 이미 채워진 SajuProfile을 요구합니다 — '
        '먼저 Phase3AnalysisEngine.analyze()를 호출하세요.',
      );
    }

    final ref = referenceDate ?? DateTime.now();
    final gender = baseProfile.birthInfo.gender;
    final dayStemHanja = baseProfile.dayStemHanja;
    final precision = baseProfile.daewoonStartPrecision;

    final daewoon = DaewoonEngine.analyze(
      eightChar: core.eightChar,
      dayStemHanja: dayStemHanja,
      gender: gender,
      precision: precision,
      count: daewoonCount,
    );

    if (daewoon.isEmpty) {
      throw StateError(
        'Phase4AnalysisEngine.analyze(): daewoonCount=$daewoonCount로는 '
        '대운을 1개도 계산할 수 없습니다(count는 1 이상이어야 함).',
      );
    }

    // [referenceDate]가 속한 대운 구간(10년)을 찾는다 — 없으면(예: 아직
    // 첫 대운 시작 전인 소운기 구간이거나, 마지막 대운 이후) 가장 가까운
    // 대운 구간(이전 대운이 없으면 첫 대운, 이후 대운이 없으면 마지막
    // 대운)으로 대체한다.
    DaewoonEntry currentDaewoon = daewoon.first;
    for (final d in daewoon) {
      if (ref.year >= d.startYear && ref.year < d.startYear + 10) {
        currentDaewoon = d;
        break;
      }
      if (ref.year >= d.startYear) {
        currentDaewoon = d; // 소운기 이후 아직 도달한 대운 중 가장 최신.
      }
    }
    final sewoonFromYear = currentDaewoon.startYear;
    final sewoonToYear = currentDaewoon.startYear + 9;

    final sewoon = SewoonEngine.analyzeYears(
      eightChar: core.eightChar,
      dayStemHanja: dayStemHanja,
      gender: gender,
      fromYear: sewoonFromYear,
      toYear: sewoonToYear,
      precision: precision,
    );

    final wolwoon = WolwoonEngine.analyzeYear(
      eightChar: core.eightChar,
      dayStemHanja: dayStemHanja,
      gender: gender,
      year: ref.year,
      precision: precision,
    );

    return baseProfile.copyWith(
      daewoon: daewoon,
      sewoon: sewoon,
      wolwoon: wolwoon,
    );
  }
}
