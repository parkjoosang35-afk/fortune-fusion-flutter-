// [j7 · A05 신규 엔진 이전] 레거시(SajuEngine.calculate) vs 신규
// (PHASE1~4 → sajuResultFromProfile 어댑터) A05(평생 건강운) 결과 비교
// 테스트.
//
// A01/B01과 동일한 원칙(§2/§3) — 단순 "테스트 통과 여부"가 아니라 다음 전부를
// 나란히 출력/비교한다:
//   1) 사주 8글자(년/월/일/시주)
//   2) 일간
//   3) 오행(개수)
//   4) 십신(7키)
//   5) 대운(간지/시작연령/시작연도)
//   6) 신강신약(dayMasterStrength) — A05는 사용하지 않지만 회귀 확인용
//   7) 용신/희신/기신/구신 (신규 전용 — 참고용 로그)
//   8) A05 판단에 실제 쓰이는 계산값(healthFortune.coreOrgans/warnings/
//      recommendedFood, fiveElementsCount)
//   9) 최종 A05 결과(JeontongCategoryResult: core_organs/lifetime_warnings/
//      advice_food/lifestyle)
//  10) 결과 문구 전체
//
// [A05의 계산 의존성 — B01과 동일한 Type 1 패턴] `getLifeHealth(saju, interp)`
// → `interp.healthFortune`(=`interpretHealth()`)은 `saju.fiveElementsCount`
// (오행 개수)와 `saju.dayMaster.element`(일간 오행)만 사용하고
// `dayMasterStrength`(신강신약)는 전혀 참조하지 않는다. `getLifeHealth()`가
// 추가로 계산하는 `lifetimeWarnings`(경고 문구)도 동일하게 오행 개수만
// 사용한다. 오행 총량이 legacy/신규 완전 일치함은 이미 A01~A04 테스트에서
// 반복 확인되었으므로, A05는 seed-user-A/B/C 전원 완전 일치해야 한다 — 만약
// 다르다면 오행 계산 자체나 rules(오행별 장기/음식 매핑)에 회귀가 있다는
// 뜻이므로 반드시 원인을 밝혀야 한다.
import 'package:flutter_app/features/home/domain/jeontong_eighty_calculator.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase2_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase3_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase4_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_result_adapter.dart';
import 'package:flutter_app/features/home/domain/saju_engine.dart' as legacy;
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/domain/saju_life_modules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 골든 테스트와 동일한 기준일(kFixedDate).
final _kFixedDate = DateTime.utc(2026, 8, 13);

/// test/fixtures/jeontong_inputs.dart 의 3개 seed 유저를 이 테스트 파일
/// 안에서 그대로 재현한다(값 자체는 jeontong_inputs.dart와 100% 동일).
class _SeedUser {
  const _SeedUser({
    required this.userId,
    required this.birthDateTimeUtc,
    required this.isLunar,
    required this.gender,
  });
  final String userId;
  final DateTime birthDateTimeUtc;
  final bool isLunar;
  final String gender; // 'M' | 'F'
}

final _seedUsers = <_SeedUser>[
  _SeedUser(
    userId: 'seed-user-A',
    birthDateTimeUtc: DateTime.utc(1972, 2, 12, 17, 0, 0),
    isLunar: false,
    gender: 'M',
  ),
  _SeedUser(
    userId: 'seed-user-B',
    birthDateTimeUtc: DateTime.utc(1990, 6, 15, 3, 0, 0),
    isLunar: false,
    gender: 'F',
  ),
  _SeedUser(
    userId: 'seed-user-C',
    birthDateTimeUtc: DateTime.utc(2005, 11, 30, 21, 0, 0),
    isLunar: false,
    gender: 'F',
  ),
];

/// report_builder.dart의 `_tryBuildRealReport()`와 동일한 규약 —
/// birthDateTimeUtc(UTC 저장값) + 9시간 = KST 벽시계 시각.
DateTime _toKst(DateTime utc) => utc.add(const Duration(hours: 9));

String _legacyGender(String mf) => mf == 'F' ? 'female' : 'male';

