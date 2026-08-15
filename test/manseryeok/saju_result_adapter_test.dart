// [정통사주 80종 · j6 어댑터] SajuProfile → SajuResult 어댑터 검증 테스트.
//
// 사용자 지시(j6, 11개 조건) §7 대응 — 레거시 결과와의 대조를 두 가지로
// 명확히 구분한다.
//
// A. 계산값 대조: PHASE1~4(SajuProfile) 기반 어댑터 결과와 레거시
//    `SajuEngine.calculate()` 결과가 어느 필드에서 같고 다른지 확인한다.
//    다르다고 해서 실패로 처리하지 않는다(§7 "레거시 결과와 무조건
//    동일해야 한다는 뜻은 아닙니다") — 대신 "왜 다른지"를 주석/reason으로
//    남기고, 같아야 하는 필드(오행 총량/십신 7키/공망/천을귀인 등 3종
//    신살/대운 간지·시작연령·시작연도)는 실제로 일치하는지 회귀
//    검증한다.
// B. 해석 결과 대조: 어댑터가 만든 SajuResult를 기존 해석 계층
//    (`SajuInterpreter.fullInterpretation`)에 그대로 넣었을 때 예외 없이
//    유효한 해석 결과가 나오는지 확인한다(문구 내용 자체의 1:1 동일성은
//    요구하지 않음 — 목표는 "신규 계산 결과를 기존 해석 시스템이 정상
//    소비하는가").
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase2_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase3_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase4_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_result_adapter.dart';
import 'package:flutter_app/features/home/domain/saju_engine.dart' as legacy;
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

