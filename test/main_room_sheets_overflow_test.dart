// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원방 메인화면(MainRoomScreen)에서
// 열리는 두 핵심 바텀시트 — 소원 전문 펼침 카드(_wishFullCard) 내부의 공유/돌보기
// 버튼, 소원방 돌보기 시트(_CareSheet), 소원방 공유 시트(_ShareSheet) — 가 좁은
// 화면 + 글자 확대 조합에서 버튼이 잘리거나 탭 불가능해지지 않는지 실측한다.
//
// [조사 결과] CareSheet·ShareSheet 모두 Container(decoration: sheet) >
// SingleChildScrollView(Column(mainAxisSize: MainAxisSize.min)) 구조라서,
// 내용이 화면보다 길어지면(글자 확대·긴 레벨명·긴 소원 텍스트 등) 시트 전체가
// 세로로 스크롤되어 맨 아래 버튼까지 항상 탭할 수 있다 — 지시서 D항("팝업/안내창은
// 내부 스크롤, 버튼 항상 탭 가능")을 이미 만족하는 구조로 확인됨(세로 스크롤
// 관점에서는 실제 버그 아님, 수정 불요).
//
// [발견된 실제 버그 — 매트릭스를 표준 5종(390x844@1.0 / 360x640@1.3 /
// 320x568@1.5 / 320x568@2.0 / 320x568@2.5)으로 확장하며 신규 발견]
// CareSheet 안의 "입장 인트로 항상 생략" 토글 카드 Row(라벨 Text + 44x26
// AnimatedContainer 토글 스위치, mainAxisAlignment: spaceBetween)는 라벨에
// Flexible 보호가 전혀 없어, 글자 확대(2.0~2.5배)에서 라벨이 토글 스위치를
// 가로로 밀어내 320x568@2.0에서 40px, @2.5에서 101px 오른쪽 오버플로가
// 실측됐다(debugDumpRenderTree()로 확인). 이 Row는 CareSheet가
// `showModalBottomSheet()`로 열리는데, 이는 Navigator 루트 Overlay를
// 쓰므로 wishroom_shell.dart의 소원방 모듈 공통 textScaler 1.3배 상한
// (IndexedStack 안 탭 5종에만 적용) 서브트리 "밖"에서 렌더링돼 그 보호도
// 받지 못한다 — 테스트가 shell 없이 MainRoomScreen을 직접 여는 것과
// 무관하게, 실제 앱에서도 동일하게 재현 가능한 진짜 버그다.
//
// [수정 내용] (디자인·문구·색상 변경 없음) 라벨 Text를 Flexible로 감싸
// 공간이 부족하면 자연스럽게 2줄로 줄바꿈되게 했다 — 평소 크기에선 한 줄로
// 기존과 동일하게 보이고, 토글 스위치는 항상 고정폭으로 제자리에 보인다.
//
// 아래 테스트로 표준 5종 매트릭스 전 조건에서 CareSheet·ShareSheet 모두
// 오버플로 없이 뜨고, 스크롤을 통해 모든 버튼에 닿을 수 있음을 회귀
// 테스트로 고정한다.
import 'dart:io';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/room/main_room_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<WishRoom> updateRoom(String id, {Visibility? visibility}) async {
    return WishRoom.fromJson(_roomJson(vis: visibility?.name ?? 'PUBLIC'));
  }

  @override
  Future<({String token, String url})> shareLink(String id, {bool reissue = false}) async =>
      (token: 't', url: 'https://sintong.app/w/abcdef123456');

  @override
  Future<WallpaperStatus> wallpaperStatus() async => const WallpaperStatus.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Map<String, dynamic> _roomJson({String vis = 'PUBLIC'}) => {
  'id': 'wr_1', 'ownerId': 'u',
  'text': '건강하고 행복하게 오래오래오래오래오래 살고 싶어요 정말정말정말 아주 길게 써봅니다',
  'char': 'F00', 'theme': 'free', 'outfitNow': 'free', 'visibility': vis,
  'devotionCount': 1234, 'supportCount': 987, 'pouchReceived': 100000,
  'level': 12, 'points': 40.0, 'levelName': '아주 길고 긴 레벨 이름을 가진 소망입니다만',
  'curLevelPts': 0, 'nextLevelPts': 100,
  'brightness': 1.0, 'isMine': true,
  'devotionsToday': 2, 'devotionsRemaining': 8, 'dailyLimit': 10, 'cooldownSec': 30, 'daysLit': 5,
  'wishColor': 'red', 'paper': 'hanji',
  'effects': {
    'src': [
      {'id': 'i1', 'type': 'devo', 'v': 5},
      {'id': 'i2', 'type': 'devo', 'v': 3},
    ],
  },
};

