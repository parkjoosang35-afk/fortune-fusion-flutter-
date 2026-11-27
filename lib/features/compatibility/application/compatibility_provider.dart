import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/compatibility_repository.dart';
import '../domain/compatibility_model.dart';
import '../../result_access/domain/result_access_model.dart';
import '../../result_access/domain/pending_result_access_return.dart';
import '../../../core/auth/auth_token_store.dart';

/// [궁합(C그룹) 신규 구현] 궁합 화면 단위 지역 Provider.
/// NameFortuneProvider/SajuProvider와 동일한 LoadState 기반 패턴을 그대로
/// 재사용한다(신규 상태관리 구조 없음).
class CompatibilityProvider extends ChangeNotifier {
  final CompatibilityRepository _repository;
  CompatibilityProvider(this._repository);

  LoadState<CompatibilityResultModel> _state = const LoadState.initial();
  LoadState<CompatibilityResultModel> get state => _state;

  List<CompatibilityResultModel> _history = [];
  List<CompatibilityResultModel> get history => _history;

  CompatibilityType? _type;
  String? _nameA;
  String? _nameB;
  String? _birthDateA;
  String? _birthDateB;
  ResultAccessBeginResult? _access;
  String? _adSessionId;
  int _sessionGeneration = 0;
  bool _needsNewAccess = false;
  bool get needsNewAccess => _needsNewAccess;
  Map<String, dynamic> get inputForRestore => {
    'type': _type?.apiValue,
    'nameA': _nameA,
    'nameB': _nameB,
    'birthDateA': _birthDateA,
    'birthDateB': _birthDateB,
  };

  /// [Stage2 결함수정 — 결함-A10-01] 로그아웃 시 이전 계정이 입력했던
  /// 이름/생년월일(개인정보) 및 궁합 조회 이력이 잔존해 다음 계정에
  /// 노출되지 않도록 초기화한다.
  void clearOnLogout() {
    _state = const LoadState.initial();
    _history = [];
    _type = null;
    _nameA = null;
    _nameB = null;
    _birthDateA = null;
    _birthDateB = null;
    _access = null;
    _adSessionId = null;
    _sessionGeneration++;
    _needsNewAccess = false;
    PendingResultAccessReturnStore.clear();
    notifyListeners();
  }

  /// [테스트 전용 — 외부 검수 지시 ③ Task 5] 실제 서버 왕복(POST
  /// /api/public/compatibility/request) 없이 [CompatibilityResultScreen]
  /// 위젯 트리를 결과 성공 상태로 곧바로 전환하기 위한 헬퍼.
  /// TarotProvider.debugInjectResult와 동일한 패턴 — 위젯 테스트 전용이며
  /// 앱 정상 동작 경로(request/retry/loadHistory)에는 전혀 영향을 주지
  /// 않는다.
  @visibleForTesting
  void debugInjectResult(CompatibilityResultModel result) {
    _state = LoadState.success(result);
    notifyListeners();
  }

  Future<void> request({
    required CompatibilityType type,
    required String nameA,
    required String nameB,
    required String birthDateA,
    required String birthDateB,
    required ResultAccessBeginResult access,
    String? adSessionId,
  }) async {
    if (_state.status == LoadStatus.loading) return;
    final session = _sessionGeneration;
    _state = const LoadState.loading();
    notifyListeners();
    final stored = await PendingResultAccessReturnStore.peek();
    final storedAccess = stored?.userInput['_resultAccess'];
    if (adSessionId == null &&
        storedAccess is Map &&
        storedAccess['transactionId'] == access.transactionId) {
      adSessionId = stored?.userInput['_adSessionId'] as String?;
    }
    if (session != _sessionGeneration) return;
    _adSessionId = adSessionId;
    _access = access;
    _needsNewAccess = false;
    _type = type;
    _nameA = nameA;
    _nameB = nameB;
    _birthDateA = birthDateA;
    _birthDateB = birthDateB;

    _state = const LoadState.loading();
    notifyListeners();

    await PendingResultAccessReturnStore.save(
      PendingResultAccessReturn(
        contentType: 'compatibility',
        returnRoute: '/compatibility/input',
        savedAt: DateTime.now(),
        userInput: {
          ...inputForRestore,
          '_ownerUserId': await AuthTokenStore.getCurrentUserId(),
          '_resultAccess': {
            'transactionId': access.transactionId,
            'paymentMethod': access.paymentMethod.code,
            'status': access.status,
            'amount': access.amount,
            'idempotent': access.idempotent,
          },
          if (adSessionId != null) '_adSessionId': adSessionId,
        },
      ),
    );
    if (session != _sessionGeneration) return;
    final result = await _repository.requestCompatibility(
      type: type,
      nameA: nameA,
      nameB: nameB,
      birthDateA: birthDateA,
      birthDateB: birthDateB,
      paymentMethod: access.paymentMethod.code,
      transactionId: access.transactionId,
      adSessionId: adSessionId,
    );
    if (session != _sessionGeneration) return;
    if (result.success ||
        const {
          'GENERATION_FAILED',
          'PROMPT_NOT_CONFIGURED',
          'INVALID_INPUT',
          'DAILY_ABSOLUTE_LIMIT_REACHED',
          'TRANSACTION_ALREADY_PROCESSED',
        }.contains(result.errorCode)) {
      await PendingResultAccessReturnStore.clearTransaction(
        access.transactionId,
      );
    }

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      // 네트워크 오류/진행 중은 동일 거래로 확인한다. 환불된 거래만 새 게이트가 필요하다.
      _needsNewAccess = const {
        'GENERATION_FAILED',
        'PROMPT_NOT_CONFIGURED',
        'INVALID_INPUT',
        'DAILY_ABSOLUTE_LIMIT_REACHED',
        'TRANSACTION_ALREADY_PROCESSED',
      }.contains(result.errorCode);
      _state = LoadState.error(result.errorMessage ?? '궁합 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry({ResultAccessBeginResult? access}) async {
    if (_type == null || _nameA == null || _nameB == null || _access == null) {
      return;
    }
    if (_needsNewAccess && access == null) return;
    await request(
      type: _type!,
      nameA: _nameA!,
      nameB: _nameB!,
      birthDateA: _birthDateA ?? '',
      birthDateB: _birthDateB ?? '',
      access: access ?? _access!,
      adSessionId: access == null ? _adSessionId : null,
    );
  }

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = result.data!;
      notifyListeners();
    }
  }
}
