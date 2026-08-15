// [j11 · D04/D10 신규 구현] 레거시(SajuEngine.calculate) vs 신규(PHASE1~4 →
// sajuResultFromProfile 어댑터) 경로에서 D04(이번 주 운세)/D10(오늘 피해야
// 할 일) 결과를 비교한다.
//
// D04/D10은 B02~B10/C06~C10과 마찬가지로 "원본 파이썬 이식"이 아니라 이번
// 세션에서 saju_d_group_modules.dart에 신규로 설계한 계산이다(사용자 최종
// 지시 §3 "D04/D10 진행"). D04는 D02/D03/D05~D09가 이미 사용 중인
// getDailyFortune을 7일 반복 호출하는 것뿐이고, D10은 C08과 동일한 §5 공통
// 엔진(RelationshipsEngine.analyzeExternal)을 오늘 일진 간지로 호출하는
// 것뿐이라, 원국 4주(saju.pillars)만 legacy/new가 일치하면 두 경로의 결과도
// 완전히 동일해야 한다.
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

const _dIds = ['D04', 'D10'];

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile, this.results);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile;
  final Map<String, JeontongCategoryResult> results;
}

Map<String, JeontongCategoryResult> _runDGroup(
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
  return {for (final id in _dIds) id: runJeontongCategory(id, ctx)};
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
  final r = _runDGroup(saju, interp, referenceDate, null);
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
  final r = _runDGroup(saju, interp, referenceDate, p4);
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

  group('[j11·D04/D10] 카테고리 등록/제외 상태 확인', () {
    test('kJeontongPlaceholderCategoryIds에 D04/D10이 더 이상 없어야 함', () {
      for (final id in _dIds) {
        expect(
          kJeontongPlaceholderCategoryIds.contains(id),
          isFalse,
          reason: '$id는 실계산으로 전환되어 플레이스홀더 목록에서 빠져야 함',
        );
      }
    });
  });

  group('[j11·D04/D10] 레거시 vs 신규(PHASE1~4+어댑터) 결과 완전 일치 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: D04/D10 — legacy와 new의 결과 데이터가 완전히 동일해야 함', () {
        final legacyD = _runLegacy(u, _kFixedDate);
        final newD = _runNew(u, _kFixedDate);

        for (final id in _dIds) {
          final legacyData = legacyD.results[id]!.data;
          final newData = newD.results[id]!.data;
          // ignore: avoid_print
          print('[$id] legacy=$legacyData');
          // ignore: avoid_print
          print('[$id] new   =$newData');
          expect(
            newData,
            legacyData,
            reason: '${u.userId}: $id는 원국 4주 + 오늘(referenceDate) 기준 일진만으로 '
                '계산되므로 legacy/new 결과가 완전히 동일해야 함',
          );
        }
      });
    }
  });

  group('[j11·D04] 이번 주 운세 — 7일치 daily_summary 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: D04 daily_summary 길이는 7', () {
        final newD = _runNew(u, _kFixedDate);
        final daily = newD.results['D04']!.data['daily_summary'] as List;
        expect(daily.length, 7);
        expect(newD.results['D04']!.data['overall'], isNotEmpty);
      });
    }
  });

  group('[j11·D10] 오늘 피해야 할 일 — §5 공통 엔진(analyzeExternal) 결과 확인', () {
    test('seed-user-A(1972-02-13 KST 02:00 남): D10 결과에 관계 판정 문구가 포함됨', () {
      final newD = _runNew(_seedUsers.first, _kFixedDate);
      final data = newD.results['D10']!.data;
      // ignore: avoid_print
      print('[D10 seed-user-A] $data');
      expect(data['title'], isNotEmpty);
      expect(data['overall'], isNotEmpty);
      expect(data['advice'], isNotEmpty);
      // 의학적/단정적 진단 표현 금지 — "반드시"류의 단정 표현이 아니라
      // "가능성"/"조심하면 좋은 날" 수준의 완곡한 표현만 사용해야 함.
      expect(data['overall'], isNot(contains('반드시')));
    });
  });

  group('[j11·D04/D10] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: JeontongCalcContext(profile 포함) + runJeontongCategory("D04"/"D10") 예외 없이 동작', () {
        final newD = _runNew(u, _kFixedDate);
        final rules = SajuFortuneRules.cachedOrNull;
        expect(rules, isNotNull);

        final ctx = JeontongCalcContext(
          saju: newD.saju,
          interp: newD.interp,
          rules: rules!,
          referenceDate: _kFixedDate,
          profile: newD.profile,
        );

        for (final id in _dIds) {
          late final JeontongCategoryResult result;
          expect(() => result = runJeontongCategory(id, ctx), returnsNormally);
          expect(result.category, isNotEmpty);
          expect(result.data.length, greaterThan(1));
        }
      });
    }
  });
}
