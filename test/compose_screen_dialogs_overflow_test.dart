// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원 작성(ComposeScreen)의 다이얼로그/
// 봉인 확인 시트가 좁은 화면 + 글자 확대 조합에서 오버플로 없이 렌더되는지 실측한다.
// - _showCompletedNotice(): 소원이 이루어진 방에서 새 소원 작성 시 뜨는 AlertDialog.
// - WrSealConfirm: "봉인하기" 눌렀을 때 뜨는 확인 오버레이(Column(mainAxisSize:min)).
// 둘 다 고정 길이 텍스트만 사용해 설계상 안전해 보이지만, 코드만 보고 "안전할 것"이라고
// 단정하지 않고 실제로 pump해서 확인한다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/compose/compose_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

WishRoom _buildCompletedRoom() => WishRoom.fromJson({
  'id': 'completed-room-1',
  'ownerId': 'owner-1',
  'text': '완성된 소원',
  'char': 'F03',
  'devotionCount': 0,
  'supportCount': 0,
  'pouchReceived': 0,
  'level': 10,
  'points': 0,
  'levelName': '완성',
  'curLevelPts': 0,
  'nextLevelPts': 0,
  'brightness': 1.0,
  'status': 'COMPLETED',
  'visibility': 'PUBLIC',
  'daysLit': 100,
  'wishColor': 'hope',
  'paper': 'hanji',
});

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  WishRoom? room,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // [버그수정 — 실제 검증으로 발견, other_room_screen_sheets_overflow_test.dart와
  // 동일 사유] WrCatalog.load()는 rootBundle.loadString()으로 실제 비동기 I/O를
  // 수행한다. testWidgets()의 fake-async 환경에서 직접 await하면 테스트가 영원히
  // 멈추므로 반드시 tester.runAsync()로 감싼다.
  await tester.runAsync(() => WrCatalog.load());
  final provider = WishRoomProvider(_FakeWrRepository())..room = room;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(home: ComposeScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '소원이 이루어진 방 보유 중 새 소원 작성 진입 시 안내 다이얼로그가 '
      '${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale, room: _buildCompletedRoom());
        await tester.pump(const Duration(milliseconds: 300));

        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
        expect(find.text('새 소원은 조금 뒤에 봉인할 수 있어요'), findsOneWidget);
        expect(find.text('알겠어요'), findsOneWidget);

        // 다이얼로그 버튼이 실제로 탭 가능한지(화면 밖으로 밀려나 탭 불가 상태가
        // 아닌지) 확인 — 탭 후 다이얼로그가 닫혀야 한다.
        await tester.tap(find.text('알겠어요'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
        expect(find.text('알겠어요'), findsNothing);
      },
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '소원 작성 화면 기본 진입(작성 폼)이 ${size.width.toInt()}x${size.height.toInt()}'
      '@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale, room: null);
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
      },
    );
  }
}
