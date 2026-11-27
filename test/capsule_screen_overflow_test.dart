// [반응형 화면 규격 통일 — 잘림 현상 수정] 타임캡슐 열람 화면(CapsuleOpenScreen)
// 'ask' 단계 전수조사 — 실제 버그 2건 발견 및 수정(1차: 두루마리 높이
// 무제한, 2차: 선택지 패널 bottom 고정+상한 없음).
//
// `_CapStep.ask` 단계는 펼쳐진 두루마리(`Positioned(top:150)`, 소원 글자
// 수에 비례해 높이가 늘어나는 가변 높이 블록)와 "이 소원은 어떻게
// 되었나요?" 선택지 패널(`Positioned(bottom:40)`, 버튼 3개 고정)을 함께
// 화면에 배치한다.
//
// [1차 버그 — 두루마리 쪽 높이 무제한] 좁은 화면(360x640)과 글자 확대
// (1.3배) 조합에서 두루마리 소원 텍스트(최대 100자)가 길면 아래 선택지
// 패널과 실제로 겹치는 것을 `tester.getRect()` 비교로 실측 확인했다.
//   390x844@1.0  → overlap=false (디자인 기준이라 문제 없음)
//   360x640@1.3  → overlap=true  (두루마리 하단이 "이 소원은…" 안내문 위로 내려옴)
//   320x568@1.5  → overlap=true
// [1차 수정] (디자인·폰트·여백·애니메이션 변경 없음) 두루마리 안의 소원
// 텍스트를 `main_room_screen.dart`에서 이미 쓰는 공통 패턴
// (`ConstrainedBox(maxHeight) + SingleChildScrollView`)으로 감싸 두루마리
// 전체 높이를 제한했다(maxHeight:60, 320x568@1.5까지 실측으로 역산).
//
// [2차 버그 — 매트릭스를 2.0x/2.5x까지 확장하며 추가 발견] 선택지 패널이
// `Positioned(bottom:40)`만 있고 `top` 상한이 없어, 글자 확대가 더
// 커지면(2.0x/2.5x) "이 소원은 어떻게 되었나요?" 타이틀이 2~3줄로
// 늘어나며 패널 전체 높이가 위로 커져 두루마리 영역(항상 bottom=246
// 고정)과 겹치는 것을 실측 확인했다(320x568@2.0: wishBottom=246 >
// askTop=180, 320x568@2.5: wishBottom=246 > askTop=138).
// [2차 수정] (텍스트를 자르거나 임의 패딩으로 가리지 않음) 선택지 패널에
// `top:256`(두루마리 영역 바로 아래) 상한을 명시해 두루마리 공간을
// 침범할 수 없게 하고, `Align(bottomCenter) + SingleChildScrollView`로
// 감싸 내용이 짧을 땐 기존처럼 하단에 붙어 보이되, 길어지면 패널
// "안"에서 스크롤되게 했다 — 두루마리 쪽과 동일한 공통 패턴.
//
// [측정 대상 관련 주의] Text(room.text) 자체는 SingleChildScrollView의
// "스크롤 콘텐츠"라서 넘치는 글자 수만큼 레이아웃 높이가 그대로 커진다
// (화면엔 안 보여도 렌더박스는 전체 텍스트 크기). 그래서 겹침 판정은
// Text의 rect가 아니라, maxHeight로 실제 보이는 영역을 제한하는
// SingleChildScrollView 쪽에 단 key(`wr_capsule_wish_scroll`)의 rect를
// 기준으로 해야 한다 — Text 기준으로 측정하면 수정 후에도 항상
// "겹침"으로 나오는 거짓 양성(false positive)이 발생한다.
//
// 아래 테스트는 표준 5종 배율 조합(1.0/1.3/1.5/2.0/2.5)에서 두루마리와
// 선택지 패널이 겹치지 않는지(overlap=false) 회귀 테스트로 고정한다.
// 'rewish'(다시 소원 빌기) 단계도 같은 두루마리 구조를 공유하므로 함께
// 예외 없이 렌더링되는지 확인한다(선택지 패널이 스크롤 가능해져 버튼이
// 스크롤 안에 있을 수 있으므로 ensureVisible 후 tap).
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/capsule/capsule_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<WishRoom> unseal(String id) async => WishRoom.fromJson(_roomJson());
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

