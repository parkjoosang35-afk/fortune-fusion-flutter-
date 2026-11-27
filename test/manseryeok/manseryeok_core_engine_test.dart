// [정통사주 80종 전용 신규 엔진] PHASE 1 검증 테스트.
//
// 37번 지시 §24 "1차: 년주/월주/일주/시주" 및 §25 "테스트 데이터
// (입춘 직전/직후, 절기 경계, 자시, 윤년, 음력, 윤달, 다양한 출생시간)"에
// 대응한다.
//
// 검증 전략:
// 1) 회귀(regression) 검증 — 기존 검증된 `SajuEngine.calculate()`
//    (=jeontong_eighty_golden_test.dart의 골든 데이터로 이미 대조된
//    엔진)와 신규 `ManseryeokCoreEngine`이 동일 입력에서 동일한
//    년/월/일/시주(천간+지지)를 산출하는지 1:1 대조한다. 이 신규 엔진은
//    기존 엔진의 계산 정책(sect 기본값)을 그대로 계승하도록 설계되었으므로
//    (manseryeok_policy.dart 참고) 결과가 달라지면 안 된다.
// 2) 정책 동작 자체 검증 — normalizeToKst(), 윤달 부호 변환 등 신규로
//    추가된 로직이 의도대로 동작하는지 별도 검증한다.
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/saju_engine.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'PHASE 1 회귀 검증 — SajuEngine(레거시 jeontong 엔진) vs ManseryeokCoreEngine',
    () {
      void expectSamePillars({
        required int year,
        required int month,
        required int day,
        required int hour,
        int minute = 0,
        String gender = 'male',
        bool isLunar = false,
        bool isLeapMonth = false,
        String label = '',
      }) {
        final legacyResult = legacy.SajuEngine.calculate(
          year: year,
          month: month,
          day: day,
          hour: hour,
          minute: minute,
          gender: gender,
          isLunar: isLunar,
        );

        final newProfile = ManseryeokCoreEngine.buildProfile(
          year: year,
          month: month,
          day: day,
          hour: hour,
          minute: minute,
          gender: gender,
          calendarType: isLunar
              ? CalendarInputType.lunar
              : CalendarInputType.solar,
          isLeapMonth: isLeapMonth,
        );

        expect(
          newProfile.yearPillar.stemHanja,
          legacyResult.pillars['year']!.gan,
          reason: '[$label] 년간 불일치',
        );
        expect(
          newProfile.yearPillar.branchHanja,
          legacyResult.pillars['year']!.zhi,
          reason: '[$label] 년지 불일치',
        );
        expect(
          newProfile.monthPillar.stemHanja,
          legacyResult.pillars['month']!.gan,
          reason: '[$label] 월간 불일치',
        );
        expect(
          newProfile.monthPillar.branchHanja,
          legacyResult.pillars['month']!.zhi,
          reason: '[$label] 월지 불일치',
        );
        expect(
          newProfile.dayPillar.stemHanja,
          legacyResult.pillars['day']!.gan,
          reason: '[$label] 일간 불일치',
        );
        expect(
          newProfile.dayPillar.branchHanja,
          legacyResult.pillars['day']!.zhi,
          reason: '[$label] 일지 불일치',
        );
        expect(
          newProfile.hourPillar.stemHanja,
          legacyResult.pillars['hour']!.gan,
          reason: '[$label] 시간 불일치',
        );
        expect(
          newProfile.hourPillar.branchHanja,
          legacyResult.pillars['hour']!.zhi,
          reason: '[$label] 시지 불일치',
        );

        // 한글/오행/음양 파생값도 기존 매핑 테이블 재사용이므로 함께 대조.
        expect(newProfile.dayPillar.kr, legacyResult.pillars['day']!.kr);
      }

      test('seed-user-A: 1972-02-13 02:00 KST 남 (박주상님 샘플, 입춘 직후)', () {
        // test/fixtures/jeontong_inputs.dart 의 seed-user-A 와 동일 입력
        // (1972-02-12 17:00Z == 1972-02-13 02:00 KST).
        expectSamePillars(
          year: 1972,
          month: 2,
          day: 13,
          hour: 2,
          minute: 0,
          gender: 'male',
          label: 'seed-user-A',
        );
      });

      test('seed-user-B: 1990-06-15 12:00 KST 여', () {
        // fixtures: _dt(1990, 6, 15, 3) UTC == 1990-06-15 12:00 KST.
        expectSamePillars(
          year: 1990,
          month: 6,
          day: 15,
          hour: 12,
          minute: 0,
          gender: 'female',
          label: 'seed-user-B',
        );
      });

      test('seed-user-C: 2005-12-01 06:00 KST 여', () {
        // fixtures: _dt(2005, 11, 30, 21) UTC == 2005-12-01 06:00 KST.
        expectSamePillars(
          year: 2005,
          month: 12,
          day: 1,
          hour: 6,
          minute: 0,
          gender: 'female',
          label: 'seed-user-C',
        );
      });

      test('입춘 직전(절입 이전) 경계 — 1972-02-04 오전(연/월주 절기 경계)', () {
        expectSamePillars(
          year: 1972,
          month: 2,
          day: 4,
          hour: 0,
          minute: 0,
          gender: 'male',
          label: '입춘 직전 00:00',
        );
      });

      test('입춘 직후 경계 — 1972-02-05 오후', () {
        expectSamePillars(
          year: 1972,
          month: 2,
          day: 5,
          hour: 12,
          minute: 0,
          gender: 'male',
          label: '입춘 직후',
        );
      });

      test('절기 경계 — 2024-03-05 경칩 근처', () {
        expectSamePillars(
          year: 2024,
          month: 3,
          day: 5,
          hour: 10,
          minute: 0,
          gender: 'female',
          label: '경칩 근처',
        );
      });

      test('자시 경계 — 23:30 (야자시, ZiHourPolicy 기본값=lateZiSameDay)', () {
        expectSamePillars(
          year: 2000,
          month: 5,
          day: 10,
          hour: 23,
          minute: 30,
          gender: 'male',
          label: '야자시 23:30',
        );
      });

      test('자시 경계 — 00:30 (조자시)', () {
        expectSamePillars(
          year: 2000,
          month: 5,
          day: 10,
          hour: 0,
          minute: 30,
          gender: 'male',
          label: '조자시 00:30',
        );
      });

      test('자시 경계 — 정확히 00:00', () {
        expectSamePillars(
          year: 1999,
          month: 1,
          day: 1,
          hour: 0,
          minute: 0,
          gender: 'female',
          label: '자정 00:00',
        );
      });

      test('윤년 — 2000-02-29 (100의배수이자 400의배수인 윤년)', () {
        expectSamePillars(
          year: 2000,
          month: 2,
          day: 29,
          hour: 8,
          minute: 0,
          gender: 'male',
          label: '2000-02-29 윤년',
        );
      });

      test('윤년 — 2024-02-29', () {
        expectSamePillars(
          year: 2024,
          month: 2,
          day: 29,
          hour: 15,
          minute: 0,
          gender: 'female',
          label: '2024-02-29 윤년',
        );
      });

      test('음력 입력 — 1972년 음력 1월 1일', () {
        expectSamePillars(
          year: 1972,
          month: 1,
          day: 1,
          hour: 10,
          minute: 0,
          gender: 'male',
          isLunar: true,
          label: '음력 1972-01-01',
        );
      });

      test('음력 입력 — 1990년 음력 5월 15일', () {
        expectSamePillars(
          year: 1990,
          month: 5,
          day: 15,
          hour: 14,
          minute: 0,
          gender: 'female',
          isLunar: true,
          label: '음력 1990-05-15',
        );
      });

      test('다양한 출생시간 — 정오(12:00)', () {
        expectSamePillars(
          year: 1985,
          month: 8,
          day: 20,
          hour: 12,
          minute: 0,
          gender: 'male',
          label: '정오',
        );
      });

      test('다양한 출생시간 — 새벽(04:15)', () {
        expectSamePillars(
          year: 1985,
          month: 8,
          day: 20,
          hour: 4,
          minute: 15,
          gender: 'female',
          label: '새벽',
        );
      });

      test('과거 날짜 — 1950-01-01', () {
        expectSamePillars(
          year: 1950,
          month: 1,
          day: 1,
          hour: 9,
          minute: 0,
          gender: 'male',
          label: '과거 1950',
        );
      });

      test('미래 날짜 — 2035-12-31', () {
        expectSamePillars(
          year: 2035,
          month: 12,
          day: 31,
          hour: 18,
          minute: 0,
          gender: 'female',
          label: '미래 2035',
        );
      });

      test('현재 근접 날짜 — 2026-08-13(골든 기준일)', () {
        expectSamePillars(
          year: 2026,
          month: 8,
          day: 13,
          hour: 10,
          minute: 0,
          gender: 'male',
          label: '골든 기준일',
        );
      });
    },
  );

  group('PHASE 1 — 윤달(leap month) 지원 검증', () {
    test('윤달 지정 시 lunar.getMonth() 가 음수(윤달) 로 계산된다', () {
      // 2023년은 음력 윤2월이 존재하는 해.
      final profile = ManseryeokCoreEngine.buildProfile(
        year: 2023,
        month: 2,
        day: 10,
        hour: 10,
        minute: 0,
        gender: 'male',
        calendarType: CalendarInputType.lunar,
        isLeapMonth: true,
      );

      expect(
        profile.lunarLeapMonth,
        isTrue,
        reason: '윤달로 지정했으면 lunarLeapMonth=true 여야 한다',
      );
      expect(profile.birthInfo.isLeapMonth, isTrue);
    });

    test('윤달을 지정하지 않으면(평달) lunarLeapMonth=false', () {
      final profile = ManseryeokCoreEngine.buildProfile(
        year: 2023,
        month: 2,
        day: 10,
        hour: 10,
        minute: 0,
        gender: 'male',
        calendarType: CalendarInputType.lunar,
        isLeapMonth: false,
      );

      expect(profile.lunarLeapMonth, isFalse);
    });
  });

  group('PHASE 1 — normalizeToKst() 해외 출생 시간대 변환 검증', () {
    test('국내 출생(KST, +540분)은 값이 변하지 않는다(회귀 없음)', () {
      final input = DateTime(1990, 6, 15, 12, 30);
      final result = ManseryeokCoreEngine.normalizeToKst(
        input,
        birthUtcOffsetMinutes: kstUtcOffsetMinutes,
      );
      expect(result, input);
    });

    test('뉴욕 출생(EST, UTC-5=-300분) 벽시계 시각을 KST로 환산한다', () {
      // 뉴욕 2020-01-01 09:00 (EST, UTC-5) == UTC 2020-01-01 14:00
      // == KST(UTC+9) 2020-01-01 23:00.
      // (구현이 내부적으로 UTC DateTime을 반환하므로, 값 비교는 연/월/일/
      // 시/분 필드 단위로 수행한다 — isUtc 플래그 차이로 인한 오탐 방지.)
      final input = DateTime(2020, 1, 1, 9, 0);
      final result = ManseryeokCoreEngine.normalizeToKst(
        input,
        birthUtcOffsetMinutes: -5 * 60,
      );
      expect(result.year, 2020);
      expect(result.month, 1);
      expect(result.day, 1);
      expect(result.hour, 23);
      expect(result.minute, 0);
    });

    test('도쿄 출생(JST, UTC+9)은 KST와 동일 오프셋이므로 값이 그대로다', () {
      final input = DateTime(2020, 1, 1, 9, 0);
      final result = ManseryeokCoreEngine.normalizeToKst(
        input,
        birthUtcOffsetMinutes: 9 * 60,
      );
      expect(result, input);
    });

    test('해외 출생 buildProfile() 통합 — 뉴욕 출생자가 KST 환산 후 정상 계산된다', () {
      // 뉴욕 2020-01-01 09:00 EST == KST 2020-01-01 23:00.
      final profileForeign = ManseryeokCoreEngine.buildProfile(
        year: 2020,
        month: 1,
        day: 1,
        hour: 9,
        minute: 0,
        gender: 'male',
        calendarType: CalendarInputType.solar,
        utcOffsetMinutes: -5 * 60,
      );
      final profileKstDirect = ManseryeokCoreEngine.buildProfile(
        year: 2020,
        month: 1,
        day: 1,
        hour: 23,
        minute: 0,
        gender: 'male',
        calendarType: CalendarInputType.solar,
      );

      expect(
        profileForeign.dayPillar.hanja,
        profileKstDirect.dayPillar.hanja,
        reason: '해외 출생 KST 환산 결과가 직접 KST 입력과 동일한 일주를 내야 한다',
      );
      expect(
        profileForeign.hourPillar.hanja,
        profileKstDirect.hourPillar.hanja,
      );
    });
  });

  group('PHASE 1 — 동일 입력 동일 결과(결정론) 검증(37번 지시 §26)', () {
    test('동일 입력으로 여러 번 계산해도 완전히 동일한 결과가 나온다', () {
      SajuProfileSnapshot buildSnapshot() {
        final p = ManseryeokCoreEngine.buildProfile(
          year: 1988,
          month: 3,
          day: 17,
          hour: 7,
          minute: 45,
          gender: 'female',
          calendarType: CalendarInputType.solar,
        );
        return SajuProfileSnapshot(
          p.yearPillar.hanja,
          p.monthPillar.hanja,
          p.dayPillar.hanja,
          p.hourPillar.hanja,
        );
      }

      final first = buildSnapshot();
      final second = buildSnapshot();
      final third = buildSnapshot();

      expect(second.toString(), first.toString());
      expect(third.toString(), first.toString());
    });
  });

  group('PHASE 1 — 엔진 버전/네임스페이스 검증', () {
    test('엔진 버전이 레거시와 무관한 전용 네임스페이스를 사용한다', () {
      expect(kJeontongSajuEngineVersion, 'jeontong-manseryeok-1.0.0');
      expect(kJeontongSajuEngineVersion, isNot(contains('ai-fortune')));
      expect(kJeontongSajuEngineVersion, isNot(contains('legacy')));
    });

    test('SajuProfile.engineVersion 이 buildProfile() 결과에 올바르게 설정된다', () {
      final profile = ManseryeokCoreEngine.buildProfile(
        year: 2000,
        month: 1,
        day: 1,
        hour: 12,
        minute: 0,
        gender: 'male',
        calendarType: CalendarInputType.solar,
      );
      expect(profile.engineVersion, kJeontongSajuEngineVersion);
    });
  });
}

/// 테스트 전용 — 4주 한자 표기를 하나의 비교 가능한 값으로 묶는다.
class SajuProfileSnapshot {
  SajuProfileSnapshot(this.year, this.month, this.day, this.hour);
  final String year;
  final String month;
  final String day;
  final String hour;

  @override
  String toString() => '$year $month $day $hour';
}
