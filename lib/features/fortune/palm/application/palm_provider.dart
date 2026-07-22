import 'package:flutter/foundation.dart';
import '../../../../core/utils/load_state.dart';
import '../data/palm_repository.dart';
import '../domain/palm_model.dart';

class PalmProvider extends ChangeNotifier {
  final PalmRepository _repository;
  PalmProvider(this._repository);

  LoadState<PalmResultModel> _state = const LoadState.initial();
  LoadState<PalmResultModel> get state => _state;

  List<PalmResultModel> _history = [];
  List<PalmResultModel> get history => _history;

  Future<void> analyze() async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.analyze();
    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '손금 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() => analyze();

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = result.data!;
      notifyListeners();
    }
  }

  void selectFromHistory(String id) {
    final found = _history.where((e) => e.id == id).toList();
    if (found.isNotEmpty) {
      _state = LoadState.success(found.first);
      notifyListeners();
    }
  }
}