/// 주어진 생년월일시로 PHASE1→2→3→4 전체를 실행해 완성된 [SajuProfile]을
/// 만드는 헬퍼(phase4_analysis_engine_test.dart와 동일 패턴 재사용).
SajuProfile buildFullProfile({
  required int year,
  required int month,
  required int day,
  required int hour,
  int minute = 0,
  required String gender,
  DateTime? referenceDate,
}) {
  final withCore = ManseryeokCoreEngine.buildProfileWithCore(
    year: year,
    month: month,
    day: day,
    hour: hour,
    minute: minute,
    gender: gender,
    calendarType: CalendarInputType.solar,
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
  return p4;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SajuRules.resetForTest();
    await SajuRules.preload();
  });

  group('A. 계산값 대조 — 어댑터(SajuResult) vs 레거시(SajuEngine.calculate)', () {
    // 박주상 골든 샘플(1972-02-13 02:00 KST 남) — PHASE1~4 회귀 테스트와
    // 동일 샘플을 사용해 기존 검증 맥락을 그대로 이어간다.
    final referenceDate = DateTime(2026, 8, 13);

    test('사주 8글자(년/월/일/시주)는 레거시와 100% 동일해야 한다', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      for (final pos in ['year', 'month', 'day', 'hour']) {
        expect(
          adapted.pillars[pos]!.gan,
          legacyResult.pillars[pos]!.gan,
          reason: '$pos 천간 불일치',
        );
        expect(
          adapted.pillars[pos]!.zhi,
          legacyResult.pillars[pos]!.zhi,
          reason: '$pos 지지 불일치',
        );
        expect(
          adapted.pillars[pos]!.kr,
          legacyResult.pillars[pos]!.kr,
          reason: '$pos 한글 표기 불일치',
        );
      }
    });

    test('일간(dayMaster) 정보가 레거시와 100% 동일해야 한다', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      expect(adapted.dayMaster.gan, legacyResult.dayMaster.gan);
      expect(adapted.dayMaster.kr, legacyResult.dayMaster.kr);
      expect(adapted.dayMaster.element, legacyResult.dayMaster.element);
      expect(adapted.dayMaster.yinYang, legacyResult.dayMaster.yinYang);
      expect(
        adapted.dayMaster.image,
        legacyResult.dayMaster.image,
        reason: 'ganImage 고정표 공유 재사용이므로 반드시 동일해야 함',
      );
    });

    test('오행 총량(fiveElementsCount)이 레거시와 100% 동일해야 한다', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      expect(
        adapted.fiveElementsCount,
        legacyResult.fiveElementsCount,
        reason:
            'FiveElementsProfile.totalCount는 five_elements_engine.dart 주석대로 '
            '레거시 elementsCount와 동일 계산이어야 함',
      );
    });

    test('십신(tenGods) 7키가 레거시와 100% 동일해야 한다', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      expect(
        adapted.tenGods,
        legacyResult.tenGods,
        reason:
            'HiddenStemsEngine.analyzeStemAndBranchTenGods()는 레거시와 동일한 '
            '7키 구조 + getTenGod() 공유 함수를 사용하므로 완전 일치해야 함',
      );
    });

    test('공망(gongmang)이 레거시와 100% 동일해야 한다(동일 함수 재호출)', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      expect(adapted.gongmang, legacyResult.gongmang);
    });

    test('레거시 3종 신살(천을귀인/문창귀인/역마) 목록이 레거시와 100% 동일해야 한다', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      expect(
        adapted.sinsal,
        legacyResult.sinsal,
        reason:
            'SinsalEngine이 legacy findSinsal()을 그대로 재사용하므로 3종 목록은 '
            '완전 일치해야 함(신규가 추가로 갖는 12신살/양인/괴강/백호/원진은 '
            '레거시 SajuResult.sinsal에 없으므로 어댑터에서 의도적으로 제외)',
      );
    });

    test('대운(luckPillars) 8개 구간(간지/시작연령/시작연도)이 레거시와 100% 동일해야 한다', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      // [의도된 차이 — 실패 아님] 신규 어댑터는 항상 9개 실제 대운을
      // 반환하지만 레거시는 소운기 포함 9개 중 실제 대운이 8개뿐이다
      // (phase4_analysis_engine_test.dart와 동일한 이유). 겹치는 8개
      // 구간만 대조한다.
      expect(adapted.luckPillars.length, 9);
      final legacyReal =
          legacyResult.luckPillars.where((lp) => lp.ganZhi.isNotEmpty).toList();
      expect(legacyReal.length, 8);
      for (var i = 0; i < legacyReal.length; i++) {
        expect(adapted.luckPillars[i].ganZhi, legacyReal[i].ganZhi, reason: '대운[$i] 간지');
        expect(
          adapted.luckPillars[i].startAge,
          legacyReal[i].startAge,
          reason: '대운[$i] 시작연령',
        );
        expect(
          adapted.luckPillars[i].startYear,
          legacyReal[i].startYear,
          reason: '대운[$i] 시작연도',
        );
      }
    });

    test('currentAge/currentLuck이 레거시와 100% 동일해야 한다(동일 판정 로직 재사용)', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );
      final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
      final legacyResult = legacy.SajuEngine.calculate(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: referenceDate,
      );

      expect(adapted.currentAge, legacyResult.currentAge);
      expect(adapted.currentLuck?.ganZhi, legacyResult.currentLuck?.ganZhi);
      expect(adapted.currentLuck?.startAge, legacyResult.currentLuck?.startAge);
    });

    test(
      '[의도된 차이 — 참고용] dayMasterStrength 포맷은 레거시와 텍스트가 다를 수 있다 '
      '(레거시=간이 비율판정, PHASE3=억부/조후 정밀판정 — §8: 다르면 PHASE1~4가 기준)',
      () {
        final profile = buildFullProfile(
          year: 1972,
          month: 2,
          day: 13,
          hour: 2,
          gender: 'male',
          referenceDate: referenceDate,
        );
        final adapted = sajuResultFromProfile(profile, referenceDate: referenceDate);
        final legacyResult = legacy.SajuEngine.calculate(
          year: 1972,
          month: 2,
          day: 13,
          hour: 2,
          gender: 'male',
          referenceDate: referenceDate,
        );

        // 포맷(한자 표기 형태)이 레거시 3종 중 하나와 정확히 일치하는지만
        // 확인한다 — 판정값 자체(신강/중화/신약)가 레거시와 같은지는
        // 검증하지 않는다(다른 알고리즘이므로 다를 수 있음, §8 원칙).
        expect(
          ['身强(신강)', '中和(중화)', '身弱(신약)'].contains(adapted.dayMasterStrength),
          isTrue,
          reason: '어댑터 출력 포맷은 레거시가 이해하는 3종 문자열 중 하나여야 함',
        );
        // 참고용 출력 — 실패 조건 아님, 판정 알고리즘 차이를 문서화.
        // ignore: avoid_print
        print(
          '[참고] dayMasterStrength: adapted=${adapted.dayMasterStrength} '
          'legacy=${legacyResult.dayMasterStrength} '
          '(다를 수 있음 — PHASE3 억부/조후 기준이 새 표준)',
        );
      },
    );

    test('여러 샘플(순행/역행, 양력, 남/녀)에서 8글자·오행·십신·공망·3종신살·대운이 모두 일치', () {
      final samples = [
        (1972, 2, 13, 2, 0, 'male'),
        (1990, 5, 15, 14, 30, 'male'),
        (1995, 11, 3, 9, 15, 'female'),
        (2000, 1, 1, 0, 0, 'male'),
      ];
      for (final s in samples) {
        final ref = DateTime(s.$1 + 20, 1, 1);
        final profile = buildFullProfile(
          year: s.$1,
          month: s.$2,
          day: s.$3,
          hour: s.$4,
          minute: s.$5,
          gender: s.$6,
          referenceDate: ref,
        );
        final adapted = sajuResultFromProfile(profile, referenceDate: ref);
        final legacyResult = legacy.SajuEngine.calculate(
          year: s.$1,
          month: s.$2,
          day: s.$3,
          hour: s.$4,
          minute: s.$5,
          gender: s.$6,
          referenceDate: ref,
        );

        for (final pos in ['year', 'month', 'day', 'hour']) {
          expect(adapted.pillars[pos]!.gan, legacyResult.pillars[pos]!.gan, reason: '$s $pos gan');
          expect(adapted.pillars[pos]!.zhi, legacyResult.pillars[pos]!.zhi, reason: '$s $pos zhi');
        }
        expect(adapted.fiveElementsCount, legacyResult.fiveElementsCount, reason: '$s fiveElements');
        expect(adapted.tenGods, legacyResult.tenGods, reason: '$s tenGods');
        expect(adapted.gongmang, legacyResult.gongmang, reason: '$s gongmang');
        expect(adapted.sinsal, legacyResult.sinsal, reason: '$s sinsal(3종)');

        final legacyReal =
            legacyResult.luckPillars.where((lp) => lp.ganZhi.isNotEmpty).toList();
        for (var i = 0; i < legacyReal.length; i++) {
          expect(adapted.luckPillars[i].ganZhi, legacyReal[i].ganZhi, reason: '$s 대운[$i]');
        }
      }
    });
  });

  group('B. 해석 결과 대조 — 어댑터 SajuResult를 기존 해석계층에 그대로 투입', () {
    test('SajuInterpreter.fullInterpretation()이 예외 없이 정상 결과를 생성한다', () {
      final profile = buildFullProfile(
        year: 1972,
        month: 2,
        day: 13,
        hour: 2,
        gender: 'male',
        referenceDate: DateTime(2026, 8, 13),
      );
      final adapted = sajuResultFromProfile(
        profile,
        referenceDate: DateTime(2026, 8, 13),
      );

      late final SajuFullInterpretation interp;
      expect(
        () => interp = SajuInterpreter.fullInterpretation(adapted),
        returnsNormally,
      );

      // JSON Rule 정상 매칭 + 문구 정상 출력 확인(빈 문자열이 아님).
      expect(interp.dayMasterAnalysis.title, isNotEmpty);
      expect(interp.fiveElementsAnalysis, isNotNull);
      expect(interp.tenGodsAnalysis, isNotNull);
      expect(interp.wealthFortune, isNotNull);
      expect(interp.careerFortune, isNotNull);
      expect(interp.loveFortune, isNotNull);
      expect(interp.healthFortune, isNotNull);
      expect(interp.sinsalAnalysis.list, isNotEmpty);
      expect(interp.currentLuckAnalysis.title, isNotEmpty);
    });

    test('동일 입력 → 동일 결과(결정론) — 앱 재실행 시나리오 시뮬레이션', () {
      SajuProfile makeProfile() => buildFullProfile(
        year: 1990,
        month: 5,
        day: 15,
        hour: 14,
        minute: 30,
        gender: 'male',
        referenceDate: DateTime(2026, 8, 13),
      );

      final adapted1 = sajuResultFromProfile(
        makeProfile(),
        referenceDate: DateTime(2026, 8, 13),
      );
      final adapted2 = sajuResultFromProfile(
        makeProfile(),
        referenceDate: DateTime(2026, 8, 13),
      );

      final interp1 = SajuInterpreter.fullInterpretation(adapted1);
      final interp2 = SajuInterpreter.fullInterpretation(adapted2);

      expect(interp1.dayMasterAnalysis.title, interp2.dayMasterAnalysis.title);
      expect(interp1.wealthFortune.message, interp2.wealthFortune.message);
      expect(
        interp1.currentLuckAnalysis.message,
        interp2.currentLuckAnalysis.message,
      );
    });

    test('여러 샘플에서 예외 없이 해석 결과가 생성된다(회귀 안전망)', () {
      final samples = [
        (1972, 2, 13, 2, 0, 'male'),
        (1990, 5, 15, 14, 30, 'male'),
        (1995, 11, 3, 9, 15, 'female'),
        (2000, 1, 1, 0, 0, 'male'),
      ];
      for (final s in samples) {
        final ref = DateTime(s.$1 + 20, 1, 1);
        final profile = buildFullProfile(
          year: s.$1,
          month: s.$2,
          day: s.$3,
          hour: s.$4,
          minute: s.$5,
          gender: s.$6,
          referenceDate: ref,
        );
        final adapted = sajuResultFromProfile(profile, referenceDate: ref);
        expect(
          () => SajuInterpreter.fullInterpretation(adapted),
          returnsNormally,
          reason: '$s 샘플에서 해석 계층 예외 발생하면 안됨',
        );
      }
    });
  });

  group('예외 처리 — 미완료 프로필 방어', () {
    test('PHASE2~4 미완료 SajuProfile을 넘기면 StateError 발생', () {
      final withCore = ManseryeokCoreEngine.buildProfileWithCore(
        year: 1990,
        month: 5,
        day: 15,
        hour: 14,
        minute: 30,
        gender: 'male',
        calendarType: CalendarInputType.solar,
      );
      // PHASE1만 완료된 프로필(fiveElements/tenGods/sinsal/strength/daewoon
      // 전부 null) — 이중 계산 대신 명시적 실패를 요구.
      expect(
        () => sajuResultFromProfile(withCore.profile),
        throwsStateError,
      );
    });
  });
}
