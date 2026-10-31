// [신통방통 반응형 화면 규격 통일 지시서] 회원가입/로그인 화면 영구 회귀 테스트
//
// 배경: LoginScreen/SignupScreen을 5개 기기폭×텍스트스케일 조합으로 실측한
// 결과, 2개의 실제 RenderFlex 오버플로 버그가 확인되어 아래와 같이 수정했다.
//
// 1) `AuthFormHeader`(로그인/회원가입 공용 상단 바) — eyebrow 라벨
//    Text가 Flexible/Expanded 없이 배치돼 있어, 좁은 화면 + 큰 텍스트
//    스케일(예: 320x568@2.0+)에서 넘침. → `Flexible(child: Text(...,
//    overflow: TextOverflow.ellipsis))`로 감싸 넘치면 말줄임표로 축약.
// 2) LoginScreen의 "로그인 상태 유지 / 아이디 찾기 | 비밀번호 찾기" Row —
//    바깥 Row(spaceBetween)의 양쪽 자식이 모두 Row(mainAxisSize: min)로만
//    구성돼 보호 장치가 전혀 없었다. → 양쪽 모두 Wrap으로 교체하고 바깥
//    컨테이너를 SizedBox(width: double.infinity) + Wrap(spaceBetween)으로
//    바꿔, 공간이 부족하면 두 번째 줄로 자연스럽게 줄바꿈되도록 했다
//    (explore_screen.dart에서 검증된 동일 패턴 재사용).
//
// SignupScreen은 (1)번 공용 버그만 겪었고(320x568@2.5에서만 40px 넘침),
// LoginScreen은 (1)+(2) 두 버그가 겹쳐 더 넓은 범위(360x640@1.3부터)에서
// 넘쳤다. 두 수정 모두 기존 디자인/색상/정렬/간격을 바꾸지 않았다 — 공간이
// 부족할 때만 줄바꿈/말줄임표로 대응한다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/auth/presentation/login_screen.dart';
import 'package:flutter_app/features/auth/presentation/signup_screen.dart';
import 'package:flutter_app/features/wallet/application/wallet_provider.dart';
import 'package:flutter_app/features/wallet/data/wallet_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AuthRepository/AuthProvider/WalletRepository/WalletProvider는 생성자
  // 시점에 네트워크 호출을 하지 않으므로(확인됨) Mock 없이 실 인스턴스를
  // 그대로 사용할 수 있다.
  Widget wrap(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(AuthRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => WalletProvider(WalletRepository()),
          ),
        ],
        child: MaterialApp(home: child),
      );

  const cases = <(Size, double)>[
    (Size(390, 844), 1.0),
    (Size(360, 640), 1.3),
    (Size(320, 568), 1.5),
    (Size(320, 568), 2.0),
    (Size(320, 568), 2.5),
  ];

  for (final (size, scale) in cases) {
    final label = '${size.width.toInt()}x${size.height.toInt()}@$scale';

    testWidgets('login screen $label overflow 없어야 함', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: wrap(const LoginScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.takeException(),
        isNull,
        reason: 'login $label overflow 없어야 함',
      );
    });

    testWidgets('signup screen $label overflow 없어야 함', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: wrap(const SignupScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.takeException(),
        isNull,
        reason: 'signup $label overflow 없어야 함',
      );
    });
  }
}
