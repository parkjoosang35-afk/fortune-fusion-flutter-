import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wish_room/presentation/screens/wish_write_screen.dart';
import 'package:flutter_app/features/wish_room/presentation/widgets/wish_room_seal.dart';

/// [디자인 핸드오프 — "마법진이 소환되는 신전"] README `3. Compose Wish`의
/// "Seal picker"(6개 도장 선택기: 願/合/康/福/緣/財) 통합 회귀 테스트.
///
/// 이 위젯은 순수 시각 프리셋(로컬 UI 상태)이며 저장 로직(_save)에는
/// 전달되지 않으므로, 여기서는 "6개 도장이 모두 렌더링되고 탭으로 선택
/// 상태가 바뀌는지"만 검증한다 — WishItem 데이터 모델이나 서버 API 계약을
/// 변경하지 않았음을 확인하는 목적.
void main() {
  Future<void> pumpWriteScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WishWriteScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('Seal picker는 願/合/康/福/緣/財 6개 도장을 모두 렌더링한다', (
    tester,
  ) async {
    await pumpWriteScreen(tester);

    for (final seal in WishSeal.values) {
      expect(find.text(seal.glyph), findsOneWidget);
    }
    expect(find.byType(WishRoomSeal), findsNWidgets(WishSeal.values.length));
  });

  testWidgets('도장을 탭하면 선택 상태(selected)가 해당 WishRoomSeal로 이동한다', (
    tester,
  ) async {
    await pumpWriteScreen(tester);

    // 기본 선택값은 WishSeal.wish('願').
    WishRoomSeal sealWidgetFor(String glyph) => tester.widget<WishRoomSeal>(
      find.ancestor(
        of: find.text(glyph),
        matching: find.byType(WishRoomSeal),
      ),
    );

    expect(sealWidgetFor('願').selected, isTrue);
    expect(sealWidgetFor('合').selected, isFalse);

    await tester.tap(find.text('合'));
    await tester.pump();

    expect(sealWidgetFor('合').selected, isTrue);
    expect(sealWidgetFor('願').selected, isFalse);
  });
}
