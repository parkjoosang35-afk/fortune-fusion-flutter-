// [작은 화면/글자확대 잘림 수정 회귀 방지 — 2026 반응형 규격 통일]
// GuinjiInvitationLetter의 "메타 태그 행"(INVITATION + 날짜)이
// mainAxisAlignment.spaceBetween으로 고정된 Row라 좁은 화면이나 날짜
// 텍스트가 길어지는 날(요일 한자 포함)에 RenderFlex 오버플로가 발생했다
// (390x844 표준 폭 기준 실측 22px 초과, guinji_map_guest_join_screen.dart
// 전체 화면 렌더 중 처음 발견). 날짜 Text를 Flexible+ellipsis로 감싸
// 수정했다 — 이 테스트는 다양한 폭에서 더 이상 오버플로가 나지 않음을
// 고정한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/guinji/presentation/guinji_invitation_letter.dart';

void main() {
  final widths = <double>[320, 360, 390, 428];

  for (final width in widths) {
    testWidgets('InvitationLetter가 폭 ${width.toInt()}에서 오버플로 없이 렌더된다', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: const SingleChildScrollView(
                child: GuinjiInvitationLetter(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('INVITATION'), findsOneWidget);
      // 인장 등장 애니메이션(Future.delayed 400ms + 1400ms 컨트롤러)이
      // 끝날 시간만큼 pump해 "pending timer" 단언 실패를 방지한다.
      await tester.pump(const Duration(milliseconds: 2000));
    });
  }

  testWidgets('호스트 이름/캐릭터 포함 시에도 오버플로 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: GuinjiInvitationLetter(
                hostName: '수아',
                characterType: const GuinjiHostCharacterType(
                  element: '목',
                  hanja: '木',
                  title: '큰 나무형',
                  tagline: '쭉쭉 뻗어나가는 성장형',
                  description: '',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 2000));
  });
}
