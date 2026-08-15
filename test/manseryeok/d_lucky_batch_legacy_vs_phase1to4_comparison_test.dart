// [j7 · D02/D03/D05~D09/G01/G02/G04/H01~H05/H07/H10 배치 이전] 레거시
// (SajuEngine.calculate) vs 신규(PHASE1~4 → sajuResultFromProfile 어댑터)
// 17개 카테고리 결과 비교 테스트.
//
// [배치로 묶은 이유] 아래 17개 카테고리는 전부 dayMasterStrength(신강신약)를
// 전혀 참조하지 않는 두 개의 공용 헬퍼 중 하나만 호출한다(Type 1, C그룹/A05와
// 동일 패턴) — 계산 의존성이 완전히 동일하므로 카테고리별로 파일을 17개
// 만드는 대신 하나의 배치 파일에서 id 목록을 순회하며 동일한 강도로
// 검증한다:
//
//   ① `_dailyFortuneToResult()` → `getDailyFortune(saju, rules, year, month,
//      day)` 사용 — D02(오늘), D03(내일), D05(재물), D06(애정), D07(건강),
//      D08(시간). `getDailyFortune()`은 지정 일자의 일진 간지와 일간의 십신
//      관계 + 부족 오행만 사용, dayMasterStrength 완전 미참조.
//   ② `_luckyItemsToResult()` → `getLuckyItems(saju, rules)` 사용 —
//      D09, G01(=_a05 재사용 — 아래 별도 주석), G02(=_a05 재사용),
//      G04, H01, H02, H03, H04, H05, H07, H10. `getLuckyItems()`는
//      `saju.fiveElementsCount`의 최소값(부족 오행)만 사용,
//      dayMasterStrength 완전 미참조.
//
// [G01/G02 특이사항] `jeontong_eighty_calculator.dart`의 `_categoryIndex`에서
// `'G01': (ctx) => _a05(ctx)`, `'G02': (ctx) => _a05(ctx)`로 정의되어 있어
// 실제로는 이미 개별 검증이 끝난 A05(평생 건강운, Type 1)를 그대로 재사용한다.
// `_a05()`가 반환하는 `category` 필드는 '평생 건강운'으로 고정이지만(G01의
// 매트릭스 title은 '오행별 취약 장기', G02는 '평생 조심할 병'), 이는
// `report_builder.dart`의 `_mapCalculatedResultToReport()`가 화면에 보여주는
// `hero.name`은 `entry.title`(매트릭스 title)을 사용하지 `result.category`를
// 사용하지 않으므로 UX에 영향이 없다 — 이 테스트는 `result.data`(실제 판단
// 근거)의 legacy/신규 일치 여부만 검증한다.
//
// 검증 항목(카테고리당 공통, id별로 반복):
//   1) 사주 8글자/일간/오행/십신/대운 — 유저당 1회만 출력(반복 방지)
//   2) 신강신약(dayMasterStrength) — 유저당 1회만 출력, 17개 전부 미사용 확인용
//   3) 각 id별 `runJeontongCategory(id, ctx)` 결과 전체(`category`+`data`)
//      legacy vs 신규 strict 비교 — Type 1이므로 100% 완전 일치를 기대값으로
//      한다(일간이 이미 legacy/신규 완전 일치하므로).
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

/// 골든 테스트와 동일한 기준일(kFixedDate) — D02(오늘)/D03(내일)의 기준일.
final _kFixedDate = DateTime.utc(2026, 8, 13);

/// 이번 배치에서 검증할 17개 카테고리 id — 전부 dayMasterStrength 미참조.
const _batchCategoryIds = <String>[
  'D02', 'D03', 'D05', 'D06', 'D07', 'D08', 'D09',
  'G01', 'G02', 'G04',
  'H01', 'H02', 'H03', 'H04', 'H05', 'H07', 'H10',
];

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

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile; // legacy 번들은 null
}

_Bundle _runLegacy(_SeedUser u, DateTime referenceDate) {
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
  return _Bundle(saju, interp, null);
}

