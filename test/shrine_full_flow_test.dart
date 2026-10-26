// shrine_full_flow_test.dart — 신당(THE SHRINE) 전체 흐름 실제 실행 검증:
// 이야기 시작 → 선택지 진행 → 의식(쓰기/서명/태우기) → 부적 생성 → 부적 수령.
//
// [배경] 과거 검증은 "코드/에셋이 APK 안에 들어 있다"는 정적 확인에
// 머물러 있었다(2026-10-26 지적 사항). 이 테스트는 실제로 각 화면을
// pumpWidget 하고, 사용자 조작(탭)을 시뮬레이션해 ShrineSessionProvider의
// 상태가 기대한 대로 전이되는지 — 즉 화면이 실제로 렌더링되고 다음
// 단계로 실제로 진행되는지를 런타임에서 검증한다.
//
// [범위] 메인 스토리(StoryScreen, shrine.json `story`)가 아니라 추가
// 이야기(TaleScreen, `tales.room`)를 사용한다 — 이유:
//  1) TaleScreen은 이번 검증 대상인 9426e2c 수정(_han 안전 fallback)이
//     실제로 적용된 코드 경로이므로, 여기를 구동하는 것 자체가 그
//     수정이 런타임에서 정상 동작함을 보여준다.
//  2) story/tale 둘 다 동일한 StoryPos/judge()/meaningSrc 엔진을
//     공유하므로(설계 문서 "메인 StoryScreen과 같은 엔진" 주석) 하나를
//     검증하면 다른 하나의 핵심 로직(선택 → flags → judge → meaningSrc)도
//     동일하게 검증된 것으로 간주할 수 있다.
//
// [네트워크 경계] MeaningScreen._go()/ReceiveScreen._keep()은
// ShrineServerRepository(admin_web 서버 HTTP 호출)를 통해 발급 가능
// 여부를 검증한다. 실 네트워크 호출은 단위/위젯 테스트 범위 밖이므로
// _FakeShrineServerRepository로 성공 응답을 흉내 낸다 — 이는 "서버가
// 허가했다"는 전제 하에 클라이언트 쪽 상태 전이(ritual 진입, receive
// 진입, box 추가)가 올바른지만을 검증하는 것이며, 실제 서버 연동
// 자체를 검증하는 것은 아니다(별도 ShrineServerRepository 단위
// 테스트/실 서버 통합 테스트의 몫 — 이 테스트가 대체하지 않는다).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/shrine/data/models.dart';
import 'package:flutter_app/features/shrine/engine/shrine_engine.dart';
import 'package:flutter_app/features/shrine/engine/shrine_server_repository.dart';
import 'package:flutter_app/features/shrine/screens/screens.dart'
    show RitualScreen;
import 'package:flutter_app/features/shrine/screens/screens_v3.dart';
import 'package:flutter_app/features/shrine/shrine_module.dart' show shrine;
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/widgets/bujeok.dart'
    show BujeokLayout;
import 'package:flutter_app/features/shrine/widgets/common.dart';
import 'package:flutter_app/features/shrine/widgets/shrine_fx.dart'
    show SignStroke;

/// 실 서버(admin_web) 호출을 흉내 내는 가짜 Repository. 항상 "발급
/// 가능"/"발급 기록 성공"을 돌려준다 — 서버 재검증 로직 자체는 이
/// 테스트의 관심사가 아니다(그건 ShrineServerRepository 쪽 책임).
class _FakeShrineServerRepository implements ShrineServerRepository {
  int canIssueCalls = 0;
  int recordIssueCalls = 0;

  @override
  Future<ApiResult<ShrineCanIssueResult>> canIssue({
    required String? sajuFp,
    required String storyId,
  }) async {
    canIssueCalls++;
    return ApiResult.ok(const ShrineCanIssueResult(ok: true));
  }

  @override
  Future<ApiResult<String>> recordIssue({
    required String sajuFp,
    required String storyId,
    required String composeKey,
  }) async {
    recordIssueCalls++;
    return ApiResult.ok('TEST-SERIAL-0001');
  }

  @override
  Future<ApiResult<String>> sign(String payload) async =>
      ApiResult.ok('fake-sig');

