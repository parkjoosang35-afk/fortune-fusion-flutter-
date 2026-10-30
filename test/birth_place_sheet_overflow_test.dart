// [showModalBottomSheet isScrollControlled 누락 패턴 전수 검증]
// birth_input_screen.dart의 _changeBirthPlace()가 isScrollControlled
// 없이 showModalBottomSheet를 호출하는 것을 확인, 17개 지역 Wrap 목록이
// 작은 화면/글자확대 조건에서 오버플로를 내는지 widget test로 실측한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/birth_input_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
      ChangeNotifierProvider(create: (_) => SajuRenewalProvider(SajuRenewalApi())),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '출생정보 입력 화면의 태어난 곳 변경 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
            child: _wrap(const BirthInputScreen()),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final changeFinder = find.text('변경');
        expect(changeFinder, findsWidgets);
        await tester.ensureVisible(changeFinder.first);
        await tester.pump();
        await tester.tap(changeFinder.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        // 시트 목록의 마지막 항목(제주)까지 실제로 그려지는지 확인.
        expect(find.text('제주'), findsOneWidget);
      },
    );
  }
}
