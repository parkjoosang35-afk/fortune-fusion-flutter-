// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원 완료·봉인 화면(CompleteScreen)
// 전수조사 — 실제 버그 3건 발견 및 수정(최근 1건은 매트릭스를 표준 5종
// (390,844)@1.0 / (360,640)@1.3 / (320,568)@1.5 / (320,568)@2.0 /
// (320,568)@2.5 로 확장하며 추가로 발견됨 — 구 매트릭스는 2.0x/2.5x가
// 없어 이 버그를 못 잡고 있었다).
//
// 이 화면은 이미 디자인 캔버스(390x844) 레이어를 공용 `WrCanvasScaler`로
// 감싸고 있어(line 259 부근) 지시서 ③ "공통 구조"는 준수된 상태였다. 다만
// 1) 완료 연출 6단계 완료 후 뜨는 "축하합니다" 캡션 아래 `Positioned(bottom:34)`
//    로 배치되는 `_BottomCard`의 저장/공유 텍스트버튼 Row와,
// 2) 봉인 완료 후의 `_SealedBody`(+새 소원방 만들기/소원 기록관 보기 버튼)
// 가 WrCanvasScaler "밖"에서 화면 실좌표/실제 Flex로 배치되고 있어, 글자
// 확대(textScaler)·좁은 화면 조합에서 실제 오버플로가 발생하는지 실측이
// 필요했다.
//
// [발견된 실제 버그 1] `_BottomCard`의 "이미지로 저장 · 기념 이미지 공유하기"
// 텍스트버튼 Row(구 line 684, `Row(mainAxisAlignment: MainAxisAlignment.center)`):
// 390x844@1.0 기준에서는 안전하지만, 360x640@1.3에서 29px, 320x568@1.5에서
// 107px 오른쪽으로 오버플로(RenderFlex overflowed) — 두 버튼의 실제 폭 합이
// 좁은 화면+확대된 글자에서 Row 폭을 넘어섬.
//
// [발견된 실제 버그 2] `_SealedBody`의 콘텐츠 Column(구 line 787,
// `Column(mainAxisAlignment: MainAxisAlignment.center)`)과 그 안의 동일한
// 저장/공유 Row(구 line 887): 390x844@1.0은 안전하지만 360x640@1.3에서
// Row 88px/Column 52px, 320x568@1.5에서 Row 172px/Column 256px 오버플로.
// Column 쪽은 "화면보다 콘텐츠가 커지면 중앙정렬된 채로 그냥 넘친다"는
// 전형적인 패턴 — `lib/features/home/presentation/widgets/
// welcome_reward_modal.dart`에서 동일 버그 클래스에 이미 적용된 표준 수정
// 패턴(LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight))을
// 그대로 재사용했다.
//
// [수정 내용] (디자인·문구·아이콘·애니메이션 변경 없음)
// - 저장/공유 Row 2곳 모두 `Row(mainAxisAlignment:center)` →
//   `Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4)`로 교체
//   (`other_room_screen.dart`에 이미 쓰는 공통 패턴 재사용) — 공간이 부족하면
//   다음 줄로 자연스럽게 넘어간다.
// - `_SealedBody`의 콘텐츠 Column을 `LayoutBuilder` +
//   `SingleChildScrollView(child: ConstrainedBox(minHeight: constraints.maxHeight, ...))`
//   로 감쌌다 — 내용이 화면에 다 들어가면 지금처럼 그대로 중앙정렬되고
//   (ConstrainedBox의 minHeight는 바닥값일 뿐이라 짧은 내용엔 영향 없음),
//   넘칠 때만 스크롤로 모든 버튼에 닿을 수 있다.
//
// [발견된 실제 버그 3 — 매트릭스 확장 중 신규 발견] 완료 연출(_st>=6,
// _seal==0)에서 뜨는 "축하합니다" 캡션 블록(닫기 버튼 Row + 제목/부제
// Column + 기존 Spacer())은 320x568@1.5까지는 안전했지만, 2.0x/2.5x에서
// 닫기 버튼(56px)+제목/부제 블록(2.5배에서 529px)=585px로 Stack이 주는
// 568px 제약을 17px 초과해 아래쪽이 잘렸다(`debugDumpRenderTree()`로
// 각 자식 높이 실측 확인). `_SealedBody`와 같은 버그 클래스이므로 동일
// 표준 패턴(`SingleChildScrollView`)을 재사용해 감쌌다 — 내용이 화면에
// 다 들어가면 지금처럼 그대로 위쪽에 붙어 보이고, 넘칠 때만 스크롤된다.
// 더 이상 의미 없던 기존 Spacer()(스크롤 영역 안에서는 밀어낼 형제가
// 없음)는 제거 — 시각적 변화 없음.
//
// 아래 테스트는 완료 연출 마지막 단계(_st=6, already:true 경로로 연출 타이머
// 없이 즉시 진입)와 봉인 완료 상태(status=SEALED → `_seal=3`, `_SealedBody`)
// 두 경로 모두를 표준 5종 매트릭스(아래 `conditions`)에서 렌더링해 수정 후
// 예외 없이 렌더링되는지(=오버플로 재발하지 않는지) 회귀 테스트로 고정한다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/complete/complete_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Map<String, dynamic> _roomJson({required String status}) => {
  'id': 'wr_1', 'ownerId': 'u',
  'text': '건강하고 행복하게 오래오래오래오래오래 살고 싶어요 정말정말정말 아주 길게 써봅니다',
  'char': 'F00', 'theme': 'free', 'outfitNow': 'free', 'visibility': 'PUBLIC',
  'status': status,
  'devotionCount': 1234, 'supportCount': 987, 'pouchReceived': 100000,
  'level': 12, 'points': 40.0, 'levelName': '아주 길고 긴 레벨 이름을 가진 소망입니다만',
  'curLevelPts': 0, 'nextLevelPts': 100,
  'brightness': 1.0, 'isMine': true,
  'devotionsToday': 2, 'devotionsRemaining': 8, 'dailyLimit': 10, 'cooldownSec': 30, 'daysLit': 999,
  'wishColor': 'red', 'paper': 'hanji',
};

