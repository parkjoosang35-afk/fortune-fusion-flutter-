// 임시 수동 검증 테스트 (영구 테스트 스위트 아님).
//
// 목적: 실제 프로덕션 백엔드(sintong.kr)를 (Mock 없이) 직접 호출하여
// A01 카테고리의 /saju/v3/interpret 결과가 실제 위젯 트리에 렌더링되는지
// 확인한다. G01과는 별도 파일로 분리하여, 동일 테스트 프로세스 내에서
// 두 번째 실네트워크 호출 이후 HttpClient가 400을 반환하는 flutter_test
// 프레임워크의 알려진 제약(테스트 스위트당 1회 경고 이후 오염 가능성)을
// 회피한다 — `flutter test`는 파일 단위로 별도 VM 프로세스를 사용한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/home/data/jeontong_profile_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/jeontong_v3_report_view.dart';

Future<void> saveTestProfile(String userId) async {
  await jeontongProfileStore.save(
    userId,
    JeontongInput(
      birthDateTimeLocal: DateTime(1990, 5, 15, 12, 0),
      gender: 'M',
      isLunar: false,
      name: '홍길동',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('REAL BACKEND: A01 renders v3 report view with content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    jeontongProfileStore.clearForTest();
    await saveTestProfile('local-guest');

    tester.view.physicalSize = const Size(420, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: JeontongEightyResultScreen(categoryId: 'A01')),
    );
    await tester.pump();

    bool found = false;
    for (int i = 0; i < 90; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pump();
      if (find.byType(JeontongV3ReportView).evaluate().isNotEmpty) {
        for (int j = 0; j < 5; j++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(seconds: 1)),
          );
          await tester.pump();
        }
        found = true;
        break;
      }
    }

    expect(found, isTrue, reason: 'A01 결과 화면이 시간 내에 렌더링되지 않았습니다.');

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    debugPrint('=== A01 rendered texts (${texts.length}) ===');
    for (final t in texts) {
      debugPrint('A01| $t');
    }

    expect(find.byType(JeontongV3ReportView), findsOneWidget);
    expect(texts, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
