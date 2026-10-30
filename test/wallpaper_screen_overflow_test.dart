// [반응형 화면 규격 통일 — 잘림 현상 수정] 배경화면 설정 화면(WallpaperScreen)이
// 좁은 화면 + 글자 확대 조합에서 오버플로 없이 뜨는지 실측한다. 미리보기 카드,
// 레벨명, 상태 안내, 보존된 소원방 목록(긴 텍스트)까지 포함한 메인 화면을 검증한다.
//
// [조사 결과] WPMaking·WPIosDone·WPWebInstallGuide·WPEntryCard·WPFullPreview·
// WPApplied는 모두 Column(mainAxisSize: MainAxisSize.min)을 높이 제약이 없는
// 부모(Center/Align/Positioned-no-height)에 두는 구조라 메인화면의 "둥근 정성
// 버튼"에서 발견했던 "고정 지름 원 + 가변 텍스트" 같은 위험 패턴이 없다(코드
// 리딩으로 확인, 별도 수정 불필요). 메인 화면(WallpaperScreen.build())은 아래
// 테스트로 실제 렌더링까지 확인했다.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/wallpaper/wallpaper_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<WallpaperStatus> wallpaperStatus() async => const WallpaperStatus.empty();
  @override
  Future<List<WishRoom>> archive() async => [
        WishRoom.fromJson(_roomJson(
          id: 'arch1',
          text: '이루어진 긴 소원 문구가 들어갑니다 정말 길게',
          levelName: '빛나는 완성',
          status: 'ARCHIVED',
        )),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Map<String, dynamic> _roomJson({
  String id = 'wr_1',
  String text = '건강하고 행복하게 오래오래 살고 싶어요',
  String levelName = '피어나는 소망입니다만 아주 길게 써봅니다',
  String status = 'ACTIVE',
}) =>
    {
      'id': id, 'ownerId': 'u', 'text': text, 'char': 'F00',
      'theme': 'free', 'outfitNow': 'free', 'status': status,
      'devotionCount': 3, 'supportCount': 1, 'pouchReceived': 10,
      'level': 12, 'points': 40.0, 'levelName': levelName, 'curLevelPts': 0, 'nextLevelPts': 100,
      'brightness': 1.0, 'isMine': true,
      'devotionsToday': 2, 'devotionsRemaining': 8, 'dailyLimit': 10, 'cooldownSec': 30, 'daysLit': 5,
      'completedAt': status == 'ARCHIVED' ? 1704067200000 : null,
    };

Me _user() => Me.fromJson({
      'id': 'u', 'nick': '검증', 'repChar': 'F00', 'pouch': 1000,
      'ownedChars': ['F00', 'M00'],
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
        child: const MaterialApp(home: WallpaperScreen()),
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
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
    (const Size(320, 568), 1.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      'WallpaperScreen(긴 소원방 텍스트 포함)이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size, textScale);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