Future<void> _pump(
  WidgetTester tester,
  Size size,
  double textScale, {
  required String status,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async { await WrCatalog.load(); });

  final provider = WishRoomProvider(_FakeWrRepository())
    ..room = WishRoom.fromJson(_roomJson(status: status))
    ..catalogLoaded = true
    ..characters = WrCatalog.I.characters
    ..items = WrCatalog.I.items;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: CompleteScreen(roomId: 'wr_1', already: true),
        ),
      ),
    ),
  );
  await tester.pump();
  // _LotusPop(index*140ms) 등 완료 연출 내부 Future.delayed 타이머를 모두
  // 흘려보내 "Timer still pending" 테스트 위생 이슈 없이 최종 레이아웃을
  // 검사한다(실제 레이아웃 버그와 무관한 잡음 제거 목적).
  await tester.pump(const Duration(seconds: 3));
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

  group('CompleteScreen 완료 연출 완료 상태(_st=6) — 축하 캡션 + _BottomCard', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, size, textScale, status: 'COMPLETED');
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}

        expect(find.text('축하합니다'), findsOneWidget);
        expect(find.text('成 소원방 봉인하기'), findsOneWidget);
        expect(find.text('되돌리기'), findsOneWidget);
        expect(find.text('💌 후기'), findsOneWidget);
      });
    }
  });

  group('CompleteScreen 봉인 완료 상태(_seal=3) — _SealedBody', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, size, textScale, status: 'SEALED');
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}

        expect(find.text('+ 새로운 소원방 만들기'), findsOneWidget);
        expect(find.text('소원 기록관 보기'), findsOneWidget);
      });
    }
  });
}
