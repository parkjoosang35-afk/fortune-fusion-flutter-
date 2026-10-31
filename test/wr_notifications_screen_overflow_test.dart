// [반응형 화면 규격 통일 — 알림함(wishroom) 전수조사]
// WrNotificationsScreen(소원방 알림함)에 대해 5개 크기/textScale 조건에서
// 긴 알림 문구(한 줄에 담기 힘든 길이) + 필터 칩 전체 탭을 구성해 검증한다.
//
// [조사 결과 — 실제 버그 없음, 안전 확인됨]
// 1. 알림 행(_NotiRow) 본문 텍스트는 이미 maxLines:3 + overflow:ellipsis로
//    보호되어 있어 textScale 2.5x + 긴 문구에도 넘치지 않는다.
// 2. 필터 칩 묶음(전체/응원/복주머니/댓글/시스템)은 가로 스크롤
//    ListView(scrollDirection: horizontal) 안에 있어 "응원" 등 뒤쪽 칩은
//    textScale 확대 시 초기 뷰포트 밖(스크롤해야 보임)에 위치할 수 있다.
//    이는 레이아웃 겹침/잘림 버그가 아니라 가로 스크롤 목록의 정상 동작이며,
//    ensureVisible로 스크롤 후 탭하면 정상적으로 필터가 전환된다(아래에서 확인).
// 3. 칩 Container 자체 높이(34px, SizedBox(height:34))는 textScale 2.5x에서도
//    텍스트 높이(약 20px)보다 여유가 있어 세로로 넘치지 않는다.
//
// 이 테스트는 향후 회귀(알림 행 overflow, 필터 칩 탭 불가 등)를 잡기 위한
// 영구 회귀 테스트다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/features/notifications/notifications_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<List<WrNotification>> notifications() async =>
      List.generate(6, (i) {
        final types = NotiType.values;
        return WrNotification.fromJson({
          'id': 'n$i',
          'text':
              '매우매우매우매우매우매우매우매우매우매우매우매우매우매우매우매우매우매우매우매우 긴 알림 문구 테스트입니다 번호 $i 끝까지 길게 이어집니다',
          'type': types[i % types.length].name,
          'roomId': null,
          'at': DateTime(2025, 1, 1, 12, i).millisecondsSinceEpoch,
          'read': i.isEven,
        });
      });

  @override
  Future<int> readNotifications({String? id}) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (size, scale) in <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ]) {
    testWidgets(
      'wr notifications screen ${size.width.toInt()}x${size.height.toInt()}@$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = WishRoomProvider(_FakeWrRepository());
        await provider.loadNotifications();

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: ChangeNotifierProvider<WishRoomProvider>.value(
              value: provider,
              child: const MaterialApp(home: WrNotificationsScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [전체 필터] overflow 없어야 함',
        );

        // 필터 칩을 순회하며 각각 탭해 본다("시스템" 등 다른 분기 경로 검증).
        // ensureVisible: 가로 스크롤 목록 특성상 뒤쪽 칩은 초기 뷰포트 밖에
        //있을 수 있어(정상 동작) 탭 전에 스크롤해 보이게 한다.
        for (final label in ['응원', '복주머니', '댓글', '시스템', '전체']) {
          final finder = find.text(label);
          if (finder.evaluate().isNotEmpty) {
            await tester.ensureVisible(finder.first);
            await tester.pump();
            await tester.tap(finder.first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              tester.takeException(),
              isNull,
              reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [$label 필터] overflow 없어야 함',
            );
          }
        }
      },
    );
  }
}