Me _user() => Me.fromJson({
      'id': 'u', 'nick': '아주긴닉네임검증용테스트닉네임', 'repChar': 'F00', 'pouch': 1000,
      'ownedChars': ['F00', 'M00'], 'skipIntro': false,
    });

Future<void> _pump(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await WrCatalog.load();
    final data = ByteData.view(
        File('/usr/share/fonts/truetype/nanum/NanumSquareR.ttf').readAsBytesSync().buffer);
    for (final f in ['Pretendard', 'NotoSerifKR', 'GowunBatang', 'IBMPlexMono']) {
      await (FontLoader(f)..addFont(Future.value(data))).load();
    }
  });

  final provider = WishRoomProvider(_FakeWrRepository())
    ..room = WishRoom.fromJson(_roomJson())
    ..me = _user()
    ..catalogLoaded = true
    ..characters = WrCatalog.I.characters
    ..items = WrCatalog.I.items;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(home: MainRoomScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
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

  for (final (size, textScale) in conditions) {
    testWidgets(
      'CareSheet/ShareSheet가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 스크롤로 모든 버튼에 닿는다',
      (tester) async {
        await _pump(tester, size, textScale);

        // 1) 소원 도크를 탭해 _wishFullCard(소원 전문 펼침)를 연다.
        expect(find.textContaining('일째 밝히는 중'), findsOneWidget);
        await tester.tap(find.textContaining('일째 밝히는 중'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull, reason: 'wishFullCard open');}

        // 2) 공유 버튼 탭 -> ShareSheet (wishFullCard 안의 버튼이 나중에
        // 추가돼 트리상 뒤에 위치하므로 .last).
        expect(find.text('⤴ 공유'), findsWidgets);
        await tester.tap(find.text('⤴ 공유').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull, reason: 'ShareSheet open');}

        // ShareSheet 모달 라우트를 닫는다. [참고] 버튼 onPressed가 실제 앱에서도
        // _wishOpen=false를 먼저 호출하므로 wishFullCard는 이미 닫혀 있다(정상).
        Navigator.of(tester.element(find.text('SHARE · 소원방 공유'))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 3) wishFullCard를 다시 열고 "소원방 돌보기" 버튼 탭 -> CareSheet
        await tester.tap(find.textContaining('일째 밝히는 중'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('소원방 돌보기'), findsOneWidget);
        await tester.tap(find.text('소원방 돌보기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull, reason: 'CareSheet open');}

        // CareSheet 맨 아래 "완료" 버튼까지 스크롤로 닿는지 확인 — 버튼이
        // 화면보다 아래에 있어도(320x568@1.5) 시트 내부 스크롤로 항상 탭 가능해야
        // 한다(지시서 D항).
        await tester.scrollUntilVisible(
          find.text('✿ 소원이 이루어졌어요'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('✿ 소원이 이루어졌어요'), findsOneWidget);
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull, reason: 'CareSheet scroll to bottom button');}

        // CareSheet -> ShareSheet(공개범위가 비공개가 아닐 때만 노출되는
        // "소원방 공유하기" 버튼)도 스크롤 후 탭 가능한지 확인.
        if (find.text('⤴ 소원방 공유하기 · 링크 보내기').evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(
            find.text('⤴ 소원방 공유하기 · 링크 보내기'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('⤴ 소원방 공유하기 · 링크 보내기'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull, reason: 'CareSheet -> ShareSheet open');}
        }
      },
    );
  }
}
