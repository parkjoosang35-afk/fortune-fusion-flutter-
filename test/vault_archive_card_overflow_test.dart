// 보관함(vault) '소원 기록관' 탭의 SliverGrid 카드(_CurrentRoomCard/_ArchiveCard/
// DottedBox) 회귀 테스트.
//
// [발견한 버그] childAspectRatio:.74 그리드는 셀 "높이"가 화면 "폭"에 비례해
// 정해지는데, 세 위젯 모두 내용물(썸네일+텍스트 블록)이 화면 폭과 무관하게
// 항상 같은 자연 높이를 요구하는 Column이었다. 실측 결과 320x568 화면에서
// textScale 2.0부터 `RenderFlex overflowed`가 발생했다:
//   - _CurrentRoomCard: 320x568@2.0 91px / @2.5 117px (바닥)
//   - _ArchiveCard: 320x568@2.5 46px (바닥)
//   - DottedBox: 320x568@2.5 3.3px (바닥)
// 390x844@1.0(기본)에서는 재현되지 않았다.
//
// [수정 내용] (디자인·문구·색상·레이아웃 비율 변경 없음)
// _CurrentRoomCard: 썸네일 SizedBox(height:150) → Expanded, 텍스트 블록을
//   Flexible+FittedBox(fit:scaleDown)로 감싸 공간이 부족할 때만 비율대로
//   줄어들게 함.
// _ArchiveCard: "완성"+소원 텍스트+날짜 3줄 블록을 Flexible+FittedBox로 감쌈.
// DottedBox: 전체를 FittedBox(scaleDown)로 감쌈.
// 공간이 충분한 평소 케이스(390x844@1.0 등)는 FittedBox가 1:1로 유지하므로
// 기존 모습 그대로다.
import 'dart:io';
import 'package:flutter/material.dart' hide Visibility;
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
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
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
    testWidgets('archive tab card grid ${size.width.toInt()}x${size.height.toInt()}@$scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await WrCatalog.load();
        final data = ByteData.view(File('/usr/share/fonts/truetype/nanum/NanumSquareR.ttf').readAsBytesSync().buffer);
        for (final family in ['Pretendard', 'NotoSerifKR', 'GowunBatang', 'IBMPlexMono']) {
          await (FontLoader(family)..addFont(Future.value(data))).load();
        }
      });

      final archiveRoom = WishRoom.fromJson({
        'id': 'archived-1', 'ownerId': 'owner-1', 'owner': '테스트', 'text': '아주 길고 긴 소원 텍스트가 한 줄에 다 안 들어갈 정도로 깁니다',
        'char': 'F00', 'status': 'ARCHIVED', 'devotionCount': 10, 'supportCount': 10,
        'pouchReceived': 0, 'level': 1, 'points': 0, 'levelName': '시작',
        'curLevelPts': 0, 'nextLevelPts': 100, 'brightness': 1.0,
            'completedAt': DateTime(2024, 3, 15).millisecondsSinceEpoch, 'daysLit': 365,
      });
      final provider = WishRoomProvider(_FakeWrRepository([archiveRoom]))..room = archiveRoom;

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<WishRoomProvider>.value(
            value: provider,
            child: const MaterialApp(home: VaultScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // 기본 탭이 '소원 기록관'(탭0)이므로 별도 전환 불필요.
      // _ongoing 기본값 false -> done 카드(=_ArchiveCard) 바로 렌더됨.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [done tab: _ArchiveCard/DottedBox] overflow 없어야 함');

      // '진행 중' 칩 탭 → _CurrentRoomCard 렌더 경로도 점검.
      await tester.tap(find.text('진행 중 (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [ongoing tab: _CurrentRoomCard] overflow 없어야 함');
    });
  }
}
