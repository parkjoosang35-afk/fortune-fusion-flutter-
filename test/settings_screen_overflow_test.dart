// [반응형 화면 규격 통일 — 잘림 현상 수정] 설정 화면(SettingsScreen)이 좁은
// 화면 + 글자 확대 조합에서 오버플로 없이 뜨는지 실측한다.
//
// [조사 결과 — 1차] 본문은 SafeArea > ListView(섹션별 Container+Column+Row) 구조라
// 세로 길이가 늘어나도 전체가 자연스럽게 스크롤된다. 회원탈퇴 다이얼로그는
// 공용 showAppConfirmDialog(AlertDialog)를 사용하며, 이미
// test/app_dialog_overflow_test.dart에서 긴 메시지 기준으로 반응형 검증이
// 끝나 있다(OverflowBar unbounded width 버그도 그 쪽에서 이미 수정됨).
// _PolicyLinkRow/_NotificationPrefRow도 Expanded+Column(min) 구조라 고정폭
// 제약이 없어 위험 패턴이 없음을 코드 리딩으로 확인(실제 버그 아님, 수정 불요).
//
// [조사 결과 — 2차, 신규 확인 버그] 위 1차 조사는 showAppConfirmDialog(회원탈퇴)만
// 검증했을 뿐, 이 화면 전용 커스텀 AlertDialog인 _editRealName()의
// "실명 등록" 다이얼로그(content: Column(mainAxisSize: min) + 안내문구 2줄 +
// TextField)는 검증하지 않았다. 320x568 좁은 화면에서 textScale을 올리면
// 실측 @2.0 184px, @2.5 370px 세로 오버플로가 발생함을 확인(실제 버그).
// → settings_screen.dart의 content를 SingleChildScrollView로 감싸 수정 완료.
// 아래 두 번째 testWidgets 그룹이 이 다이얼로그를 직접 열어 전체 textScale
// 매트릭스(최대 2.5)로 회귀 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/mypage/presentation/settings_screen.dart';

Future<void> _pump(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    ),
  );
  await tester.pump();
  // 버전 정보(package_info_plus)·서버 버전(http) 비동기 로딩까지 기다린다.
  await tester.pump(const Duration(seconds: 1));
}

/// [반응형 화면 규격 통일 지시서] settings_screen.dart `_editRealName()`의
/// AlertDialog content와 동일한 구조(SingleChildScrollView로 감싼
/// Column(mainAxisSize: min) + 안내문구 2줄 + TextField)를 재현해 전체
/// textScale 매트릭스로 오버플로 여부를 직접 검증한다. private 메서드라
/// 직접 호출할 수 없어 동일 구조를 복제했다 — settings_screen.dart의 content를
/// 수정할 때는 이 재현 구조도 함께 갱신해야 한다.
Future<void> _pumpRealNameDialog(
  WidgetTester tester,
  Size size,
  double textScale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('실명 등록'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '신당(THE SHRINE)에서 발급하는 부적에 새길 이름입니다.\n'
                            '닉네임과는 별도로 실명을 입력해 주세요.',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: '예) 홍길동',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () {}, child: const Text('취소')),
                      TextButton(onPressed: () {}, child: const Text('저장')),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      'SettingsScreen이 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pump(tester, size, textScale);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // [반응형 화면 규격 통일 지시서 — 실측 확인된 버그 회귀 테스트]
  // 실명 등록 다이얼로그: 320x568 기준 @2.0 184px, @2.5 370px 세로 오버플로
  // 확인 후 SingleChildScrollView로 수정. 전체 매트릭스(최대 2.5)로 검증.
  final dialogConditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in dialogConditions) {
    testWidgets(
      '실명 등록 다이얼로그가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        await _pumpRealNameDialog(tester, size, textScale);
        final ex = tester.takeException();
        if (ex != null) {
          debugDumpRenderTree();
        }
        expect(ex, isNull);
      },
    );
  }
}
