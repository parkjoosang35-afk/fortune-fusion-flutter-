// [j14 · E08/E09/E10 재검토 → 실계산 전환] 레거시(SajuEngine.calculate) vs
// 신규(PHASE1~4 → sajuResultFromProfile 어댑터) 경로에서 E08(띠 궁합)/
// E09(오행 궁합)/E10(겉궁합 vs 속궁합) 결과를 비교한다.
//
// E08~E10은 원래 "상대방 사주 필요 → 구현 불가"로 분류된 E01~E07과 함께
// placeholder 였으나, 재검토 결과 안내 문구 자체가 "연지 기준 12띠 대조"/
// "오행 상보성 대조"/"연주(겉)·일주(속) 분리 대조"라는 자기참조형 계산
// 힌트를 담고 있어 상대방 정보 없이 본인 사주만으로 계산 가능함이 밝혀져
// saju_e_group_modules.dart로 실계산 전환되었다(F09와 동일한 재검토 패턴).
//
// [완전 일치 예상] E08/E09/E10은 [SajuProfile](PHASE1~4 전용 데이터)에
// 전혀 의존하지 않고 [SajuResult](pillars['year'].zhi / dayMaster.element)
// 와 고정 룰표(zhi_combos/sheng/ke)만 조회하므로, G05/G06과 동일하게
// legacy/new 결과가 완전히 동일해야 한다.
import 'package:flutter_app/features/home/domain/jeontong_eighty_calculator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
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

const _eIds = ['E08', 'E09', 'E10'];

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile, this.results);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile;
  final Map<String, JeontongCategoryResult> results;
}

Map<String, JeontongCategoryResult> _runEGroup(
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
  return {for (final id in _eIds) id: runJeontongCategory(id, ctx)};
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
  final r = _runEGroup(saju, interp, referenceDate, null);
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
  final r = _runEGroup(saju, interp, referenceDate, p4);
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

  group('[j14·E08/E09/E10] 카테고리 등록/제외 상태 확인', () {
    test('kJeontongPlaceholderCategoryIds에 E08/E09/E10이 더 이상 없어야 함', () {
      for (final id in _eIds) {
        expect(
          kJeontongPlaceholderCategoryIds.contains(id),
          isFalse,
          reason: '$id는 자기참조형 실계산으로 전환되어 플레이스홀더 목록에서 빠져야 함',
        );
      }
    });

    // (2026-08-16 최종 삭제) E01~E07은 진짜 상대방 사주가 필요해 구현
    // 불가로 최종 확정되어, 플레이스홀더로 남는 대신 카탈로그
    // (JeontongEightyMatrix)에서 완전히 삭제되었다.
    test('E01~E07은 카탈로그에서 완전히 삭제되어 더 이상 존재하지 않아야 함', () {
      for (final id in ['E01', 'E02', 'E03', 'E04', 'E05', 'E06', 'E07']) {
        expect(
          JeontongEightyMatrix.byId(id),
          isNull,
          reason: '$id는 상대방 사주가 필요해 구현 불가로 카탈로그에서 삭제되었어야 함',
        );
        expect(kJeontongPlaceholderCategoryIds.contains(id), isFalse);
      }
    });
  });

  // E08/E09/E10은 [SajuProfile](PHASE1~4 전용 데이터)에 전혀 의존하지
  // 않고 [SajuResult](pillars['year'].zhi/dayMaster.element)와 고정
  // 룰표(zhi_combos/sheng/ke)만 조회하므로 legacy/new가 완전히 동일해야
  // 한다(G05/G06과 동일한 구조 — 대운 목록을 순회하지 않으므로
  // B02~B10/F05~F08의 8개/9개 대운 차이 문제와도 무관하다).
  group('[j14·E08/E09/E10] 레거시 vs 신규(PHASE1~4+어댑터) 결과 완전 일치 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: E08/E09/E10 — legacy와 new의 결과 데이터가 완전히 동일해야 함', () {
        final legacyE = _runLegacy(u, _kFixedDate);
        final newE = _runNew(u, _kFixedDate);

        for (final id in _eIds) {
          final legacyData = legacyE.results[id]!.data;
          final newData = newE.results[id]!.data;
          // ignore: avoid_print
          print('[$id] legacy=$legacyData');
          // ignore: avoid_print
          print('[$id] new   =$newData');
          expect(
            newData,
            legacyData,
            reason:
                '${u.userId}: $id는 원국 연지/일간 오행만으로 계산되며 '
                '[SajuProfile]에 의존하지 않으므로 legacy/new 결과가 '
                '완전히 동일해야 함',
          );
        }
      });
    }
  });

  group('[j14·E08] 띠 궁합 — 연지 기준 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: E08 결과에 내 띠/베스트/워스트/요약이 채워짐', () {
        final newE = _runNew(u, _kFixedDate);
        final data = newE.results['E08']!.data;
        expect(data['my_animal'], isNotEmpty);
        expect(data['best_matches'], isA<List>());
        expect(data['worst_matches'], isA<List>());
        expect(data['summary'], isNotEmpty);
      });
    }
  });

  group('[j14·E09] 오행 궁합 — 일간 오행 기준 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: E09 결과에 4방향 오행 관계와 요약이 채워짐', () {
        final newE = _runNew(u, _kFixedDate);
        final data = newE.results['E09']!.data;
        expect(data['my_element'], isNotEmpty);
        expect(data['supportive_element'], isNotEmpty);
        expect(data['supported_element'], isNotEmpty);
        expect(data['clashing_element'], isNotEmpty);
        expect(data['clashed_by_element'], isNotEmpty);
        expect(data['summary'], isNotEmpty);
      });
    }
  });

  group('[j14·E10] 겉궁합 vs 속궁합 — 연주/일주 오행 관계 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: E10 결과에 겉/속 오행과 관계/요약이 채워짐', () {
        final newE = _runNew(u, _kFixedDate);
        final data = newE.results['E10']!.data;
        expect(data['outer_element'], isNotEmpty);
        expect(data['inner_element'], isNotEmpty);
        expect(data['relation'], isNotEmpty);
        expect(data['summary'], isNotEmpty);
      });
    }
  });

  group('[j14·E08/E09/E10] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext(profile 포함) + runJeontongCategory(E그룹) 예외 없이 동작',
        () {
          final newE = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(rules, isNotNull);

          final ctx = JeontongCalcContext(
            saju: newE.saju,
            interp: newE.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
            profile: newE.profile,
          );

          for (final id in _eIds) {
            late final JeontongCategoryResult result;
            expect(
              () => result = runJeontongCategory(id, ctx),
              returnsNormally,
            );
            expect(result.category, isNotEmpty);
            expect(result.data.length, greaterThan(1));
          }
        },
      );
    }
  });
}
