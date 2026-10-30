// [반응형 화면 규격 통일 — 잘림 현상 수정] link_invite_screen.dart 전수조사.
//
// 발견한 실제 버그:
// `LinkInviteScreen`은 초대장 카드(`Positioned(top:230,...)`, 소원 텍스트
// 길이에 따라 내부 높이 가변)와 "🕯 소원방에 들어가기" 입장 버튼
// (`Positioned(bottom:44,...)`)을 모두 390×844 디자인 기준 "고정 픽셀 좌표"로
// 배치하고 있었는데, 소원방 패키지의 다른 모든 화면(`_WelcomeScreen`,
// `MainRoomScreen`, `WallpaperScreen` 등)과 달리 공용 `WrCanvasScaler`로
// 감싸지 않은 유일한 화면이었다.
//
// `Stack`+`Positioned` 레이아웃은 두 자식이 화면 상에서 겹치더라도
// `RenderFlex overflowed`류 예외를 던지지 않고 "조용히" 겹친 채로 레이아웃에
// 성공한다. 그래서 `tester.takeException()`만으로는 이 버그를 잡을 수 없었고,
// `tester.getRect()`로 카드 텍스트와 버튼의 실제 렌더링 Rect를 직접 측정해
// `cardRect.bottom > btnRect.top` 여부로 겹침을 판정해야 했다.
//
// 수정 전 실측 결과 (디자인 기준 390×844 대비 화면비가 짧은 기기들):
//   390x844 @1.0  → overlap=false (디자인 기준 그 자체라 문제 없음)
//   360x640 @1.3  → overlap=true  (카드 하단이 버튼 상단보다 아래로 내려감)
//   320x568 @1.5  → overlap=true
//   320x480 @1.0  → overlap=true (텍스트 확대 없이도 겹침 — 화면비 자체의 문제)
//
// 원인: 공용 레이아웃 구조(WrCanvasScaler)를 거치지 않아 디자인 좌표가 그대로
// 뷰포트에 노출됨 → 지침 ③ "공통 화면 구조/배치 규칙부터 점검/수정" 대상.
//
// 수정 내용: `Scaffold(body: Stack(...))` → `Scaffold(body:
// WrCanvasScaler(child: Stack(...)))`로 감싸 다른 화면들과 동일하게
// `min(width/390, height/844)` 비율로 축소 배치되도록 함. 디자인·좌표·애니메이션
// (WrPetalRain 등)은 전혀 변경하지 않았고, "화면에 맞추는 비율 계산"이라는
// 공통 규칙만 적용했다.
//
// 수정 후 재검증 결과: 동일 4개 조건 모두 overlap=false로 확인.
//
// 추가로 `_err != null` 에러 상태 분기(로그인 만료/존재하지 않는 방 등)도
// WrCanvasScaler 내부로 함께 이동했으므로, 해당 분기도 예외 없이 안전하게
// 렌더링되는지 별도 조건에서 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/link/link_invite_screen.dart';

/// 정상적으로 방 정보를 반환하는 가짜 레포지토리.
class _FakeWrRepositoryOk implements WrRepository {
  @override
  Future<WishRoom> roomByToken(String token) async => WishRoom.fromJson(_roomJson());
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// 토큰이 무효/만료된 상황을 재현하는 가짜 레포지토리 (_err 분기 테스트용).
class _FakeWrRepositoryError implements WrRepository {
  @override
  Future<WishRoom> roomByToken(String token) async =>
      throw ApiError(404, 'LINK_INVALID', '존재하지 않거나 만료된 초대 링크예요. 아주 길게 길게 길게 메시지를 늘려서 줄바꿈이 여러 번 일어나도록 만들어 봅니다 끝도없이');
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Map<String, dynamic> _roomJson() => {
  'id': 'wr_1', 'ownerId': 'u', 'owner': '아주긴닉네임을가진사용자닉네임',
  'text': '건강하고 행복하게 오래오래오래오래오래 살고 싶어요 정말정말정말 아주 길게 길게 길게 써봅니다 끝도없이',
  'char': 'F00', 'theme': 'free', 'outfitNow': 'free', 'visibility': 'PUBLIC',
  'devotionCount': 3, 'supportCount': 1, 'pouchReceived': 10,
  'level': 12, 'points': 40.0, 'levelName': '피어나는 소망', 'curLevelPts': 0, 'nextLevelPts': 100,
  'brightness': 1.0, 'isMine': false,
  'devotionsToday': 2, 'devotionsRemaining': 8, 'dailyLimit': 10, 'cooldownSec': 30, 'daysLit': 999,
  'wishColor': 'red', 'paper': 'hanji',
};

Future<void> _pump(WidgetTester tester, WrRepository repo, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async { await WrCatalog.load(); });

  final provider = WishRoomProvider(repo)
    ..catalogLoaded = true
    ..characters = WrCatalog.I.characters
    ..items = WrCatalog.I.items;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: ChangeNotifierProvider<WishRoomProvider>.value(
        value: provider,
        child: const MaterialApp(home: LinkInviteScreen(token: 't')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 480), 1.0),
  ];

  group('LinkInviteScreen 정상 초대장 — 카드/버튼 겹침 없음 (WrCanvasScaler 수정 확인)', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, _FakeWrRepositoryOk(), size, textScale);
        expect(tester.takeException(), isNull);

        final cardRect = tester.getRect(find.text(
          '"건강하고 행복하게 오래오래오래오래오래 살고 싶어요 정말정말정말 아주 길게 길게 길게 써봅니다 끝도없이"',
        ));
        final btnRect = tester.getRect(find.text('🕯 소원방에 들어가기'));

        // 핵심 회귀 방지 포인트: 카드 텍스트 하단이 버튼 상단보다 아래로
        // 내려가면(= 겹치면) 버튼이 가려지거나 탭하기 어려워진다.
        expect(
          cardRect.bottom <= btnRect.top,
          isTrue,
          reason: '초대장 카드(bottom=${cardRect.bottom})가 입장 버튼(top=${btnRect.top})을 '
              '덮으면 안 됨 — WrCanvasScaler 미적용 시 재발하는 회귀 버그',
        );
      });
    }
  });

  group('LinkInviteScreen 에러 상태(_err) — 예외 없이 안전하게 렌더링', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        await _pump(tester, _FakeWrRepositoryError(), size, textScale);
        expect(tester.takeException(), isNull);

        // 에러 메시지와 "돌아가기" 버튼이 모두 화면에 그려지는지 확인.
        expect(find.textContaining('존재하지 않거나 만료된 초대 링크'), findsOneWidget);
        expect(find.text('돌아가기'), findsOneWidget);
      });
    }
  });
}
