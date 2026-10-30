// [반응형 화면 규격 통일 — 잘림 현상 수정] 설정 화면(SettingsScreen)이 좁은
// 화면 + 글자 확대 조합에서 오버플로 없이 뜨는지 실측한다.
//
// [조사 결과] 본문은 SafeArea > ListView(섹션별 Container+Column+Row) 구조라
// 세로 길이가 늘어나도 전체가 자연스럽게 스크롤된다. 회원탈퇴/실명 등록
// 다이얼로그는 공용 showAppConfirmDialog/AlertDialog를 사용하며, 이미
// test/app_dialog_overflow_test.dart에서 긴 메시지 기준으로 반응형 검증이
// 끝나 있다(OverflowBar unbounded width 버그도 그 쪽에서 이미 수정됨).
// _PolicyLinkRow/_NotificationPrefRow도 Expanded+Column(min) 구조라 고정폭
// 제약이 없어 위험 패턴이 없음을 코드 리딩으로 확인(실제 버그 아님, 수정 불요).
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
}
