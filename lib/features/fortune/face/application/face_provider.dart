import 'package:flutter/foundation.dart';
import '../../../../core/utils/load_state.dart';
import '../data/face_repository.dart';
import '../domain/face_model.dart';

class FaceProvider extends ChangeNotifier {
  final FaceRepository _repository;
  FaceProvider(this._repository);

  LoadState<FaceResultModel> _state = const LoadState.initial();
  LoadState<FaceResultModel> get state => _state;

  List<FaceResultModel> _history = [];
  List<FaceResultModel> get history => _history;

  Future<void> analyze() async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.analyze();
    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '관상 분석에 실패했습니다.');
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
