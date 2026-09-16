import 'package:flutter/foundation.dart';
import '../../../core/api/api_result.dart';
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
