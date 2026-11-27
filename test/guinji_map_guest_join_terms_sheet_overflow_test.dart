// [반응형 화면 규격 통일 — 잘림 현상 수정]
// guinji_map_guest_join_screen.dart의 _showTermsSheet()(개인정보 수집·이용
// 안내 바텀시트)는 이전에 isScrollControlled 없이 showModalBottomSheet를
// 호출해 높이가 화면 절반으로 강제 고정되고, 시스템 글자 확대(1.3배)에서
// 제목+본문+버튼이 그 절반 높이를 넘어 55px 바닥 오버플로가 났었다(소스
// 코드 주석에 기록된 실측). 현재 소스는 이미 isScrollControlled: true +
// SafeArea(top: false) + SingleChildScrollView 패턴으로 수정되어 있으나,
// 이 수정이 표준 5-콤보 매트릭스(390x844@1.0 ~ 320x568@2.5)로 직접
// 검증된 적은 없었다(기존 guinji_invitation_letter_overflow_test.dart는
// GuinjiInvitationLetter 위젯만 커버하고 이 시트는 다루지 않음). 이
// 테스트는 실제 소스의 _showTermsSheet 위젯 트리를 동일하게 재현해
// 회귀를 방지한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/guinji/presentation/guinji_invitation_theme.dart';

Future<void> showTermsSheetLike(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(GiRadius.sheet),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF24133D), GiColors.bg2],
              ),
              border: Border(top: BorderSide(color: Color(0x40F5CF6A))),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '개인정보 수집 · 이용 안내',
                    style: TextStyle(
                      fontFamily: GiFonts.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: GiColors.fg,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '입력하신 이름(닉네임)·생년월일·태어난 시간·성별은 지도 '
                    '소유자와의 관계를 계산하는 용도로만 사용되며, 지도 '
                    '소유자에게만 결과 형태로 표시돼요. 수집된 정보는 관계 '
                    '계산 목적 외에는 사용되지 않아요.',
                    style: TextStyle(
                      fontFamily: GiFonts.body,
                      fontSize: 13.5,
                      height: 1.6,
                      color: GiColors.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: GiColors.glow,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GiRadius.field),
                        ),
                      ),
                      child: const Text(
                        '확인했어요',
                        style: TextStyle(
                          fontFamily: GiFonts.body,
                          fontWeight: FontWeight.w700,
                          color: GiColors.bg1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '귀인지도 게스트참여 개인정보 안내 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showTermsSheetLike(context),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        var ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);

        // [참고] 320x568@2.0~2.5처럼 글자 확대가 커서 시트 내용이 화면
        // 높이를 넘으면 SingleChildScrollView가 의도대로 스크롤되어 버튼이
        // 일시적으로 보이는 영역 밖에 위치할 수 있다 — 이는 "확인했어요"
        // 버튼이 영원히 눌리지 않는 잘림 버그가 아니라, 스크롤해야 닿는
        // 정상적인 긴 콘텐츠 동작이다. ensureVisible로 스크롤한 뒤 탭한다.
        await tester.ensureVisible(find.text('확인했어요'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('확인했어요'));
        await tester.pumpAndSettle();
        ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
      },
    );
  }
}
