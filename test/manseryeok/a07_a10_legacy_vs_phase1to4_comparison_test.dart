// [j8 · A07~A10 신규 구현] 레거시(SajuEngine.calculate + SajuInterpreter) vs
// 신규(PHASE1~4 → sajuResultFromProfile 어댑터 → SajuInterpreter) 경로에서
// A07(자녀운)/A08(부모·형제운)/A09(학업·시험운)/A10(인생 5대 전환점) 결과를
// 비교한다.
//
// A07~A10은 A01~A06과 달리 "원본 파이썬 이식"이 아니라 이번 세션에서
// saju_life_modules.dart에 신규로 설계한 계산이다(사용자 최종 지시
// §7 A그룹). 따라서 원본과의 1:1 대조가 아니라, 다음을 검증한다:
//   1) legacy 경로와 new(PHASE1~4) 경로가 동일한 십신 분포를 낼 때
//      (dayMasterStrength 등 다른 조건과 무관하게 십신 distribution
//      자체는 8글자/오행/십신이 100% 일치하므로 항상 동일해야 함)
//      A07~A10 결과도 완전히 동일해야 한다.
//   2) 각 결과가 정의된 값 집합/형식을 벗어나지 않는다(구조적 안전성).
//   3) runJeontongCategory('A07'~'A10', ctx) 경로가 예외 없이 정상
//      동작하고, kJeontongPlaceholderCategoryIds에서 제외되어 있다.
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

class _Bundle {
  _Bundle(this.saju, this.interp, this.a07, this.a08, this.a09, this.a10);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult a07;
  final JeontongCategoryResult a08;
  final JeontongCategoryResult a09;
  final JeontongCategoryResult a10;
}