/// 레거시 경로 전체 실행 결과 묶음.
class _LegacyBundle {
  _LegacyBundle(this.saju, this.interp, this.a05);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final LifeHealthResult a05;
}

/// 신규(PHASE1~4 + 어댑터) 경로 전체 실행 결과 묶음.
class _NewBundle {
  _NewBundle(this.profile, this.saju, this.interp, this.a05);
  final SajuProfile profile;
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final LifeHealthResult a05;
}

_LegacyBundle _runLegacy(_SeedUser u, DateTime referenceDate) {
  final kst = _toKst(u.birthDateTimeUtc);
  final saju = legacy.SajuEngine.calculate(
    year: kst.year,
    month: kst.month,
    day: kst.day,
    hour: kst.hour,
    minute: kst.minute,
    gender: _legacyGender(u.gender),
    isLunar: u.isLunar,
    referenceDate: referenceDate,
  );
  final interp = SajuInterpreter.fullInterpretation(saju);
  final a05 = getLifeHealth(saju, interp);
  return _LegacyBundle(saju, interp, a05);
}

_NewBundle _runNew(_SeedUser u, DateTime referenceDate) {
  final kst = _toKst(u.birthDateTimeUtc);
  final withCore = ManseryeokCoreEngine.buildProfileWithCore(
    year: kst.year,
    month: kst.month,
    day: kst.day,
    hour: kst.hour,
    minute: kst.minute,
    gender: _legacyGender(u.gender),
    calendarType: u.isLunar ? CalendarInputType.lunar : CalendarInputType.solar,
  );
  final p2 = Phase2AnalysisEngine.analyze(
    baseProfile: withCore.profile,
    core: withCore.core,
  );
  final p3 = Phase3AnalysisEngine.analyze(baseProfile: p2);
  final p4 = Phase4AnalysisEngine.analyze(
    baseProfile: p3,
    core: withCore.core,
    referenceDate: referenceDate,
  );
  final saju = sajuResultFromProfile(p4, referenceDate: referenceDate);
  final interp = SajuInterpreter.fullInterpretation(saju);
  final a05 = getLifeHealth(saju, interp);
  return _NewBundle(p4, saju, interp, a05);
}

