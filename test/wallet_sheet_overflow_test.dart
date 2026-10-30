// [반응형 화면 규격 통일 — 잘림 현상 수정] 공용 지갑 시트(WalletSheet)가
// 좁은 화면 + 글자 확대 조합에서 오버플로 없이 렌더되는지 실측한다.
// 구성: 잔액 표시, 광고 카드, 일일 미션 5종, 사용처 바로가기 카드 3개(가로 Row),
// 전체 내역 버튼. 사용처 카드 3개가 고정 폭 Row 안에서 짧은 라벨만 쓰므로 설계상
// 안전해 보이지만 실측으로 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/wallet/wallet_sheet.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Me _buildMe() => Me.fromJson({
  'id': 'me-1',
  'nick': '나',
  'repChar': 'F03',
  'pouch': 1234,
  'accountAgeDays': 30,
  'giftToday': 0,
  'unread': 0,
  'ownedChars': ['F00', 'M00'],
  'earnToday': {'attend': 1},
});

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // [버그수정 — other_room_screen_sheets_overflow_test.dart와 동일 사유]
  // WrCatalog.load()는 rootBundle.loadString()으로 실제 비동기 I/O를
  // 수행하므로 testWidgets()의 fake-async 환경에서 직접 await하면 테스트가
  // 영원히 멈춘다. 반드시 tester.runAsync()로 감싼다.
  await tester.runAsync(() => WrCatalog.load());
  final provider = WishRoomProvider(_FakeWrRepository())..me = _buildMe();

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => const WalletSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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
      '지갑 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale);

        expect(tester.takeException(), isNull);
        expect(find.text('내 복주머니'), findsOneWidget);
        expect(find.text('짧은 영상 보고 복주머니 받기'), findsOneWidget);

        // [버그수정 아님 — 테스트 보정] 시트 내부 ListView는 Sliver 지연
        // 빌드라서 뷰포트 밖(스크롤해야 보이는) 위젯은 Element 자체가
        // 생성되지 않아 find.text()가 찾지 못한다. 좁은 화면/글자 확대
        // 조건일수록 윗부분 콘텐츠 높이가 늘어나 "소원방에서 쓰는 곳"
        // 섹션이 초기 뷰포트 밖으로 밀려날 수 있으므로, outfits20_test.dart
        // 등 기존 테스트와 동일하게 scrollUntilVisible로 스크롤한 뒤 확인한다
        // (실제 사용자는 시트를 스크롤해서 내려보므로 이는 정상 동작이다).
        await tester.scrollUntilVisible(
          find.text('소원방에서 쓰는 곳'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('소원방에서 쓰는 곳'), findsOneWidget);
        expect(find.text('수호자'), findsOneWidget);
        expect(find.text('꾸미기'), findsOneWidget);
        expect(find.text('선물하기'), findsOneWidget);
      },
    );
  }
}
