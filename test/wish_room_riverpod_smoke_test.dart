import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/wish_room/data/local/wish_room_local_store.dart';
import 'package:flutter_app/features/wish_room/presentation/screens/wish_room_screen.dart';
import 'package:flutter_app/features/wish_room/presentation/widgets/wish_guide_dialog.dart';

/// [소원방 신규 시스템 회귀 테스트] 슬롯/성장/치성타입/꾸미기 시스템 도입
/// 이후의 API(prayForWish + PrayerTypeSheet)에 맞춰 갱신된 스모크 테스트.
///
/// mock 데이터(buildMockWishRoom)는 대표 소원이 이미 등록된 상태로
/// 시작하므로(정책: 첫 진입에도 데모용 대표 소원 1개 존재), 빈 상태 CTA인
/// "소원 빌기"는 노출되지 않는다 — 대신 치성 CTA 버튼(오늘의 정성 올리기)이
/// 바로 노출된다.
void main() {
  // MockWishRoomRepository가 초회 가이드 노출 여부를 shared_preferences로
  // 영속화하므로, 테스트 환경에서도 mock 저장소를 초기화해야 한다.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // [Sprint 3] MockWishRoomRepository가 Hive에 실제로 저장/로드하므로,
    // 이전 테스트가 남긴 디스크 상태가 섞이지 않도록 매번 box를 비운다.
    await WishRoomLocalStore.resetForTest();
  });

  Future<void> pumpAndDismissGuide(WidgetTester tester) async {
    // [Sprint 3] fetchInitialData()가 WishRoomLocalStore(Hive)의 실제 파일
    // I/O(dart:io)를 거치게 되면서, 이 위젯의 초기 데이터 로딩 Future는
    // "가짜 타이머(Future.delayed 400ms)"와 "진짜 OS I/O(Hive box
    // open/read)"가 섞인 체인이 됐다. testWidgets 본문은 기본적으로
    // FakeAsync zone 안에서 실행되는데, 그 zone은 real dart:io 이벤트
    // 루프 콜백을 절대 진행시켜주지 못한다 — 즉 pumpWidget을 fake zone에서
    // 호출하면 그 안에서 시작된 Hive 관련 Future는 무한히 pending 상태로
    // 남는다(몇 번을 pump해도 완료되지 않음).
    //
    // 해결책: pumpWidget과 그 뒤에 이어지는 초기 로딩 대기까지 전부를
    // tester.runAsync()의 콜백 "안에서" 실행한다. runAsync는 콜백을 진짜
    // (root) zone에서 실행하므로, 그 안에서 트리거되는 Hive I/O도 실제
    // 이벤트 루프를 타고 정상적으로 완료된다. runAsync 내부에서는
    // pump(duration) 대신 진짜 delay(Future.delayed) + 인자 없는
    // tester.pump()(프레임 1회 플러시)를 번갈아 사용한다.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: WishRoomScreen()),
        ),
      );
      await tester.pump();

      // mock repository의 fetchInitialData() 지연(400ms) + Hive 파일 I/O가
      // 모두 끝날 만큼 여유 있게 진짜 시간을 흘려보낸다.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await tester.pump();

      // 배경/오브제 애니메이션이 repeat()로 무한 반복되므로(정상 동작)
      // pumpAndSettle 대신 고정 시간만큼만 몇 프레임 더 플러시한다.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    });

    // 초회 가이드 팝업이 자동으로 뜨므로 먼저 닫는다.
    expect(find.byType(WishGuideDialog), findsOneWidget);
    await tester.tap(find.text('시작하기'));
    // [Sprint 3] 다이얼로그를 닫으면 `.then((_) => markGuideSeen())` 콜백이
    // 실행되는데, markGuideSeen()도 SharedPreferences 비동기 I/O를 거친다.
    // 이 콜백이 테스트 트리 dispose 이후에 완료되면 "Cannot use ref after
    // the widget was disposed" 예외가 새어나가므로, 여기서도 runAsync로
    // 감싸 완전히 끝날 때까지 기다린다.
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });
  }

  testWidgets('WishRoomScreen renders main content with mock data', (tester) async {
    await pumpAndDismissGuide(tester);

    // 메인 화면 핵심 요소 렌더링 확인
    expect(find.text('소원방'), findsOneWidget);
    expect(find.text('마음이 향하는 곳에, 빛이 머뭅니다.'), findsOneWidget);
    expect(find.text('건강하게 한 해를 보내게 해주세요'), findsOneWidget);

    // CTA 버튼 영역은 스크롤해야 보이는 위치이므로 스크롤 후 확인한다.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));

    // mock 대표 소원은 아직 오늘 기도하지 않은 상태(lastPrayedDate=어제)로
    // 시작하므로 "오늘의 정성 올리기" CTA가 노출된다.
    expect(find.text('오늘의 정성 올리기'), findsOneWidget);
    expect(find.text('내 소원 보기'), findsOneWidget);
    expect(find.text('방 꾸미기'), findsOneWidget);
  });

  testWidgets('Praying via daily prayer type shows prayer complete sheet', (tester) async {
    await pumpAndDismissGuide(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));

    // [Sprint 3, 중요] Dart의 async 함수는 "함수가 시작된 시점의 zone"을
    // 캡처해 이후의 모든 await continuation을 그 zone에서 재개한다. 즉
    // "오늘의 정성 올리기" CTA를 탭해 시작되는 _onPray() 콜백이 FakeAsync
    // zone(테스트 기본 zone)에서 시작되면, 그 안에서 몇 겹 뒤에 실행되는
    // controller.prayForWish() → Hive 파일 I/O도 여전히 FakeAsync zone에서
    // 재개되어 절대 끝나지 않는다(뒤에서 tester.runAsync로 아무리 감싸도
    // 이미 시작된 continuation의 zone은 바뀌지 않는다). 따라서 이 CTA
    // 탭부터 "오늘의 치성" 선택, 그 결과로 열리는 완료 시트까지 이어지는
    // 전체 흐름을 하나의 runAsync 콜백 "안에서" 시작해야 한다.
    await tester.runAsync(() async {
      // 메인 CTA 탭 → [치성 시스템] 치성 종류 선택 바텀시트(PrayerTypeSheet) 노출.
      await tester.tap(find.text('오늘의 정성 올리기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // "오늘의 치성"(무료) 옵션 선택 → Navigator.pop(type)으로
      // PrayerTypeSheet가 닫힌다. 이 pop은 즉시 일어나는 게 아니라 바텀시트
      // 닫힘 트랜지션 애니메이션(기본 ~250ms)이 끝나야 완료되고, 그래야
      // `PrayerTypeSheet.show()`가 반환하는 Future가 resolve된다 —
      // `_startPrayerFlow`는 그 Future를 await하고 있으므로, 애니메이션이
      // 끝나지 않으면 controller.prayForWish() 호출 자체가 시작되지 않는다
      // (즉 500ms 지연도, 그 안의 Hive I/O도 아직 시작 전이었다 — 이전 실패의
      // 진짜 원인).
      expect(find.text('오늘의 치성'), findsOneWidget);
      await tester.tap(find.text('오늘의 치성'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 이제서야 prayForWish()가 실제로 시작된다: mock repository의 500ms
      // 지연 + 이어지는 Hive 파일 I/O(실제 디스크 쓰기) + fetchInitialData()의
      // 400ms 지연까지 모두 끝날 만큼 여유 있게 진짜 시간을 흘려보낸다.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await tester.pump();
      // 성공 후 열리는 PrayerCompleteSheet의 등장 애니메이션까지 마친다.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    expect(find.text('당신의 소원이 방 안에 고이 담겼어요'), findsOneWidget);
    expect(find.text('내일도 밝히러 올게요'), findsOneWidget);
  });
}
