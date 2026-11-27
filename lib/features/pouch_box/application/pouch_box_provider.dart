import 'package:flutter/foundation.dart';
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../data/pouch_box_repository.dart';
import '../domain/pouch_box_model.dart';

/// [행운상자 - 복주머니 탭 신규 기능] 하단바 "복주머니" 탭 화면(PouchBoxTabScreen)의
/// 전역 상태. 오늘 현황 캐시 + 시청시작/완료 API 위임을 담당한다. 실제 화면
/// 흐름(그리드→광고→흔들림→폭발→결과 상태머신)은 화면 위젯이 담당하고,
/// 이 Provider는 API 호출만 얇게 감싼다(FortuneAdProvider와 동일한 분리 원칙).
class PouchBoxProvider extends ChangeNotifier {
  final PouchBoxRepository _repository;
  PouchBoxProvider(this._repository);

  PouchBoxState _state = PouchBoxState.initial;
  bool _isLoading = false;
  String? _error;

  PouchBoxState get state => _state;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get dailyLeft => _state.dailyLeft;
  bool get canOpenToday => _state.watchable && _state.dailyLeft > 0;

  Future<void> loadState() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _repository.getState();
    if (result.success) {
      _state = result.data!;
    } else {
      _error = result.errorMessage;
      // [비회원 둘러보기 결함수정 — 복주머니(pouch_box) 화면 비회원 오표시]
      // 조회 실패 시 과거에는 `_state`를 그대로 방치해, 직전에 유지되던
      // 낙관적 기본값([PouchBoxState.initial], watchable:true)이 화면에
      // 계속 노출되는 문제가 있었다. 실패 시점에 비회원임이 확인되면
      // (네트워크 오류 등 다른 이유로 실패했더라도) 안전한 "미로그인"
      // 상태로 명시적으로 되돌려, 비회원이 정상 회원처럼 보이는 일이
      // 없도록 한다. 정상 회원의 실패 처리(예: 네트워크 일시 오류)는
      // 기존처럼 _state를 유지한 채 _error만 노출한다(회귀 방지).
      if (!await AuthTokenStore.isLoggedIn()) {
        _state = PouchBoxState.notLoggedIn;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<ApiResult<PouchBoxSession>> startWatch() {
    return _repository.start();
  }

  Future<ApiResult<PouchBoxRewardResult>> completeWatch({
    required String sessionId,
    int? watchSeconds,
  }) async {
    final result = await _repository.complete(
      sessionId: sessionId,
      watchSeconds: watchSeconds,
    );
    if (result.success) {
      // 결과의 dailyLeft로 로컬 상태 즉시 갱신(재조회 없이).
      _state = PouchBoxState(
        dailyLimit: _state.dailyLimit,
        todayOpenedCount: _state.dailyLimit - result.data!.dailyLeft,
        dailyLeft: result.data!.dailyLeft,
        watchable: result.data!.dailyLeft > 0,
      );
      notifyListeners();
    }
    return result;
  }
}
