// [반응형 화면 규격 통일 전수조사 중 발견 — 화면 규격과는 별개의 크래시 버그]
// WishRoomIntroScreen의 "full" 인트로 연출(_SplashStage) 전수조사.
//
// _SplashStageState는 `_cam`(항상 생성)과 `_loading`(showLoading=true가
// 되는 순간, 즉 full 모드 진입 1.1초 지점에 추가로 생성) 두 개의
// AnimationController를 만드는데, 기존 코드는 `SingleTickerProviderStateMixin`
// (단수형)을 쓰고 있었다. 이 mixin은 State당 Ticker를 1개만 허용하며,
// 두 번째 컨트롤러 생성 시 `FlutterError`를 던진다 — assert가 아니라 항상
// 던지는 에러라 릴리즈 빌드에서도 그대로 재현된다(패키지 소스
// ticker_provider.dart 확인). 즉 "신규 소원방을 처음 만든 뒤 보는 full
// 인트로 연출"이 로딩바가 뜨는 1.1초 시점에 항상 크래시했다.
//
// `TickerProviderStateMixin`(복수형)으로 교체해 여러 Ticker를 허용하도록
// 수정했다 — 애니메이션 값·타이밍·디자인은 전혀 바뀌지 않는다(이미 같은
// 패턴을 쓰는 `_GateStageState`도 복수형이었다).
//
// [실측] 수정 전: introMode=full로 진입 후 1.1초(st1, 로딩바 등장) 시점에
// 테스트가 FlutterError(SingleTickerProviderStateMixin but multiple tickers
// were created)로 즉시 실패했다. 수정 후: 390x844·320x568 두 조건 모두
// st0→st1(로딩바 등장) 전환까지 예외 없이 통과한다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/intro/wish_room_intro_screen.dart';

Map<String, dynamic> _roomJson() => {
  'id': 'wr_1', 'ownerId': 'u', 'text': '소원', 'char': 'F00',
  'theme': 'free', 'outfitNow': 'free',
  'devotionCount': 3, 'supportCount': 1, 'pouchReceived': 10,
  'level': 2, 'points': 40.0, 'levelName': '레벨', 'curLevelPts': 0, 'nextLevelPts': 100,
  'brightness': 1.0, 'isMine': true, 'decayBadge': false, 'absentDays': 0,
  'devotionsToday': 2, 'devotionsRemaining': 8, 'dailyLimit': 10,
  'cooldownSec': 30, 'daysLit': 5,
};

class _FakeWrRepository implements WrRepository {
  @override
  Future<List<WrCharacter>> characters() async => [];
  @override
  Future<List<WrItem>> items() async => [];
  @override
  Future<MyRoomResponse> myRoom() async => MyRoomResponse.fromJson({
    'room': _roomJson(),
    'me': {
      'id': 'u1', 'nick': '테스트', 'repChar': 'F00', 'pouch': 0,
      'accountAgeDays': 0, 'giftToday': 0, 'unread': 0,
      'ownedChars': <String>[], 'ownedItems': <String>[], 'ownedOutfits': <String>[],
      'settings': {'skipIntro': true}, 'earnToday': {'ad': 0},
    },
    // full 인트로 모드 — _SplashStage(showLoading)가 1.1초 뒤 true가 되며
    // 버그가 재현되는 조건.
    'introMode': 'full',
  });
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Future<void> _pump(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async { await WrCatalog.load(); });

  final provider = WishRoomProvider(_FakeWrRepository());

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(home: WishRoomIntroScreen()),
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets(
      'full 인트로 st0→st1(로딩바 등장) 전환이 Ticker 예외 없이 성공한다 ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _pump(tester, size);
        expect(tester.takeException(), isNull, reason: 'st0 스플래시 최초 렌더');

        // 원본 타이밍: 1100ms에 showLoading=true로 전환되며 두 번째
        // AnimationController(_loading)가 생성된다 — 바로 이 시점에
        // 수정 전 코드는 FlutterError를 던졌다.
        await tester.pump(const Duration(milliseconds: 1100));
        expect(
          tester.takeException(),
          isNull,
          reason:
              'st1(로딩바 등장) 전환 — SingleTickerProviderStateMixin 단수형'
              ' 회귀 시 "multiple tickers were created" FlutterError 재발',
        );
        expect(find.text('소원방으로 들어가고 있어요'), findsOneWidget);
      },
    );
  }
}
