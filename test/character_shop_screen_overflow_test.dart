// [반응형 화면 규격 통일 — 잘림 현상 수정] 캐릭터 상점 화면(CharacterShopScreen)
// 'ⓘ 기본 정보 보기' 정보 시트(_infoSheet) 전수조사 — 실제 버그 발견 및 수정.
//
// _infoSheet는 `Positioned(bottom:22)`로만 배치되고 상단 제약이 전혀 없는
// `Column(mainAxisSize: min)`이라, 콘텐츠(직업·성향·성격 설명·동작 칩 등)가
// 길어지면 시트 전체가 위로 그대로 자라나 화면 상단 밖으로 밀려날 수 있었다.
// RenderFlex 오버플로 예외는 안 뜨지만(세로 제약이 없어 예외 자체가 없음)
// flutter test로 실측한 결과, 현실적인 길이의 성격 설명 2문장만으로도
// 360x640·320x568 화면에서 상단 "GUARDIAN · id" 라벨이 화면 밖(y<0)으로
// 올라가는 조용한 버그를 확인했다.
//
// [실측 결과 — 수정 전, 성격 설명 2문장 기준]
//   390x844@1.0 → top=267 (정상)
//   360x640@1.3 → top=-161 (화면 밖으로 밀려남)
//   320x568@1.5 → top=-465 (화면 밖으로 밀려남)
//
// [수정 내용] (디자인·문구·색상·애니메이션 변경 없음)
// other_room_screen.dart·guide_sheet.dart가 이미 쓰는 공통 패턴
// (`Container(constraints: BoxConstraints(maxHeight: 화면높이*.8))` +
// `Flexible(child: SingleChildScrollView(...))`)을 적용해 시트 높이를 화면의
// 80%로 제한하고, 넘치는 내용은 시트 "안"에서 스크롤로 보게 했다. 드래그
// 핸들(상단 작은 바)만 고정 헤더로 남기고 나머지 전체를 스크롤 영역으로
// 묶었다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/characters/character_shop_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<List<WrCharacter>> characters() async => [
    WrCharacter.fromJson({
      'id': 'F00', 'name': '하린', 'title': '소원을 지키는 수호자', 'grade': 'rare', 'gender': 'F', 'emblem': '🌸',
      'price': 150, 'owned': false,
      'behaviors': ['gaze', 'pray', 'flower'],
      'job': '정원사', 'type': '다정함',
      // 실제 데이터에 가까운 2문장짜리 성격 설명 — 극단치가 아닌 "현실적인"
      // 길이로도 버그가 재현됨을 보여주기 위해 과장하지 않는다.
      'personality': '차분하고 다정한 성격으로 항상 소원을 들어주는 것을 좋아해요. 작은 것에도 감사할 줄 아는 마음씨 착한 캐릭터입니다.',
      'likes': '벚꽃', 'aura': 'red', 'line': '당신의 소원을 함께 지킬게요',
    }),
  ];
  @override
  Future<List<WrItem>> items() async => [];
  @override
  Future<List<OutfitOffer>> outfits(String char) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Future<void> _pump(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async { await WrCatalog.load(); });

  final provider = WishRoomProvider(_FakeWrRepository());

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(home: CharacterShopScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
  ];

  group('CharacterShopScreen 정보 시트(_infoSheet) — 화면 밖으로 밀려나지 않음', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, size, textScale);
        await tester.tap(find.text('ⓘ 기본 정보 보기'));
        await tester.pump();
        expect(tester.takeException(), isNull);

        // "GUARDIAN · id" 라벨은 정보 시트 안에만 존재하는 유일한 텍스트라
        // 파인더가 모호해지지 않는다(무대 쪽엔 같은 문구가 없음).
        final topFinder = find.textContaining('GUARDIAN ·');
        expect(topFinder, findsOneWidget);
        final topRect = tester.getRect(topFinder);
        expect(
          topRect.top >= 0,
          isTrue,
          reason: '정보 시트 상단 라벨(top=${topRect.top})이 화면 밖으로 밀려나면 안 됨'
              ' — maxHeight+스크롤 미적용 시 재발하는 회귀 버그',
        );
      });
    }
  });
}
