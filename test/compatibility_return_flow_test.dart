import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/core/auth/auth_token_store.dart';
import 'package:flutter_app/features/compatibility/application/compatibility_provider.dart';
import 'package:flutter_app/features/compatibility/presentation/compatibility_input_screen.dart';
import 'package:flutter_app/features/result_access/application/result_access_provider.dart';
import 'package:flutter_app/features/result_access/data/result_access_repository.dart';
import 'package:flutter_app/features/result_access/domain/result_access_model.dart';
import 'package:flutter_app/features/result_access/domain/pending_result_access_return.dart';
import 'package:flutter_app/features/result_access/presentation/result_access_gate_sheet.dart';
import 'package:flutter_app/features/pass/application/pass_provider.dart';
import 'package:flutter_app/features/pass/data/pass_repository.dart';
import 'compatibility_result_access_test.dart' as fixture;

class FakeAccessRepository extends ResultAccessRepository {
  int beginCalls = 0;
  bool unauthorized = false;
  @override
  Future<ApiResult<ResultAccessQuote>> getQuote({
    required String contentType,
    String? categoryKey,
  }) async {
    if (unauthorized) return ApiResult.fail('로그인 필요', code: 'UNAUTHORIZED');
    return ApiResult.ok(
      const ResultAccessQuote(
        freePassRemaining: 2,
        freePassHasLegacyUnlimited: false,
        freePassAvailable: true,
        pouchBalance: 0,
        pouchPrice: 100,
        pouchAvailable: true,
        adAvailable: false,
        coupangClaimedTodayKey: null,
        todayClaimed: false,
      ),
    );
  }

  @override
  Future<ApiResult<ResultAccessBeginResult>> begin({
    required String transactionId,
    required String contentType,
    String? contentId,
    String? categoryKey,
    required ResultAccessPaymentMethod paymentMethod,
    String? adSessionId,
  }) async {
    beginCalls++;
    return ApiResult.ok(fixture.access(transactionId));
  }
}

class FakePassProvider extends PassProvider {
  FakePassProvider() : super(PassRepository());
  @override
  Future<void> load() async {}
}

const input = {
  'type': 'friend',
  'nameA': '나',
  'nameB': '상대',
  'birthDateA': '1990-01-01',
  'birthDateB': '1991-02-02',
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthTokenStore.clear();
    await AuthTokenStore.save(token: 'local-test', userId: 42);
  });
  Future<void> mount(
    WidgetTester tester,
    fixture.FakeCompatibilityRepository repo,
    FakeAccessRepository accessRepo,
    Widget home, {
    Map<String, WidgetBuilder>? routes,
    RouteFactory? routeFactory,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CompatibilityProvider(repo)),
          ChangeNotifierProvider(
            create: (_) => ResultAccessProvider(accessRepo),
          ),
          ChangeNotifierProvider<PassProvider>(
            create: (_) => FakePassProvider(),
          ),
        ],
        child: MaterialApp(
          home: home,
          routes:
              routes ??
              {
                '/compatibility/result': (_) =>
                    const Scaffold(body: Text('생성 요청 화면')),
              },
          onGenerateRoute: routeFactory,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('쿠팡 이동 중 종료 후 입력 복원은 게이트 선택에서 실제 생성까지 이어짐', (tester) async {
    final repo = fixture.FakeCompatibilityRepository();
    final accessRepo = FakeAccessRepository();
    await mount(
      tester,
      repo,
      accessRepo,
      const CompatibilityInputScreen(
        restoredInput: input,
        resumeResultAccess: true,
      ),
    );
    expect(find.text('프리패스로 보기 (2회 남음)'), findsOneWidget);
    await tester.tap(find.text('프리패스로 보기 (2회 남음)'));
    await tester.pumpAndSettle();
    expect(accessRepo.beginCalls, 1);
    expect(repo.ids.length, 1);
    expect(find.text('생성 요청 화면'), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets('앱 재시작은 저장된 거래로 확인하고 새 begin을 만들지 않음', (tester) async {
    final repo = fixture.FakeCompatibilityRepository();
    final accessRepo = FakeAccessRepository();
    await mount(
      tester,
      repo,
      accessRepo,
      CompatibilityInputScreen(
        restoredInput: {
          ...input,
          '_ownerUserId': 42,
          '_resultAccess': {
            'transactionId': 'saved',
            'paymentMethod': 'FREEPASS',
            'status': 'pending',
            'amount': 1,
            'idempotent': true,
          },
        },
        resumeResultAccess: true,
      ),
    );
    expect(repo.ids, ['saved']);
    expect(accessRepo.beginCalls, 0);
    expect(await PendingResultAccessReturnStore.hasPending(), false);
  });
  testWidgets('다른 계정의 저장 거래는 호출하지 않고 개인정보 입력을 지움', (tester) async {
    final repo = fixture.FakeCompatibilityRepository();
    final accessRepo = FakeAccessRepository();
    await mount(
      tester,
      repo,
      accessRepo,
      CompatibilityInputScreen(
        restoredInput: {
          ...input,
          '_ownerUserId': 99,
          '_resultAccess': {
            'transactionId': 'foreign',
            'paymentMethod': 'FREEPASS',
            'status': 'pending',
            'amount': 1,
            'idempotent': true,
          },
        },
        resumeResultAccess: true,
      ),
    );
    expect(repo.ids, isEmpty);
    expect(accessRepo.beginCalls, 0);
    expect(find.text('상대'), findsNothing);
    expect(await PendingResultAccessReturnStore.hasPending(), false);
  });
  testWidgets('로그인 복귀는 라우트 종료를 기다리지 않고 복원 화면이 게이트 결과를 처리', (tester) async {
    await PendingResultAccessReturnStore.save(
      PendingResultAccessReturn(
        contentType: 'compatibility',
        returnRoute: '/compatibility/input',
        savedAt: DateTime.now(),
        userInput: input,
      ),
    );
    final repo = fixture.FakeCompatibilityRepository();
    final accessRepo = FakeAccessRepository();
    bool returned = false;
    await mount(
      tester,
      repo,
      accessRepo,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              returned = await restorePendingResultAccessAfterLogin(context);
            },
            child: const Text('로그인 완료'),
          ),
        ),
      ),
      routeFactory: (settings) {
        if (settings.name != '/compatibility/input') return null;
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CompatibilityInputScreen(
            restoredInput: args['restoredInput'] as Map<String, dynamic>,
            resumeResultAccess: args['resumeResultAccess'] == true,
          ),
        );
      },
    );
    await tester.tap(find.text('로그인 완료'));
    await tester.pumpAndSettle();
    expect(returned, true);
    await tester.tap(find.text('프리패스로 보기 (2회 남음)'));
    await tester.pumpAndSettle();
    expect(repo.ids.length, 1);
  });
  test('실패 견적은 이전 계정 견적을 지움', () async {
    final repo = FakeAccessRepository();
    final provider = ResultAccessProvider(repo);
    await provider.loadQuote(contentType: 'compatibility');
    expect(provider.quote, isNotNull);
    repo.unauthorized = true;
    await provider.loadQuote(contentType: 'compatibility');
    expect(provider.quote, null);
    expect(provider.lastErrorReason, 'UNAUTHORIZED');
  });
}
