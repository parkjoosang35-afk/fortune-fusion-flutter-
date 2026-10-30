// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원방 알림함
// (lib/features/wishroom/features/notifications/notifications_screen.dart)이
// 긴 알림 문구 + 좁은 화면 + 글자 확대 조합에서 오버플로 없이 렌더되는지
// 검증한다. 알림 행(_NotiRow)의 본문 Text는 maxLines:3+ellipsis로 제한돼
// 있어 설계상 안전해 보이지만 실측으로 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/features/notifications/notifications_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<List<WrNotification>> notifications() async => [
        WrNotification.fromJson({
          'id': 'n1',
          'text':
              '아주 긴 알림 문구입니다 — 좁은 화면에서 한 줄에 다 들어가지 않고 '
              '여러 줄로 넘어갈 만큼 길게 작성해, 알림 카드 바깥으로 잘리거나 '
              '넘치지 않는지 확인하기 위한 실측용 텍스트입니다. 조금 더 길게 적습니다.',
          'type': 'SUPPORT',
          'roomId': null,
          'at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'read': false,
        }),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '소원방 알림함(긴 문구)이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = WishRoomProvider(_FakeWrRepository());

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: ChangeNotifierProvider<WishRoomProvider>.value(
              value: provider,
              child: const MaterialApp(home: WrNotificationsScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('알림함'), findsOneWidget);
        expect(find.textContaining('아주 긴 알림 문구입니다'), findsOneWidget);
      },
    );
  }
}
