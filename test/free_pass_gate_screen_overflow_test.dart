// [신통방통 반응형 화면 규격 통일 지시서] 프리패스 안내 화면
// (FreePassGateScreen) 가로 오버플로 회귀 테스트.
//
// 배경: 이 화면은 현재 코드베이스에서 도달 경로가 없는 화면(dead code, 파일
// 상단 doc comment 2026-10-11 기록)이지만, 지시서의 "전체 화면 점검" 범위에
// 포함되어 있고 라우트/파일 자체는 삭제하지 않고 유지되므로 그대로 실측한다.
//
// `_StatusCard` 위젯 안에 Flexible/Expanded 보호가 없는 Row 2개가 있어
// 코드 리딩 단계에서 후보로 지목되었고, 아래 worst-case 데이터(레거시
// 시간제 겸용 remainingLabel "기존 시간제 이용권 보유 · 999999회 남음" +
// 매우 큰 지갑 잔액 + 구독 활성)로 5개 기기폭×텍스트스케일 조합을 실측한
// 결과 둘 다 실제 RenderFlex 오버플로 버그로 확인되었다(debugDumpRenderTree
// 기준 최대 854px/479px):
//  1) "프리패스 이용 중" + Spacer() + remainingLabel Row (line 208)
//  2) "복주머니 N개" + (구독 중이면) "구독 이용 중" 배지 Row (line 244)
// 두 Row 모두 로그인/회원가입 화면(login_screen.dart)에서 검증된 동일
// 패턴으로 수정했다 — 바깥을 SizedBox(width: double.infinity) + Wrap으로
// 감싸(또는 그냥 Wrap으로), 공간이 충분하면 기존과 완전히 동일하게 한 줄로
// 보이고 부족할 때만 자연스럽게 다음 줄로 줄바꿈되도록 했다. 디자인/색상/
// 간격/기능은 전혀 바꾸지 않았다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/core/domain/access/access_checker.dart';
import 'package:flutter_app/features/pass/application/pass_provider.dart';
import 'package:flutter_app/features/pass/data/pass_repository.dart';
import 'package:flutter_app/features/pass/domain/pass_model.dart';
import 'package:flutter_app/features/pass/presentation/free_pass_gate_screen.dart';
import 'package:flutter_app/features/subscription/application/subscription_provider.dart';
import 'package:flutter_app/features/subscription/data/subscription_repository.dart';
import 'package:flutter_app/features/wallet/application/wallet_provider.dart';
import 'package:flutter_app/features/wallet/data/wallet_repository.dart';

/// 실 네트워크 호출 없이, "레거시 시간제 겸용 + 매우 큰 횟수" 상태를
/// 강제해 remainingLabel을 최장 형태로 만든다.
class _FakePassRepository extends PassRepository {
  @override
  Future<ApiResult<List<PassPolicyModel>>> getPolicies() async =>
      ApiResult.ok(const []);

  @override
  Future<ApiResult<PassStatusModel>> getStatus() async => ApiResult.ok(
    PassStatusModel(
      isActive: true,
      policyName: '쿠팡 프리패스',
      activatedAt: DateTime(2026, 1, 1),
      expiresAt: DateTime.now().add(const Duration(hours: 10)),
      remainingSec: 36000,
      remainingCount: 999999,
      hasLegacyUnlimited: true,
    ),
  );
}

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider() : super(WalletRepository());

  @override
  int get balance => 1234567890;

  @override
  Future<void> load() async {
    // 네트워크 호출 없이 즉시 완료(오버플로 검증에는 영향 없음).
  }
}

class _FakeSubscriptionProvider extends SubscriptionProvider {
  _FakeSubscriptionProvider() : super(SubscriptionRepository());

  @override
  bool get isPremium => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cases = <(Size, double)>[
    (Size(390, 844), 1.0),
    (Size(360, 640), 1.3),
    (Size(320, 568), 1.5),
    (Size(320, 568), 2.0),
    (Size(320, 568), 2.5),
  ];

  for (final (size, scale) in cases) {
    final label = '${size.width.toInt()}x${size.height.toInt()}@$scale';

    testWidgets('FreePassGateScreen $label overflow 없어야 함', (tester) async {
      SharedPreferences.setMockInitialValues({});

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final passProvider = PassProvider(_FakePassRepository());

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<PassProvider>.value(value: passProvider),
              ChangeNotifierProvider<WalletProvider>(
                create: (_) => _FakeWalletProvider(),
              ),
              ChangeNotifierProvider<SubscriptionProvider>(
                create: (_) => _FakeSubscriptionProvider(),
              ),
              ProxyProvider<PassProvider, AccessChecker>(
                update: (_, pass, __) => AccessChecker(pass: pass),
              ),
            ],
            child: const MaterialApp(home: FreePassGateScreen()),
          ),
        ),
      );

      // initState의 addPostFrameCallback(load()) + Fake Repository의
      // 즉시완료 Future가 모두 반영되도록 몇 프레임 더 진행한다.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final ex = tester.takeException();
      if (ex != null) {
        debugDumpRenderTree();
      }
      expect(ex, isNull, reason: 'FreePassGateScreen $label overflow 없어야 함');
      expect(find.text('프리패스 안내'), findsOneWidget);
    });
  }
}
