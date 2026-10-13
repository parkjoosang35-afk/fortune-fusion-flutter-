import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/result_access/domain/pending_result_access_return.dart';
import 'package:flutter_app/core/auth/auth_token_store.dart';
import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/compatibility/application/compatibility_provider.dart';
import 'package:flutter_app/features/compatibility/data/compatibility_repository.dart';
import 'package:flutter_app/features/compatibility/domain/compatibility_model.dart';
import 'package:flutter_app/features/result_access/domain/result_access_model.dart';

class FakeCompatibilityRepository extends CompatibilityRepository {
  final List<String> ids = [];
  String? failure;
  Completer<void>? waitForResponse;
  @override
  Future<ApiResult<CompatibilityResultModel>> requestCompatibility({
    required CompatibilityType type,
    required String nameA,
    required String nameB,
    required String birthDateA,
    required String birthDateB,
    required String paymentMethod,
    required String transactionId,
    String? adSessionId,
  }) async {
    ids.add(transactionId);
    if (waitForResponse != null) await waitForResponse!.future;
    if (failure != null) return ApiResult.fail('검증 실패', code: failure);
    return ApiResult.ok(
      CompatibilityResultModel(
        id: 'compat_1',
        nameA: nameA,
        nameB: nameB,
        type: type.apiValue,
        score: 80,
        topicResults: const {},
        summary: '검증',
        createdAt: DateTime(2026, 10, 13),
      ),
    );
  }
}

ResultAccessBeginResult access(String id) => ResultAccessBeginResult(
  transactionId: id,
  paymentMethod: ResultAccessPaymentMethod.freepass,
  status: 'pending',
  amount: 1,
  idempotent: false,
);
Future<void> request(CompatibilityProvider provider) => provider.request(
  type: CompatibilityType.friend,
  nameA: '나',
  nameB: '상대',
  birthDateA: '1990-01-01',
  birthDateB: '1991-02-02',
  access: access('first'),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthTokenStore.clear();
    await AuthTokenStore.save(token: 'local-test', userId: 42);
  });
  test('거래 정보 전달과 네트워크 재시도는 같은 거래 유지', () async {
    final repo = FakeCompatibilityRepository()..failure = 'NETWORK_ERROR';
    final provider = CompatibilityProvider(repo);
    await request(provider);
    expect(provider.needsNewAccess, false);
    await provider.retry();
    expect(repo.ids, ['first', 'first']);
    expect(provider.inputForRestore['type'], 'friend');
    final saved = await PendingResultAccessReturnStore.peek();
    expect(saved?.userInput['_ownerUserId'], 42);
    expect(
      (saved?.userInput['_resultAccess'] as Map)['transactionId'],
      'first',
    );
  });
  test('환불된 생성 실패는 새 게이트 없이 재요청하지 않음', () async {
    final repo = FakeCompatibilityRepository()..failure = 'GENERATION_FAILED';
    final provider = CompatibilityProvider(repo);
    await request(provider);
    expect(provider.needsNewAccess, true);
    await provider.retry();
    expect(repo.ids, ['first']);
    repo.failure = null;
    await provider.retry(access: access('second'));
    expect(repo.ids, ['first', 'second']);
    expect(provider.state.isSuccess, true);
    expect(await PendingResultAccessReturnStore.hasPending(), false);
  });
  test('차감 거래는 6시간 이후에도 재시작 상태 확인을 위해 보존', () async {
    await PendingResultAccessReturnStore.save(
      PendingResultAccessReturn(
        contentType: 'compatibility',
        returnRoute: '/compatibility/input',
        savedAt: DateTime.now().subtract(const Duration(days: 1)),
        userInput: {
          '_resultAccess': {'transactionId': 'persisted'},
        },
      ),
    );
    expect(
      (await PendingResultAccessReturnStore.consume())?.contentType,
      'compatibility',
    );
    expect(await PendingResultAccessReturnStore.consume(), isNotNull);
    await PendingResultAccessReturnStore.clearTransaction('persisted');
    expect(await PendingResultAccessReturnStore.consume(), null);
  });
  test('로그아웃 후 늦은 응답은 이전 계정 결과를 복원하지 않음', () async {
    final repo = FakeCompatibilityRepository()
      ..waitForResponse = Completer<void>();
    final provider = CompatibilityProvider(repo);
    final pending = request(provider);
    while (repo.ids.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    provider.clearOnLogout();
    repo.waitForResponse!.complete();
    await pending;
    expect(provider.state.isInitial, true);
    expect(
      provider.inputForRestore.values.every((value) => value == null),
      true,
    );
  });
  test('영속 저장 대기 중 두 번 요청해도 호출은 한 번', () async {
    final repo = FakeCompatibilityRepository();
    final provider = CompatibilityProvider(repo);
    await Future.wait([request(provider), request(provider)]);
    expect(repo.ids, ['first']);
  });
  test('로그아웃은 거래와 입력 복원 정보를 제거', () async {
    final repo = FakeCompatibilityRepository();
    final provider = CompatibilityProvider(repo);
    await request(provider);
    provider.clearOnLogout();
    await provider.retry();
    expect(repo.ids, ['first']);
    expect(
      provider.inputForRestore.values.every((value) => value == null),
      true,
    );
  });
}
