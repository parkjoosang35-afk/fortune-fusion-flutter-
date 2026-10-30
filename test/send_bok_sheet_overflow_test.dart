import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/wallet/application/wallet_provider.dart';
import 'package:flutter_app/features/wallet/data/wallet_repository.dart';
import 'package:flutter_app/features/wallet/presentation/widgets/send_bok_sheet.dart';

class _FakeWalletRepository extends WalletRepository {
  @override
  Future<ApiResult<({int userId, String nickname})>> lookupUserByNickname(
    String nickname,
  ) async {
    return ApiResult.ok((userId: 42, nickname: nickname));
  }
}

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider() : super(_FakeWalletRepository());
}

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '복 나누기 시트(키보드 열림 포함)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = _FakeWalletProvider();

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: ChangeNotifierProvider<WalletProvider>.value(
              value: provider,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => showSendBokSheet(
                        context,
                        recipientNickname: '아주긴닉네임테스트유저입니다12345',
                      ),
                      child: const Text('열기'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 금액 입력 필드를 탭해 키보드가 열리는 상황을 시뮬레이션한다 —
        // 작은 화면에서 입력창+프리셋칩+버튼이 가려지는 조건 재현.
        // (테스트 환경에서 실제 IME는 뜨지 않으므로 tester.view.viewInsets를
        // 직접 올려 키보드 열림 상태의 MediaQuery.viewInsets.bottom을 재현한다.)
        final amountField = find.byType(TextField).first;
        await tester.tap(amountField);
        tester.view.viewInsets = FakeViewPadding(bottom: 280 * tester.view.devicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
