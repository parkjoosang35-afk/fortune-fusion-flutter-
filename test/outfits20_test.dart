import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/features/characters/character_shop_screen.dart';

Map<String, dynamic> roomJson({String char = 'F00', String? outfitId, String theme = 'free'}) => {
  'id': 'wr_1', 'ownerId': 'u', 'text': '소원', 'char': char,
  'theme': theme, 'outfitNow': theme, 'outfitId': outfitId,
  'devotionCount': 0, 'supportCount': 0, 'pouchReceived': 0,
  'level': 1, 'points': 0, 'levelName': '시작', 'curLevelPts': 0,
  'brightness': 1, 'isMine': true,
};
Me user({List<String> outfits = const []}) => Me.fromJson({
  'id': 'u', 'nick': '검증', 'repChar': 'F00', 'pouch': 1000,
  'ownedChars': ['F00', 'M00'], 'ownedOutfits': outfits,
});
class Repo implements WrRepository {
  int purchases = 0, equips = 0;
  bool failEquip = false;
  @override Future<List<OutfitOffer>> outfits(String char) async => [
    for (final t in WrTheme.values) OutfitOffer.fromJson({'theme': t.name, 'owned': true, 'hasArt': true}),
  ];
  @override Future<Me> buyNamedOutfit(String char, String outfitId) async {
    purchases++;
    return user(outfits: ['$char:$outfitId']);
  }
  @override Future<WishRoom> setNamedOutfit(String id, String outfitId) async {
    equips++;
    if (failEquip) throw ApiError(409, 'TEST_FAILURE', '착용 실패');
    return WishRoom.fromJson(roomJson(outfitId: outfitId));
  }
  @override dynamic noSuchMethod(Invocation i) => throw UnsupportedError('${i.memberName}');
}
class DelayedOutfitRepo extends Repo {
  final pending = <String, Completer<List<OutfitOffer>>>{};
  @override Future<List<OutfitOffer>> outfits(String char) => (pending[char] = Completer<List<OutfitOffer>>()).future;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => WrCatalog.load());
  test('의상 조회는 마지막 선택만 반영하고 로그아웃 후 응답은 폐기한다', () async {
    final repo = DelayedOutfitRepo();
    final p = WishRoomProvider(repo)..me = user();
    final first = p.loadOutfits('F00');
    final second = p.loadOutfits('M00');
    repo.pending['M00']!.complete([]);
    await second;
    expect(p.outfitOffers.firstWhere((o) => o.id == 'O_free_02').compatible, true);
    repo.pending['F00']!.complete([]);
    await first;
    expect(p.outfitOffers.firstWhere((o) => o.id == 'O_free_02').compatible, true);
    final late = p.loadOutfits('F00');
    p.clearOnLogout();
    repo.pending['F00']!.complete([]);
    await late;
    expect(p.outfitOffers, isEmpty);
  });
  test('신규 20벌의 원본 자산·테마·성별·캐릭터 제한 검증', () async {
    final all = WrCatalog.I.newOutfits;
    expect(all.length, 20);
    expect(all.map((o) => o['id']).toSet().length, 20);
    for (final t in WrTheme.values) expect(all.where((o) => o['theme'] == t.name).length, 5);
    for (final o in all) {
      final code = o['gender'] == 'F' ? 'F00' : 'M00';
      final asset = WrCatalog.I.charImage(code, WrTheme.free, outfitId: o['id']);
      expect(asset, 'assets/wishroom/outfits/${o['id']}.png');
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(1000));
      expect(WrCatalog.I.charImage('F03', WrTheme.free, outfitId: o['id']), isNot(asset));
    }
  });
  test('구매와 착용을 의상 번호로 구분하고 재조회 모델에 보존', () async {
    final repo = Repo();
    final p = WishRoomProvider(repo)..room = WishRoom.fromJson(roomJson())..me = user();
    await p.loadOutfits('F00');
    expect(p.outfitOffers.where((o) => o.isNew).length, 20);
    expect(p.outfitOffers.where((o) => o.isNew && o.compatible).length, 12);
    final offer = p.outfitOffers.firstWhere((o) => o.id == 'O_free_01');
    expect(await p.wearNamedOutfit('F00', offer), true);
    expect(repo.purchases, 1);
    expect(repo.equips, 1);
    expect(p.room!.outfitId, 'O_free_01');
    expect(p.me!.ownedOutfits, contains('F00:O_free_01'));
    expect(WishRoom.fromJson(roomJson(outfitId: p.room!.outfitId)).outfitId, 'O_free_01');
  });
  test('다른 수호자 전용·방 미생성은 구매하지 않으며 착용 실패는 성공 처리하지 않는다', () async {
    final repo = Repo();
    final p = WishRoomProvider(repo)..room = WishRoom.fromJson(roomJson())..me = user();
    await p.loadOutfits('F00');
    final wrong = p.outfitOffers.firstWhere((o) => o.id == 'O_free_02');
    expect(await p.wearNamedOutfit('F00', wrong), false);
    expect(repo.purchases, 0);
    final wrongTheme = p.outfitOffers.firstWhere((o) => o.id == 'O_god_01');
    expect(await p.wearNamedOutfit('F00', wrongTheme), false);
    expect(p.lastError!.code, 'THEME_MISMATCH');
    expect(repo.purchases, 0);
    final good = p.outfitOffers.firstWhere((o) => o.id == 'O_free_01');
    repo.failEquip = true;
    expect(await p.wearNamedOutfit('F00', good), false);
    expect(p.lastError!.code, 'TEST_FAILURE');
    expect(p.outfitOffers.firstWhere((o) => o.id == 'O_free_01').owned, true);
    expect(p.me!.ownedOutfits, contains('F00:O_free_01'));
    p.room = null;
    expect(await p.wearNamedOutfit('F00', good), false);
    expect(p.lastError!.code, 'NO_ROOM');
  });
  testWidgets('신규 의상 카드와 전신 선택 미리보기', (tester) async {
    tester.view.physicalSize = const Size(412, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final data = ByteData.view(File('/usr/share/fonts/truetype/nanum/NanumSquareR.ttf').readAsBytesSync().buffer);
      for (final f in ['Pretendard', 'NotoSerifKR', 'GowunBatang', 'IBMPlexMono']) {
        await (FontLoader(f)..addFont(Future.value(data))).load();
      }
    });
    final p = WishRoomProvider(Repo())..catalogLoaded = true..characters = WrCatalog.I.characters
      ..me = user()..room = WishRoom.fromJson(roomJson());
    await p.loadOutfits('F00');
    await tester.pumpWidget(MaterialApp(home: ChangeNotifierProvider.value(value: p, child: const CharacterShopScreen())));
    await tester.pump();
    await tester.tap(find.text('👕 의상'));
    await tester.pump();
    final context = tester.element(find.byType(CharacterShopScreen));
    await tester.runAsync(() async {
      for (final offer in p.outfitOffers) {
        await precacheImage(AssetImage(offer.isNew ? offer.asset : WrCatalog.I.charImage('F00', offer.theme)), context);
      }
    });
    await tester.pump();
    await tester.scrollUntilVisible(find.text('봄 벚꽃 한복'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('봄 벚꽃 한복'));
    await tester.pump();
    await Scrollable.ensureVisible(tester.element(find.text('봄 벚꽃 한복')), alignment: .68);
    await tester.pump();
    final stage = tester.widgetList<Image>(find.byType(Image)).singleWhere((i) => i.height == 320);
    expect(stage.image, const AssetImage('assets/wishroom/outfits/O_free_01.png'));
    expect(stage.fit, BoxFit.contain);
    expect(find.text('잠김 · 다른 수호자 전용'), findsWidgets);
    await expectLater(find.byType(CharacterShopScreen), matchesGoldenFile('goldens/outfits20_preview.png'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
