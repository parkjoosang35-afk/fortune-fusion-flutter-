// [반응형 화면 규격 통일 — 잘림 현상 수정] 보관함(Vault) "당시 모습 재생"
// 다이얼로그(_ReplayOverlay, showDialog)의 하단 한지 카드 검증.
//
// 다른 시트들과 달리 _ReplayOverlay의 소원 문구 Text(room.text, ...)에는
// maxLines/overflow 제한이 전혀 없다(다른 유사 위치들은 maxLines:1~3+
// ellipsis로 제한돼 있음 — _CurrentRoomCard/_ArchiveCard/seal_reading_flow
// 등). 카드는 Positioned(left:16, right:16, bottom:44)로 화면 하단에 고정
// 배치되고 위쪽으로는 자유롭게 늘어날 수 있는 구조라, 소원 문구가 길고
// 화면이 작을 때 카드 상단이 화면 밖(상태바/타이틀 영역과 겹침)으로
// 넘어가거나 Stack 안에서 잘릴 가능성이 있다. 실측으로 확인한다.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/vault/vault_screen.dart';

class _FakeWrRepository implements WrRepository {
  final List<WishRoom> _archive;
  _FakeWrRepository(this._archive);

  @override
  Future<List<WishRoom>> archive() async => _archive;

  @override
  Future<List<Map<String, dynamic>>> ledger() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '보관함 "당시 모습 재생" 카드(긴 소원문구)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          await WrCatalog.load();
          final data = ByteData.view(
            File(
              '/usr/share/fonts/truetype/nanum/NanumSquareR.ttf',
            ).readAsBytesSync().buffer,
          );
          for (final family in [
            'Pretendard',
            'NotoSerifKR',
            'GowunBatang',
            'IBMPlexMono',
          ]) {
            await (FontLoader(family)..addFont(Future.value(data))).load();
          }
        });

        final completedRoom = WishRoom.fromJson({
          'id': 'test-room',
          'ownerId': 'test-owner',
          'text':
              '이 소원은 아주 길게 작성된 소원 문구입니다. 재생 카드가 화면 '
              '하단에 고정되어 있고 이 문구에는 줄 수 제한이 없기 때문에, '
              '좁은 화면에서 카드가 위로 많이 늘어났을 때 상단 타이틀이나 '
              '화면 경계를 벗어나 잘리지는 않는지 확인하기 위한 실측용 '
              '텍스트입니다. 조금 더 길게 작성합니다.',
          'char': 'F03',
          'devotionCount': 12,
          'supportCount': 34,
          'pouchReceived': 5,
          'level': 7,
          'points': 500,
          'levelName': '성취',
          'curLevelPts': 0,
          'nextLevelPts': 1000,
          'brightness': 1.0,
          'status': 'ARCHIVED',
          'completedAt': DateTime(2026, 2, 1).millisecondsSinceEpoch,
          'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'daysLit': 31,
        });

        final provider = WishRoomProvider(_FakeWrRepository([completedRoom]))
          ..items = const [];

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: ChangeNotifierProvider<WishRoomProvider>.value(
              value: provider,
              child: const MaterialApp(home: VaultScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // "완성" 카드를 탭해 _ReplayOverlay를 연다.
        final archiveCard = find.text('완성');
        expect(archiveCard, findsOneWidget);
        await tester.tap(archiveCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('이루어진 소원방'), findsOneWidget);
      },
    );
  }
}