const _wishText =
    '건강하고 행복하게 오래오래오래오래오래 살고 싶어요 정말정말정말 아주 길게 길게 길게 써봅니다 끝도없이 계속 길게 길게 아주 길게 써봅니다 정말 끝도없이';

Map<String, dynamic> _roomJson() => {
  'id': 'wr_1', 'ownerId': 'u',
  'text': _wishText,
  'char': 'F00', 'theme': 'free', 'outfitNow': 'free', 'visibility': 'PUBLIC',
  'status': 'SEALED',
  'devotionCount': 3, 'supportCount': 1, 'pouchReceived': 10,
  'level': 12, 'points': 40.0, 'levelName': '피어나는 소망', 'curLevelPts': 0, 'nextLevelPts': 100,
  'brightness': 1.0, 'isMine': true,
  'devotionsToday': 2, 'devotionsRemaining': 8, 'dailyLimit': 10, 'cooldownSec': 30, 'daysLit': 999,
  'wishColor': 'red', 'paper': 'hanji',
  'sealedOn': '2024-01-01', 'sealUntil': '2026-01-01', 'sealTotalDays': 730,
};

Future<void> _pumpAsk(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async { await WrCatalog.load(); });

  final provider = WishRoomProvider(_FakeWrRepository())
    ..catalogLoaded = true
    ..characters = WrCatalog.I.characters
    ..items = WrCatalog.I.items;

  final room = WishRoom.fromJson(_roomJson());

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: MaterialApp(home: CapsuleOpenScreen(room: room)),
      ),
    ),
  );
  await tester.pump();
  // open -> ask 자동 전환까지(initState Timer, 3000ms) 대기.
  await tester.pump(const Duration(milliseconds: 3500));
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

  group('CapsuleOpenScreen ask 단계 — 두루마리/선택지 패널 겹침 없음', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pumpAsk(tester, size, textScale);
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}

        expect(find.text('이 소원은 어떻게 되었나요?'), findsOneWidget);

        // [중요] Text(room.text) 자체는 ConstrainedBox+SingleChildScrollView의
        // '스크롤 콘텐츠'라서, 넘치는 글자 수만큼 레이아웃 높이가 그대로
        // 커진다(스크롤되어 화면엔 안 보이지만 렌더박스는 전체 텍스트 크기).
        // 따라서 실제로 '화면에 보이는' 영역인 뷰포트(key:
        // wr_capsule_wish_scroll, maxHeight:150으로 제한됨)를 기준으로
        // 겹침을 판정해야 한다 — Text의 rect를 쓰면 클리핑 전 크기가 나와
        // 오탐(false positive)이 발생한다.
        final wishScrollRect = tester.getRect(find.byKey(const Key('wr_capsule_wish_scroll')));
        final askRect = tester.getRect(find.text('이 소원은 어떻게 되었나요?'));
        expect(
          wishScrollRect.bottom <= askRect.top,
          isTrue,
          reason: '두루마리 소원 스크롤 뷰포트(bottom=${wishScrollRect.bottom})가 선택지'
              ' 안내문(top=${askRect.top})을 덮으면 안 됨 — ConstrainedBox+스크롤'
              ' 미적용 시 재발하는 회귀 버그',
        );

        // 선택지 3개 버튼 모두 화면에 그려지는지 확인.
        expect(find.text('소원이 이루어졌어요'), findsOneWidget);
        expect(find.text('아직 진행 중이에요'), findsOneWidget);
        expect(find.text('다시 소원을 빌어요'), findsOneWidget);
      });
    }
  });

  group('CapsuleOpenScreen rewish 단계 — 동일 두루마리 구조, 예외 없이 렌더링', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pumpAsk(tester, size, textScale);
        // [반응형 화면 규격 통일] ask 패널이 SingleChildScrollView로 감싸여
        // 있어, 글자 확대로 내용이 길어지면 '다시 소원을 빌어요' 버튼이
        // 스크롤해야 보이는 위치에 있을 수 있다(정상 동작 — 사용자는
        // 스크롤해서 탭 가능). ensureVisible로 실제 사용자 동작처럼
        // 스크롤한 뒤 탭한다.
        await tester.ensureVisible(find.text('다시 소원을 빌어요'));
        await tester.pump();
        await tester.tap(find.text('다시 소원을 빌어요'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
        expect(find.text('🔐 소원 봉인하기'), findsOneWidget);
      });
    }
  });
}
