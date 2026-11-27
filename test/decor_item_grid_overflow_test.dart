// [반응형 화면 규격 통일 — 잘림 현상 수정] 꾸미기 화면(DecorScreen) 아이템
// 그리드(_itemGrid) 카드 전수조사 — 두 개의 별개 실버그 발견 및 수정.
//
// === 버그 1: 카드 Column 하단 잘림 (RenderFlex overflowed ... on the bottom) ===
//
// _itemGrid는 `SliverGridDelegateWithFixedCrossAxisCount(childAspectRatio: .8)`를
// 쓰는데, 이 설정은 셀 "높이"가 화면 "폭"에 비례해서(폭이 좁을수록 셀이
// 낮아짐) 정해진다. 그런데 카드 내용물(아이콘 56px + 이름 + 등급 라벨 +
// 기운 뱃지 + 가격/상태 줄)은 화면 폭과 무관하게 항상 같은 고정 높이를
// 요구하는 `Column(mainAxisSize: min)`이었다. 실측 결과 콘텐츠 높이는
// 최소 126px인데, 그리드 셀이 제공하는 콘텐츠 영역 높이는:
//   390px 폭 → 셀 123.3px (이미 126px보다 작음 — 기본 화면에서도 발생)
//   360px 폭 → 셀 110.8px
//   320px 폭 → 셀  94.2px
// 실제 카탈로그 데이터 기준 THEME 탭(기본 선택 탭)의 20개 아이템 전부가
// tier와 effect를 동시에 갖고 있어(기운 뱃지 줄까지 포함하는 최악 케이스),
// 화면을 열자마자 거의 모든 카드에서 바닥 잘림이 재현됐다.
//
// [수정 내용] (디자인·문구·색상·애니메이션 변경 없음)
// character_shop_screen.dart의 _charGrid가 이미 쓰는 패턴과 동일하게,
// 고정 높이 아이콘 슬롯(`SizedBox(height:56, ...)`)을
// `Expanded(child: Center(child: FittedBox(fit: contain, child: 아이콘)))`로
// 바꿔 — 이름·등급·뱃지·가격처럼 항상 다 보여야 하는 줄은 그대로 두고
// 아이콘 영역만 셀이 좁을 때 유연하게 줄어들도록 했다. 바깥 Column의
// `mainAxisSize: min`도 제거해(Expanded가 쓰이려면 부모가 높이를
// 정해줘야 하므로) 셀이 제공하는 전체 높이를 채우도록 했다.
//
// === 버그 2: 기운 뱃지(_fxBadge) 가로 잘림 (overflowed ... on the right) ===
//
// 버그 1과는 독립적인 별개의 버그(git stash로 수정 전/후 동일하게 재현됨을
// 확인해 버그 1 수정이 원인이 아님을 검증함). _fxBadge(big:false)는
// 그리드 카드처럼 좁은 공간에서 쓰이는데, `v`값이 큰 효과 라벨(예:
// "불빛 60%↑", "정성 +30%" 등 — 실제 카탈로그에 다수 존재)의 폭이 카드
// 안쪽 가용 폭(320 화면에서 약 67px)보다 넓어 가로로 잘렸다.
//
// [수정 내용] (디자인·문구·색상 변경 없음)
// _fxBadge 전체를 `FittedBox(fit: scaleDown)`으로 감쌌다. 공간이 충분한
// 기존 상세 시트(big:true)에서는 1.0 이상으로 확대하지 않으므로 기존
// 디자인에 전혀 영향이 없고, 카드처럼 폭이 좁을 때만 뱃지 전체가 비율대로
// 살짝 작아져 잘리지 않는다.
//
// [실측 결과 — 수정 전, THEME 탭 전체 아이템(tier+effect 모두 있음) 기준]
//   390x844@1.0 → RenderFlex overflowed ... on the bottom
//   360x640@1.0 → RenderFlex overflowed ... on the bottom (19px)
//   320x568@1.0 → RenderFlex overflowed ... on the bottom (36px) +
//                 RenderFlex overflowed ... on the right (8.9px, _fxBadge)
// [실측 결과 — 수정 후] 위 모든 조건 + 320x568@1.3에서 exception=null.
//
// === 추가 발견: textScale 1.5 이상에서 재발하는 미세 바닥 잘림 ===
// 버그1을 아이콘 영역(Expanded+FittedBox)만 수정한 1차 버전은 390/360/320
// 폭 기준 textScale 1.0에서는 해결됐지만, 텍스트가 커지는 조건(실측
// 320x568@1.5)에서 "RenderFlex overflowed by 0.639 pixels on the bottom"이
// 새로 재현됐다(카드 Column 전체, decor_screen.dart:1019). 원인은 텍스트
// 블록(이름+등급+뱃지+가격)이 여전히 고정 크기였기 때문 — 아이콘만 줄어드는
// 걸로는 textScale이 커질 때의 여유분이 부족했다.
// [수정] 텍스트 블록 전체를 `Expanded(flex:4, child: FittedBox(fit:
// scaleDown, child: Column(mainAxisSize:min, ...기존 내용 그대로...)))`로
// 묶어 — 아이콘(flex:3)과 함께 전체 카드가 셀 높이에 맞춰 비율대로 줄어들게
// 했다. 텍스트 내용·문구·색상 변경 없음, 단지 레이아웃 컨테이너만 교체.
// [실측 결과 — 수정 후] 320x568@1.5에서도 exception=null 확인.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/decor/decor_screen.dart';

class _FakeWrRepository implements WrRepository {
  // 실제 카탈로그 전체를 그대로 사용 — THEME 탭(기본 선택 탭)의 모든
  // 아이템은 tier != null && effect != null 조합(최악 케이스)을 갖는다.
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
      // THEME 탭에서 전부 tier+effect를 가진 최악 케이스가 노출되도록
      // 'god' 테마로 고정(기본 탭이 THEME이므로 별도 탭 전환 불필요).
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

  group('DecorScreen 아이템 그리드(_itemGrid) — 카드 잘림 없음(THEME 탭 기본 로드)', () {
    final conditions = <(Size, double)>[
      (const Size(390, 844), 1.0),
      (const Size(360, 640), 1.0),
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 1.3),
      (const Size(320, 568), 1.5),
    ];

    for (final (size, textScale) in conditions) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()}@$textScale — overflow 없음',
        (tester) async {
          await _pump(tester, size, textScale);
          expect(
            tester.takeException(),
            isNull,
            reason:
                '카드 Column 바닥 잘림(버그1) 또는 _fxBadge 가로 잘림(버그2) 중'
                ' 하나라도 재발하면 여기서 RenderFlex overflowed 예외가 잡힘',
          );
        },
      );
    }
  });
}
