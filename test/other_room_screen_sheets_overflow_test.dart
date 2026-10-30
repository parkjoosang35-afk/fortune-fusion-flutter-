// [반응형 화면 규격 통일 — 잘림 현상 수정] 타인의 소원방(OtherRoomScreen) 하단
// 시트 3종(응원 메시지 _openMessageSheet · 복주머니 보내기 _openGiftSheet ·
// 더보기/신고·차단 _openMoreSheet) 및 소원 전문 펼침 카드(_wishOpenCard)가
// 좁은 화면 + 긴 텍스트(평범한 실제 데이터, 특수 edge-case 아님) + 글자 확대
// 조합에서 오버플로 없이 렌더되는지 실측한다.
//
// 메시지 시트는 `Flexible(child: SingleChildScrollView(...))`로, 소원 펼침
// 카드는 `ConstrainedBox(maxHeight:150)+SingleChildScrollView`로 이미
// 스크롤 래핑돼 있어 설계상 안전해 보이지만, 선물 시트(_openGiftSheet)는
// SingleChildScrollView가 전혀 없는 `Column(mainAxisSize:min)`만 사용해
// 실측이 필요하다.
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

WishRoom _buildRoom() => WishRoom.fromJson({
  'id': 'other-room-1',
  'ownerId': 'owner-1',
  'owner': '민들레',
  'region': '서울',
  'text':
      '이 소원은 아주 길게 작성된 평범한(=특수 edge-case가 아닌) 소원 문구입니다. '
      '좁은 화면에서 한 줄에 다 들어가지 않고 소원 펼침 카드 안에서 여러 줄로 '
      '넘어갈 만큼 길게 적어, 버튼이나 텍스트가 바깥으로 잘리지 않는지 확인하기 '
      '위한 실측용 텍스트입니다. 조금 더 길게 적어봅니다.',
  'char': 'F03',
  'devotionCount': 3,
  'supportCount': 12,
  'pouchReceived': 40,
  'level': 3,
  'points': 30,
  'levelName': '정성',
  'curLevelPts': 0,
  'nextLevelPts': 100,
  'brightness': 1.0,
  'status': 'ACTIVE',
  'visibility': 'PUBLIC',
  'daysLit': 5,
  'wishColor': 'hope',
  'paper': 'hanji',
});

List<WrComment> _buildComments() => [
  WrComment.fromJson({
    'id': 'c1',
    'author': '해바라기',
    'text': '응원합니다! 꼭 이루어지길 바라요.',
    'at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
  }),
  WrComment.fromJson({
    'id': 'c2',
    'author': '달빛소년',
    'text': '저도 비슷한 소원이 있어요. 함께 응원할게요!',
    'at': DateTime(2026, 1, 2).millisecondsSinceEpoch,
  }),
];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await WrCatalog.load();
  final provider = WishRoomProvider(_FakeWrRepository(_buildRoom(), _buildComments()));

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: MaterialApp(home: OtherRoomScreen(roomId: 'other-room-1')),
      ),
    ),
  );
  // initState의 addPostFrameCallback(loadViewedRoom)이 실행되도록 몇 프레임 더 진행.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
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
      '소원 전문 펼침 카드(긴 소원문구)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale);

        // 하단 도크의 한 줄 소원 카드(GestureDetector)를 탭 — 텍스트가 있는 위젯으로 찾는다.
        final wishCardFinder = find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.startsWith('이 소원은 아주 길게'),
        );
        expect(wishCardFinder, findsOneWidget);
        await tester.tap(wishCardFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('❤ 응원하기'), findsOneWidget);
      },
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '응원 메시지 시트(기존 댓글 포함)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale);

        await tester.tap(find.text('💬 응원 메시지'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('응원 한 마디'), findsOneWidget);
        expect(find.text('도착한 마음 2'), findsOneWidget);
      },
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '복주머니 보내기 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale);

        await tester.tap(find.text('복주머니'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('복주머니 보내기'), findsOneWidget);
        // 금액 칩 탭 → setSheetState 반영도 오버플로 없이 동작하는지 확인.
        await tester.tap(find.text('50개'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('복주머니 50개 보내기'), findsOneWidget);
      },
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '더보기(신고·차단) 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale);

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('이 소원방'), findsOneWidget);
        expect(find.text('소원방 신고하기'), findsOneWidget);
        expect(find.text('이 분 차단하기'), findsOneWidget);
      },
    );
  }
}
