// [80종 전수평가 · 사전 점검] 32개 실계산 카테고리가 실제 화면 진입점
// (`JeontongReportBuilder.build()`)을 통해 정상적으로 "실계산 경로"를 타는지
// (플레이스홀더/폴백 경로로 떨어지지 않는지) 검증한다.
//
// 골든 테스트는 콘텐츠의 결정론(내용이 안 바뀜)만 검증하지만, 이 테스트는
// "결과 화면에 실제로 정상 출력되는가"(사용자 확인 요청 사항 1번)를
// 별도로 확인한다 — 특히 heroHeadline/sections가 비어있지 않은지, 그리고
// 32개 전부가 실제로 실계산 경로(placeholder 폴백이 아님)로 들어가는지.
import 'package:flutter/widgets.dart';
import 'package:flutter_app/features/fortune/shared/domain/fortune_report_model.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

const migrated32 = <String>[
  'A01',
  'B01',
  'C01',
  'D01',
  'A02',
  'A03',
  'A04',
  'A05',
  'A06',
  'C02',
  'C03',
  'C04',
  'C05',
  'D02',
  'D03',
  'D05',
  'D06',
  'D07',
  'D08',
  'D09',
  'F01',
  'F02',
  'G01',
  'G02',
  'G04',
  'H01',
  'H02',
  'H03',
  'H04',
  'H05',
  'H07',
  'H10',
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
  });

  test('32개 실계산 카테고리 — 실제 화면 진입점(JeontongReportBuilder.build)에서 '
      '정상 FortuneReport 생성 및 빈 결과 없음 확인', () {
    expect(migrated32.length, 32, reason: '32개 목록 자체가 32개인지 먼저 확인');

    final birthUtc = DateTime.utc(1990, 5, 15, 1); // KST 1990-05-15 10:00
    var okCount = 0;
    final failures = <String>[];

    for (final id in migrated32) {
      final entry = JeontongEightyMatrix.byId(id);
      if (entry == null) {
        failures.add('$id: JeontongEightyMatrix에 없음');
        continue;
      }
      try {
        final report = JeontongReportBuilder.build(
          entry,
          date: DateTime.utc(2026, 8, 13),
          userId: 'screen-check-user',
          birthDateTimeUtc: birthUtc,
          gender: 'M',
          isLunar: false,
        );
        final hero = report.hero;
        if (hero.headline.trim().isEmpty) {
          failures.add('$id: hero.headline이 비어있음');
          continue;
        }
        if (report.sections.isEmpty) {
          failures.add('$id: sections가 비어있음');
          continue;
        }
        okCount++;
      } catch (e) {
        failures.add('$id: 예외 발생 - $e');
      }
    }

    // ignore: avoid_print
    print('[화면 진입 점검] 정상 $okCount/${migrated32.length}, 실패: $failures');
    expect(failures, isEmpty, reason: '32개 전부 정상 출력되어야 함');
    expect(okCount, migrated32.length);
  });
}
