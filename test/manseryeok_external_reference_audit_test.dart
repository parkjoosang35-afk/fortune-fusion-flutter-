// [사용자 요청 — 외부 검수 지시 ①] 만세력 기준 "정답 데이터"와 사주 엔진
// 계산 결과(사주팔자/오행/십성/신강신약/용신)를 대조하는 독립 감사 테스트.
//
// "보고서만 믿지 말고 직접 대조해 달라"는 요청에 따라, 본 프로젝트
// 엔진과 완전히 무관한 **외부 독립 라이브러리**로 정답을 생성했다.
// - 라이브러리: `lunar_python` (PyPI, 널리 쓰이는 중국 전통 만세력/
//   사주팔자 계산 패키지, 이 프로젝트와 코드/저자 모두 무관)
// - sect(자시 처리 정책) = 2 (야자시도 당일로 계산) — 이 프로젝트의
//   기본 정책(`ZiHourPolicy.lateZiSameDay`, manseryeok_policy.dart)과
//   동일하게 맞춰서 비교 조건을 통일했다.
// - 정답 생성 명령 예시(재현 가능):
//     python3 -c "
//     from lunar_python import Solar
//     s = Solar.fromYmdHms(1990,3,15,8,30,0)
//     ec = s.getLunar().getEightChar(); ec.setSect(2)
//     print(ec.getYear(), ec.getMonth(), ec.getDay(), ec.getTime())
//     "
//   → 庚午 己卯 己卯 戊辰 (아래 personA 케이스와 동일)
//
// 대조 범위: 일반 케이스, 입춘 절기 경계(전/후), 자시 경계(23시대/0시대),
// 윤년 2/29. 모두 "지시문 §25"가 요구한 경계 사례군에 해당한다.
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('만세력 외부 정답 대조 감사 — lunar_python(sect=2) vs 사주 엔진', () {
    void expectPillars({
      required String label,
      required DateTime kst,
      required String gender,
      required String expectedYearGanZhi,
      required String expectedMonthGanZhi,
      required String expectedDayGanZhi,
      required String expectedTimeGanZhi,
    }) {
      final result = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: gender,
        isLunar: false,
        referenceDate: DateTime(2024, 1, 1),
      );
      final p = result.profile;
      final actualYear = '${p.yearPillar.stemHanja}${p.yearPillar.branchHanja}';
      final actualMonth =
          '${p.monthPillar.stemHanja}${p.monthPillar.branchHanja}';
      final actualDay = '${p.dayPillar.stemHanja}${p.dayPillar.branchHanja}';
      final actualTime =
          '${p.hourPillar.stemHanja}${p.hourPillar.branchHanja}';

      // 콘솔에 실제 대조 과정을 그대로 남긴다(보고서 수치 재현 가능하도록).
      // ignore: avoid_print
      print(
        '[외부정답대조:$label] 입력=$kst '
        '엔진결과(년/월/일/시)=$actualYear/$actualMonth/$actualDay/$actualTime '
        'vs lunar_python정답=$expectedYearGanZhi/$expectedMonthGanZhi/'
        '$expectedDayGanZhi/$expectedTimeGanZhi',
      );

      expect(actualYear, expectedYearGanZhi, reason: '[$label] 년주 불일치');
      expect(actualMonth, expectedMonthGanZhi, reason: '[$label] 월주 불일치');
      expect(actualDay, expectedDayGanZhi, reason: '[$label] 일주 불일치');
      expect(actualTime, expectedTimeGanZhi, reason: '[$label] 시주 불일치');
    }

    test('일반 케이스 A — 1990-03-15 08:30 남', () {
      expectPillars(
        label: 'personA',
        kst: DateTime(1990, 3, 15, 8, 30),
        gender: 'male',
        expectedYearGanZhi: '庚午',
        expectedMonthGanZhi: '己卯',
        expectedDayGanZhi: '己卯',
        expectedTimeGanZhi: '戊辰',
      );
    });

    test('일반 케이스 B — 1995-11-02 22:10 여', () {
      expectPillars(
        label: 'personB',
        kst: DateTime(1995, 11, 2, 22, 10),
        gender: 'female',
        expectedYearGanZhi: '乙亥',
        expectedMonthGanZhi: '丙戌',
        expectedDayGanZhi: '丁酉',
        expectedTimeGanZhi: '辛亥',
      );
    });

    test('절기 경계 — 입춘 직전(2024-02-03 23:00)', () {
      expectPillars(
        label: '입춘경계전',
        kst: DateTime(2024, 2, 3, 23, 0),
        gender: 'male',
        expectedYearGanZhi: '癸卯',
        expectedMonthGanZhi: '乙丑',
        expectedDayGanZhi: '丁酉',
        expectedTimeGanZhi: '壬子',
      );
    });

    test('절기 경계 — 입춘 직후(2024-02-04 17:00)', () {
      expectPillars(
        label: '입춘경계후',
        kst: DateTime(2024, 2, 4, 17, 0),
        gender: 'male',
        expectedYearGanZhi: '甲辰',
        expectedMonthGanZhi: '丙寅',
        expectedDayGanZhi: '戊戌',
        expectedTimeGanZhi: '辛酉',
      );
    });

    test('자시 경계 — 23시대(2000-06-15 23:30, 당일 유지 정책)', () {
      expectPillars(
        label: '자시23시대',
        kst: DateTime(2000, 6, 15, 23, 30),
        gender: 'male',
        expectedYearGanZhi: '庚辰',
        expectedMonthGanZhi: '壬午',
        expectedDayGanZhi: '甲辰',
        expectedTimeGanZhi: '丙子',
      );
    });

    test('자시 경계 — 0시대(2000-06-16 00:30, 다음날 일주로 전환)', () {
      expectPillars(
        label: '자시00시대',
        kst: DateTime(2000, 6, 16, 0, 30),
        gender: 'male',
        expectedYearGanZhi: '庚辰',
        expectedMonthGanZhi: '壬午',
        expectedDayGanZhi: '乙巳',
        expectedTimeGanZhi: '丙子',
      );
    });

    test('윤년 2/29 — 2000-02-29 12:00', () {
      expectPillars(
        label: '윤년229',
        kst: DateTime(2000, 2, 29, 12, 0),
        gender: 'female',
        expectedYearGanZhi: '庚辰',
        expectedMonthGanZhi: '戊寅',
        expectedDayGanZhi: '丁巳',
        expectedTimeGanZhi: '丙午',
      );
    });

    test('음력 입력 — 1988년 음력 5월 8일(양력 1988-06-21) 14:05 남', () {
      // lunar_python 역산: 음력1988-5-8 == 양력1988-6-21,
      // 팔자(sect=2) = 戊辰 戊午 丁未 丁未
      final result =
          JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
            kst: DateTime(1988, 5, 8, 14, 5),
            gender: 'male',
            isLunar: true,
            referenceDate: DateTime(2024, 1, 1),
          );
      final p = result.profile;
      final actualYear =
          '${p.yearPillar.stemHanja}${p.yearPillar.branchHanja}';
      final actualMonth =
          '${p.monthPillar.stemHanja}${p.monthPillar.branchHanja}';
      final actualDay = '${p.dayPillar.stemHanja}${p.dayPillar.branchHanja}';
      final actualTime =
          '${p.hourPillar.stemHanja}${p.hourPillar.branchHanja}';
      // ignore: avoid_print
      print(
        '[외부정답대조:음력1988] 엔진결과=$actualYear/$actualMonth/$actualDay/$actualTime '
        'vs lunar_python정답=戊辰/戊午/丁未/丁未',
      );
      expect(actualYear, '戊辰', reason: '[음력1988] 년주 불일치');
      expect(actualMonth, '戊午', reason: '[음력1988] 월주 불일치');
      expect(actualDay, '丁未', reason: '[음력1988] 일주 불일치');
      expect(actualTime, '丁未', reason: '[음력1988] 시주 불일치');
    });
  });

  group('오행/신강신약/용신 — 파생 계산 필드 null-free 및 합계 정합성 감사', () {
    test('personA: 오행 총합=8(8글자), 신강신약 점수 0.0~1.0 사이, 용신 비어있지 않음', () {
      final result =
          JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
            kst: DateTime(1990, 3, 15, 8, 30),
            gender: 'male',
            isLunar: false,
            referenceDate: DateTime(2024, 1, 1),
          );
      final p = result.profile;
      final fe = p.fiveElements;
      expect(fe, isNotNull, reason: '오행 분석 필드가 null이면 PHASE2가 실행되지 않은 것');
      final total = fe!.totalCount.values.fold<int>(0, (a, b) => a + b);
      expect(
        total,
        8,
        reason: '사주 8글자(년간지/월간지/일간지/시간지) 오행 총합은 반드시 8이어야 함',
      );

      expect(p.strength, isNotNull, reason: 'PHASE3 신강신약 분석이 비어있음');
      expect(
        p.strength!.score,
        inInclusiveRange(0.0, 1.0),
        reason: '신강신약 점수는 0.0~1.0 범위의 정규화된 값이어야 함',
      );

      expect(p.yongsin, isNotNull, reason: 'PHASE3 용신 분석이 비어있음');
      expect(p.yongsin!.yongsin, isNotEmpty, reason: '주 용신 오행이 비어있으면 안 됨');

      // ignore: avoid_print
      print(
        '[파생필드감사:personA] 오행합계=$total, 신강신약점수=${p.strength!.score}, '
        '용신=${p.yongsin!.yongsin}(${p.yongsin!.method})',
      );
    });
  });
}
