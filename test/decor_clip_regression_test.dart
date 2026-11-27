import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/decor/decor_screen.dart';

class _Repo implements WrRepository {
  @override
  Future<List<WrItem>> items() async => [];

  @override
  Future<List<WrCharacter>> characters() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

void main() {
  testWidgets('꾸미기 미리보기의 클립 장식이 있어 Null-check가 발생하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await WrCatalog.load();
      final data = ByteData.view(File('/usr/share/fonts/truetype/nanum/NanumSquareR.ttf').readAsBytesSync().buffer);
      for (final family in ['Pretendard', 'NotoSerifKR', 'GowunBatang', 'IBMPlexMono']) {
        await (FontLoader(family)..addFont(Future.value(data))).load();
      }
    });
    final provider = WishRoomProvider(_Repo())
      ..room = WishRoom.fromJson({
        'id': 'test-room', 'ownerId': 'test-owner', 'text': '검증용 소원',
        'char': 'F03', 'devotionCount': 0, 'supportCount': 0,
        'pouchReceived': 0, 'level': 1, 'points': 0, 'levelName': '시작',
        'curLevelPts': 0, 'nextLevelPts': 100, 'brightness': 1.0,
      });
    await tester.pumpWidget(MaterialApp(home: ChangeNotifierProvider.value(
      value: provider, child: const DecorScreen(),
    )));
    await tester.pump();
    final clipped = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((widget) => widget.clipBehavior != Clip.none);
    expect(clipped, isNotEmpty);
    for (final widget in clipped) {
      expect(widget.decoration, isNotNull);
    }
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(DecorScreen), matchesGoldenFile('goldens/decor_clip_preview.png'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
