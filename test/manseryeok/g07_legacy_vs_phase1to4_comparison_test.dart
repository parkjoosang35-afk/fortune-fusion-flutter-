// [j14 · G07 신규 구현] 레거시(SajuEngine.calculate) vs 신규(PHASE1~4 →
// sajuResultFromProfile 어댑터) 경로에서 G07(정신 건강 취약도) 결과를
// 비교한다.
//
// [2026-08-15 G07 재검토 → 실계산 전환] G07은 원래 "정신 건강은 명리학적
// 판정 근거가 약하다"는 이유로 placeholder였으나, PHASE2([RelationshipsEngine
// .analyze])가 이미 계산한 원진(怨嗔)·귀문(鬼門關殺) 관계와
// five_elements_rules.json의 화·수 오행 `excess` 필드(심리적 성향 서술
// 포함)를 조합하면 새 판정 공식 없이 계산 가능함이 밝혀져 실계산으로
// 전환했다(E08/E09/E10·F09와 동일한 재검토 패턴).
//
// [profile 의존 구조] G07은 [SajuProfile.relationships](원진/귀문, PHASE2가
// 계산)에 의존한다. legacy 경로(profile=null)에서는 G03/G08과 동일하게
// "판단 불가"로 안전 처리되고, new 경로(profile 有)에서는 실제 판정을
// 반환한다 — 완전 일치가 아니라 "전환 동작 자체"의 정확성을 검증한다.
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

class _Bundle {
  _Bundle(this.saju, this.interp, this.profile, this.result);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuProfile? profile;
  final JeontongCategoryResult result;
}

JeontongCategoryResult _runG07(
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
  return runJeontongCategory('G07', ctx);
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
  final r = _runG07(saju, interp, referenceDate, null);
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
  final r = _runG07(saju, interp, referenceDate, p4);
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

  group('[j14·G07] 카테고리 등록/제외 상태 확인', () {
    test('kJeontongPlaceholderCategoryIds에 G07이 더 이상 없어야 함', () {
      expect(
        kJeontongPlaceholderCategoryIds.contains('G07'),
        isFalse,
        reason: 'G07은 실계산으로 전환되어 플레이스홀더 목록에서 빠져야 함',
      );
    });

    // (2026-08-16 최종 삭제) G09(장수 가능성)는 계산 불가로 최종 확정되어
    // 플레이스홀더로 남는 대신 카탈로그(JeontongEightyMatrix)에서 완전히
    // 삭제되었다.
    test('G09는 카탈로그에서 완전히 삭제되어 더 이상 존재하지 않아야 함', () {
      expect(JeontongEightyMatrix.byId('G09'), isNull);
      expect(kJeontongPlaceholderCategoryIds.contains('G09'), isFalse);
    });
  });

  // [B08/B09/G03/G08 선례와 동일 원리] G07은 [SajuProfile.relationships]
  // (원진/귀문, PHASE2가 계산)에만 존재하는 데이터를 조회한다. legacy
  // 경로(SajuEngine.calculate, profile=null)에서는 새로 계산하지 않고
  // "판단 불가"로 안전하게 반환하며, new 경로(profile 有)에서는 실제
  // 판정을 반환한다. 완전 일치를 기대하는 것이 아니라 이 "전환 동작
  // 자체"가 올바른지 검증한다.
  group('[j14·G07] 원진·귀문 관계 + 화·수 과다 오행 기반 판정 — profile 유무에 따른 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: legacy(profile=null)는 판단 불가, new(profile 有)는 실제 판정',
        () {
          final legacyB = _runLegacy(u, _kFixedDate);
          final newB = _runNew(u, _kFixedDate);

          // ignore: avoid_print
          print('[G07] legacy=${legacyB.result.data}');
          // ignore: avoid_print
          print('[G07] new   =${newB.result.data}');

          expect(legacyB.result.data['relation_types'], isEmpty);
          expect(legacyB.result.data['excess_elements'], isEmpty);
          expect(legacyB.result.data['verdict'], '판단 불가');
          expect(legacyB.result.data['message'], contains('판단하기 어려워요'));

          final relations = newB.profile?.relationships;
          expect(
            relations,
            isNotNull,
            reason: '${u.userId}: PHASE2가 계산한 원국 관계가 있어야 함',
          );
          expect(newB.result.data['verdict'], isNot('판단 불가'));
          expect(newB.result.data['message'], isNot(contains('판단하기 어려워요')));
          expect(newB.result.data['excess_elements'], isA<List>());
        },
      );
    }
  });

  group('[j14·G07] 정신 건강 취약도 — 필드 구조 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: G07 결과에 관계 종류/과다 오행/판정/메시지가 채워짐', () {
        final newB = _runNew(u, _kFixedDate);
        final data = newB.result.data;
        expect(data['relation_types'], isA<List>());
        expect(data['excess_elements'], isA<List>());
        expect(data['verdict'], isNotEmpty);
        expect(data['message'], isNotEmpty);
        expect(
          data['verdict'],
          anyOf(['예민한 편 — 마음 관리 신경 쓰면 좋음', '가벼운 예민형', '비교적 안정적']),
        );
      });
    }
  });

  // [사용자 확정 지시 §6] G07은 의학적 진단처럼 표현하지 않는다.
  group('[j14·G07] 건강 카테고리 표현 원칙(§6) 확인 — 의학적 진단 아님 명시', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 메시지에 단정적 진단 표현이 없고 "의학적 ... 아니에요" 문구 포함', () {
        final newB = _runNew(u, _kFixedDate);
        final message = newB.result.data['message'] as String;
        expect(message, isNot(contains('반드시')));
        expect(message, isNot(contains('진단됩니다')));
        expect(
          message,
          contains('의학적'),
          reason: 'G07 메시지는 의학적 진단이 아님을 명시해야 함(§6)',
        );
      });
    }
  });

  group('[j14·G07] runJeontongCategory 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext(profile 포함) + runJeontongCategory(G07) 예외 없이 동작',
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

          late final JeontongCategoryResult result;
          expect(
            () => result = runJeontongCategory('G07', ctx),
            returnsNormally,
          );
          expect(result.category, isNotEmpty);
          expect(result.data.length, greaterThan(1));
        },
      );
    }
  });
}
