// [2026 디자인 핸드오프 — `/guinji-map/*` 신규 8화면] 렌더 스모크 테스트.
//
// [목적] "귀인지도가 잘 안 나오면 안 된다"는 명시적 경고에 대한 검증 —
// 각 화면이 실제 Provider(AuthProvider/GuinjiProvider) 트리 아래에서
// 예외 없이 위젯 트리를 빌드하는지 확인한다(런타임 크래시 방지).
// 실제 네트워크 API는 호출하지 않으므로(위젯 pump까지만 검증), API
// 응답 형식 자체의 정확성은 이 테스트의 범위가 아니다 — 여기서는 "화면이
// 크래시 없이 뜨는가"만 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/guinji/application/guinji_provider.dart';
import 'package:flutter_app/features/guinji/data/guinji_repository.dart';
import 'package:flutter_app/features/guinji/domain/guinji_person.dart';
import 'package:flutter_app/features/guinji/domain/pending_guinji_join.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_landing_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_input_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_calculating_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_map_result_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_map_share_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_map_ranking_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_guest_result_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_map_guest_join_screen.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
      ChangeNotifierProvider(
        create: (_) => GuinjiProvider(GuinjiRepository()),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

const _samplePeople = [
  GuinjiPerson(
    id: 'p1',
    name: '수아',
    birth: '2003·05·14',
    ohaeng: 'hwa',
    relation: 'CHEON_GWII',
    score: 92,
    note: '천을귀인 · 인성',
  ),
  GuinjiPerson(
    id: 'p2',
    name: '민서',
    birth: '2002·11·03',
    ohaeng: 'mok',
    relation: 'JORYEOK',
    score: 81,
    note: '비견',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('L · Landing 화면이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(_wrap(const GuinjiLandingScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('I · Input 화면이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(_wrap(const GuinjiInputScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // 폼 요소가 실제로 그려지는지 확인.
    expect(find.text('지도 만들기'), findsOneWidget);
  });

  // [버그 수정 회귀 방지 — 사주 재입력] "회원가입/로그인을 안 하고 내
  // 귀인지도 만들기를 하면 사주를 넣으려고 하고, 클릭 시 로그인/회원가입
  // 페이지로 넘어가고, 로그인이나 회원가입 시 다시 사주를 넣으라고 한다"는
  // 버그 리포트에 대한 검증. [GuinjiInputScreen]이 [initialDraft]를 받으면
  // 로그인 전 입력했던 값을 그대로 폼에 복원해야 한다(빈 화면으로 재진입
  // 금지).
  testWidgets('I · Input 화면이 initialDraft로 재진입 시 이전 입력값을 복원한다', (
    tester,
  ) async {
    const draft = GuinjiMapEntryDraft(
      nickname: '수아',
      year: '1998',
      month: '05',
      day: '14',
      hour: '09',
      minute: '20',
      calendarIndex: 1,
      timeUnknown: false,
    );
    await tester.pumpWidget(
      _wrap(const GuinjiInputScreen(initialDraft: draft)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // TextField는 EditableText와 그 내부 렌더링 Text 둘 다에 같은 문자열이
    // 나타날 수 있어 findsWidgets(1개 이상)로 검증한다 — 핵심은 "빈 폼이
    // 아니라 이전에 입력한 값이 실제로 화면에 존재하는가"이다.
    expect(find.text('수아'), findsWidgets);
    expect(find.text('1998'), findsWidgets);
    expect(find.text('05'), findsWidgets);
    expect(find.text('14'), findsWidgets);
    expect(find.text('09'), findsWidgets);
    expect(find.text('20'), findsWidgets);
  });

  testWidgets('C · Calculating 화면이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      _wrap(GuinjiCalculatingScreen(onComplete: () {})),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('M · My Map 화면이 people 없이도 예외 없이 렌더된다(빈 상태)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const GuinjiMapResultScreen(ownerName: '나', people: [])),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('지인을 초대하면 여기에 표시돼요'), findsOneWidget);
  });

  testWidgets('M · My Map 화면이 실제 people 데이터로 노드를 렌더한다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const GuinjiMapResultScreen(
          ownerName: '지민',
          people: _samplePeople,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('수아'), findsOneWidget);
    expect(find.text('민서'), findsOneWidget);
  });

  for (final count in [1, 3]) {
    testWidgets('M · $count명 지도 렌더 및 복귀가 예외 없이 동작한다', (tester) async {
      final people = [
        ..._samplePeople.take(count),
        if (count == 3) const GuinjiPerson(id: 'p3', name: '지우', birth: '1998·01·02', ohaeng: 'su', relation: 'HAP', score: 75, note: '합'),
      ];
      await tester.pumpWidget(_wrap(GuinjiMapResultScreen(ownerName: '나', people: people)));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      for (final person in people) {
        expect(find.text(person.name), findsOneWidget);
      }
    });
  }

  testWidgets('M 화면 노드 탭 시 N 바텀시트가 크래시 없이 뜬다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GuinjiMapResultScreen(
          ownerName: '지민',
          people: _samplePeople,
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('수아'));
    await tester.pump();
    await tester.tap(find.text('수아'));
    // 화면에 무한 반복(repeat()) 애니메이션이 있어 pumpAndSettle()은
    // 절대 안정 상태에 도달하지 못하고 타임아웃된다. 바텀시트 열림
    // 애니메이션이 끝날 만큼의 유한한 시간만 pump한다.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // 현재 바텀시트의 공유 버튼이 실제로 그려져야 한다.
    expect(find.text('공유'), findsOneWidget);
  });

  testWidgets('S · Share 화면이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GuinjiMapShareScreen(
          ownerName: '지민',
          mapToken: 'test-token-123',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S · Share 화면이 mapToken 빈 문자열이어도 크래시 없이 렌더된다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const GuinjiMapShareScreen(ownerName: '나', mapToken: '')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('지도를 여는 중…'), findsOneWidget);
  });

  // [핸드오프 §05-3 `RankScreen` 1:1 이식] "유형별 목록"은 더 이상 별도
  // 화면(F · Friend List)이 아니라 랭킹 화면의 두 번째 탭이다.
  testWidgets('F · 유형별 목록(랭킹 화면 2번째 탭)이 예외 없이 렌더된다(빈 목데이터)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const GuinjiMapRankingScreen(people: [], initialTab: 1)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('F · 유형별 목록이 실제 people 기반으로도 렌더된다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(GuinjiMapRankingScreen(people: _samplePeople, initialTab: 1)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('수아'), findsOneWidget);
  });

  testWidgets('Y · Guest Result 화면이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GuinjiGuestResultScreen(
          hostName: '지민',
          relationKey: 'CHEON_GWII',
          score: 92,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('게스트 참여(join) 화면이 예외 없이 렌더된다', (tester) async {
    // [22개 선행 실패 조사/수정 — 별도 원인] 이 화면은 initState에서
    // addPostFrameCallback으로 fetchHostProfile()(실 네트워크 GET,
    // .timeout(15s))을 호출한다(AuthTokenStore와는 무관 — 비로그인
    // 전용 API). 단일 pump()만으로는 이 비동기 호출(및 그 내부
    // timeout Timer)이 완료되기 전에 테스트가 끝나버려 "A Timer is
    // still pending even after the widget tree was disposed"로
    // 실패했다(디버그 실행으로 확인: AuthTokenStore 관련 로그 없이 이
    // Timer 단언만 발생). 실패하는 응답(테스트 바인딩이 자동 반환하는
    // HTTP 400)이 실제로 도착해 Future/Timer가 정리될 시간을 주기 위해
    // 추가로 pump한다(화면은 실패를 조용히 무시하도록 설계되어 있어
    // 폴백 문구로 정상 렌더된다).
    await tester.pumpWidget(
      _wrap(const GuinjiMapGuestJoinScreen(token: 'test-token')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
