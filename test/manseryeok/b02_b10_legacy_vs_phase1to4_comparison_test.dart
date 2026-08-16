// [j9 · B02~B10 신규 구현] 레거시(SajuEngine.calculate) vs 신규(PHASE1~4 →
// sajuResultFromProfile 어댑터) 경로에서 B02(대운별 재물)/B03(대운별 직업)/
// B04(대운별 건강)/B05(대운별 애정)/B06(대운 전환기)/B07(다음 대운)/
// B08(최고 대운)/B09(최악 대운)/B10(대운×세운 조합) 결과를 비교한다.
//
// B02~B10은 A07~A10과 마찬가지로 "원본 파이썬 이식"이 아니라 이번 세션에서
// saju_daewoon_modules.dart에 신규로 설계한 계산이다(사용자 최종 지시 §3).
// 따라서 원본과의 1:1 대조가 아니라 다음을 검증한다:
//   1) legacy 경로(SajuEngine.calculate)와 new(PHASE1~4+어댑터) 경로가
//      동일한 대운 목록(간지)을 낼 때, B02~B07/B10 결과도 동일해야 한다
//      (둘 다 saju.luckPillars 기반 getTenGod 재구성만 사용하므로).
//   2) B08/B09는 PHASE3가 계산한 SajuProfile.yongsin(용신/기신)이 있어야만
//      실제 판정이 나온다 — legacy 경로(profile=null)에서는 "판단 불가"로
//      안전하게 처리되는지 확인한다.
//   3) runJeontongCategory('B02'~'B10', ctx) 경로가 예외 없이 정상 동작하고,
//      kJeontongPlaceholderCategoryIds에서 제외되어 있다.
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

const _bIds = ['B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B08', 'B09', 'B10'];

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile, this.results);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile;
  final Map<String, JeontongCategoryResult> results;
}