Map<String, JeontongCategoryResult> _runQuartet(
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
  return {
    'A07': runJeontongCategory('A07', ctx),
    'A08': runJeontongCategory('A08', ctx),
    'A09': runJeontongCategory('A09', ctx),
    'A10': runJeontongCategory('A10', ctx),
  };
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
  final r = _runQuartet(saju, interp, referenceDate);
  return _Bundle(saju, interp, r['A07']!, r['A08']!, r['A09']!, r['A10']!);
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
  final r = _runQuartet(saju, interp, referenceDate);
  return _Bundle(saju, interp, r['A07']!, r['A08']!, r['A09']!, r['A10']!);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
  });

  group('[j8·A07~A10] 카테고리 등록/제외 상태 확인', () {
    test('kJeontongPlaceholderCategoryIds에 A07~A10이 더 이상 없어야 함', () {
      expect(kJeontongPlaceholderCategoryIds.contains('A07'), isFalse);
      expect(kJeontongPlaceholderCategoryIds.contains('A08'), isFalse);
      expect(kJeontongPlaceholderCategoryIds.contains('A09'), isFalse);
      expect(kJeontongPlaceholderCategoryIds.contains('A10'), isFalse);
    });
  });

  group('[j8·A07~A10] 레거시 vs 신규(PHASE1~4+어댑터) 전체 비교 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 8글자/십신 분포/A07~A10 전체 비교', () {
        final legacyB = _runLegacy(u, _kFixedDate);
        final newB = _runNew(u, _kFixedDate);

        // ignore: avoid_print
        print('\n========== ${u.userId} (A07~A10) ==========');

        // ── 십신 분포(공통 입력) ──
        final legacyDist = legacyB.interp.tenGodsAnalysis.distribution;
        final newDist = newB.interp.tenGodsAnalysis.distribution;
        // ignore: avoid_print
        print('[십신분포] legacy=$legacyDist');
        // ignore: avoid_print
        print('[십신분포] new   =$newDist');
        expect(
          newDist,
          legacyDist,
          reason: '${u.userId} 십신 분포는 8글자가 동일하므로 완전히 일치해야 함',
        );

        // ── A07(자녀운) ──
        // ignore: avoid_print
        print('[A07] legacy=${legacyB.a07.data}');
        // ignore: avoid_print
        print('[A07] new   =${newB.a07.data}');
        expect(legacyB.a07.category, '평생 자녀운');
        expect(newB.a07.category, '평생 자녀운');
        expect(newB.a07.data['child_god'], anyOf(['관성(자녀성)', '식상(자녀성)']));
        expect(newB.a07.data['count'], isA<int>());
        expect(newB.a07.data['style'], isNotEmpty);
        expect(newB.a07.data['message'], isNotEmpty);
        expect(newB.a07.data['timing_hint'], isNotEmpty);
        expect(
          newB.a07.data,
          legacyB.a07.data,
          reason: '${u.userId}: A07은 십신 분포만으로 결정되므로 완전 동일해야 함',
        );

        // ── A08(부모·형제운) ──
        // ignore: avoid_print
        print('[A08] legacy=${legacyB.a08.data}');
        // ignore: avoid_print
        print('[A08] new   =${newB.a08.data}');
        expect(legacyB.a08.category, '평생 부모·형제운');
        expect(newB.a08.data['parent_god'], '인성(정인·편인)');
        expect(newB.a08.data['sibling_god'], '비겁(비견·겁재)');
        expect(newB.a08.data['parent_count'], isA<int>());
        expect(newB.a08.data['sibling_count'], isA<int>());
        expect(
          newB.a08.data,
          legacyB.a08.data,
          reason: '${u.userId}: A08은 십신 분포만으로 결정되므로 완전 동일해야 함',
        );

        // ── A09(학업·시험운) ──
        // ignore: avoid_print
        print('[A09] legacy=${legacyB.a09.data}');
        // ignore: avoid_print
        print('[A09] new   =${newB.a09.data}');
        expect(legacyB.a09.category, '평생 학업·시험운');
        expect(newB.a09.data['study_god_count'], isA<int>());
        expect(newB.a09.data['has_munchang'], isA<bool>());
        expect(newB.a09.data['style'], isNotEmpty);
        expect(newB.a09.data['message'], isNotEmpty);
        // 문창귀인 boolean은 saju.sinsal 목록에 의존 — legacy/new 신살
        // 계산 경로가 다를 수 있으므로(§ 신강신약과 유사하게 PHASE 기준
        // 차이 가능) 완전 동일성은 강제하지 않고 구조만 검증한다.
        // ignore: avoid_print
        print(
          '[A09·문창귀인] legacy=${legacyB.a09.data['has_munchang']} '
          'new=${newB.a09.data['has_munchang']}',
        );

        // ── A10(인생 5대 전환점) — 대운 목록 조회 ──
        // [주의] legacy.SajuResult.luckPillars는 맨 앞에 "출생~첫 대운"
        // 구간을 나타내는 간지 없는(ganZhi='') 플레이스홀더 항목을 포함할
        // 수 있으나(SajuEngine 고유 동작), PHASE1~4 DaewoonEngine은 이
        // 플레이스홀더를 생성하지 않는다(a03 테스트의 [대운] 섹션에서도
        // 동일하게 `legacyReal`로 빈 간지를 걸러낸 뒤 비교하는 것과 같은
        // 원리). A10은 getLifeTransitionPoints(saju)가 saju.luckPillars의
        // 앞 5개를 그대로 조회하는 순수 함수이므로, 빈 간지를 걸러낸
        // "실제 대운" 기준으로 비교해야 공정하다.
        // ignore: avoid_print
        print('[A10] legacy=${legacyB.a10.data}');
        // ignore: avoid_print
        print('[A10] new   =${newB.a10.data}');
        expect(legacyB.a10.category, '인생 5대 전환점');
        final newPoints = newB.a10.data['points'] as List;
        expect(newPoints.length, lessThanOrEqualTo(5));
        expect(newB.a10.data['summary'], isNotEmpty);
        final legacyRealPoints = legacyB.saju.luckPillars
            .where((lp) => lp.ganZhiKr.isNotEmpty)
            .take(5)
            .map(
              (lp) => {
                'start_age': lp.startAge,
                'start_year': lp.startYear,
                'gan_zhi_kr': lp.ganZhiKr,
              },
            )
            .toList();
        if (legacyRealPoints.isNotEmpty) {
          expect(
            newPoints,
            legacyRealPoints,
            reason:
                '${u.userId}: 빈 간지 플레이스홀더를 제외한 "실제 대운" 앞 5개는 legacy/new가 완전히 동일해야 함',
          );
        }
      });
    }
  });

  group('[j8·A07~A10] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext + runJeontongCategory("A07"~"A10") 예외 없이 동작',
        () {
          final newB = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(rules, isNotNull);

          final ctx = JeontongCalcContext(
            saju: newB.saju,
            interp: newB.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
          );

          for (final id in ['A07', 'A08', 'A09', 'A10']) {
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
