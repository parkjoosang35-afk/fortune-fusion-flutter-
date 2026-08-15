// [j12 · F03~F08/F10 신규 구현] 레거시(SajuEngine.calculate) vs 신규(PHASE1~4 →
// sajuResultFromProfile 어댑터) 경로에서 F03~F08/F10(사업 아이템/창업vs직장/
// 이직 타이밍/부동산 매매 타이밍/투자 성향/결혼 적령기/유학·해외 진출운)
// 결과를 비교한다.
//
// F03~F08/F10은 B02~B10/C06~C10/D04/D10과 마찬가지로 "원본 파이썬 이식"이
// 아니라 이번 세션에서 saju_f_group_modules.dart에 신규로 설계한 계산이다
// (사용자 최종 지시 §3 "F03~F08/F10 진행", 사용자 승인 "응"). 모든 계산은
// 이미 검증된 순수 함수/고정 테이블(getTenGod/getGongmang/findSinsal) 및
// B02~B10이 이미 구현한 대운×십신 복원 헬퍼(daewoonsWithTenGod,
// getDaewoonCareerFlow, getDaewoonLoveFlow)를 재사용할 뿐이라, 원국
// 4주(saju.pillars)+대운(luckPillars)만 legacy/new가 일치하면 두 경로의
// 결과도 완전히 동일해야 한다.
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

const _fIds = ['F03', 'F04', 'F05', 'F06', 'F07', 'F08', 'F10'];

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile, this.results);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile;
  final Map<String, JeontongCategoryResult> results;
}

