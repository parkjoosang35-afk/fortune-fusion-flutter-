// [반응형 화면 규격 통일 — 잘림 현상 수정] 꾸미기(DecorScreen) '자리 옮기기'
// (PlaceMode, _PlaceModeView) 진입 즉시 발생하던 치명적 크래시 — 실제 버그
// 발견 및 수정.
//
// _PlaceModeView.build()에서 드래그 핸들을 그리는 LayoutBuilder가 Stack의
// 직계 자식이었고, 그 builder가 Positioned를 그대로 반환하고 있었다.
// Positioned는 반드시 Stack의 "직계" 자식이어야 ParentData가 올바르게
// 적용되는데, 실제 부모가 LayoutBuilder가 되면서
//   Incorrect use of ParentDataWidget.
//   The ParentDataWidget Positioned(...) wants to apply ParentData of type
//   StackParentData to a RenderObject, which has been set up to accept
//   ParentData of incompatible type BoxParentData.
// FlutterError가 즉시 발생해, 보유한 장식·꽃·인장·테마 소품을 "자리 옮기기"
// 버튼으로 재배치하려는 순간 화면이 죽는 버그였다(디자인·좌표계산·화면
// 크기와 무관한 위젯 트리 구조 결함 — git log 확인 결과 이 화면이 처음
// 만들어진 커밋부터 존재한 버그).
//
// [수정 내용] (디자인·좌표 계산식·시각 요소 변경 없음)
// LayoutBuilder를 Positioned.fill로 감싸 Stack의 직계 자식 자리를 유지하고,
// LayoutBuilder의 builder가 Positioned를 직접 반환하는 대신
// Stack(children: [Positioned(...)])를 반환하도록 구조만 바로잡았다.
// 드래그 핸들의 좌표 계산식·크기·시각 효과는 수정 전과 동일하다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/decor/decor_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<List<WrItem>> items() async => [
    WrItem.fromJson({
      'id': 'd_lamp',
      'name': '종이등',
      'slot': 'DECORATION',
      'price': 100,
      'owned': true,
      'kind': 'stand',
      's': 52,
    }),
  ];
  @override
  Future<List<WrCharacter>> characters() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  double bottomInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await WrCatalog.load();
  });

  final provider = WishRoomProvider(_FakeWrRepository())
    ..room = WishRoom.fromJson({
      'id': 'test-room',
      'ownerId': 'test-owner',
      'owner': '테스트',
      'text': '검증용 소원',
      'char': 'F00',
      'devotionCount': 0,
      'supportCount': 0,
      'pouchReceived': 0,
      'level': 1,
      'points': 0,
      'levelName': '시작',
      'curLevelPts': 0,
      'nextLevelPts': 100,
      'brightness': 1.0,
      'equip': {
        'CANDLE': 'c_basic',
        'FLOWER': 'f_none',
        'BACKGROUND': 'b_night',
        'SPECIAL': 's_none',
        'DECORATION': ['d_lamp'],
      },
    });
  await provider.loadCatalog();

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: EdgeInsets.only(bottom: bottomInset),
        viewPadding: EdgeInsets.only(bottom: bottomInset),
      ),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(home: DecorScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> enterPlaceMode(WidgetTester tester) async {
    // THEME가 기본 선택 슬롯이므로 보유 장식(DECORATION) 탭으로 전환한다.
    final decoTab = find.textContaining('장식');
    expect(decoTab, findsWidgets);
    await tester.tap(decoTab.first);
    await tester.pump();

    // 장식 아이템 카드를 눌러 ItemCard 시트를 연다.
    final itemName = find.text('종이등');
    expect(itemName, findsWidgets);
    await tester.tap(itemName.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 이미 장착된 아이템이므로 "자리 옮기기" 버튼으로 PlaceMode에 진입한다.
    final moveBtn = find.text('✥ 자리 옮기기');
    expect(moveBtn, findsOneWidget);
    await tester.tap(moveBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('꾸미기 "자리 옮기기" 진입 시 ParentDataWidget 크래시가 발생하지 않는다 (390x844)', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844));
    await enterPlaceMode(tester);

    // 수정 전엔 이 지점에서 FlutterError(Incorrect use of
    // ParentDataWidget)가 발생해 PlaceMode 화면 자체가 그려지지 않았다.
    expect(tester.takeException(), isNull);

    // PlaceMode 화면의 핵심 UI(드래그 핸들 라벨 · 하단 액션 버튼 3개)가
    // 정상적으로 그려졌는지 확인한다.
    expect(find.text('✥ 끌어서 옮기기'), findsOneWidget);
    expect(find.text('기본 자리'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('여기에 두기'), findsOneWidget);
  });

  testWidgets(
    '꾸미기 "자리 옮기기" — 제스처 기반 드래그 핸들이 실제로 탭/드래그 가능하다 (ParentData 정상 적용 확인)',
    (tester) async {
      await _pump(tester, const Size(390, 844));
      await enterPlaceMode(tester);
      expect(tester.takeException(), isNull);

      // 드래그 핸들(라벨 '✥ 끌어서 옮기기'을 담은 GestureDetector)을 실제로
      // 드래그해 onPanUpdate가 예외 없이 동작하는지 확인한다. ParentData가
      // 잘못 적용된 상태였다면 Positioned가 레이아웃 단계에서 무시되어
      // 핸들이 화면 밖(0,0 등 의도치 않은 위치)에 머물거나, 애초에 이
      // 지점까지 오기 전에 build() 자체가 예외로 죽었다.
      final handleLabel = find.text('✥ 끌어서 옮기기');
      final handleRect = tester.getRect(handleLabel);
      expect(handleRect.left.isFinite, isTrue);
      expect(handleRect.top.isFinite, isTrue);

      await tester.drag(handleLabel, const Offset(20, 10));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('꾸미기 "자리 옮기기" — 하단 제스처 내비게이션 여백(48px)이 있어도 크래시 없이 동작한다', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844), bottomInset: 48);
    await enterPlaceMode(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('여기에 두기'), findsOneWidget);
  });
}
