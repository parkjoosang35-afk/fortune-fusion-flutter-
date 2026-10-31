// [반응형 화면 규격 통일 — 잘림 현상 수정] 꾸미기 화면(DecorScreen) 상단
// 방 미리보기의 "지금 켜진 기운" 뱃지 목록(_fxList Wrap) 잘림 버그.
//
// === 버그 설명 ===
// 방 미리보기 영역은 390x844 Column 안에 고정 height:400인 SizedBox +
// Stack(clipBehavior: Clip.hardEdge)로 구성된 "카메라 뷰파인더"이며, 안쪽에
// Positioned.fill(ClipRect(...RoomScene...))가 있다. 이 400px 하드 클립은
// wr_canvas.dart 기준 의도된 카메라 줌 연출(코드 주석 참고)이라 전체
// min-scale 규칙 예외 대상이지만, "지금 켜진 기운" 뱃지 Wrap은 그 카메라
// 연출과 무관한 일반 UI 요소임에도 같은 Clip.hardEdge Stack 안에
// `Positioned(top: 318, ...)`로 배치되어 있었다.
//
// 뱃지는 장착 아이템의 효과(devo/support/cool/daily/pouch/decay) 조합에 따라
// 최대 6개까지 동시에 표시될 수 있는데(_fxList 참고), top:318부터 400px
// 경계까지 겨우 82px밖에 여유가 없어 뱃지가 2줄 이상이 되거나 textScale이
// 커지면 아래쪽 뱃지가 400px 클립 경계에 실제로 잘렸다(또는 완전히
// 보이지 않게 밀려났다).
//
// [실측 결과 — 수정 전, 6개 효과 전부 활성화 최악 케이스 기준]
//   390x844@1.0 → 정상(여유 있음)
//   360x640@1.3 → "불빛" 뱃지 bottom=406 (400 초과, 6px 잘림)
//   320x568@1.5 → "불빛"/"복 +15" 뱃지 bottom=415 (15px 잘림)
//   320x568@2.0 → 두 뱃지 모두 y=448~520 (뷰파인더 완전히 밖, 사용자에게
//                 전혀 보이지 않음 — 예외 발생 없이 "조용히" 잘리는
//                 silent bug이므로 RenderFlex overflow로는 잡히지 않음)
//
// [수정 내용] (디자인·문구·색상 변경 없음)
// Positioned를 top:318 고정 대신 top:318 + bottom:8 로 바꿔 사용 가능한
// 높이를 명시적으로 제한하고, 그 안을 LayoutBuilder + FittedBox(fit:
// scaleDown) + SizedBox(width: 가용폭)로 감싸 뱃지 Wrap 전체가 남은
// 공간보다 커지면 비율대로 축소되도록 했다. 평소처럼 뱃지가 1~2개뿐이라
// 공간이 충분한 경우는 FittedBox가 축소를 하지 않으므로(1:1 scale)
// 기존 모양이 그대로 유지된다.
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
  Future<List<WrItem>> items() async {
    await WrCatalog.load();
    return WrCatalog.I.items
        .map(
          (it) => WrItem.fromJson({
            'id': it.id,
            'name': it.name,
            'slot': it.slot.name,
            'price': it.price,
            'owned': true,
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

/// 400px 뷰파인더(room preview)의 "화면 내 Y 좌표" 상한.
/// DecorScreen은 Column의 첫 자식이 뷰파인더이고, 이 테스트는 항상 화면
/// 최상단에서 시작하는 MaterialApp(home:)이므로 전역 좌표 기준으로도
/// 그대로 400.0이 클립 경계가 된다.
const double _viewfinderBottom = 400.0;

Future<void> _pump(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await WrCatalog.load();
  });

  // 6개 효과(devo/support/cool/daily/pouch/decay)가 전부 활성화된 최악 케이스
  // — _fxList()가 6개 뱃지를 모두 생성하도록 room.effects를 직접 구성한다.
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
      'equip': {
        'CANDLE': 'c_moon',
        'FLOWER': 'f_mum',
        'DECORATION': ['d_jadeincense'],
        'SPECIAL': 's_none',
        'SEAL': [],
        'THEME': [],
      },
      'effects': {
        'devo': 25,
        'support': 20,
        'cool': 5,
        'daily': 1,
        'pouch': 15,
        'decay': 60,
      },
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
  // _PlaceFx/_EffectOn 진입 애니메이션 종료 대기(이번 케이스는 _placed==null
  // 이라 연출이 없지만, 다른 조건과의 일관성을 위해 동일하게 대기).
  await tester.pump(const Duration(milliseconds: 1100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DecorScreen 방 미리보기 — "지금 켜진 기운" 뱃지(_fxList Wrap) 잘림 없음', () {
    final conditions = <(Size, double)>[
      (const Size(390, 844), 1.0),
      (const Size(360, 640), 1.3),
      (const Size(320, 568), 1.5),
      (const Size(320, 568), 2.0),
      (const Size(320, 568), 2.5),
    ];

    for (final (size, textScale) in conditions) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()}@$textScale — 6개 기운 뱃지 모두 400px 뷰파인더 안에 보임',
        (tester) async {
          await _pump(tester, size, textScale);
          expect(tester.takeException(), isNull);

          // _fxList()가 만드는 6개 뱃지 문구 전부를 순서대로 확인한다.
          const labels = ['정성', '응원', '머금기', '하루', '복 +15', '불빛'];
          for (final label in labels) {
            final finder = find.textContaining(label);
            expect(
              finder,
              findsWidgets,
              reason: '"$label" 기운 뱃지가 트리에서 발견되지 않음(렌더 자체가 안 됨)',
            );
            final rect = tester.getRect(finder.first);
            expect(
              rect.bottom,
              lessThanOrEqualTo(_viewfinderBottom),
              reason:
                  '"$label" 뱃지가 400px 카메라 뷰파인더의 ClipRect 경계 아래로'
                  ' 내려가 화면에서 잘림(또는 완전히 가려짐)',
            );
            expect(
              rect.top,
              greaterThanOrEqualTo(0.0),
              reason: '"$label" 뱃지가 화면 위쪽 경계를 벗어남',
            );
          }
        },
      );
    }
  });
}
