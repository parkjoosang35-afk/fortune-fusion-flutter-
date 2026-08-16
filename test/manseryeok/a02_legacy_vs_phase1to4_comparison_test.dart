// [j7 · A02 신규 엔진 이전] 레거시(SajuEngine.calculate) vs 신규
// (PHASE1~4 → sajuResultFromProfile 어댑터) A02(성격·기질) 결과 비교 테스트.
//
// A01/B01/C01/D01과 동일한 원칙(§2/§3) — 단순 "테스트 통과 여부"가 아니라
// 다음 전부를 나란히 출력/비교한다:
//   1) 사주 8글자(년/월/일/시주)
//   2) 일간
//   3) 오행(개수)
//   4) 십신(7키)
//   5) 대운(간지/시작연령/시작연도)
//   6) 신강신약(dayMasterStrength) — A02 자체는 사용하지 않지만 회귀 확인용
//   7) 용신/희신/기신/구신 (신규 전용 — 참고용 로그)
//   8) A02 판단에 실제 쓰이는 계산값(dayMasterAnalysis.title/dominant 십신 등)
//   9) 최종 A02 결과(headline/coreNature/personality/strengths/weaknesses/
//      fiveElements/lifeTheme/summary — A01과 동일한 데이터, category만 다름)
//  10) 결과 문구 전체
//
// [A02의 계산 의존성 — A01과 완전 동일] `_a02(ctx)`(jeontong_eighty_
// calculator.dart)는 `_a01(ctx)`를 그대로 호출한 뒤 category 필드만
// '성격·기질'로 바꿔 반환한다(`getLifeTotal(interp)` 재사용).
// getLifeTotal()은 `interp.dayMasterAnalysis`(=interpretDayMaster())를
// 사용하고, interpretDayMaster()는 `saju.dayMasterStrength`(신강/중화/
// 신약)를 직접 분기 조건으로 사용해 personality/headline 문구를 고른다.
// 즉 A02는 A01과 마찬가지로 dayMasterStrength에 **간접 의존**한다.
// 따라서 legacy/신규 dayMasterStrength 판정이 다른 seed(예: seed-user-C,
// PHASE3 억부법 中和 vs 레거시 단순비율 身强)에서는 A01과 동일한 이유로
// headline/personality 문구가 달라지는 것이 정상이며 §2/§3 원칙에 따라
// strict 동일성이 아닌 구조적 안전성(soft assertion)만 강제한다.
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
import 'package:flutter_test/flutter_test.dart';

/// 골든 테스트와 동일한 기준일(kFixedDate).
final _kFixedDate = DateTime.utc(2026, 8, 13);

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

DateTime _toKst(DateTime utc) => utc.add(const Duration(hours: 9));

String _legacyGender(String mf) => mf == 'F' ? 'female' : 'male';

class _LegacyBundle {
  _LegacyBundle(this.saju, this.interp, this.a02);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult a02;
}

class _NewBundle {
  _NewBundle(this.profile, this.saju, this.interp, this.a02);
  final SajuProfile profile;
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult a02;
}

