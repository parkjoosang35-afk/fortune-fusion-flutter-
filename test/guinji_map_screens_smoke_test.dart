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

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/guinji/application/guinji_provider.dart';
import 'package:flutter_app/features/guinji/data/guinji_repository.dart';
import 'package:flutter_app/features/guinji/domain/guinji_person.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_landing_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_input_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_calculating_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_map_result_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_map_share_screen.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_friend_list_screen.dart';
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
    expect(find.text('다음'), findsOneWidget);
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
    await tester.tap(find.text('수아'));
    // 화면에 무한 반복(repeat()) 애니메이션이 있어 pumpAndSettle()은
    // 절대 안정 상태에 도달하지 못하고 타임아웃된다. 바텀시트 열림
    // 애니메이션이 끝날 만큼의 유한한 시간만 pump한다.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // 바텀시트 안 "이 관계 공유하기" 버튼이 보여야 한다.
    expect(find.text('이 관계 공유하기'), findsOneWidget);
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

  testWidgets('F · Friend List 화면이 예외 없이 렌더된다(기본 목데이터)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const GuinjiFriendListScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('F · Friend List 화면이 실제 people 기반 목록으로도 렌더된다', (
    tester,
  ) async {
    final entries = guinjiFriendEntriesFromPeople(_samplePeople);
    expect(entries.length, 2);
    expect(entries.first.name, '수아'); // 점수 92 > 81 이므로 1위
    expect(entries.first.rank, 1);
    expect(entries.first.ohaengLabel, '火 오행');

    await tester.pumpWidget(
      _wrap(GuinjiFriendListScreen(friends: entries)),
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
    await tester.pumpWidget(
      _wrap(const GuinjiMapGuestJoinScreen(token: 'test-token')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
