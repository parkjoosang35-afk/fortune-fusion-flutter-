import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/room/room_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RoomScene alone smoke', (tester) async {
    await WrCatalog.load();
    final room = WishRoom.fromJson({
      'id': 'r1', 'ownerId': 'o1', 'owner': 'me', 'region': 'seoul', 'text': 'hi',
      'char': 'F03', 'devotionCount': 0, 'supportCount': 0, 'pouchReceived': 0,
      'level': 1, 'points': 0, 'levelName': 'start', 'curLevelPts': 0,
      'nextLevelPts': 100, 'brightness': 1.0, 'status': 'ACTIVE',
      'visibility': 'PUBLIC', 'daysLit': 1, 'wishColor': 'hope', 'paper': 'hanji',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomScene(room: room, items: const [], entering: true),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