  @override
  Future<ApiResult<bool>> verifyShare({
    required String payload,
    required String sig,
  }) async => ApiResult.ok(true);
}

Future<SharedPreferences> _freshPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // shrine.json 로드 + BujeokLayout 초기화 — shrine_module.dart의
  // ShrineModule.init()과 동일한 선행 조건(부적 렌더링 위젯들이
  // BujeokLayout.L을 참조하므로 반드시 필요).
  setUpAll(() async {
    shrine = await Shrine.load();
    // bujeokLayout은 Shrine 모델에 포함되지 않으므로(순환참조 방지 설계)
    // shrine_module.dart의 ShrineModule.init()과 동일하게 원본 JSON을
    // 한 번 더 읽어 BujeokLayout을 초기화한다 — BujeokSheet 등 부적
    // 렌더링 위젯이 BujeokLayout.L을 참조하므로 반드시 필요하다.
    final raw =
        jsonDecode(
              await rootBundle.loadString('assets/shrine/data/shrine.json'),
            )
            as Map;
    BujeokLayout.init(raw['bujeokLayout']);
    expect(shrine.tales.isNotEmpty, true);
  });

  Widget harness({
    required ShrineSessionProvider provider,
    required _FakeShrineServerRepository repo,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ShrineSessionProvider>.value(value: provider),
        Provider<ShrineServerRepository>.value(value: repo),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('신당 전체 흐름 실제 실행 검증 (이야기→선택→의식→서명→부적생성→수령)', () {
    testWidgets('1단계 이야기 시작 + 선택지 진행: TaleScreen이 렌더링되고 선택 탭이 '
        '다음 노드로 실제로 진행된다 (9426e2c _han() 안전 fallback 적용 경로)', (
      tester,
    ) async {
      final prefs = await _freshPrefs();
      final provider = ShrineSessionProvider(prefs);
      provider.update(
        (s) => s.copy(name: '테스터', topic: 'love', reduce: true, timer: false),
      );
      final repo = _FakeShrineServerRepository();

      await tester.pumpWidget(
        harness(
          provider: provider,
          repo: repo,
          child: const TaleScreen(id: 'room'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // r1 노드 첫 줄이 타이핑 중 — reduce:true라 msPerChar=0, 즉시 완료 콜백.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(TaleScreen), findsOneWidget);
      expect(find.byType(Typewriter), findsOneWidget);

      // 타이핑 완료까지 대사 3줄을 모두 넘긴다(각 탭 = _next()).
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(Typewriter));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // r1 노드는 선택지 2개("복도를 따라 걸어간다" / "할머니 영정에 먼저
      // 절한다") — 실제로 화면에 렌더링되어 있어야 한다.
      expect(find.text('복도를 따라 걸어간다'), findsOneWidget);
      expect(find.text('할머니 영정에 먼저 절한다'), findsOneWidget);

      // 선택지를 탭 → reduce:true라 150ms 후 다음 노드(r2)로 전환된다.
      await tester.tap(find.text('복도를 따라 걸어간다'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 50));

      // [핵심 검증] 선택 진행 후 ShrineSessionProvider.talePos['room']이
      // 실제로 r2로 갱신되었는지 — "화면이 넘어간 것처럼 보이는 것"이
      // 아니라 상태 전이가 실제로 일어났는지를 직접 확인한다.
      expect(provider.state.talePos['room']?.node, 'r2');

      // [테스트 위생] r1 노드는 chapter('壹 · 할머니의 집')가 있어
      // _enter()가 initState에서 600ms(reduce:true) 뒤 챕터 타이틀을
      // 지우는 Future.delayed 타이머를 예약한다. 지금까지 pump한 총
      // 시간(≈550ms)은 아직 600ms에 못 미쳐 타이머가 남아 있으므로,
      // 위젯 트리가 폐기되기 전에 추가로 pump해 반드시 타이머가 실행되게
      // 한다 — 그렇지 않으면 flutter_test가 "Timer가 아직 pending"이라며
      // 테스트 자체를 실패시킨다(앱 버그가 아니라 테스트 쪽 타이밍 문제).
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('1~2단계 전체 선택 진행 → 결말 판정(judge) → meaningSrc 설정까지 '
        '실제로 도달한다 (room: r1→r2→r3→rc→ending A)', (tester) async {
      final prefs = await _freshPrefs();
      final provider = ShrineSessionProvider(prefs);
      provider.update(
        (s) => s.copy(name: '테스터', topic: 'love', reduce: true, timer: false),
      );
      final repo = _FakeShrineServerRepository();

      await tester.pumpWidget(
        harness(
          provider: provider,
          repo: repo,
          child: const TaleScreen(id: 'room'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      Future<void> advanceThroughLines() async {
        for (var i = 0; i < 4; i++) {
          final tw = find.byType(Typewriter);
          if (tw.evaluate().isEmpty) break;
          await tester.tap(tw);
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      // r1 → "문을 연다"(open) 선택과 동형인 첫 선택지를 타고 r2로.
      await advanceThroughLines();
      await tester.tap(find.text('복도를 따라 걸어간다')); // flag: walk
      await tester.pump(const Duration(milliseconds: 250));

      // r2 → "문을 연다"(open) 선택 → r3.
      await advanceThroughLines();
      expect(provider.state.talePos['room']?.node, 'r2');
      await tester.tap(find.text('문을 연다')); // flag: open
      await tester.pump(const Duration(milliseconds: 250));

      // r3 → "반닫이를 연다"(chest) 선택 → rc(클라이맥스 노드, timer=8).
      await advanceThroughLines();
      expect(provider.state.talePos['room']?.node, 'r3');
      await tester.tap(find.text('반닫이를 연다')); // flag: chest
      await tester.pump(const Duration(milliseconds: 250));

      // rc(클라이맥스) → "반닫이 속 부적을 꺼내 든다"(talis) 선택.
      // route: {'all':['talis'], 'ending':'A'} 가 최우선 매치되므로
      // flags={walk, open, chest, talis} → ending 'A' 로 판정되어야 한다.
      await advanceThroughLines();
      expect(provider.state.talePos['room']?.node, 'rc');
      await tester.tap(find.text('반닫이 속 부적을 꺼내 든다')); // flag: talis
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 50));

      // [핵심 검증 — 선택 기록 → 결말 판정] _TaleState._choose()가
      // S.judge(flags)를 실제로 호출해 meaningSrc를 세팅했는지 확인.
      // (Shrine.judge와 동일한 RouteRule.match 로직 — tale.judge도 동일 엔진.)
      final tale = shrine.tales['room']!;
      final expectedEnding = tale.judge({'walk', 'open', 'chest', 'talis'});
      expect(expectedEnding, 'A');
      expect(provider.state.meaningSrc, isNotNull);
      expect(provider.state.meaningSrc!.story, 'room');
      expect(provider.state.meaningSrc!.ending, expectedEnding);
      // talePos['room']은 종료 시 null로 리셋된다(_TaleState._choose 참고).
      expect(provider.state.talePos['room'], isNull);
      // taleEndings에 결말 1회 기록이 실제로 누적되었는지.
      expect(provider.state.taleEndings['room']?.containsKey('A'), true);

      // 화면이 실제로 TaleEndScreen으로 전환(ShrineNav.go) 요청되었는지는
      // 이 테스트에서 Navigator 스택을 쓰지 않았으므로(ShrineNav는
      // Navigator.push를 호출하지만 harness가 ShrineNav 라우트 스택 밖에서
      // 단독 pump 하고 있음) 직접 확인하지 않는다 — 대신 "다음 화면
      // 진입에 필요한 상태(meaningSrc)가 실제로 만들어졌는가"를
      // 검증함으로써 책임을 분리한다. 화면 전환 자체(ShrineNav.go 호출)는
      // shrine_app_shell_entry_point_test.dart가 이미 shrineScreenFor()
      // 라우팅 테이블을 별도로 검증하고 있다.
    });

    testWidgets('3~4단계 의식(ritual): RitualScreen이 렌더링되고, 쓰기→종이→서명 '
        '손으로 긋기(SignStroke)가 실제로 ink=1까지 진행된다 '
        '(cb15e49가 고친 LayoutBuilder/ParentData 스택오버플로우 회귀 없음)', (
      tester,
    ) async {
      final prefs = await _freshPrefs();
      final provider = ShrineSessionProvider(prefs);
      final spec = shrine.talismans.compose(
        type: 'guard',
        flavor: 'observe',
        story: 'room',
        ending: 'A',
      );
      provider.update(
        (s) => s.copy(
          name: '테스터',
          topic: 'love',
          reduce: false,
          timer: false,
          pending: Pending(
            spec,
            const StorySource('room', 'A', {'talis'}, []),
            'observe',
            '/shrine/list',
          ),
        ),
      );
      final repo = _FakeShrineServerRepository();

      await tester.pumpWidget(
        harness(
          provider: provider,
          repo: repo,
          child: const RitualScreen(),
        ),
      );
      // Ph.write: ShrineVideo(name:'write') — 테스트 환경에 video_player
      // 플러그인이 없어 초기화가 실패하고 poster 이미지로 자동 폴백한다
      // (shrine_video.dart _ShrineVideoState._init() catch 분기). 이후
      // onEnd 콜백이 실패 경로에서 800ms 뒤 호출되어 Ph.paper로 전이된다.
      expect(find.byType(RitualScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 600)); // Ph.paper 진입 + 500ms 지연 후 ink.animateTo 시작

      // 이름 "테스터"(3자) → steps는 bjCompose 결과에 따라 달라지지만
      // nameAt = (steps-1.5)/steps 로 항상 1 미만 → signing 단계 진입.
      // ink.animateTo(nameAt) 애니메이션 길이는 Dur.brushPerChar(900ms) *
      // (name.length+3) = 900*6 = 5400ms 이므로 충분히 대기한다.
      await tester.pump(const Duration(seconds: 6));

      // [핵심 검증 1] "손수 그으십시오" 서명 유도 문구가 실제로 보이는지
      // — RitualScreen._RitualState.signing=true 로 전이되었다는 뜻이며,
      // 이는 cb15e49가 고친 Positioned/Stack 트리가 매 프레임
      // "Incorrect use of ParentDataWidget" 예외 없이 정상 렌더링됨을
      // 전제로 한다(예외가 났다면 이 지점까지 pump가 실패로 끝났을 것).
      expect(find.textContaining('손수 그으십시오'), findsOneWidget);
      expect(find.byType(SignStroke), findsOneWidget);

      // [핵심 검증 2] SignStroke 영역에 실제 포인터 드래그를 흉내 내어
      // 서명을 끝까지 긋는다 — onDone 콜백이 ink.value=1로 만들어야 한다.
      final signArea = find.byType(SignStroke);
      final box = tester.getRect(signArea);
      final gesture = await tester.startGesture(
        Offset(box.center.dx, box.top + 2),
      );
      await gesture.moveTo(Offset(box.center.dx, box.bottom - 2));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      // _finish()의 700ms 지연 onDone 콜백 대기.
      await tester.pump(const Duration(milliseconds: 800));

      // 서명 완료 → "다 되었습니다. 부적을 누르십시오." 안내로 전환.
      expect(find.textContaining('부적을 누르십시오'), findsOneWidget);
    });
  });

  group('신당 부적 수령(ReceiveScreen) 실제 실행 검증', () {
    testWidgets('5단계 부적 생성 확정 + 6단계 부적 수령: give→unroll→name→keep '
        '단계를 실제로 거쳐 box에 부적이 추가된다', (tester) async {
      final prefs = await _freshPrefs();
      final provider = ShrineSessionProvider(prefs);
      final spec = shrine.talismans.compose(
        type: 'guard',
        flavor: 'observe',
        story: 'room',
        ending: 'A',
      );
      final saju = const SajuResult(
        pillars: {'year': '甲子', 'month': '乙丑', 'day': '丙寅', 'hour': '丁卯'},
        dayStem: '丙',
        dayElement: '火',
        dayLabel: '병화(丙火)',
        elements: {'木': 2, '火': 2, '土': 1, '金': 1, '水': 2},
        source: 'SAMPLE',
      );
      provider.update(
        (s) => s.copy(
          name: '테스터',
          topic: 'love',
          reduce: true,
          saju: saju,
          pending: Pending(
            spec,
            const StorySource('room', 'A', {'talis'}, []),
            'observe',
            '/shrine/list',
          ),
        ),
      );
      final repo = _FakeShrineServerRepository();

      await tester.pumpWidget(
        harness(
          provider: provider,
          repo: repo,
          child: const ReceiveScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ReceiveScreen), findsOneWidget);

      // RPh.give: ShrineVideo(name:'give') — video_player 미설치 환경이라
      // 역시 poster로 폴백 후 onEnd가 800ms 뒤 호출되어 RPh.unroll로 전이.
      await tester.pump(const Duration(milliseconds: 900));
      // RPh.unroll: reduce:true → 300ms 후 자동으로 RPh.name으로 전이.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      // [핵심 검증 1] RPh.name 단계 — "이름을 어떻게 남기시겠습니까" UI가
      // 실제로 떠 있고, "부적 간직하기" 버튼이 눌리는지 확인한다.
      expect(find.text('名 · 이름을 어떻게 남기시겠습니까'), findsOneWidget);
      expect(find.text('부적 간직하기'), findsOneWidget);

      await tester.tap(find.text('부적 간직하기'));
      // _keep()은 비동기(_FakeShrineServerRepository.recordIssue)를
      // 거치므로 충분히 pump 한다.
      // [테스트 위생] ReceiveScreen은 배경에 Embers(AnimationController..
      // repeat())를 항상 띄우므로 pumpAndSettle()은 "모든 애니메이션이
      // 멈출 때"를 기다리다 영원히 끝나지 않아 타임아웃된다(앱 버그
      // 아님 — 의도된 무한 루프 연출). 따라서 pumpAndSettle 대신 고정
      // 시간만큼 pump해 _keep()의 await 체인(Future.microtask 포함)이
      // 모두 해소되길 기다린다.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));

      // [핵심 검증 2] 서버(Fake) record-issue가 실제로 1회 호출되었는지
      // — "버튼이 보였다"가 아니라 "실제로 발급 플로우가 실행되었는지".
      expect(repo.recordIssueCalls, 1);

      // [핵심 검증 3 — 최종 목표] ShrineSessionProvider.state.box에 부적
      // 1장이 실제로 추가되었는지(=「부적 수령」 완료의 상태적 정의).
      expect(provider.state.box.length, 1);
      expect(provider.state.box.first.key, spec.key);
      expect(provider.state.issued, 1);

      // [핵심 검증 4] 화면이 RPh.keep으로 실제 전환되어 "부적함에
      // 담았습니다" 문구가 렌더링되는지.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.textContaining('부적함에 담았습니다'), findsOneWidget);
    });

    testWidgets('이미 같은 key의 부적을 보유한 경우 재열람(dup=true)으로 처리되고 '
        '서버 record-issue가 다시 호출되지 않는다(중복 발급 방지)', (tester) async {
      final prefs = await _freshPrefs();
      final provider = ShrineSessionProvider(prefs);
      final spec = shrine.talismans.compose(
        type: 'guard',
        flavor: 'observe',
        story: 'room',
        ending: 'A',
      );
      provider.update(
        (s) => s.copy(
          name: '테스터',
          topic: 'love',
          reduce: true,
          pending: Pending(
            spec,
            const StorySource('room', 'A', {'talis'}, []),
            'observe',
            '/shrine/list',
          ),
          box: [
            BoxItem(
              key: spec.key,
              no: 'N°0001',
              date: '2026-01-01',
              spec: spec,
              source: const StorySource('room', 'A'),
            ),
          ],
          issued: 1,
        ),
      );
      final repo = _FakeShrineServerRepository();

      await tester.pumpWidget(
        harness(
          provider: provider,
          repo: repo,
          child: const ReceiveScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('부적 간직하기'));
      // [테스트 위생] 위 테스트와 동일한 이유로 pumpAndSettle 대신 고정
      // 시간 pump 사용(Embers 무한 반복 애니메이션으로 인한 타임아웃 방지).
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));

      // 이미 box에 있던 key이므로 _keep()의 already-분기로 서버 호출 없이
      // 바로 RPh.keep으로 전이되어야 한다.
      expect(repo.recordIssueCalls, 0);
      expect(provider.state.box.length, 1); // 중복 추가되지 않음
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.textContaining('이미 간직한 부적'), findsOneWidget);
    });
  });
}
