// [반응형 화면 규격 통일 — 잘림 현상 수정] 마이 탭 알림 목록
// (lib/features/notification/notifications_screen.dart)이 긴 제목/본문 +
// 좁은 화면 + 글자 확대 조합에서 오버플로 없이 렌더되는지 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/notification/data/notification_repository.dart';
import 'package:flutter_app/features/notification/notification_provider.dart';
import 'package:flutter_app/features/notification/notifications_screen.dart';

class _FakeNotificationRepository extends NotificationRepository {
  @override
  Future<ApiResult<Map<String, dynamic>>> getList({int limit = 50}) async {
    return ApiResult.ok({
      'notifications': [
        {
          'id': '1',
          'title':
              '아주 길게 작성된 알림 제목입니다 — 좁은 화면에서 한 줄에 다 들어가지 않을 만큼 긴 제목',
          'body':
              '알림 본문도 마찬가지로 길게 작성합니다. 좁은 화면과 확대된 글자 크기 조합에서 '
              '이 본문 텍스트가 카드 바깥으로 넘치거나 잘리지 않는지 확인하기 위한 실측용 '
              '문구입니다. 조금 더 길게 작성해 둡니다.',
          'sentAt': DateTime(2026, 1, 1, 9, 30).toIso8601String(),
          'isRead': false,
          'deepLink': null,
        },
      ],
      'unreadCount': 1,
    });
  }

  @override
  Future<ApiResult<int>> markAllRead() async => ApiResult.ok(1);
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
      '마이 탭 알림 목록(긴 제목/본문)이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(_FakeNotificationRepository()),
              child: const MaterialApp(home: NotificationsScreen()),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('알림'), findsOneWidget);
        expect(find.textContaining('아주 길게 작성된 알림 제목'), findsOneWidget);
      },
    );
  }
}
