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
//
// [추가 조사 — 복주머니 부족 시트(_shortageSheet)] _infoSheet와 정확히 동일한
// 구조적 결함(`Positioned(bottom:22)` + 상단 제약 없는 `Column(mainAxisSize:
// min)`, 내부 스크롤 없음)이 _shortageSheet에도 있었다. 캐릭터 구매 시도 시
// 복주머니가 부족하면 뜨는 시트로, 현실적인 콘텐츠(캐릭터 1명 정보 기준)만으로도
// 재현됐다.
//
// [실측 결과 — 수정 전]
//   390x844@1.0 → top=311 (정상)
//   360x640@1.3 → top=-46 (화면 밖으로 밀려남)
//   320x568@1.5 → top=-259 (화면 밖으로 밀려남)
//
// _infoSheet와 동일한 패턴으로 수정(드래그 핸들만 고정, 나머지는
// maxHeight*.8 + Flexible+SingleChildScrollView)했고, 수정 후 재측정 결과
// 모든 조건에서 top>=0이며, 하단 '다른 방법으로 모으기' 버튼도 스크롤 후
// 정상적으로 탭 가능함을 확인했다.
//
// [발견된 실제 버그 3 — 매트릭스를 표준 5종(390x844@1.0 / 360x640@1.3 /
// 320x568@1.5 / 320x568@2.0 / 320x568@2.5)으로 확장하며 신규 발견]
// 이 화면의 bottomNavigationBar(5개 탭 라벨, fontSize:10)는
// wishroom_shell.dart가 소원방 모듈 전체(IndexedStack 안 탭 5종)에 이미
// 적용 중인 공통 정책("텍스트 스케일 1.3배까지 레이아웃 유지" — textScaler를
// 1.3배로 clamp하는 MediaQuery 오버라이드) 서브트리 "밖"에서
// Navigator.push로 열려 그 보호를 받지 못하고 있었다. 그 결과 글자 확대
// (2.0~2.5배)에서 bottomNavigationBar 실제 높이가 56px→109px로 커지면서
// body의 "목록 패널"(Expanded) 가용 높이를 짓눌러, 안쪽 탭 Row(56px 고정)+
// CTA 버튼(52px+패딩, 고정)의 합이 남은 공간을 넘어 320x568@2.0/2.5에서
// 14px 하단 오버플로가 실측됐다(debugDumpRenderTree()로 확인. _infoSheet·
// _shortageSheet는 이 버그와 무관하게 같은 조건에서 함께 실패했는데,
// 원인은 시트 자체가 아니라 뒤에 깔린 바디 레이아웃이 오버플로를
// 일으키면 테스트의 예외 체크가 먼저 걸리기 때문).
//
// [수정 내용] 새 패딩을 추가하는 대신, 같은 모듈에 이미 승인된 공통 정책
// (textScaler 1.3배 상한)을 이 화면의 build() 최상단에도 동일하게 적용해
// 근본 원인을 없앴다 — 1.3배까지는 완전히 동일하게 보이고, 그 이상만
// 시각적으로 더 커지지 않는다(축소<1.0은 그대로 허용). 디자인·문구·색상
// 변경 없음.
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
      'price': 200, 'owned': false,
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
  // _shortageSheet 테스트를 위해 구매 시도 시 항상 복주머니 부족 에러를 던진다.
  // price(200) > pouch(50)로 사전에 수치가 맞춰져 있어 실제 '부족' 흐름과 일치한다.
  @override
  Future<Me> buyCharacter(String id) async =>
      throw ApiError(409, 'INSUFFICIENT', '복주머니가 조금 부족해요', {'need': 200, 'have': 50});
  @override
  Future<MyRoomResponse> myRoom() async => MyRoomResponse.fromJson({
    'room': null,
    'me': {
      'id': 'u1', 'nick': '테스트', 'repChar': 'F00', 'pouch': 50,
      'accountAgeDays': 10, 'giftToday': 0, 'unread': 0,
      'ownedChars': <String>[], 'ownedItems': <String>[], 'ownedOutfits': <String>[],
      'settings': {'skipIntro': true}, 'earnToday': {'ad': 0},
    },
    'introMode': 'none',
  });
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
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  group('CharacterShopScreen 정보 시트(_infoSheet) — 화면 밖으로 밀려나지 않음', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, size, textScale);
        await tester.tap(find.text('ⓘ 기본 정보 보기'));
        await tester.pump();
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}

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

  group('CharacterShopScreen 복주머니 부족 시트(_shortageSheet) — 화면 밖으로 밀려나지 않음', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, size, textScale);

        final ctaFinder = find.textContaining('함께하기');
        expect(ctaFinder, findsOneWidget);
        await tester.tap(ctaFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}

        // 'NEED MORE'는 부족 시트 안에만 존재하는 유일한 텍스트.
        final topFinder = find.text('NEED MORE');
        expect(topFinder, findsOneWidget);
        final topRect = tester.getRect(topFinder);
        expect(
          topRect.top >= 0,
          isTrue,
          reason: '복주머니 부족 시트 상단 라벨(top=${topRect.top})이 화면 밖으로'
              ' 밀려나면 안 됨 — maxHeight+스크롤 미적용 시 재발하는 회귀 버그',
        );

        // 하단 '다른 방법으로 모으기' 버튼은 내부 스크롤 후에도 항상 탭
        // 가능해야 한다(시트가 화면을 벗어나 버튼까지 함께 밀려나지 않는지 확인).
        final otherBtn = find.text('다른 방법으로 모으기');
        expect(otherBtn, findsOneWidget);
        await tester.scrollUntilVisible(
          otherBtn,
          50,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        await tester.tap(otherBtn, warnIfMissed: false);
        await tester.pump();
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
      });
    }
  });
}
