// [신통방통 반응형 화면 규격 통일 지시서] 얼굴관상·손금 진입 시 뜨는
// "민감정보(사진) 처리 동의" 바텀시트(_ConsentSheet,
// sensitive_photo_consent_dialog.dart) 오버플로 테스트.
//
// [확인된 실제 버그 2건 - debugDumpRenderTree로 근본원인 확정]
// 1) 세로 오버플로: _ConsentSheet의 고정 Column(mainAxisSize: min)에
//    SingleChildScrollView 보호가 없어, 작은 화면(320px대) + textScale
//    1.5배 이상 조합에서 안내문구가 길어지며 세로 RenderFlex 오버플로가
//    발생했다(실측 320x568@1.5 65px, @2.0 430px, @2.5 882px).
//    SingleChildScrollView로 감싸 해결 — 디자인/문구/버튼 변경 없음.
// 2) 가로 오버플로(공용 위젯 파급 버그): 위 수정 후에도 320x568@2.0/2.5에서
//    오버플로가 남아 debugDumpRenderTree로 추적한 결과, 원인은 이 시트가
//    아니라 하단 "동의하고 계속하기"/"거부하기" 버튼이 쓰는 공용 위젯
//    SintongPrimaryButton/SintongGhostButton(sintong_button.dart) 내부 Row가
//    라벨 Text에 overflow 보호 없이 textScale 확대분을 그대로 받아
//    가로로 넘쳤다(실측 @2.0 65px, @2.5 132px). 두 위젯 모두 라벨을
//    Flexible+ellipsis로 감싸 해결 — 기존 라벨 길이에서는 시각적 변화 없음
//    (face_capture_screen.dart/palm_capture_screen.dart에서도 동일 위젯을
//    쓰므로 함께 보호됨).
//
// 기존 테스트는 textScale 1.3까지만 검증해 이 버그들을 놓쳤었다. 이번에
// 표준 5개 기기폭×텍스트스케일 조합(최대 2.5배)으로 범위를 확장한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/fortune/shared/presentation/sensitive_photo_consent_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '민감정보(사진) 처리 동의 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => SensitivePhotoConsentDialog.ensureConsent(
                      context,
                      feature: 'face',
                      featureLabel: '관상',
                    ),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final ex = tester.takeException();
        if (ex != null) {
          debugDumpRenderTree();
        }
        expect(ex, isNull);
        expect(find.text('동의하고 계속하기'), findsOneWidget);
        expect(find.text('거부하기'), findsOneWidget);
      },
    );
  }
}
