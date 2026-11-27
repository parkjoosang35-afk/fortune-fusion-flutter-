import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/features/characters/character_shop_screen.dart';

class _Repo implements WrRepository {
  @override
  Future<List<OutfitOffer>> outfits(String char) async => [
    for (final theme in WrTheme.values) OutfitOffer.fromJson({'theme': theme.name, 'owned': true, 'hasArt': true, 'price': 0}),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

void main() {
  testWidgets('의상은 실제 네 가지 그림을 표시하고 선택하면 무대도 같은 의상으로 바뀐다', (tester) async {
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
    final p = WishRoomProvider(_Repo())
      ..catalogLoaded = true
      ..characters = WrCatalog.I.characters
      ..me = Me.fromJson({'id': 'preview-user', 'nick': '검증', 'repChar': 'F03', 'pouch': 0, 'ownedChars': ['F03']});
    await p.loadOutfits('F03');
    await tester.pumpWidget(MaterialApp(home: ChangeNotifierProvider.value(value: p, child: const CharacterShopScreen())));
    await tester.pump();
    await tester.tap(find.text('👕 의상'));
    await tester.pump();
    final context = tester.element(find.byType(CharacterShopScreen));
    await tester.runAsync(() async {
      for (final theme in WrTheme.values) {
        await precacheImage(AssetImage(WrCatalog.I.charImage('F03', theme)), context);
      }
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('장미빛'), findsNothing);
    expect(find.textContaining('달빛'), findsNothing);
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.childrenDelegate.estimatedChildCount, 9); // 기존 4종 + 현재 테마의 신규 5벌
    await tester.tap(find.text('하나님 의상'));
    await tester.pump();
    final stageImages = tester.widgetList<Image>(find.byType(Image)).where((image) => image.height == 320);
    expect(stageImages.single.image, AssetImage(WrCatalog.I.charImage('F03', WrTheme.god)));
    await expectLater(find.byType(CharacterShopScreen), matchesGoldenFile('goldens/outfit_actual_preview.png'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
