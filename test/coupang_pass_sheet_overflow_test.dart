import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/pass/application/pass_provider.dart';
import 'package:flutter_app/features/pass/data/pass_repository.dart';
import 'package:flutter_app/features/pass/domain/pass_model.dart';
import 'package:flutter_app/features/pass/presentation/coupang_pass_sheet.dart';
import 'package:flutter_app/features/wallet/application/wallet_provider.dart';
import 'package:flutter_app/features/wallet/data/wallet_repository.dart';

class _FakePassRepository extends PassRepository {
  @override
  Future<ApiResult<List<PassPolicyModel>>> getPolicies() async {
    return ApiResult.ok([
      const PassPolicyModel(
        id: 11,
        name: '쿠팡 프리패스',
        passType: PassType.ad,
        durationMin: 0,
        grantCount: 2,
        adType: 'image',
        bannerImageUrl: null,
        adGuideTitle: '"정통사주 상세"는 프리패스로 열람할 수 있어요',
        adGuideText: '쿠팡 파트너스 광고를 확인하면 결과보기 2회가\n지급되어 무료로 이용할 수 있어요.',
      ),
    ]);
  }

  @override
  Future<ApiResult<PassStatusModel>> getStatus() async {
    return ApiResult.ok(PassStatusModel.inactive());
  }
}

class _FakePassProvider extends PassProvider {
  _FakePassProvider() : super(_FakePassRepository());
  // 시트가 열릴 때(initState) 다시 load()를 호출하는데, 실제 리포지토리를
  // 그대로 써도 Fake라 네트워크 호출이 없으니 안전함 — override 불필요.
}

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider() : super(WalletRepository());
  @override
  Future<void> load() async {
    // 네트워크 호출 없이 즉시 완료 처리(실제 흐름에서 쓰이지 않는 호출이라
    // 오버플로 검증에는 영향 없음).
  }
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
      '쿠팡 프리패스 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final passProvider = _FakePassProvider();
        final walletProvider = _FakeWalletProvider();

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<PassProvider>.value(value: passProvider),
                ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => showCoupangPassSheet(context, categoryTitle: '정통사주 상세'),
                      child: const Text('열기'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        // _glowController가 repeat(reverse:true)로 무한 반복하므로
        // pumpAndSettle 대신 고정 시간만 pump한다.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));
        {final ex = tester.takeException(); if (ex != null) debugDumpRenderTree(); expect(ex, isNull);}
        expect(find.text('쿠팡 방문하기'), findsOneWidget);
      },
    );
  }
}