Map<String, JeontongCategoryResult> _runFGroup(
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
  return {for (final id in _fIds) id: runJeontongCategory(id, ctx)};
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
  final r = _runFGroup(saju, interp, referenceDate, null);
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
  final r = _runFGroup(saju, interp, referenceDate, p4);
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

  group('[j12·F03~F08/F10] 카테고리 등록/제외 상태 확인', () {
    test('kJeontongPlaceholderCategoryIds에 F03~F08/F10이 더 이상 없어야 함', () {
      for (final id in _fIds) {
        expect(
          kJeontongPlaceholderCategoryIds.contains(id),
          isFalse,
          reason: '$id는 실계산으로 전환되어 플레이스홀더 목록에서 빠져야 함',
        );
      }
    });

    test('F09는 여전히 플레이스홀더 목록에 남아 있어야 함(이번 라운드 구현 대상 아님)', () {
      expect(kJeontongPlaceholderCategoryIds.contains('F09'), isTrue);
    });
  });

  // F03(일간 오행+재성 카운트)/F04(관성 카운트+공망)/F07(편재·정재 카운트)/
  // F10(역마+편재+수 오행 카운트)은 대운 목록([saju.luckPillars])을 전혀
  // 순회하지 않으므로 legacy/new가 완전히 동일해야 한다.
  const fIdsFullEqual = ['F03', 'F04', 'F07', 'F10'];

  group('[j12·F03/F04/F07/F10] 레거시 vs 신규(PHASE1~4+어댑터) 결과 완전 일치 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F03/F04/F07/F10 — legacy와 new의 결과 데이터가 완전히 동일해야 함', () {
        final legacyF = _runLegacy(u, _kFixedDate);
        final newF = _runNew(u, _kFixedDate);

        for (final id in fIdsFullEqual) {
          final legacyData = legacyF.results[id]!.data;
          final newData = newF.results[id]!.data;
          // ignore: avoid_print
          print('[$id] legacy=$legacyData');
          // ignore: avoid_print
          print('[$id] new   =$newData');
          expect(
            newData,
            legacyData,
            reason: '${u.userId}: $id는 원국 4주(distribution/gongmang/sinsal/'
                'fiveElementsCount)만으로 계산되며 대운 목록을 순회하지 않으므로 '
                'legacy/new 결과가 완전히 동일해야 함',
          );
        }
      });
    }
  });

  // [알려진 차이 — B02~B10 선례와 동일 원리, §8/§11 "신규 엔진이 맞으면
  // 유지"] F05/F06/F08은 daewoonsWithTenGod(saju.luckPillars 순회)를
  // 직접(F06) 또는 getDaewoonCareerFlow/getDaewoonLoveFlow를 통해
  // 간접(F05/F08) 사용한다. legacy(SajuEngine.calculate)는
  // `getDaYun().take(9)`로 원시 9개를 잘라 그 중 맨 앞 1개(소운기,
  // ganZhi='')가 필터링되어 실제 대운이 8개만 남는 반면, PHASE4의
  // [DaewoonEngine]은 소운기를 내부에서 걸러낸 뒤에도 요청한 개수(9)를
  // 채워 9개를 반환한다(daewoon_engine.dart 참고) — legacy가 슬롯
  // 낭비로 1개 적은 것이지 new가 틀린 게 아니다(b02_b10 테스트에서 이미
  // 동일하게 결론). 따라서 이 3개 카테고리는 리스트 필드에 대해 "공통
  // 접두사(legacy 길이만큼) 일치"만 검증하고, 대운 개수에 무관한
  // 불리언/문자열 필드는 완전 일치를 검증한다.
  group('[j12·F05/F06/F08] 레거시 vs 신규 — 대운 목록 의존 필드는 공통 접두사 비교', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F05/F06/F08 — 대운 개수 무관 필드는 완전 일치, 리스트 필드는 공통 접두사 일치', () {
        final legacyF = _runLegacy(u, _kFixedDate);
        final newF = _runNew(u, _kFixedDate);

        // F05 — current_daewoon_hit/current_year_hit/verdict는 대운
        // "개수"가 아니라 saju.currentLuck(공통 접두사 안에 항상 존재)과
        // upcoming.first(가장 이른 시기 — 공통 접두사 안에서 결정)에만
        // 의존하므로 완전 일치해야 한다. upcoming_periods(리스트)만
        // 공통 접두사 비교로 완화한다.
        final legacyF05 = legacyF.results['F05']!.data;
        final newF05 = newF.results['F05']!.data;
        // ignore: avoid_print
        print('[F05] legacy=$legacyF05');
        // ignore: avoid_print
        print('[F05] new   =$newF05');
        expect(newF05['current_daewoon_hit'], legacyF05['current_daewoon_hit']);
        expect(newF05['current_year_hit'], legacyF05['current_year_hit']);
        expect(newF05['verdict'], legacyF05['verdict']);
        final legacyUpcoming = legacyF05['upcoming_periods'] as List;
        final newUpcoming = newF05['upcoming_periods'] as List;
        expect(
          newUpcoming.take(legacyUpcoming.length).toList(),
          legacyUpcoming,
          reason: '${u.userId}: F05 upcoming_periods 공통 접두사(legacy 길이만큼)는 legacy/new 동일해야 함',
        );

        // F06 — timeline은 daewoonsWithTenGod 전체를 그대로 순회하므로
        // 공통 접두사만 비교한다. peak_periods/summary는 새로 추가된
        // 9번째 대운이 우연히 peak 조건(토+재성)을 만족하지 않는 한
        // legacy와 동일하게 나오지만, 조건 만족 여부는 사주마다 다를 수
        // 있으므로 완전 일치를 강제하지 않고 legacy의 peak가 new의
        // peak에 순서대로 포함(prefix)되는지만 확인한다.
        final legacyF06 = legacyF.results['F06']!.data;
        final newF06 = newF.results['F06']!.data;
        // ignore: avoid_print
        print('[F06] legacy=$legacyF06');
        // ignore: avoid_print
        print('[F06] new   =$newF06');
        final legacyTimeline = legacyF06['timeline'] as List;
        final newTimeline = newF06['timeline'] as List;
        expect(
          newTimeline.take(legacyTimeline.length).toList(),
          legacyTimeline,
          reason: '${u.userId}: F06 timeline 공통 접두사(legacy 길이만큼)는 legacy/new 동일해야 함',
        );
        final legacyPeaks = legacyF06['peak_periods'] as List;
        final newPeaks = newF06['peak_periods'] as List;
        expect(
          newPeaks.take(legacyPeaks.length).toList(),
          legacyPeaks,
          reason: '${u.userId}: F06 peak_periods 공통 접두사는 legacy/new 동일해야 함(신규 9번째 대운이 추가로 peak일 수만 있음)',
        );

        // F08 — spouse_god_label(성별 기반, 대운 무관)은 완전 일치해야
        // 한다. active_periods(리스트)는 공통 접두사 비교로 완화한다.
        final legacyF08 = legacyF.results['F08']!.data;
        final newF08 = newF.results['F08']!.data;
        // ignore: avoid_print
        print('[F08] legacy=$legacyF08');
        // ignore: avoid_print
        print('[F08] new   =$newF08');
        expect(newF08['spouse_god_label'], legacyF08['spouse_god_label']);
        final legacyActive = legacyF08['active_periods'] as List;
        final newActive = newF08['active_periods'] as List;
        expect(
          newActive.take(legacyActive.length).toList(),
          legacyActive,
          reason: '${u.userId}: F08 active_periods 공통 접두사는 legacy/new 동일해야 함',
        );
      });
    }
  });

  group('[j12·F03] 맞는 사업 아이템 — 일간 오행 기반 업종 목록 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F03 결과에 오행/업종 목록/스타일이 채워짐', () {
        final newF = _runNew(u, _kFixedDate);
        final data = newF.results['F03']!.data;
        expect(data['element'], isNotEmpty);
        expect((data['items'] as List), isNotEmpty);
        expect(data['style'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j12·F04] 창업 vs 직장 — 관성/공망 기반 판정 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F04 결과에 관성 개수/판정/메시지가 채워짐', () {
        final newF = _runNew(u, _kFixedDate);
        final data = newF.results['F04']!.data;
        expect(data['officer_count'], isA<int>());
        expect(data['gongmang_hits_officer'], isA<bool>());
        expect(data['verdict'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j12·F05] 이직 타이밍 — 대운·세운 관성 발동 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F05 결과에 대운/세운 발동 여부와 판정이 채워짐', () {
        final newF = _runNew(u, _kFixedDate);
        final data = newF.results['F05']!.data;
        expect(data['current_daewoon_hit'], isA<bool>());
        expect(data['current_year_hit'], isA<bool>());
        expect(data['verdict'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j12·F06] 부동산 매매 타이밍 — 토·재성 대운 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F06 결과에 타임라인/요약이 채워짐', () {
        final newF = _runNew(u, _kFixedDate);
        final data = newF.results['F06']!.data;
        expect((data['timeline'] as List), isNotEmpty);
        expect(data['summary'], isNotEmpty);
      });
    }
  });

  group('[j12·F07] 투자 성향 분석 — 편재/정재 비율 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F07 결과에 공격/방어 카운트와 스타일이 채워짐', () {
        final newF = _runNew(u, _kFixedDate);
        final data = newF.results['F07']!.data;
        expect(data['aggressive_count'], isA<int>());
        expect(data['defensive_count'], isA<int>());
        expect(data['style'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j12·F08] 결혼 적령기 — 재/관성 대운 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F08 결과에 배우자성 라벨/메시지가 채워짐', () {
        final newF = _runNew(u, _kFixedDate);
        final data = newF.results['F08']!.data;
        expect(data['spouse_god_label'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j12·F10] 유학·해외 진출운 — 역마·편재·수 오행 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: F10 결과에 역마/편재/수 오행 카운트와 점수가 채워짐', () {
        final newF = _runNew(u, _kFixedDate);
        final data = newF.results['F10']!.data;
        expect(data['has_yeokma'], isA<bool>());
        expect(data['wealth_count'], isA<int>());
        expect(data['water_count'], isA<int>());
        expect(data['score'], isA<int>());
        expect(data['style'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j12·F06/F07/F08] 건강 카테고리 아님 — 단정적 표현 최소 확인', () {
    test('seed-user-A: F06/F07/F08 메시지에 "반드시" 같은 단정 표현이 없어야 함', () {
      final newF = _runNew(_seedUsers.first, _kFixedDate);
      for (final id in ['F06', 'F07', 'F08']) {
        final data = newF.results[id]!.data;
        final message = data['message'] ?? data['summary'];
        expect(message, isNot(contains('반드시')));
      }
    });
  });

  group('[j12·F03~F08/F10] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext(profile 포함) + runJeontongCategory(F그룹) 예외 없이 동작',
        () {
          final newF = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(rules, isNotNull);

          final ctx = JeontongCalcContext(
            saju: newF.saju,
            interp: newF.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
            profile: newF.profile,
          );

          for (final id in _fIds) {
            late final JeontongCategoryResult result;
            expect(() => result = runJeontongCategory(id, ctx), returnsNormally);
            expect(result.category, isNotEmpty);
            expect(result.data.length, greaterThan(1));
          }
        },
      );
    }
  });
}
