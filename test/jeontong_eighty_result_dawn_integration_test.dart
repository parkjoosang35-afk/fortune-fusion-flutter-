// [2026 Dawn Paper 결과화면 통합] JeontongEightyResultScreen 실제 진입점을
// 통해 새 [SajuDawnResultPage] 경로가 실제로 활성화되고 예외 없이
// 렌더링되는지 검증한다.
//
// [배경] 기존 jeontong_eighty_result_bookmark_toggle_test.dart /
// jeontong_eighty_result_frame_bench_test.dart는 둘 다
// `SharedPreferences.setMockInitialValues({})`로 "저장된 프로필 없음"
// 상태만 검증해, `_ResultBody.build()`의 `if (hasProfile) { ... }` Dawn
// 라우팅 분기를 전혀 통과하지 않는다. 이 파일이 그 커버리지 공백을
// 메운다 — `jeontongProfileStore.save()`로 실제 프로필을 채운 뒤 진입해,
// legacy `Column` 레이아웃이 아니라 [SajuDawnResultPage]가 렌더링되는지
// 직접 확인한다.
//
// [재계산 금지] 이 테스트는 새 계산 로직을 추가하지 않는다 — 이미 검증된
// PHASE1~4 파이프라인 + Dawn 데이터 빌더가 예외 없이 동작하는지만 화면
// 엔트리포인트 관점에서 스모크 테스트한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/data/jeontong_profile_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/saju_result_redesign/saju_dawn_result_page.dart';
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';

/// 무한 반복 애니메이션(CircularProgressIndicator) 함정 회피 — 기존
/// frame_bench/bookmark_toggle 테스트와 동일한 헬퍼.
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
    // VisibilityDetector 기본 500ms 폴링 타이머가 pumpAndSettle을
    // 막지 않도록 즉시 갱신 모드로 낮춘다(saju_dawn_result_page_widget_test.dart
    // 와 동일한 이유).
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    jeontongReportCache.clear();
    JeontongHistoryStore.instance.clearForTest();
    jeontongProfileStore.clearForTest();
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness({required String categoryId}) {
    return MaterialApp(
      home: JeontongEightyResultScreen(categoryId: categoryId),
    );
  }

  testWidgets(
    'Pipeline A(A01, JeontongDeepReportData 경로) — 프로필이 있으면 SajuDawnResultPage로 렌더링',
    (tester) async {
      await jeontongProfileStore.save(
        '1',
        JeontongInput(
          birthDateTimeLocal: DateTime(1990, 6, 15, 12, 0),
          gender: 'M',
          isLunar: false,
        ),
      );

      // 화면 전체(壹~柒 + 히어로 + 풋터)가 지연 빌드 없이 올라오도록
      // 스크롤 가능한 큰 뷰포트를 준다(saju_dawn_result_page_widget_test.dart와
      // 동일한 이유).
      tester.view.physicalSize = const Size(420, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(categoryId: 'A01'));
      await _pumpUntilLoaded(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // legacy 레이아웃이 아니라 새 Dawn Paper 전체 페이지가 렌더링됐는지
      // 직접 확인한다.
      expect(find.byType(SajuDawnResultPage), findsOneWidget);
      // 즐겨찾기 계약(ValueKey) 유지 확인 — 새 경로에서도 동일 키를 씀.
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
      // 壹~柒 섹션 라벨이 모두 그려졌는지 확인.
      for (final label in [
        '壹 · ONE',
        '貳 · TWO',
        '參 · THREE',
        '肆 · FOUR',
        '伍 · FIVE',
        '陸 · SIX',
        '柒 · SEVEN',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '섹션 라벨 "$label"이 렌더링되지 않음',
        );
      }
    },
  );

  testWidgets(
    'Pipeline B(A02, paragraphs 경로) — 프로필이 있으면 SajuDawnResultPage로 렌더링',
    (tester) async {
      await jeontongProfileStore.save(
        '1',
        JeontongInput(
          birthDateTimeLocal: DateTime(1985, 3, 2, 8, 30),
          gender: 'F',
          isLunar: false,
        ),
      );

      tester.view.physicalSize = const Size(420, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(categoryId: 'A02'));
      await _pumpUntilLoaded(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byType(SajuDawnResultPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '프로필이 없으면(미입력) 여전히 legacy 레이아웃으로 폴백한다(회귀 없음)',
    (tester) async {
      // setUp에서 SharedPreferences를 빈 값으로 초기화 + 프로필 미저장
      // 상태이므로 hasProfile == false → Dawn 경로가 활성화되지 않아야 함.
      await tester.pumpWidget(harness(categoryId: 'A01'));
      await _pumpUntilLoaded(tester);
      await tester.pumpAndSettle();

      expect(find.byType(SajuDawnResultPage), findsNothing);
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
    },
  );
}