Map<String, JeontongCategoryResult> _runBGroup(
  legacy.SajuResult saju,
  SajuFullInterpretation interp,
  DateTime referenceDate,
  SajuProfile? profile,
) {
  final rules = SajuFortuneRules.cachedOrNull!;
  final ctx = JeontongCalcContext(
    saju: saju,
    interp: interp,
    rules: rules,
    referenceDate: referenceDate,
    profile: profile,
  );
  return {for (final id in _bIds) id: runJeontongCategory(id, ctx)};
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
  // legacy 경로는 SajuProfile(용신/기신)을 계산하지 않는다 — B08/B09가
  // "판단 불가"로 안전 처리되는지 확인하기 위해 의도적으로 null.
  final r = _runBGroup(saju, interp, referenceDate, null);
  return _Bundle(saju, interp, null, r);
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
  final r = _runBGroup(saju, interp, referenceDate, p4);
  return _Bundle(saju, interp, p4, r);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
  });

  group('[j9·B02~B10] 카테고리 등록/제외 상태 확인', () {
    test('kJeontongPlaceholderCategoryIds에 B02~B10이 더 이상 없어야 함', () {
      for (final id in _bIds) {
        expect(
          kJeontongPlaceholderCategoryIds.contains(id),
          isFalse,
          reason: '$id는 실계산으로 전환되어 플레이스홀더 목록에서 빠져야 함',
        );
      }
    });
  });

  // [알려진 차이 — A10 선례와 동일 원리, §11 "신규 엔진이 맞으면 유지"]
  // legacy(SajuEngine.calculate)는 `getDaYun().take(9)`로 원시 9개를 자르는데,
  // 그 중 맨 앞 1개는 "소운기"(출생~첫 대운 시작 전, ganZhi='')다. 필터링
  // 후 legacy의 "실제 대운"은 8개만 남는다. 반면 PHASE4의 [DaewoonEngine]은
  // 소운기를 내부에서 걸러낸 뒤에도 요청한 개수(count=9)만큼 실제 대운을
  // 채워서 반환하므로 9개가 나온다 — legacy가 슬롯 낭비로 1개 적은 것이지,
  // new가 틀린 게 아니다(재확인: 두 목록의 첫 8개는 완전히 동일).
  group('[j9·B02~B10] 레거시 vs 신규(PHASE1~4+어댑터) 대운 목록 비교(공통 접두사) — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: 대운 간지 목록의 공통 접두사(legacy 8개)는 legacy/new 동일, new는 9번째를 추가로 보유',
        () {
          final legacyB = _runLegacy(u, _kFixedDate);
          final newB = _runNew(u, _kFixedDate);

          final legacyReal = legacyB.saju.luckPillars
              .where((lp) => lp.ganZhiKr.isNotEmpty)
              .toList();
          final newReal = newB.saju.luckPillars
              .where((lp) => lp.ganZhiKr.isNotEmpty)
              .toList();

          // ignore: avoid_print
          print('\n========== ${u.userId} (대운 목록) ==========');
          // ignore: avoid_print
          print('[legacy] ${legacyReal.map((e) => e.ganZhiKr).toList()}');
          // ignore: avoid_print
          print('[new]    ${newReal.map((e) => e.ganZhiKr).toList()}');

          expect(
            legacyReal.length,
            8,
            reason: 'legacy는 소운기 슬롯 낭비로 실제 대운이 항상 8개여야 함(회귀 확인)',
          );
          expect(
            newReal.length,
            9,
            reason: 'new는 요청한 count(9)만큼 실제 대운을 항상 채워야 함(회귀 확인)',
          );
          expect(
            newReal.take(8).map((e) => e.ganZhiKr).toList(),
            legacyReal.map((e) => e.ganZhiKr).toList(),
            reason:
                '${u.userId}: 공통 접두사(첫 8개)는 8글자가 동일하므로 legacy/new가 완전히 동일해야 함',
          );
        },
      );
    }
  });

  group('[j9·B02~B07,B10] legacy/new 결과 비교(공통 접두사 기준, 용신 불필요 항목)', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: B02/B03/B04/B05/B06/B07/B10 — legacy 타임라인은 new 타임라인의 접두사와 동일',
        () {
          final legacyB = _runLegacy(u, _kFixedDate);
          final newB = _runNew(u, _kFixedDate);

          for (final id in ['B02', 'B03', 'B04', 'B05', 'B06', 'B07']) {
            final legacyData = legacyB.results[id]!.data;
            final newData = newB.results[id]!.data;
            // ignore: avoid_print
            print('[$id] legacy=$legacyData');
            // ignore: avoid_print
            print('[$id] new   =$newData');

            final legacyTimeline = legacyData['timeline'] as List?;
            final newTimeline = newData['timeline'] as List?;
            if (legacyTimeline != null && newTimeline != null) {
              expect(
                newTimeline.take(legacyTimeline.length).toList(),
                legacyTimeline,
                reason:
                    '${u.userId}: $id의 timeline은 공통 접두사(legacy 길이만큼)가 legacy/new 완전히 동일해야 함',
              );
            }
          }

          // B10(대운×세운 조합)은 luckPillars가 아니라 saju.currentLuck 1건 +
          // 올해 세운만 보므로(대운 개수 차이의 영향 없음) 완전 동일해야 한다.
          // ignore: avoid_print
          print('[B10] legacy=${legacyB.results['B10']!.data}');
          // ignore: avoid_print
          print('[B10] new   =${newB.results['B10']!.data}');
          expect(
            newB.results['B10']!.data,
            legacyB.results['B10']!.data,
            reason:
                '${u.userId}: B10은 currentLuck 1건 기준이므로 legacy/new가 완전히 동일해야 함',
          );
        },
      );
    }
  });

  group('[j9·B08/B09] 용신/기신 기반 최고·최악 대운 — profile 유무에 따른 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: legacy(profile=null)는 판단 불가, new(profile 有)는 실제 판정',
        () {
          final legacyB = _runLegacy(u, _kFixedDate);
          final newB = _runNew(u, _kFixedDate);

          // legacy 경로는 SajuProfile을 계산하지 않으므로 B08/B09가 "판단
          // 불가"로 안전 처리되어야 한다(새로 용신을 만들어내지 않는다).
          expect(legacyB.results['B08']!.data['periods'], isEmpty);
          expect(
            legacyB.results['B08']!.data['summary'],
            contains('판단하기 어려워요'),
          );
          expect(legacyB.results['B09']!.data['periods'], isEmpty);
          expect(
            legacyB.results['B09']!.data['summary'],
            contains('판단하기 어려워요'),
          );

          // new 경로는 PHASE3 SajuProfile.yongsin이 있으므로 실제 오행
          // 라벨을 포함한 판정 문구가 나와야 한다(값 자체는 사주마다 다르므로
          // "판단 불가" 문구가 아닌 것만 확인 — 결정론 값은 별도 회귀에서
          // 확인).
          final yongsin = newB.profile?.yongsin;
          expect(
            yongsin,
            isNotNull,
            reason: '${u.userId}: PHASE3가 계산한 용신/기신이 있어야 함',
          );
          // ignore: avoid_print
          print(
            '[${u.userId}] yongsin=${yongsin?.yongsin} gisin=${yongsin?.gisin}',
          );
          // ignore: avoid_print
          print('[B08] new=${newB.results['B08']!.data}');
          // ignore: avoid_print
          print('[B09] new=${newB.results['B09']!.data}');
          expect(
            newB.results['B08']!.data['summary'],
            isNot(contains('판단하기 어려워요')),
          );
          expect(
            newB.results['B09']!.data['summary'],
            isNot(contains('판단하기 어려워요')),
          );
        },
      );
    }
  });

  group('[j9·B02~B10] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext(profile 포함) + runJeontongCategory("B02"~"B10") 예외 없이 동작',
        () {
          final newB = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(rules, isNotNull);

          final ctx = JeontongCalcContext(
            saju: newB.saju,
            interp: newB.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
            profile: newB.profile,
          );

          for (final id in _bIds) {
            late final JeontongCategoryResult result;
            expect(
              () => result = runJeontongCategory(id, ctx),
              returnsNormally,
            );
            expect(result.category, isNotEmpty);
            // 플레이스홀더가 아니라 실계산 결과여야 하므로, 단일 키
            // {'message':...}/{'note':...} 형태가 아니라 여러 키를 가져야 한다.
            expect(result.data.length, greaterThan(1));
          }
        },
      );
    }
  });
}
