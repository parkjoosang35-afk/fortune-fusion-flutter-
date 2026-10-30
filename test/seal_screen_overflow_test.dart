// [반응형 화면 규격 통일 — 잘림 현상 수정] 신당(THE SHRINE) 부적→소원방 봉인
// 진입 시트(showSealToWishRoomSheet)의 두 분기(_NoWishRoomSheet·
// _ConfirmSealSheet) 모두 SafeArea(child: Container(...Column(mainAxisSize:
// min)))만 쓰고 SingleChildScrollView가 없어, 다른 유사 시트들에서 발견된
// "isScrollControlled: true인데 스크롤 래핑이 없는" 패턴과 구조적으로
// 동일하다. seal_reading_flow.dart의 이미 검증된 안전 패턴(소원 텍스트
// maxLines:3+ellipsis로 길이 제한)과 동일하게 제한돼 있는지, 실제 좁은
// 화면/글자 확대 조합에서도 오버플로가 없는지 실측한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/engine/shrine_engine.dart';
import 'package:flutter_app/features/shrine/screens/seal_screen.dart';
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

const _spec = TalismanSpec(
  key: 'test-key',
  type: 'money',
  flavor: 'calm',
  sig: 'sig-1',
  name: '재물운 부적',
  head: 'head',
  base: 'base',
  paper: 'paper',
  phrase: 'phrase',
  phraseMeaning: 'phrase meaning',
  motif: 'motif',
  border: 'border',
  seal: 'seal',
  designId: 'design-1',
);

final _boxItem = BoxItem(
  key: 'box-1',
  no: 'no-1',
  date: '2026-01-01',
  spec: _spec,
  source: const StorySource('room', 'A'),
);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required WishRoomProvider wrProvider,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final shrineProvider = ShrineSessionProvider(prefs);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<WishRoomProvider>.value(value: wrProvider),
          ChangeNotifierProvider<ShrineSessionProvider>.value(value: shrineProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showSealToWishRoomSheet(context, item: _boxItem),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
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
      '소원방 없음 안내 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        final provider = WishRoomProvider(_FakeWrRepository())
          ..loaded = true
          ..room = null;

        await _pump(tester, size: size, textScale: textScale, wrProvider: provider);

        expect(tester.takeException(), isNull);
        expect(find.text('소원 쓰러 가기'), findsOneWidget);
      },
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '봉인 확인 시트(긴 소원문구)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        final provider = WishRoomProvider(_FakeWrRepository())
          ..loaded = true
          ..room = WishRoom.fromJson({
            'id': 'test-room',
            'ownerId': 'test-owner',
            'text':
                '이 소원은 아주 길게 작성된 소원 문구입니다. 화면이 작을 때 '
                '이 문구와 안내 텍스트, 버튼이 모두 잘리지 않고 보이는지 '
                '확인하기 위한 실측 테스트용 텍스트입니다. 조금 더 길게.',
            'char': 'F03',
            'devotionCount': 0,
            'supportCount': 0,
            'pouchReceived': 0,
            'level': 1,
            'points': 0,
            'levelName': '시작',
            'curLevelPts': 0,
            'nextLevelPts': 100,
            'brightness': 1.0,
            'status': 'ACTIVE',
          });

        await _pump(tester, size: size, textScale: textScale, wrProvider: provider);

        expect(tester.takeException(), isNull);
        expect(find.text('봉인하러 가기'), findsOneWidget);
      },
    );
  }
}