String _pillarsStr(Map<String, legacy.SajuPillar> pillars) =>
    '${pillars['year']!.kr}년 ${pillars['month']!.kr}월 '
    '${pillars['day']!.kr}일 ${pillars['hour']!.kr}시';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
  });

  group('[j7·A05] 레거시 vs 신규(PHASE1~4+어댑터) 전체 비교 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 8글자/일간/오행/십신/대운/신강신약/용희기구/A05 전체 비교', () {
        final legacyB = _runLegacy(u, _kFixedDate);
        final newB = _runNew(u, _kFixedDate);

        // ignore: avoid_print
        print('\n========== ${u.userId} ==========');

        // ── 1) 사주 8글자 ──
        final legacyPillars = _pillarsStr(legacyB.saju.pillars);
        final newPillars = _pillarsStr(newB.saju.pillars);
        // ignore: avoid_print
        print('[8글자] legacy=$legacyPillars');
        // ignore: avoid_print
        print('[8글자] new   =$newPillars');
        expect(
          newPillars,
          legacyPillars,
          reason: '${u.userId} 8글자는 100% 동일해야 함',
        );

        // ── 2) 일간 ──
        // ignore: avoid_print
        print(
          '[일간] legacy=${legacyB.saju.dayMaster.gan}(${legacyB.saju.dayMaster.kr}/${legacyB.saju.dayMaster.element})',
        );
        // ignore: avoid_print
        print(
          '[일간] new   =${newB.saju.dayMaster.gan}(${newB.saju.dayMaster.kr}/${newB.saju.dayMaster.element})',
        );
        expect(
          newB.saju.dayMaster.gan,
          legacyB.saju.dayMaster.gan,
          reason: '${u.userId} 일간 불일치',
        );
        expect(
          newB.saju.dayMaster.element,
          legacyB.saju.dayMaster.element,
          reason: '${u.userId} 일간 오행 불일치',
        );

        // ── 3) 오행(개수) — A05의 핵심 입력값 ──
        // ignore: avoid_print
        print('[오행] legacy=${legacyB.saju.fiveElementsCount}');
        // ignore: avoid_print
        print('[오행] new   =${newB.saju.fiveElementsCount}');
        expect(
          newB.saju.fiveElementsCount,
          legacyB.saju.fiveElementsCount,
          reason: '${u.userId} 오행 총량 불일치',
        );

        // ── 4) 십신(7키) ──
        // ignore: avoid_print
        print('[십신] legacy=${legacyB.saju.tenGods}');
        // ignore: avoid_print
        print('[십신] new   =${newB.saju.tenGods}');
        expect(
          newB.saju.tenGods,
          legacyB.saju.tenGods,
          reason: '${u.userId} 십신 불일치',
        );

        // ── 5) 대운 ──
        final legacyReal = legacyB.saju.luckPillars
            .where((lp) => lp.ganZhi.isNotEmpty)
            .toList();
        // ignore: avoid_print
        print(
          '[대운] legacy(${legacyReal.length}개)=${legacyReal.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}',
        );
        // ignore: avoid_print
        print(
          '[대운] new(${newB.saju.luckPillars.length}개)=${newB.saju.luckPillars.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}',
        );
        for (var i = 0; i < legacyReal.length; i++) {
          expect(
            newB.saju.luckPillars[i].ganZhi,
            legacyReal[i].ganZhi,
            reason: '${u.userId} 대운[$i] 간지 불일치',
          );
        }

        // ── 6) 신강신약(dayMasterStrength) — A05엔 미사용, 회귀 확인용 ──
        final strengthSame =
            newB.saju.dayMasterStrength == legacyB.saju.dayMasterStrength;
        // ignore: avoid_print
        print('[신강신약] legacy=${legacyB.saju.dayMasterStrength}');
        // ignore: avoid_print
        print(
          '[신강신약] new   =${newB.saju.dayMasterStrength}  (${strengthSame ? "동일" : "★ 다름(A01/A04와 동일한 seed-user-C 패턴 - A05엔 영향 없음) ★"})',
        );
        if (newB.profile.strength != null) {
          final s = newB.profile.strength!;
          // ignore: avoid_print
          print(
            '[신강신약·PHASE3 상세] score=${s.score.toStringAsFixed(3)} '
            'monthOrder=${s.monthOrderScore} root=${s.rootScore} '
            'support=${s.supportScore} control=${s.controlScore} drain=${s.drainScore}',
          );
        }

        // ── 7) 용신/희신/기신/구신 (신규 전용, A05엔 미사용 — 참고 로그) ──
        if (newB.profile.yongsin != null) {
          final y = newB.profile.yongsin!;
          // ignore: avoid_print
          print(
            '[용희기구·신규전용] method=${y.method} 용신=${y.yongsin} 희신=${y.heesin} '
            '기신=${y.gisin} 구신=${y.gusin}',
          );
        }

        // ── 8) A05 판단에 실제 사용되는 계산값(healthFortune) ──
        final lHealth = legacyB.interp.healthFortune;
        final nHealth = newB.interp.healthFortune;
        // ignore: avoid_print
        print('[A05계산값·coreOrgans] legacy=${lHealth.coreOrgans}');
        // ignore: avoid_print
        print('[A05계산값·coreOrgans] new   =${nHealth.coreOrgans}');
        // ignore: avoid_print
        print('[A05계산값·warnings] legacy=${lHealth.warnings}');
        // ignore: avoid_print
        print('[A05계산값·warnings] new   =${nHealth.warnings}');
        // ignore: avoid_print
        print('[A05계산값·recommendedFood] legacy=${lHealth.recommendedFood}');
        // ignore: avoid_print
        print('[A05계산값·recommendedFood] new   =${nHealth.recommendedFood}');
        expect(
          nHealth.coreOrgans,
          lHealth.coreOrgans,
          reason: '${u.userId} healthFortune.coreOrgans 불일치',
        );
        expect(
          nHealth.warnings,
          lHealth.warnings,
          reason: '${u.userId} healthFortune.warnings 불일치',
        );
        expect(
          nHealth.recommendedFood,
          lHealth.recommendedFood,
          reason: '${u.userId} healthFortune.recommendedFood 불일치',
        );

        // ── 9) 최종 A05 결과(LifeHealthResult) 전체 필드 ──
        // ignore: avoid_print
        print('[A05·coreOrgans] legacy=${legacyB.a05.coreOrgans}');
        // ignore: avoid_print
        print('[A05·coreOrgans] new   =${newB.a05.coreOrgans}');
        // ignore: avoid_print
        print('[A05·lifetimeWarnings] legacy=${legacyB.a05.lifetimeWarnings}');
        // ignore: avoid_print
        print('[A05·lifetimeWarnings] new   =${newB.a05.lifetimeWarnings}');
        // ignore: avoid_print
        print('[A05·adviceFood] legacy=${legacyB.a05.adviceFood}');
        // ignore: avoid_print
        print('[A05·adviceFood] new   =${newB.a05.adviceFood}');
        // ignore: avoid_print
        print('[A05·lifestyle] legacy=${legacyB.a05.lifestyle}');
        // ignore: avoid_print
        print('[A05·lifestyle] new   =${newB.a05.lifestyle}');

        final a05Same =
            legacyB.a05.coreOrgans.toString() ==
                newB.a05.coreOrgans.toString() &&
            legacyB.a05.lifetimeWarnings.toString() ==
                newB.a05.lifetimeWarnings.toString() &&
            legacyB.a05.adviceFood.toString() ==
                newB.a05.adviceFood.toString() &&
            legacyB.a05.lifestyle == newB.a05.lifestyle;
        // ignore: avoid_print
        print(
          '[결론] A05 전체 데이터 동일여부=$a05Same '
          '(dayMasterStrength동일=$strengthSame — A05는 신강신약을 사용하지 않으므로 '
          'strength 차이와 무관하게 오행 총량이 일치하는 한 항상 동일해야 함)',
        );

        // ── A05는 dayMasterStrength에 의존하지 않으므로, 오행 총량이 이미
        // 완전 일치함을 확인했다면(위 3번) legacy/신규 A05 결과는 100%
        // 동일해야 한다 — 이것이 A05의 정상 기대값이다(B01과 동일한 Type 1).
        expect(
          newB.a05.coreOrgans,
          legacyB.a05.coreOrgans,
          reason:
              '${u.userId}: A05는 dayMasterStrength를 사용하지 않는 카테고리이므로 '
              '오행 계산(위에서 이미 일치 확인됨)이 같다면 coreOrgans도 완전히 동일해야 합니다.',
        );
        expect(
          newB.a05.lifetimeWarnings,
          legacyB.a05.lifetimeWarnings,
          reason:
              '${u.userId}: lifetimeWarnings 불일치 — 오행 개수 임계값(0개/3개 이상) 로직 회귀 가능성.',
        );
        expect(
          newB.a05.adviceFood,
          legacyB.a05.adviceFood,
          reason:
              '${u.userId}: adviceFood 불일치 — rules의 오행별 food_good 매핑 회귀 가능성.',
        );
        expect(
          newB.a05.lifestyle,
          legacyB.a05.lifestyle,
          reason: '${u.userId}: lifestyle은 고정 문구이므로 항상 동일해야 함.',
        );
      });
    }
  });

  group('[j7·A05] runJeontongCategory("A05", ctx) 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext + runJeontongCategory("A05") 예외 없이 동작',
        () {
          final newB = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(
            rules,
            isNotNull,
            reason: 'SajuFortuneRules.preload()가 setUpAll에서 완료되어야 함',
          );

          final ctx = JeontongCalcContext(
            saju: newB.saju,
            interp: newB.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
          );

          late final JeontongCategoryResult result;
          expect(
            () => result = runJeontongCategory('A05', ctx),
            returnsNormally,
          );
          expect(result.category, '평생 건강운');
          expect(result.data['core_organs'], newB.a05.coreOrgans);
          expect(result.data['lifetime_warnings'], newB.a05.lifetimeWarnings);
          expect(result.data['advice_food'], newB.a05.adviceFood);
          expect(result.data['lifestyle'], newB.a05.lifestyle);
        },
      );
    }
  });
}