JeontongCategoryResult _runA02(
  legacy.SajuResult saju,
  SajuFullInterpretation interp,
  DateTime referenceDate,
) {
  final rules = SajuFortuneRules.cachedOrNull!;
  final ctx = JeontongCalcContext(
    saju: saju,
    interp: interp,
    rules: rules,
    referenceDate: referenceDate,
  );
  return runJeontongCategory('A02', ctx);
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
  final a02 = _runA02(saju, interp, referenceDate);
  return _LegacyBundle(saju, interp, a02);
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
  final a02 = _runA02(saju, interp, referenceDate);
  return _NewBundle(p4, saju, interp, a02);
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

  group('[j7·A02] 레거시 vs 신규(PHASE1~4+어댑터) 전체 비교 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 8글자/일간/오행/십신/대운/신강신약/용희기구/A02 전체 비교', () {
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
          '[일간] legacy=${legacyB.saju.dayMaster.gan}(${legacyB.saju.dayMaster.kr})',
        );
        // ignore: avoid_print
        print(
          '[일간] new   =${newB.saju.dayMaster.gan}(${newB.saju.dayMaster.kr})',
        );
        expect(
          newB.saju.dayMaster.gan,
          legacyB.saju.dayMaster.gan,
          reason: '${u.userId} 일간 불일치',
        );

        // ── 3) 오행 ──
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

        // ── 5) 대운(회귀 확인용, A02는 대운 자체는 사용하지 않음) ──
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

        // ── 6) 신강신약(dayMasterStrength) — A02는 getLifeTotal→
        // interpretDayMaster() 경유로 A01과 동일하게 간접 의존함(핵심 비교 포인트) ──
        final strengthSame =
            newB.saju.dayMasterStrength == legacyB.saju.dayMasterStrength;
        // ignore: avoid_print
        print('[신강신약] legacy=${legacyB.saju.dayMasterStrength}');
        // ignore: avoid_print
        print(
          '[신강신약] new   =${newB.saju.dayMasterStrength}  (${strengthSame ? "동일" : "★ 다름(A01과 동일한 seed-user-C 패턴 - A02 문구에도 영향 있음) ★"})',
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

        // ── 7) 용신/희신/기신/구신 (신규 전용, A02엔 미사용 — 참고 로그) ──
        if (newB.profile.yongsin != null) {
          final y = newB.profile.yongsin!;
          // ignore: avoid_print
          print(
            '[용희기구·신규전용] method=${y.method} 용신=${y.yongsin} 희신=${y.heesin} '
            '기신=${y.gisin} 구신=${y.gusin}',
          );
        }

        // ── 8) A02 판단에 실제 사용되는 계산값(dayMasterAnalysis/dominant 십신) ──
        // ignore: avoid_print
        print(
          '[A02계산값] legacy dayMasterAnalysis.title=${legacyB.interp.dayMasterAnalysis.title}',
        );
        // ignore: avoid_print
        print(
          '[A02계산값] new    dayMasterAnalysis.title=${newB.interp.dayMasterAnalysis.title}',
        );
        // ignore: avoid_print
        print(
          '[A02계산값] legacy dominant십신=${legacyB.interp.tenGodsAnalysis.dominantName}'
          '(${legacyB.interp.tenGodsAnalysis.dominantCount}개)',
        );
        // ignore: avoid_print
        print(
          '[A02계산값] new    dominant십신=${newB.interp.tenGodsAnalysis.dominantName}'
          '(${newB.interp.tenGodsAnalysis.dominantCount}개)',
        );

        // ── 9) A02 판단에 실제 사용되는 계산값(JeontongCategoryResult 필드) ──
        for (final key in [
          'headline',
          'core_nature',
          'personality',
          'strengths',
          'weaknesses',
          'five_elements',
          'life_theme',
          'summary',
        ]) {
          final lv = legacyB.a02.data[key];
          final nv = newB.a02.data[key];
          // ignore: avoid_print
          print('[A02·$key] legacy=$lv');
          // ignore: avoid_print
          print('[A02·$key] new   =$nv');
        }

        // ── 10) 최종 A02 결과 전체 동일성 ──
        // ignore: avoid_print
        print(
          '[A02·category] legacy=${legacyB.a02.category}  new=${newB.a02.category}',
        );
        expect(legacyB.a02.category, '성격·기질');
        expect(newB.a02.category, '성격·기질');

        final a02Same = legacyB.a02.data.toString() == newB.a02.data.toString();
        // ignore: avoid_print
        print(
          '[결론] A02 전체 데이터 동일여부=$a02Same '
          '(dayMasterStrength동일=$strengthSame) → '
          '${!strengthSame && !a02Same ? "dayMasterStrength 차이가 A02 문구에 실제 영향을 줌(A01과 동일한 정상 패턴)" : (strengthSame && a02Same ? "완전 일치" : "다른 원인으로 차이 발생 - 확인 필요")}',
        );

        // ── 구조적 안전성만 강제(문구 1:1 동일성은 요구하지 않음 — §2/§3
        // 원칙, A01과 동일한 기준). A02는 A01과 완전히 동일한 계산 경로
        // (getLifeTotal→interpretDayMaster())를 재사용하며
        // dayMasterStrength에 간접 의존하므로, legacy/신규
        // dayMasterStrength 판정이 다른 경우(seed-user-C) headline/
        // personality 문구가 달라지는 것은 A01에서 이미 검증/승인된 것과
        // 동일한 원인의 정상적인 엔진 개선이다.
        expect(newB.a02.data['headline'], isNotEmpty);
        expect(newB.a02.data['summary'], isNotEmpty);
        expect(newB.a02.data['core_nature'], isNotEmpty);
        expect(newB.a02.data['strengths'], isNotEmpty);
        expect(newB.a02.data['weaknesses'], isNotEmpty);
        // headline엔 항상 dominant 십신 이름이 포함되어야 한다(getLifeTotal 공식).
        expect(
          newB.a02.data['headline'],
          contains(newB.interp.tenGodsAnalysis.dominantName),
        );
        // dayMasterStrength가 legacy와 동일한 seed(A, B)라면 A02 결과도
        // 완전히 동일해야 한다(진짜 회귀 방지 — strict 비교는 이 경우에만).
        if (strengthSame) {
          expect(
            newB.a02.data,
            legacyB.a02.data,
            reason:
                '${u.userId}: dayMasterStrength가 legacy와 동일하므로 A02 결과도 '
                '완전히 동일해야 합니다.',
          );
        }
      });
    }
  });

  group('[j7·A02] runJeontongCategory("A02", ctx) 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext + runJeontongCategory("A02") 예외 없이 동작',
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
            () => result = runJeontongCategory('A02', ctx),
            returnsNormally,
          );
          expect(result.category, '성격·기질');
          expect(result.data['headline'], newB.a02.data['headline']);
          expect(result.data['summary'], newB.a02.data['summary']);
        },
      );
    }
  });
}
