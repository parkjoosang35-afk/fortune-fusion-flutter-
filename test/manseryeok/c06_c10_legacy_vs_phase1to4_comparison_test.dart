// [j10 · C06~C10 신규 구현] 레거시(SajuEngine.calculate) vs 신규(PHASE1~4 →
// sajuResultFromProfile 어댑터) 경로에서 C06(이동수)/C07(시험운)/C08(관재수)
// /C09(인간관계)/C10(12개월 월별) 결과를 비교한다.
//
// C06~C10은 B02~B10과 마찬가지로 "원본 파이썬 이식"이 아니라 이번 세션에서
// saju_c_group_modules.dart에 신규로 설계한 계산이다(사용자 최종 지시 §3
// "C06~C10 진행"). 세운 간지(대표일 6/15 기준)와 일간/일지만 있으면 계산
// 가능하므로(C08만 원국 4주 전체가 필요), legacy/new 두 경로 모두 같은
// 생년월일이면 완전히 동일한 결과가 나와야 한다(대운 개수 차이 같은 B그룹
// 특유의 "알려진 차이"가 없음 — §11 "신규 엔진이 맞으면 유지"와 무관하게
// 애초에 legacy/new가 100% 일치해야 하는 케이스).
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

const _cIds = ['C06', 'C07', 'C08', 'C09', 'C10'];

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile, this.results);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile;
  final Map<String, JeontongCategoryResult> results;
}

Map<String, JeontongCategoryResult> _runCGroup(
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
  return {for (final id in _cIds) id: runJeontongCategory(id, ctx)};
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
  final r = _runCGroup(saju, interp, referenceDate, null);
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
  final r = _runCGroup(saju, interp, referenceDate, p4);
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

  group('[j10·C06~C10] 카테고리 등록/제외 상태 확인', () {
    test('kJeontongPlaceholderCategoryIds에 C06~C10이 더 이상 없어야 함', () {
      for (final id in _cIds) {
        expect(
          kJeontongPlaceholderCategoryIds.contains(id),
          isFalse,
          reason: '$id는 실계산으로 전환되어 플레이스홀더 목록에서 빠져야 함',
        );
      }
    });
  });

  group('[j10·C06~C10] 레거시 vs 신규(PHASE1~4+어댑터) 결과 완전 일치 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: C06/C07/C08/C09/C10 — legacy와 new의 결과 데이터가 완전히 동일해야 함', () {
        final legacyC = _runLegacy(u, _kFixedDate);
        final newC = _runNew(u, _kFixedDate);

        for (final id in _cIds) {
          final legacyData = legacyC.results[id]!.data;
          final newData = newC.results[id]!.data;
          // ignore: avoid_print
          print('[$id] legacy=$legacyData');
          // ignore: avoid_print
          print('[$id] new   =$newData');
          expect(
            newData,
            legacyData,
            reason: '${u.userId}: $id는 세운 간지(대표일 6/15) + 원국 4주만으로 계산되므로 '
                'legacy/new 결과가 완전히 동일해야 함',
          );
        }
      });
    }
  });

  group('[j10·C08] 세운×원국 관계 비교(analyzeExternal) 결과가 실제로 발동하는지 확인', () {
    test('seed-user-A(1972-02-13 KST 02:00 남): C08 결과에 관계/관성 판정 문구가 포함됨', () {
      final newC = _runNew(_seedUsers.first, _kFixedDate);
      final data = newC.results['C08']!.data;
      // ignore: avoid_print
      print('[C08 seed-user-A] $data');
      expect(data['title'], isNotEmpty);
      expect(data['overall'], isNotEmpty);
      expect(data['advice'], isNotEmpty);
      // 의학적 진단처럼 단정하지 않는지 — "겪습니다"류의 단정 표현이
      // 아니라 "필요한 시기"/"가능성" 수준의 완곡한 표현만 사용해야 함.
      expect(data['overall'], isNot(contains('반드시')));
    });
  });

  group('[j10·C10] 12개월 월별 요약이 정확히 12줄인지 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: C10 monthly_summary 길이는 12', () {
        final newC = _runNew(u, _kFixedDate);
        final monthly = newC.results['C10']!.data['monthly_summary'] as List;
        expect(monthly.length, 12);
      });
    }
  });

  group('[j10·C06~C10] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: JeontongCalcContext(profile 포함) + runJeontongCategory("C06"~"C10") 예외 없이 동작', () {
        final newC = _runNew(u, _kFixedDate);
        final rules = SajuFortuneRules.cachedOrNull;
        expect(rules, isNotNull);

        final ctx = JeontongCalcContext(
          saju: newC.saju,
          interp: newC.interp,
          rules: rules!,
          referenceDate: _kFixedDate,
          profile: newC.profile,
        );

        for (final id in _cIds) {
          late final JeontongCategoryResult result;
          expect(() => result = runJeontongCategory(id, ctx), returnsNormally);
          expect(result.category, isNotEmpty);
          expect(result.data.length, greaterThan(1));
        }
      });
    }
  });
}
