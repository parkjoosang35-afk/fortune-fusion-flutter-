// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원방 메인화면(MainRoomScreen)의
// 핵심 버튼인 "둥근 정성 버튼"(지름 66px 고정 원형, 소원방 하단 도크)이
// 좁은 화면 + 글자 확대 조합에서 잘리지 않는지 실측한다. 이 버튼은 평상시
// (정성/오늘 완료)·머금는 중(쿨다운)·촛불이 약해짐(다시 밝히기) 3가지 상태를
// 모두 가지므로 각 상태를 전부 커버한다.
import 'dart:io';
import 'package:flutter/material.dart';
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
  Future<WallpaperStatus> wallpaperStatus() async => const WallpaperStatus.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Map<String, dynamic> _roomJson({
  int devotionsToday = 2,
  int devotionsRemaining = 8,
  bool decayBadge = false,
  double brightness = 1.0,
}) => {
  'id': 'wr_1', 'ownerId': 'u', 'text': '건강하고 행복하게 오래오래오래오래 살고 싶어요 정말정말', 'char': 'F00',
  'theme': 'free', 'outfitNow': 'free',
  'devotionCount': 3, 'supportCount': 1, 'pouchReceived': 10,
  'level': 2, 'points': 40.0, 'levelName': '피어나는 소망입니다만', 'curLevelPts': 0, 'nextLevelPts': 100,
  'brightness': brightness, 'isMine': true, 'decayBadge': decayBadge, 'absentDays': decayBadge ? 5 : 0,
  'devotionsToday': devotionsToday, 'devotionsRemaining': devotionsRemaining, 'dailyLimit': 10,
  'cooldownSec': 30, 'daysLit': 5,
  'effects': {'src': [
    {'id': 'i1', 'type': 'devo', 'v': 5},
  ]},
};

Me _buildMe() => Me.fromJson({
  'id': 'u', 'nick': '검증', 'repChar': 'F00', 'pouch': 1000,
  'ownedChars': ['F00', 'M00'],
});

Future<void> _loadFontsOnce() async {
  final data = ByteData.view(File('/usr/share/fonts/truetype/nanum/NanumSquareR.ttf').readAsBytesSync().buffer);
  for (final f in ['Pretendard', 'NotoSerifKR', 'GowunBatang', 'IBMPlexMono']) {
    await (FontLoader(f)..addFont(Future.value(data))).load();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required Map<String, dynamic> roomJson,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // [버그수정 — other_room_screen_sheets_overflow_test.dart와 동일 사유]
  // WrCatalog.load()는 rootBundle.loadString()으로 실제 비동기 I/O를
  // 수행하므로 testWidgets()의 fake-async 환경에서 직접 await하면 테스트가
  // 영원히 멈춘다. 반드시 tester.runAsync()로 감싼다. 폰트도 같은 이유로
  // real I/O이므로 함께 묶는다.
  await tester.runAsync(() async {
    await WrCatalog.load();
    await _loadFontsOnce();
  });

  final provider = WishRoomProvider(_FakeWrRepository())
    ..room = WishRoom.fromJson(roomJson)
    ..me = _buildMe()
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

  for (final (size, textScale) in conditions) {
    testWidgets(
      '정성 버튼(평상시)이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale, roomJson: _roomJson());
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
      },
    );

    testWidgets(
      '정성 버튼(머금는 중)이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        // devotionsRemaining < dailyLimit 이고 쿨다운 중일 때(머금는 중) 표시되는
        // "{초} / 머금는 중" 2줄 레이블 — _cooldownRemain은 내부 state라 직접
        // 세팅할 수 없으므로, 쿨다운 트리거 조건(devotionsToday>0)만 맞춘 뒤
        // 1초 뒤 티커가 값을 채우도록 pump한다.
        await _pump(tester, size: size, textScale: textScale,
          roomJson: _roomJson(devotionsToday: 1, devotionsRemaining: 9));
        await tester.pump(const Duration(seconds: 1));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
      },
    );

    testWidgets(
      '정성 버튼(오늘 완료)이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale,
          roomJson: _roomJson(devotionsToday: 10, devotionsRemaining: 0));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
      },
    );

    testWidgets(
      '정성 버튼(촛불 약해짐·다시 밝히기)이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size: size, textScale: textScale,
          roomJson: _roomJson(decayBadge: true, brightness: .3));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
      },
    );
  }
}
