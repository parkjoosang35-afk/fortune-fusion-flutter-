// [j13 · G03/G05/G06/G08/G10 신규 구현] 레거시(SajuEngine.calculate) vs
// 신규(PHASE1~4 → sajuResultFromProfile 어댑터) 경로에서 G03(대운별 건강
// 주의)/G05(나에게 나쁜 음식)/G06(사주 체질)/G08(사고·수술수)/G10(회복력·
// 면역) 결과를 비교한다.
//
// G03~G10은 B02~B10/C06~C10/D04/D10/F03~F08/F10과 마찬가지로 "원본 파이썬
// 이식"이 아니라 이번 세션에서 saju_g_group_modules.dart에 신규로 설계한
// 계산이다(사용자 최종 지시 §3 "G03/G05/G06/G08/G10 진행"). 건강 카테고리
// 표현 원칙(§6 — 의학적 진단처럼 표현하지 않음)도 함께 확인한다.
//
// [profile 의존 구조] G03(용신/기신)·G08(신살/관계)은 PHASE1~4가 계산한
// [SajuProfile]에만 존재하는 데이터를 조회한다. legacy 경로(profile=null)
// 에서는 B08/B09와 동일하게 "판단 불가"로 안전 처리되므로, 완전 일치가
// 아니라 "legacy=판단 불가, new=실제 판정"이라는 별도 검증이 필요하다.
// G05/G06/G10은 profile에 의존하지 않고 [SajuResult](fiveElementsCount/
// dayMaster/dayMasterStrength)만 조회하므로 legacy/new가 완전히 동일해야
// 한다(사전 진단 실행으로 확인 완료).
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

const _gIds = ['G03', 'G05', 'G06', 'G08', 'G10'];

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile, this.results);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile;
  final Map<String, JeontongCategoryResult> results;
}

