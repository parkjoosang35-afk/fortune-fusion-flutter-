// [2026 Dawn Paper 결과화면 통합 — 전체 카테고리 크래시 없음 스모크 테스트]
//
// [배경] jeontong_eighty_result_dawn_integration_test.dart는 A01(Pipeline A)
// /A02(Pipeline B) 2종만 실제 화면 진입점을 통해 검증했다. 하지만
// `_tryBuildDawnResultPage`의 `try/catch`는 방어적으로 예외를 삼켜 legacy로
// 폴백하므로, 특정 카테고리에서만 예외가 나 "조용히" legacy로 떨어지는
// 회귀를 놓칠 수 있다(§ 완료 체크리스트 "Pipeline B(비-A01/A03-A10) 카테고리도
// 실제 화면에서 동작하는지 검증" 항목).
//
// 이 파일은 [JeontongEightyMatrix.all] 69종 전부를 실제 프로필로 진입시켜,
// 각 카테고리에서 [SajuDawnResultPage]가 실제로 뜨는지(=legacy로 조용히
// 폴백하지 않았는지) 직접 확인한다. 섹션 텍스트 상세 검증은 이미
// saju_dawn_result_page_widget_test.dart/jeontong_eighty_result_dawn_integration_test.dart
// 가 담당하므로, 여기서는 "크래시 없음 + Dawn 경로 활성화" 2가지만 넓게
// 확인한다(뷰포트를 기본값으로 둬 지연 빌드로 섹션 일부만 렌더링돼도
// 무방 — SajuDawnResultPage 위젯 자체가 트리에 있는지만 본다).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/data/jeontong_profile_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/saju_result_redesign/saju_dawn_result_page.dart';
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  var guard = 0;
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
      guard < 20) {
    await tester.pump(const Duration(milliseconds: 16));
    guard++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    jeontongReportCache.clear();
    JeontongHistoryStore.instance.clearForTest();
    jeontongProfileStore.clearForTest();
    SharedPreferences.setMockInitialValues({});
  });

  final entries = JeontongEightyMatrix.all;

  test('전제 조건: JeontongEightyMatrix.all이 비어 있지 않다(69종 기대)', () {
    expect(entries.length, greaterThan(0));
  });

  for (final entry in entries) {
    testWidgets(
      '[Dawn 전체 카테고리 스모크] ${entry.id}(${entry.title}) — 프로필이 있으면 SajuDawnResultPage가 예외 없이 렌더링된다',
      (tester) async {
        await jeontongProfileStore.save(
          '1',
          JeontongInput(
            birthDateTimeLocal: DateTime(1990, 6, 15, 12, 0),
            gender: 'M',
            isLunar: false,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(home: JeontongEightyResultScreen(categoryId: entry.id)),
        );
        await _pumpUntilLoaded(tester);
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        expect(
          find.byType(SajuDawnResultPage),
          findsOneWidget,
          reason:
              '${entry.id}에서 SajuDawnResultPage가 렌더링되지 않음 — '
              '_tryBuildDawnResultPage가 조용히 예외를 삼켜 legacy로 폴백했을 가능성.',
        );
      },
    );
  }
}
