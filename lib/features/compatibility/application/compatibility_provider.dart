import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/compatibility_repository.dart';
import '../domain/compatibility_model.dart';

class CompatibilityProvider extends ChangeNotifier {
  final CompatibilityRepository _repository;
  CompatibilityProvider(this._repository);

  LoadState<CompatibilityResultModel> _state = const LoadState.initial();
  LoadState<CompatibilityResultModel> get state => _state;

  List<CompatibilityResultModel> _history = [];
  List<CompatibilityResultModel> get history => _history;

  String? _birthDateA;
  String? _birthDateB;
  String? _nameA;
  String? _nameB;

  Future<void> request({
    required String birthDateA,
    required String birthDateB,
    String? nameA,
    String? nameB,
  }) async {
    _birthDateA = birthDateA;
    _birthDateB = birthDateB;
    _nameA = nameA;
    _nameB = nameB;

    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.requestCompatibility(
      birthDateA: birthDateA,
      birthDateB: birthDateB,
      nameA: nameA,
      nameB: nameB,
    );

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '궁합 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_birthDateA == null || _birthDateB == null) return;
    await request(
      birthDateA: _birthDateA!,
      birthDateB: _birthDateB!,
      nameA: _nameA,
      nameB: _nameB,
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
