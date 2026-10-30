import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/explore/other_room_screen.dart';

class _FakeWrRepository implements WrRepository {
  final WishRoom testRoom;
  final List<WrComment> testComments;
  _FakeWrRepository(this.testRoom, this.testComments);

  @override
  Future<WishRoom> room(String id) async => testRoom;

  @override
  Future<List<WrComment>> comments(String id) async => testComments;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('minimal smoke', (tester) async {
    await WrCatalog.load();
    final room = WishRoom.fromJson({
      'id': 'r1', 'ownerId': 'o1', 'owner': 'me', 'region': 'seoul', 'text': 'hi',
      'char': 'F03', 'devotionCount': 0, 'supportCount': 0, 'pouchReceived': 0,
      'level': 1, 'points': 0, 'levelName': 'start', 'curLevelPts': 0,
      'nextLevelPts': 100, 'brightness': 1.0, 'status': 'ACTIVE',
      'visibility': 'PUBLIC', 'daysLit': 1, 'wishColor': 'hope', 'paper': 'hanji',
    });
    final provider = WishRoomProvider(_FakeWrRepository(room, []));
    print('before pumpWidget');
    await tester.pumpWidget(
      ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: MaterialApp(home: OtherRoomScreen(roomId: 'r1')),
      ),
    );
    print('after pumpWidget, before pump');
    await tester.pump();
    print('pumped once OK');
    expect(tester.takeException(), isNull);
  });
}