Map<String, JeontongCategoryResult> _runGGroup(
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
  return {for (final id in _gIds) id: runJeontongCategory(id, ctx)};
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
  final r = _runGGroup(saju, interp, referenceDate, null);
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
  final r = _runGGroup(saju, interp, referenceDate, p4);
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

  group('[j13·G03/G05/G06/G08/G10] 카테고리 등록/제외 상태 확인', () {
    test(
      'kJeontongPlaceholderCategoryIds에 G03/G05/G06/G08/G10이 더 이상 없어야 함',
      () {
        for (final id in _gIds) {
          expect(
            kJeontongPlaceholderCategoryIds.contains(id),
            isFalse,
            reason: '$id는 실계산으로 전환되어 플레이스홀더 목록에서 빠져야 함',
          );
        }
      },
    );

    // (2026-08-15 갱신: G07은 재검토 결과 실계산으로 전환되어 이 목록에서
    // 빠졌다 — 별도 비교 테스트는
    // g07_legacy_vs_phase1to4_comparison_test.dart 참고.)
    // (2026-08-16 최종 삭제: G09(장수 가능성)는 `sinsal_engine.dart`에
    // 계산 근거 데이터가 없어 구현 불가로 최종 확정되어, 플레이스홀더로
    // 남는 대신 카탈로그(JeontongEightyMatrix)에서 완전히 삭제되었다.)
    test('G09는 카탈로그에서 완전히 삭제되어 더 이상 존재하지 않아야 함', () {
      expect(JeontongEightyMatrix.byId('G09'), isNull);
      expect(kJeontongPlaceholderCategoryIds.contains('G09'), isFalse);
    });
  });

  // G05(과다 오행 카운트)/G06(일간 오행+월지 계절)은 [SajuProfile]에
  // 전혀 의존하지 않고 [SajuResult](fiveElementsCount/dayMaster/pillars)
  // 만 조회하므로 legacy/new가 완전히 동일해야 한다(사전 진단 실행으로
  // 확인 완료 — 대운 목록을 순회하지 않아 B02~B10/F05~F08의 8개/9개
  // 차이 문제와도 무관하다).
  const gIdsFullEqual = ['G05', 'G06'];

  group('[j13·G05/G06] 레거시 vs 신규(PHASE1~4+어댑터) 결과 완전 일치 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: G05/G06 — legacy와 new의 결과 데이터가 완전히 동일해야 함', () {
        final legacyG = _runLegacy(u, _kFixedDate);
        final newG = _runNew(u, _kFixedDate);

        for (final id in gIdsFullEqual) {
          final legacyData = legacyG.results[id]!.data;
          final newData = newG.results[id]!.data;
          // ignore: avoid_print
          print('[$id] legacy=$legacyData');
          // ignore: avoid_print
          print('[$id] new   =$newData');
          expect(
            newData,
            legacyData,
            reason:
                '${u.userId}: $id는 원국 4주(fiveElementsCount/dayMaster)'
                '만으로 계산되며 [SajuProfile]에 의존하지 않으므로 '
                'legacy/new 결과가 완전히 동일해야 함',
          );
        }
      });
    }
  });

  // [A01/A02/A03 선례와 동일 원리 — §3 "PHASE1~4가 기준 엔진"] G10은
  // [SajuResult.dayMasterStrength]에 의존하는데, 이 값은 legacy(단순
  // 오행 비율 판정, `judgeStrength`)와 new(PHASE3 억부법,
  // [StrengthEngine])가 서로 다른 계산 방식을 쓰므로 신강/중화/신약
  // 경계값 근처(예: seed-user-C)에서 판정이 달라질 수 있다(身强↔中和
  // 등). 이는 PHASE3가 기준 엔진이라는 원칙(§3)에 따른 정상적인 결과이며
  // legacy에 맞추지 않는다. 따라서 dayMasterStrength가 legacy와 동일한
  // seed에서만 완전 일치를 강제하고(strict), 모든 seed에서는 구조적
  // 안전성(필드 채워짐/verdict가 정의된 값 중 하나)만 검증한다.
  group(
    '[j13·G10] 레거시 vs 신규(PHASE1~4+어댑터) — dayMasterStrength 동일 seed에서만 완전 일치',
    () {
      for (final u in _seedUsers) {
        test(
          '${u.userId}: G10 — strength 판정이 legacy와 같으면 완전 일치, 다르면 구조적 안전성만 확인',
          () {
            final legacyG = _runLegacy(u, _kFixedDate);
            final newG = _runNew(u, _kFixedDate);

            final legacyData = legacyG.results['G10']!.data;
            final newData = newG.results['G10']!.data;
            final strengthSame = legacyData['strength'] == newData['strength'];
            // ignore: avoid_print
            print('[G10] legacy=$legacyData');
            // ignore: avoid_print
            print('[G10] new   =$newData  (strength동일=$strengthSame)');

            if (strengthSame) {
              expect(
                newData,
                legacyData,
                reason:
                    '${u.userId}: dayMasterStrength가 legacy와 동일하므로 '
                    'G10 결과도 완전히 동일해야 함',
              );
            } else {
              expect(
                newData['verdict'],
                anyOf([
                  '회복력 우수형',
                  '기본 체력 양호형',
                  '꾸준한 관리 필요형',
                  '컨디션 관리 신경 써야 하는 편',
                ]),
                reason:
                    '${u.userId}: dayMasterStrength 판정 차이(PHASE3 기준 정상)로 '
                    'verdict가 달라질 수 있으나 4가지 정의된 값 중 하나여야 함',
              );
            }
            expect(newData['water_count'], isA<int>());
            expect(newData['message'], isNotEmpty);
          },
        );
      }
    },
  );

  // [B08/B09 선례와 동일 원리] G03(용신/기신)·G08(신살/관계)은
  // [SajuProfile]에만 존재하는 데이터를 조회한다. legacy 경로
  // (SajuEngine.calculate, profile=null)에서는 새로 계산하지 않고 "판단
  // 불가"로 안전하게 반환하며, new 경로(profile 有)에서는 실제 판정을
  // 반환한다. 완전 일치를 기대하는 것이 아니라 이 "전환 동작 자체"가
  // 올바른지 검증한다.
  group('[j13·G03/G08] 용신·기신/신살·관계 기반 판정 — profile 유무에 따른 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: legacy(profile=null)는 판단 불가, new(profile 有)는 실제 판정',
        () {
          final legacyG = _runLegacy(u, _kFixedDate);
          final newG = _runNew(u, _kFixedDate);

          // ignore: avoid_print
          print('[G03] legacy=${legacyG.results['G03']!.data}');
          // ignore: avoid_print
          print('[G03] new   =${newG.results['G03']!.data}');
          expect(legacyG.results['G03']!.data['timeline'], isEmpty);
          expect(legacyG.results['G03']!.data['caution_periods'], isEmpty);
          expect(
            legacyG.results['G03']!.data['summary'],
            contains('판단하기 어려워요'),
          );

          // ignore: avoid_print
          print('[G08] legacy=${legacyG.results['G08']!.data}');
          // ignore: avoid_print
          print('[G08] new   =${newG.results['G08']!.data}');
          expect(legacyG.results['G08']!.data['special_stars'], isEmpty);
          expect(legacyG.results['G08']!.data['clash_types'], isEmpty);
          expect(legacyG.results['G08']!.data['verdict'], '판단 불가');
          expect(
            legacyG.results['G08']!.data['message'],
            contains('판단하기 어려워요'),
          );

          final yongsin = newG.profile?.yongsin;
          expect(
            yongsin,
            isNotNull,
            reason: '${u.userId}: PHASE3가 계산한 용신/기신이 있어야 함',
          );
          expect((newG.results['G03']!.data['timeline'] as List), isNotEmpty);
          expect(
            newG.results['G03']!.data['summary'],
            isNot(contains('판단하기 어려워요')),
          );

          final sinsal = newG.profile?.sinsal;
          final relations = newG.profile?.relationships;
          expect(
            sinsal,
            isNotNull,
            reason: '${u.userId}: PHASE2가 계산한 신살이 있어야 함',
          );
          expect(
            relations,
            isNotNull,
            reason: '${u.userId}: PHASE2가 계산한 원국 관계가 있어야 함',
          );
          expect(newG.results['G08']!.data['verdict'], isNot('판단 불가'));
          expect(
            newG.results['G08']!.data['message'],
            isNot(contains('판단하기 어려워요')),
          );
        },
      );
    }
  });

  group('[j13·G03] 대운별 건강 주의 — 기신 오행 발동 시기 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: G03 결과에 타임라인/주의 시기/요약이 채워짐', () {
        final newG = _runNew(u, _kFixedDate);
        final data = newG.results['G03']!.data;
        expect((data['timeline'] as List), isNotEmpty);
        expect(data['caution_periods'], isA<List>());
        expect(data['summary'], isNotEmpty);
      });
    }
  });

  group('[j13·G05] 나에게 나쁜 음식 — 과다 오행 기반 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: G05 결과에 과다 오행/음식 목록/메시지가 채워짐', () {
        final newG = _runNew(u, _kFixedDate);
        final data = newG.results['G05']!.data;
        expect(data['excess_elements'], isA<List>());
        expect(data['foods_to_limit'], isA<List>());
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j13·G06] 사주 체질 — 일간 오행+계절 기반 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: G06 결과에 오행/계절/성향/장부/메시지가 채워짐', () {
        final newG = _runNew(u, _kFixedDate);
        final data = newG.results['G06']!.data;
        expect(data['element'], isNotEmpty);
        expect(data['season'], isNotEmpty);
        expect(data['personality'], isNotEmpty);
        expect((data['organs'] as List), isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j13·G08] 사고·수술수 — 신살+형충 기반 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: G08 결과에 신살/형충/판정/메시지가 채워짐', () {
        final newG = _runNew(u, _kFixedDate);
        final data = newG.results['G08']!.data;
        expect(data['special_stars'], isA<List>());
        expect(data['clash_types'], isA<List>());
        expect(data['verdict'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  group('[j13·G10] 회복력·면역 — 신강신약+수 오행 기반 필드 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: G10 결과에 신강신약/수 오행 개수/판정/메시지가 채워짐', () {
        final newG = _runNew(u, _kFixedDate);
        final data = newG.results['G10']!.data;
        expect(data['strength'], isNotEmpty);
        expect(data['water_count'], isA<int>());
        expect(data['verdict'], isNotEmpty);
        expect(data['message'], isNotEmpty);
      });
    }
  });

  // [사용자 확정 지시 §6] G03/G05/G06/G08/G10은 의학적 진단처럼 표현하지
  // 않는다. "사주 오행의 균형을 기준으로 한 생활 참고 정보" 또는 "사주
  // 명리학적 참고 정보"라는 문구가 메시지에 포함되어 있어야 하고, 의학
  // 진단을 단정하는 표현(반드시/확실히/진단됩니다)이 없어야 한다.
  //
  // [예외] G03(기신 발동 시기가 하나도 없는 경우)/G05(과다 오행이 아예
  // 없는 경우)는 "특별히 주의할 게 없다"는 안내만 하므로 애초에 의학적
  // 판단 자체가 개입할 여지가 없어 "의학적" 문구를 강제하지 않는다(단정
  // 표현 금지는 이 경우에도 동일하게 검증).
  group('[j13·G03/G05/G06/G08/G10] 건강 카테고리 표현 원칙(§6) 확인 — 의학적 진단 아님 명시', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: 메시지에 단정적 진단 표현이 없고, 주의사항이 있는 경우 "의학적 ... 아니에요" 문구 포함',
        () {
          final newG = _runNew(u, _kFixedDate);
          for (final id in _gIds) {
            final data = newG.results[id]!.data;
            final message = (data['message'] ?? data['summary']) as String;
            expect(message, isNot(contains('반드시')));
            expect(message, isNot(contains('진단됩니다')));

            final noCautionCase =
                (id == 'G03' && (data['caution_periods'] as List).isEmpty) ||
                (id == 'G05' && (data['excess_elements'] as List).isEmpty);
            if (!noCautionCase) {
              expect(
                message,
                contains('의학적'),
                reason: '$id 메시지(주의사항 있음)는 의학적 진단이 아님을 명시해야 함(§6)',
              );
            }
          }
        },
      );
    }
  });

  group('[j13·G03/G05/G06/G08/G10] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext(profile 포함) + runJeontongCategory(G그룹) 예외 없이 동작',
        () {
          final newG = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(rules, isNotNull);

          final ctx = JeontongCalcContext(
            saju: newG.saju,
            interp: newG.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
            profile: newG.profile,
          );

          for (final id in _gIds) {
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
