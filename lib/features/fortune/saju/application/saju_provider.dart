import 'package:flutter/foundation.dart';
import '../../../../core/utils/load_state.dart';
import '../data/saju_repository.dart';
import '../domain/saju_model.dart';

/// 07단계 §2.1 화면 단위 지역 Provider 예시 - SajuProvider
class SajuProvider extends ChangeNotifier {
  final SajuRepository _repository;
  SajuProvider(this._repository);

  LoadState<SajuResultModel> _state = const LoadState.initial();
  LoadState<SajuResultModel> get state => _state;

  List<SajuResultModel> _history = [];
  List<SajuResultModel> get history => _history;

  String? _birthDate;
  String? _birthTime;
  bool _isLunar = false;
  List<String> _topics = [];

  Future<void> requestSaju({
    required String birthDate,
    String? birthTime,
    required bool isLunar,
    required List<String> topics,
  }) async {
    _birthDate = birthDate;
    _birthTime = birthTime;
    _isLunar = isLunar;
    _topics = topics;

    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.requestSaju(
      birthDate: birthDate,
      birthTime: birthTime,
      isLunar: isLunar,
      topics: topics,
    );

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '사주 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_birthDate == null) return;
    await requestSaju(
      birthDate: _birthDate!,
      birthTime: _birthTime,
      isLunar: _isLunar,
      topics: _topics,
    );
  }

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = result.data!;
      notifyListeners();
    }
  }

  /// 히스토리 목록에서 특정 결과를 선택해 결과화면 상태로 반영한다.
  /// (히스토리에 없으면 아무 것도 하지 않고 현재 state를 유지 - 방금 생성한 결과를 그대로 보여주는 경우)
  void selectFromHistory(String id) {
    final found = _history.where((e) => e.id == id).toList();
    if (found.isNotEmpty) {
      _state = LoadState.success(found.first);
      notifyListeners();
    }
  }
}
