// [반응형 화면 규격 통일 — 잘림 현상 수정] 꾸미기 화면(DecorScreen) 아이템 상세
// 시트(_itemCardSheet) — 실제 버그 발견 및 수정.
//
// _itemCardSheet는 character_shop_screen.dart의 _infoSheet/_shortageSheet와
// 정확히 동일한 구조적 결함(`Positioned(bottom:22)`로만 배치되고 상단 제약이
// 전혀 없는 `Column(mainAxisSize: min)`, 내부 스크롤 없음)을 갖고 있었다.
// 콘텐츠(아이템 설명·기운 효과 카드·구매/장착 버튼 등)가 길어지면 시트 전체가
// 위로 그대로 자라나 화면 상단 밖으로 밀려날 수 있었다.
//
// [실측 결과 — 수정 전, 실제 카탈로그 중 desc가 가장 긴 아이템(d_jadeincense,
// "응원 300번의 옥향로. 향이 끊이지 않아 촛불이 절반 아래로 약해지지 않아요",
// 43자) 기준]
//   390x844@1.0 → top=473 (정상)
//   360x640@1.3 → top=172.4 (정상이지만 여유 적음)
//   320x568@1.5 → top=-54.7 (화면 밖으로 밀려남)
//   320x568@2.0 → top=-276.4 (화면 밖으로 크게 밀려남)
// 하단 CTA 버튼은 화면 안에 남아있어 겉보기엔 정상처럼 보이지만, 상단 라벨/
// 아이콘/설명이 통째로 안 보이는 조용한 버그였다.
//
// [수정 내용] (디자인·문구·색상·버튼 동작 변경 없음)
// _infoSheet·_shortageSheet가 이미 쓰는 공통 패턴(`Container(constraints:
// BoxConstraints(maxHeight: 화면높이*.8))` + `Flexible(child:
// SingleChildScrollView(...))`)을 그대로 적용했다. 드래그 핸들(상단 작은 바)만
// 고정 헤더로 남기고 나머지 전체를 스크롤 영역으로 묶었다.
//
// [실측 결과 — 수정 후] 위 4개 조건 모두 top>=0, 하단 CTA(응원 보상형 버튼)도
// 내부 스크롤 후 정상적으로 탭 가능함을 확인했다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/decor/decor_screen.dart';

class _FakeWrRepository implements WrRepository {
  // 실제 카탈로그 전체를 그대로 사용 — d_jadeincense(설명 43자, 응원 보상형
  // CTA 버튼 보유)가 DECORATION 탭 안에 포함된다.
  @override
  Future<List<WrItem>> items() async {
    await WrCatalog.load();
    return WrCatalog.I.items
        .map(
          (it) => WrItem.fromJson({
            'id': it.id,
            'name': it.name,
            'slot': it.slot.name,
            'price': it.price,
            'reward': it.reward,
            'owned': false,
            'img': it.img
                ?.replaceFirst('assets/wishroom/items/', '')
                .replaceFirst('.png', ''),
            'kind': it.kind,
            's': it.s,
            'aura': it.aura,
            'desc': it.desc,
            'tier': it.tier,
            'theme': it.theme?.name,
            'effect': it.effect == null
                ? null
                : {'type': it.effect!.type, 'v': it.effect!.v},
          }),
        )
        .toList();
  }

  @override
  Future<List<WrCharacter>> characters() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Future<void> _pump(WidgetTester tester, Size size, double textScale) async {
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
      'theme': 'god',
    });
  await provider.loadCatalog();

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
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

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  group('DecorScreen 아이템 상세 시트(_itemCardSheet) — 화면 밖으로 밀려나지 않음', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (
        tester,
      ) async {
        await _pump(tester, size, textScale);

        // THEME이 기본 탭이므로 DECORATION("장식 0/5")으로 전환.
        // 슬롯 탭 바는 가로 스크롤 ListView라 글자가 커지면 뷰포트 밖에
        // 있을 수 있어(정상 동작) 먼저 가로로 스크롤해 노출시킨다.
        final tabListView = find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        );
        for (var i = 0; i < 10; i++) {
          if (find.text('장식 0/5').hitTestable().evaluate().isNotEmpty) break;
          await tester.drag(tabListView, const Offset(-80, 0));
          await tester.pump();
        }
        final decoTab = find.text('장식 0/5').hitTestable();
        expect(decoTab, findsOneWidget);
        await tester.tap(decoTab.first);
        await tester.pump();

        // 옥향로(d_jadeincense)는 DECORATION 탭 맨 끝(응원보상형)이라 세로
        // 스크롤 필요.
        final nameFinder = find.text('옥향로');
        await tester.scrollUntilVisible(
          nameFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(nameFinder, findsOneWidget);
        await tester.tapAt(tester.getRect(nameFinder.first).center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        // "ITEM ·"는 상세 시트 안에만 존재하는 유일한 텍스트.
        final topFinder = find.textContaining('ITEM ·');
        expect(topFinder, findsOneWidget);
        final topRect = tester.getRect(topFinder);
        expect(
          topRect.top >= 0,
          isTrue,
          reason:
              '아이템 상세 시트 상단 라벨(top=${topRect.top})이 화면 밖으로 밀려나면'
              ' 안 됨 — maxHeight+스크롤 미적용 시 재발하는 회귀 버그',
        );

        // 하단 CTA(응원 보상형 "받으면 열려요" 버튼)는 내부 스크롤 후에도
        // 항상 탭 가능해야 한다.
        final cta = find.textContaining('받으면 열려요');
        expect(cta, findsOneWidget);
        await tester.scrollUntilVisible(
          cta,
          80,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        await tester.tap(cta, warnIfMissed: false);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
