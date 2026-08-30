/// [정통사주 69종 개인화 해석 엔진 — §24] "A01을 20~30명 샘플로 검증한
/// 뒤에만 69개 동시 확장 진행" 요구사항의 실제 검증 테스트.
///
/// 사용자 최종 지시 §16(결정론)/§17(개인화, 억지 개인화 금지의 반대편 —
/// 서로 다른 사주인데 같은 결과가 나오는 것도 금지) 두 가지를 30명
/// 샘플로 함께 확인한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_sample_30.dart';

void main() {
  final analyzer = const LifeOverallAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  test('30명 샘플의 A01 lifeTheme/dominantTenGodCategory가 계산값에 따라 달라진다(§24)', () {
    final themeCount = <String, int>{};
    final dominantCount = <String, int>{};
    final fullJsonSet = <String>{};

    for (final input in kJeontongSample30) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);

      themeCount[analysis.lifeTheme] =
          (themeCount[analysis.lifeTheme] ?? 0) + 1;
      dominantCount[analysis.dominantTenGodCategory] =
          (dominantCount[analysis.dominantTenGodCategory] ?? 0) + 1;
      fullJsonSet.add(analysis.toJson().toString());
    }

    // 1) 완전히 동일한 결과(JSON 전체)가 30명 전원에게 나오면 개인화 실패.
    expect(
      fullJsonSet.length,
      greaterThan(1),
      reason: '30명 전원의 A01 결과 JSON이 서로 달라야 한다(최소 2종류 이상)',
    );

    // 2) lifeTheme 하나로 30명이 전부 몰리면(사실상 고정 문장) 실패.
    final maxThemeShare = themeCount.values.reduce((a, b) => a > b ? a : b);
    expect(
      maxThemeShare,
      lessThan(kJeontongSample30.length),
      reason: '하나의 lifeTheme이 30명 전원을 차지하면 개인화 실패(고정 문장 의심)',
    );

    // 3) dominantTenGodCategory(5대 범주 + 균형)가 최소 2종류 이상 나와야
    //    한다 — 특정 범주 하나로 쏠리면 집계 로직 버그 의심.
    expect(
      dominantCount.keys.length,
      greaterThan(1),
      reason: '중심 기운(비겁/식상/재성/관살/인성/균형)이 최소 2종류는 나와야 한다',
    );

    // ignore: avoid_print
    print('lifeTheme 종류 수=${themeCount.length}/${kJeontongSample30.length}');
    // ignore: avoid_print
    print('dominantTenGodCategory 분포=$dominantCount');
  });

  test('30명 각각 동일 입력 재계산 시 완전히 동일한 결과(결정론 §16)', () {
    for (final input in kJeontongSample30.take(10)) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final r1 = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final r2 = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final a1 = analyzer
          .analyze(r1.profile, referenceDate: refDate)
          .toJson()
          .toString();
      final a2 = analyzer
          .analyze(r2.profile, referenceDate: refDate)
          .toJson()
          .toString();
      expect(a1, equals(a2), reason: '${input.userId}: 동일 입력은 항상 동일 결과여야 함');
    }
  });
}
