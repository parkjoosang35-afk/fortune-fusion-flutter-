import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/wallpaper/wallpaper_manifest.dart';

void main() {
  testWidgets('배경화면 매니페스트에 오버레이 명세(방·소원·치성·말풍선)가 담긴다', (tester) async {
    await tester.runAsync(() => WrCatalog.load());
    final room = WishRoom.fromJson({
      'id': 'local-wp',
      'ownerId': 'local-owner',
      'owner': '검증자',
      'text': '부모님 건강',
      'char': 'F01',
      'status': 'SEALED',
      'devotionCount': 12,
      'supportCount': 0,
      'pouchReceived': 0,
      'level': 3,
      'points': 100,
      'levelName': '모험',
      'curLevelPts': 100,
      'brightness': 1,
      'daysLit': 5,
    });
    final map =
        jsonDecode(buildNativeManifestJson(room, const []))
            as Map<String, dynamic>;
    expect(map['roomId'], 'local-wp');
    expect(map['wishText'], '부모님 건강');
    expect(map['devotionCount'], 12);
    expect((map['bubbleText'] as String).isNotEmpty, isTrue);
  });
}
