// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원 완료·봉인 화면(CompleteScreen)
// 전수조사.
//
// 이 화면은 이미 디자인 캔버스(390x844) 레이어를 공용 `WrCanvasScaler`로
// 감싸고 있어(line 259 부근) 지시서 ③ "공통 구조"는 준수된 상태였다. 다만
// 1) 완료 연출 6단계 완료 후 뜨는 "축하합니다" 캡션(SafeArea+Column, 캔버스
//    밖 레이어)과 그 아래 `Positioned(bottom:34)`로 배치되는 `_BottomCard`
//    (되돌리기/💌후기/봉인하기 버튼, 저장/공유 텍스트버튼)가 WrCanvasScaler
//    "밖"에서 화면 실좌표로 배치되고,
// 2) 봉인 완료 후의 `_SealedBody`(+새 소원방 만들기/소원 기록관 보기 버튼)는
//    WrCanvasScaler를 전혀 쓰지 않고 SafeArea+Padding+Column(결과를 화면
//    크기에 맞춰 직접 배치)만 사용한다
// 는 점에서, 글자 확대(textScaler)·좁은 화면에서 버튼이 화면 밖으로 밀려나거나
// 잘리지 않는지 별도로 실측이 필요하다.
//
// [조사 결과]
// - 완료 연출 축하 캡션+_BottomCard: SafeArea 내부라 시스템 UI와는 안전하게
//   분리되고, `_BottomCard`는 Column(기본 mainAxisSize=max이지만 자식이
//   SizedBox+Row 뿐이라 실제 차지 높이는 content-driven) 구조다. 버튼은
//   Expanded+SizedBox(height: WrSize.btnSmH, 고정)라서 textScaler가 커져도
//   버튼 "높이"는 늘지 않고, 내부 Text는 maxLines:1 + overflow:ellipsis로
//   가로로만 축약된다 — 세로 잘림/겹침 위험이 구조적으로 없음.
// - `_SealedBody`: SafeArea(Padding(Column(mainAxisAlignment:center,...)))
// 구조. 세로 공간이 모자라면(좁은 화면 + 글자 확대) Column이 콘텐츠 전체
// 높이로 overflow할 수 있는 위험 구조이므로, 실측 필요.
//
// 아래 테스트는 완료 연출 마지막 단계(_st=6, already:true 경로로 연출 타이머
// 없이 즉시 진입)와 봉인 완료 상태(status=SEALED → `_seal=3`, `_SealedBody`)
// 두 경로 모두를 320x568@1.5 등 가혹 조건에서 렌더링해 오버플로 예외 유무를
// 확인한다.
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
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
  ];

  group('CompleteScreen 완료 연출 완료 상태(_st=6) — 축하 캡션 + _BottomCard', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, size, textScale, status: 'COMPLETED');
        expect(tester.takeException(), isNull);

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
        expect(tester.takeException(), isNull);

        expect(find.text('+ 새로운 소원방 만들기'), findsOneWidget);
        expect(find.text('소원 기록관 보기'), findsOneWidget);
      });
    }
  });
}
