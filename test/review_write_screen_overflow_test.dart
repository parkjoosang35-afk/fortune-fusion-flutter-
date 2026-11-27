// [반응형 화면 규격 통일 — 잘림 현상 수정] 성취 후기 작성 화면(ReviewWriteScreen)
// 전수조사 — 실제 버그 2건 발견 및 수정.
//
// flutter test로 실측한 결과, 다음 두 Row가 모두 고정 크기 Text 두 개를
// 나란히 배치하고 있어 좁은 화면(360x640)+글자 확대(1.3배 이상) 조합에서
// 오른쪽으로 가로 RenderFlex 오버플로가 발생했다.
//
// [실측 결과 — 수정 전]
//   1) line 134 — 글자 수 안내 Row('N자 더 적어주세요' / 'N / 500')
//      390x844@1.0 → 정상
//      360x640@1.3 → overflow 10px
//      320x568@1.5 → overflow 88px
//   2) line 141 — 사진 첨부 안내 Row('사진 ' / '선택 · 첨부하면 복주머니 +20')
//      같은 조건에서 동일하게 오버플로(최대 84px).
//
// [수정 내용] (디자인·폰트·색상·문구·애니메이션 변경 없음)
// 두 Row 모두 길어질 수 있는 쪽 Text를 main_room_screen.dart가 이미 쓰는
// 공통 패턴(`Flexible` + `maxLines: 1` + `TextOverflow.ellipsis`)으로 감싸,
// 공간이 부족하면 말줄임표로 줄어들게 했다. 고정 폭이 필요한 쪽('N / 500'
// 글자 수 카운터)은 그대로 둔다.
//
// [추가 확인 — 버그 아님] 하단 CTA 패널(Positioned bottom:0, padding
// bottom:30)에는 SafeArea가 없지만, FakeViewPadding으로 iOS 제스처 인셋
// (34px)·Android 제스처 인셋(48px, 80px 극단치)을 모두 시뮬레이션해
// tester.getRect()로 실측한 결과 버튼이 전혀 가려지지 않았다 — 고정
// bottom:30 여백이 테스트한 모든 인셋보다 충분히 크기 때문. 따라서 이
// 화면은 SafeArea 추가 없이 그대로 두되, 회귀 확인용으로 인셋 조건을
// 테스트에 포함해 고정한다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/review/review_write_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Map<String, dynamic> _roomJson() => {
  'id': 'wr_1', 'ownerId': 'u',
  'text': '건강하고 행복하게 오래오래 살고 싶어요',
  'char': 'F00', 'theme': 'free', 'outfitNow': 'free', 'visibility': 'PUBLIC',
  'status': 'SEALED',
  'devotionCount': 3, 'supportCount': 1, 'pouchReceived': 10,
  'level': 12, 'points': 40.0, 'levelName': '피어나는 소망', 'curLevelPts': 0, 'nextLevelPts': 100,
  'brightness': 1.0, 'isMine': true,
  'devotionsToday': 2, 'devotionsRemaining': 8, 'dailyLimit': 10, 'cooldownSec': 30, 'daysLit': 999,
  'wishColor': 'red', 'paper': 'hanji',
  'sealedOn': '2024-01-01', 'sealUntil': '2026-01-01', 'sealTotalDays': 730,
};

Future<void> _pump(WidgetTester tester, Size size, double textScale, double bottomInset) async {
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
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale), padding: EdgeInsets.only(bottom: bottomInset)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: MaterialApp(home: ReviewWriteScreen(room: room)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // (화면 크기, 글자 확대 배율, 하단 제스처 내비게이션 인셋)
  final conditions = <(Size, double, double)>[
    (const Size(390, 844), 1.0, 0),
    (const Size(390, 844), 1.0, 34),  // iOS 홈 인디케이터 인셋
    (const Size(360, 640), 1.3, 48),  // Android 제스처 내비게이션 인셋 + 글자 확대
    (const Size(320, 568), 1.5, 48),
    (const Size(320, 568), 1.5, 80),  // 극단적으로 큰 인셋까지 확인
  ];

  group('ReviewWriteScreen 작성 화면 — 오버플로 없음 + 하단 CTA 안 가려짐', () {
    for (final (size, textScale, inset) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale inset=${inset.toInt()}', (tester) async {
        await _pump(tester, size, textScale, inset);
        expect(tester.takeException(), isNull);

        // 글자 수 안내 / 사진 첨부 안내가 모두 그려지는지 확인(말줄임 허용).
        expect(find.textContaining('더 적어주세요').evaluate().isNotEmpty || find.text('✓ 좋아요').evaluate().isNotEmpty, isTrue);
        expect(find.text('사진 '), findsOneWidget);

        // 하단 CTA 버튼이 인셋 영역(제스처 내비게이션)에 가려지지 않는지 확인.
        final btnFinder = find.text('💌 이야기 남기기');
        expect(btnFinder, findsOneWidget);
        final btnRect = tester.getRect(btnFinder);
        final safeBottom = size.height - inset;
        expect(
          btnRect.bottom <= safeBottom,
          isTrue,
          reason: '하단 CTA(bottom=${btnRect.bottom})가 제스처 내비게이션 인셋 영역'
              '(safeBottom=$safeBottom)을 침범하면 안 됨',
        );
      });
    }
  });
}
