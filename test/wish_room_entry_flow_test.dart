import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/luckpouch/application/luck_pouch_provider.dart';
import 'package:flutter_app/features/wallet/application/wallet_provider.dart';
import 'package:flutter_app/features/wallet/data/wallet_repository.dart';
import 'package:flutter_app/features/wish_room/data/local/wish_room_local_store.dart';
import 'package:flutter_app/features/wish_room/data/mock/mock_wish_room_repository.dart';
import 'package:flutter_app/features/wish_room/presentation/screens/wish_room_riverpod_entry.dart';
import 'package:flutter_app/features/wish_room/presentation/widgets/wish_guide_dialog.dart';

/// [소원방 공식 화면 회귀 테스트] 실제 라우팅 진입점(WishRoomRiverpodEntry)을
/// 통해 "인트로 화면 → 메인 화면 자동 전환"까지 끝까지 진행해본다.
///
/// [수정한 버그] 기존에는 ProviderScope가 WishRoomEntryScreen 하나만 감싸고
/// 있어서, 인트로 화면의 Navigator.of(context).pushReplacement(...)가 앱의
/// 루트 Navigator를 찾아 실행됐다. 그 결과 전환된 WishRoomScreen이
/// ProviderScope 밖으로 나가 Riverpod provider를 찾지 못해 렌더링에
/// 실패했고, 릴리즈 모드에서는 회색 빈 화면으로만 보였다. 이 테스트는
/// WishRoomRiverpodEntry 내부에 추가한 중첩 Navigator가 전환을
/// ProviderScope 서브트리 안에 계속 유지시켜 메인 화면이 정상적으로
/// 렌더링되는지 확인한다.
///
/// [대형 작업 — Shell 재편] 인트로 화면의 전환 목적지가 `WishRoomScreen`
/// 단독에서 `WishRoomShell`(하단 탭: 나의 소원/모두의 소원/신전관리)로
/// 바뀌었다. 탭 0번(나의 소원)이 기존 WishRoomScreen을 그대로 담고 있고,
/// 그 화면도 디자인 핸드오프 `ScreenHome` 스펙으로 재구현되어 문구가
/// "소원방"/"마음이 향하는 곳에..."에서 "나의 소원방"/"오늘도 밝게
/// 켜있어요"로 바뀌었으므로, 최종 검증 문구도 이에 맞춰 갱신했다.
void main() {
  // MockWishRoomRepository가 초회 가이드 노출 여부를 shared_preferences로
  // 영속화하므로, 테스트 환경에서도 mock 저장소를 초기화해야 한다.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // [Sprint 3] MockWishRoomRepository가 Hive에 실제로 저장/로드하므로,
    // 이전 테스트가 남긴 디스크 상태가 섞이지 않도록 매번 box를 비운다.
    await WishRoomLocalStore.resetForTest();
  });

  testWidgets(
    'WishRoomRiverpodEntry: intro screen auto-transitions into main screen '
    'and stays inside ProviderScope (no blank screen)',
    (tester) async {
      // [Sprint 3, 핵심] Dart async 함수는 "함수가 시작된 시점의 zone"을
      // 캡처해 이후의 모든 await/타이머 continuation을 그 zone에서
      // 재개한다. pumpWidget()을 FakeAsync zone(테스트 기본 zone)에서
      // 호출하면, WishRoomEntryScreen.initState()가 등록하는
      // `Future.delayed(1400ms, _enterMainScreen)` 타이머도 그 zone에
      // 캡처된다.
      //
      // [추가로 발견한 함정] `tester.runAsync()`가 실행하는 콜백의 특수
      // zone은 그 콜백의 Future가 완료되는 즉시 정리(teardown)된다. 즉
      // pumpWidget()만 담고 바로 끝나는 "짧은" runAsync 호출을 쓰면, 그
      // 안에서 등록된 1400ms 타이머는 아직 fire되지 않은 채로 zone이
      // 닫혀버려 이후 다시는 fire되지 않는다(별도의 두 번째 runAsync
      // 호출로 이어서 기다려도 이미 죽은 타이머는 살아나지 않음 — 최초
      // 시도에서 겪은 실패 원인). 따라서 pumpWidget 호출부터 인트로→메인
      // 전환 대기, `fetchInitialData()`(Hive I/O 포함)까지 이어지는 전체
      // 체인을 반드시 "하나의" runAsync 콜백 안에서 처음부터 끝까지
      // 실행해야 한다(스모크 테스트의 `pumpAndDismissGuide`와 동일한
      // 패턴).
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => WalletProvider(WalletRepository()),
              ),
              ChangeNotifierProxyProvider<WalletProvider, LuckPouchProvider>(
                create: (context) => LuckPouchProvider(context.read<WalletProvider>()),
                update: (_, wallet, previous) {
                  previous!.updateWallet(wallet);
                  return previous;
                },
              ),
            ],
            // [버그 수정] WishRoomRiverpodEntry의 기본값은 실 서버 연동
            // HttpWishRoomRepository이다. `flutter_test`의
            // TestWidgetsFlutterBinding은 모든 HTTP 요청에 강제로
            // statusCode 400을 반환하므로, override 없이는
            // fetchInitialData()가 항상 실패해 WishGuideDialog가 절대
            // 뜨지 않는다(findsOneWidget 기대가 항상 실패). 위젯에 추가한
            // `@visibleForTesting` 주입 지점을 통해 Mock 저장소를 사용한다.
            child: MaterialApp(
              home: WishRoomRiverpodEntry(
                debugRepositoryOverride: MockWishRoomRepository(),
              ),
            ),
          ),
        );
        await tester.pump();

        // 인트로 화면 렌더링 확인 (같은 runAsync 콜백 내부에서 확인 —
        // 여기서 zone을 빠져나가면 안 된다).
        // [대형 작업 — 디자인 핸드오프 Onboarding 재구현] 문구가
        // "당신의 소원이 머무는 방"에서 `ScreenOnboarding` 스펙의
        // "소원을 담을\n준비가 되셨나요"로 바뀌었다.
        expect(find.text('소원을 담을\n준비가 되셨나요'), findsOneWidget);

        // 인트로 화면의 1400ms 자동 전환 타이머가 fire된 뒤
        // `_enterMainScreen()` → `WishRoomScreen` 빌드 →
        // `fetchInitialData()`(400ms 지연 + Hive 파일 I/O)까지 이어지는
        // 체인이 끝날 만큼 여유 있게 진짜 시간을 흘려보낸다. `tester.pump()`
        // (인자 없음)는 위젯 트리를 딱 한 프레임만 다시 그릴 뿐 애니메이션
        // 시계는 전혀 전진시키지 않는다 — 그래서 `PageRouteBuilder`의
        // 500ms `pushReplacement` 전환 애니메이션은 `pump(duration)`으로
        // 명시적으로 시간을 넘겨줘야만 끝까지 진행되어 구 라우트(인트로
        // 화면)가 트리에서 실제로 제거된다(디버그 로그로 확인한 실패
        // 원인 — 인자 없는 pump만 반복해서는 전환 애니메이션이 0%에
        // 머물러 인트로 화면이 계속 남아있었다).
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        await tester.pump();
        // 여기서부터는 `pushReplacement`가 이미 호출된 뒤이므로, 전환
        // 애니메이션(500ms)이 실제로 진행되도록 duration을 넘겨 pump한다.
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 100));
        // WishRoomScreen 빌드 후 `fetchInitialData()`(mock 400ms 지연 +
        // Hive 파일 I/O)가 끝날 만큼 여유 있게 진짜 시간을 흘려보낸다.
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await tester.pump();

        // [버그 수정] fetchInitialData()가 끝나면 ref.listen이 곧바로
        // WishGuideDialog를 push하는데, 그 다이얼로그는 build() 시점에
        // guideSlidesProvider(FutureProvider, mock 200ms 실제 지연)를 watch
        // 하기 시작한다. 이 대기가 없으면 다이얼로그가 loading 상태
        // (CircularProgressIndicator)에 머물러 '건너뛰기' 버튼을 찾지
        // 못해 이후 tap()이 실패한다(스모크 테스트와 동일한 원인).
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        // 배경/오브제 애니메이션이 repeat()로 무한 반복되므로 pumpAndSettle
        // 대신 고정 시간만큼 pump한다.
        await tester.pump(const Duration(milliseconds: 400));
      });

      // 인트로 화면은 사라지고, 메인 화면(소원방 헤더 텍스트)이 보여야
      // 회색 빈 화면 버그가 없다는 것을 의미한다.
      expect(find.text('소원을 담을\n준비가 되셨나요'), findsNothing);

      // 초회 가이드 팝업이 자동으로 뜬다 — Riverpod controller가 정상
      // 동작 중이라는 증거(ProviderScope 밖이었다면 여기서 예외가 났을
      // 것이다).
      expect(find.byType(WishGuideDialog), findsOneWidget);
      // [버그 수정] '시작하기' 버튼은 마지막 슬라이드에서만 노출된다
      // (wish_guide_dialog.dart `_isLast ? '시작하기' : '다음'`). mock은
      // 5개 슬라이드를 반환하고 PageView는 index=0에서 시작하므로 이
      // 시점에는 '다음'만 렌더링되어 있다. 이 테스트는 가이드 내용이
      // 아니라 진입 플로우 자체를 검증하는 것이 목적이므로, 슬라이드
      // 인덱스와 무관하게 항상 존재하는 '건너뛰기' 버튼(onSkip: _close)을
      // 탭한다.
      await tester.tap(find.text('건너뛰기'));
      // markGuideSeen()의 SharedPreferences I/O 완료까지 진짜 시간을
      // 흘려보낸다(다른 스모크 테스트와 동일한 이유).
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      });

      // 메인 화면 핵심 요소가 실제로 렌더링되는지 확인 — 이게 통과하면
      // "인트로만 뜨고 다음은 빈 화면" 버그가 재발하지 않은 것이다.
      // [대형 작업 — Shell 재편] WishRoomShell의 탭 0번(WishRoomScreen,
      // ScreenHome 스펙 재구현)이 기본으로 표시된다.
      expect(find.text('나의 소원방'), findsOneWidget);
      expect(find.text('오늘도 밝게 켜있어요'), findsOneWidget);
      expect(find.text('건강하게 한 해를 보내게 해주세요'), findsOneWidget);
    },
  );
}