_Bundle _runNew(_SeedUser u, DateTime referenceDate) {
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
  return _Bundle(saju, interp, p4);
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

  group(
    '[j7·D02/D03/D05~D09/G01/G02/G04/H01~H05/H07/H10] '
    '레거시 vs 신규(PHASE1~4+어댑터) 배치 비교 — seed 유저 3명',
    () {
      for (final u in _seedUsers) {
        test('${u.userId}: 8글자/일간/오행/십신/대운/신강신약 + 17개 카테고리 전체 비교', () {
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
          expect(newPillars, legacyPillars, reason: '${u.userId} 8글자는 100% 동일해야 함');

          // ── 2) 일간 ──
          // ignore: avoid_print
          print('[일간] legacy=${legacyB.saju.dayMaster.gan}(${legacyB.saju.dayMaster.kr})');
          // ignore: avoid_print
          print('[일간] new   =${newB.saju.dayMaster.gan}(${newB.saju.dayMaster.kr})');
          expect(newB.saju.dayMaster.gan, legacyB.saju.dayMaster.gan, reason: '${u.userId} 일간 불일치');

          // ── 3) 오행 — D그룹(getDailyFortune)/H그룹(getLuckyItems) 공통 핵심 입력값 ──
          // ignore: avoid_print
          print('[오행] legacy=${legacyB.saju.fiveElementsCount}');
          // ignore: avoid_print
          print('[오행] new   =${newB.saju.fiveElementsCount}');
          expect(newB.saju.fiveElementsCount, legacyB.saju.fiveElementsCount, reason: '${u.userId} 오행 총량 불일치');

          // ── 4) 십신(7키) — D그룹(getDailyFortune) 핵심 입력값 ──
          // ignore: avoid_print
          print('[십신] legacy=${legacyB.saju.tenGods}');
          // ignore: avoid_print
          print('[십신] new   =${newB.saju.tenGods}');
          expect(newB.saju.tenGods, legacyB.saju.tenGods, reason: '${u.userId} 십신 불일치');

          // ── 5) 대운(회귀 확인용 — 이 배치의 17개 카테고리는 대운 자체는 미사용) ──
          final legacyReal = legacyB.saju.luckPillars.where((lp) => lp.ganZhi.isNotEmpty).toList();
          // ignore: avoid_print
          print('[대운] legacy(${legacyReal.length}개)=${legacyReal.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
          // ignore: avoid_print
          print('[대운] new(${newB.saju.luckPillars.length}개)=${newB.saju.luckPillars.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
          for (var i = 0; i < legacyReal.length; i++) {
            expect(newB.saju.luckPillars[i].ganZhi, legacyReal[i].ganZhi, reason: '${u.userId} 대운[$i] 간지 불일치');
          }

          // ── 6) 신강신약(dayMasterStrength) — 이 배치 17개 전부 미사용, 회귀 확인용 ──
          final strengthSame = newB.saju.dayMasterStrength == legacyB.saju.dayMasterStrength;
          // ignore: avoid_print
          print('[신강신약] legacy=${legacyB.saju.dayMasterStrength}');
          // ignore: avoid_print
          print('[신강신약] new   =${newB.saju.dayMasterStrength}  '
              '(${strengthSame ? "동일" : "★ 다름(seed-user-C 패턴) — 이 배치 17개 카테고리 전부 dayMasterStrength 미사용이므로 영향 없음 ★"})');
          if (newB.profile?.strength != null) {
            final s = newB.profile!.strength!;
            // ignore: avoid_print
            print('[신강신약·PHASE3 상세] score=${s.score.toStringAsFixed(3)} '
                'monthOrder=${s.monthOrderScore} root=${s.rootScore} '
                'support=${s.supportScore} control=${s.controlScore} drain=${s.drainScore}');
          }

          final rules = SajuFortuneRules.cachedOrNull!;

          // ── 7) 17개 카테고리 각각 runJeontongCategory() 결과 전체 비교 ──
          for (final id in _batchCategoryIds) {
            final legacyCtx = JeontongCalcContext(
              saju: legacyB.saju,
              interp: legacyB.interp,
              rules: rules,
              referenceDate: _kFixedDate,
            );
            final newCtx = JeontongCalcContext(
              saju: newB.saju,
              interp: newB.interp,
              rules: rules,
              referenceDate: _kFixedDate,
            );
            final legacyResult = runJeontongCategory(id, legacyCtx);
            final newResult = runJeontongCategory(id, newCtx);

            // ignore: avoid_print
            print('[$id·category] legacy=${legacyResult.category}  new=${newResult.category}');
            // ignore: avoid_print
            print('[$id·data] legacy=${legacyResult.data}');
            // ignore: avoid_print
            print('[$id·data] new   =${newResult.data}');

            expect(
              newResult.category,
              legacyResult.category,
              reason:
                  '${u.userId}·$id: category는 saju 계산과 무관한 정적/날짜 기반 문자열이므로 '
                  '항상 동일해야 함',
            );
            expect(
              newResult.data,
              legacyResult.data,
              reason:
                  '${u.userId}·$id: dayMasterStrength를 사용하지 않는 카테고리이므로 '
                  '일간·오행·십신이 이미 일치하는 한(위에서 확인됨) legacy/신규 결과가 '
                  '완전히 동일해야 합니다. 다르다면 getDailyFortune/getLuckyItems 또는 '
                  'rules 참조 로직에 회귀가 있다는 뜻입니다.',
            );
          }
        });
      }
    },
  );

  group('[j7·배치] runJeontongCategory(id, ctx) 경로 자체도 정상 동작 확인 — 17개', () {
    for (final u in _seedUsers) {
      for (final id in _batchCategoryIds) {
        test('${u.userId}·$id: JeontongCalcContext + runJeontongCategory 예외 없이 동작', () {
          final newB = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(rules, isNotNull, reason: 'SajuFortuneRules.preload()가 setUpAll에서 완료되어야 함');

          final ctx = JeontongCalcContext(
            saju: newB.saju,
            interp: newB.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
          );

          late final JeontongCategoryResult result;
          expect(() => result = runJeontongCategory(id, ctx), returnsNormally);
          expect(result.data, isNotEmpty);
        });
      }
    }
  });
}
