// [반응형 화면 규격 통일] 보관함 '응원 보상' 탭의 받기 연출(_ClaimOverlay) 및
// 보상 리스트 행(reward row) 잘림/오버플로 회귀 테스트.
//
// 실제로 확인된 버그 2건:
// 1) _ClaimOverlay — 받은 아이템 이름이 길거나 textScale이 크면, 기존엔
//    Positioned(top:150, 아래쪽 제한 없음)이라 카드 내용(아이템 이름 2줄 +
//    설명 + 버튼)이 화면 바닥 밖으로 밀려나 "닫기"/"방에 두기" 버튼을 영원히
//    누를 수 없었다. 실측: 360x640@1.3에서 23px, 320x568@1.5에서 168px 잘림.
//    수정: LayoutBuilder로 부모 Stack(_RewardTab의 TabBarView 영역 — 화면
//    전체보다 상단바+탭바 높이만큼 작음)의 실제 가용 높이를 구해
//    ConstrainedBox(maxHeight) + SingleChildScrollView로 감싸, 내용이 넘칠
//    때만 카드 내부가 스크롤되어 버튼에 항상 도달 가능하게 했다.
// 2) 보상 리스트 행의 우측 액션 영역("🎁 받기" 버튼 / "✓ 받음 · 꾸미기 ›" 칩 /
//    "N회 남음" 텍스트)이 Flexible 없이 Row에 직접 들어있어, textScale이
//    커지면(특히 "✓ 받음 · 꾸미기 ›" 칩) 왼쪽 Expanded 텍스트 컬럼이 0까지
//    줄어도 Row 전체가 가로로 넘쳤다. Flexible로 감싸 필요 시 액션 영역 자체도
//    줄어들 수 있게 했다.
//
// 이 테스트는 위 1)번 수정을 검증한다: 응원 100회 보상을 길고 특수한 아이템
// 이름("응원 100번의 특별한 황금 방울 장식 (한정판)")으로 수령했을 때, 세
// 조건(390x844@1.0, 360x640@1.3, 320x568@1.5)에서 "닫기" 버튼이 스크롤 후
// 항상 화면 안에 존재하고 탭 가능해야 한다.
//
// [추가 확인 — 이어서 수정] 320x568@2.0 조건에서는 처음엔 _ClaimOverlay 진입
// 자체가 불가능했다(별도의 가로 62px RenderFlex 오버플로). 추적 결과 원인은
// _ClaimOverlay나 _RewardTab이 아니라, 같은 VaultScreen의 TabBarView 안에
// 함께 떠 있는 _ArchiveTab(첫 번째 탭) 상단의 "진행 중 (N)"/"이루어진 소원 (N)"
// 칩 Row였다 — TabBarView는 비활성 탭도 AutomaticKeepAlive로 계속
// 빌드/레이아웃하므로, "응원 보상" 탭으로 전환만 해도 _ArchiveTab의 고정폭
// 칩 Row가 textScale 2.0에서 넘쳤다(확대된 "진행 중 (0)"/"이루어진 소원 (0)"
// 라벨이 Row 가용폭을 초과). _ArchiveTab의 칩 Row를 가로
// SingleChildScrollView로 감싸 수정했으며, 아래 320x568@2.0 테스트 조건으로
// 함께 검증한다.
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
  final WishRoom _room;
  _FakeWrRepository(this._room);

  @override
  Future<Map<String, dynamic>> claimSupportReward(String id, int at) async {
    return {
      'item': {'id': 'd_goldbell', 'name': '응원 100번의 특별한 황금 방울 장식 (한정판)', 'img': 'd_goldbell'},
      'bonus': null,
    };
  }

  @override
  Future<WishRoom> room(String id) async => _room;

  @override
  Future<List<Map<String, dynamic>>> ledger() async => [];

  @override
  Future<List<WishRoom>> archive() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

Future<void> _pumpAndClaim(WidgetTester tester, Size size, double textScale) async {
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

  // rewards를 명시적으로 지정해서 at:100 보상만 "🎁 받기" 상태가 되도록 함
  // (지정하지 않으면 supportCount>=at인 모든 보상이 동시에 "ready"로 계산되어
  //  find.text(...)가 모호해진다).
  final room = WishRoom.fromJson({
    'id': 'test-room', 'ownerId': 'test-owner', 'owner': '테스트', 'text': '검증용 소원',
    'char': 'F00', 'devotionCount': 0, 'supportCount': 100,
    'pouchReceived': 0, 'level': 1, 'points': 0, 'levelName': '시작',
    'curLevelPts': 0, 'nextLevelPts': 100, 'brightness': 1.0,
    'rewards': [
      {'at': 10, 'reward': '꽃잎 이펙트', 'icon': 'petal', 'reached': true, 'claimed': true},
      {'at': 30, 'reward': '빛가루 이펙트', 'icon': 'spark', 'reached': true, 'claimed': true},
      {'at': 50, 'reward': '랜덤 장식 1개', 'icon': 'gift', 'reached': true, 'claimed': true},
      {'at': 100, 'reward': '특별 장식', 'icon': 'chest', 'reached': true, 'claimed': false},
    ],
  });
  final provider = WishRoomProvider(_FakeWrRepository(room))..room = room;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(home: VaultScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  await tester.tap(find.text('응원 보상'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  final claimBtn = find.text('🎁 받기');
  for (int i = 0; i < 6 && claimBtn.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
  expect(claimBtn, findsOneWidget, reason: '응원 100회 보상의 "🎁 받기" 버튼을 찾을 수 없음');
  await tester.tap(claimBtn.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (size, scale) in <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
  ]) {
    testWidgets(
      '응원 보상 받기 연출(_ClaimOverlay) — ${size.width.toInt()}x${size.height.toInt()}@$scale에서 '
      '긴 아이템 이름이어도 닫기 버튼이 화면 안에서 항상 탭 가능해야 함',
      (tester) async {
        await _pumpAndClaim(tester, size, scale);
        expect(tester.takeException(), isNull);

        final closeBtn = find.text('닫기');
        expect(closeBtn, findsOneWidget, reason: '받기 연출(_ClaimOverlay)의 "닫기" 버튼이 존재해야 함');

        await tester.ensureVisible(closeBtn);
        await tester.pump();

        final rect = tester.getRect(closeBtn);
        expect(rect.top >= 0 && rect.bottom <= size.height, isTrue,
            reason: '닫기 버튼이 스크롤 후에도 화면 밖에 있음 '
                '(rect=$rect, screen height=${size.height})');

        await tester.tap(closeBtn);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
