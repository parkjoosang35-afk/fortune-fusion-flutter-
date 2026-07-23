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

  List<CompatibilityCompareRow> _compareRows = [];
  List<CompatibilityCompareRow> get compareRows => _compareRows;

  String? _birthDateA;
  String? _birthDateB;
  String? _nameA;
  String? _nameB;
  CompatibilityType _type = CompatibilityType.love;

  Future<void> request({
    required String birthDateA,
    required String birthDateB,
    String? nameA,
    String? nameB,
    CompatibilityType type = CompatibilityType.love,
  }) async {
    _birthDateA = birthDateA;
    _birthDateB = birthDateB;
    _nameA = nameA;
    _nameB = nameB;
    _type = type;

    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.requestCompatibility(
      birthDateA: birthDateA,
      birthDateB: birthDateB,
      nameA: nameA,
      nameB: nameB,
      type: type,
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
      type: _type,
    );
  }

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = result.data!;
      notifyListeners();
    }
  }

  Future<void> loadResultById(String id) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.getResultById(id);
    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '결과를 불러오지 못했습니다.');
    }
    notifyListeners();
  }

  Future<bool> toggleSave(String id) async {
    final result = await _repository.saveResult(id);
    if (!result.success || result.data == null) return false;
    _syncCurrentAndHistory(result.data!);
    notifyListeners();
    return result.data!.isSaved;
  }

  Future<String?> generateShareLink(String id) async {
    final result = await _repository.generateShareLink(id);
    if (!result.success || result.data == null) return null;
    _syncCurrentAndHistory(result.data!);
    notifyListeners();
    return result.data!.shareUrl;
  }

  Future<bool> compare(List<String> ids) async {
    final result = await _repository.compare(ids);
    if (!result.success) return false;
    _compareRows = result.data!;
    notifyListeners();
    return true;
  }

  void _syncCurrentAndHistory(CompatibilityResultModel updated) {
    if (_state.isSuccess && _state.data!.id == updated.id) {
      _state = LoadState.success(updated);
    }
    final index = _history.indexWhere((r) => r.id == updated.id);
    if (index != -1) _history[index] = updated;
  }
}
