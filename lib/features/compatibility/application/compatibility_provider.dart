import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/compatibility_repository.dart';
import '../domain/compatibility_model.dart';

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

  Future<void> request({
    required CompatibilityType type,
    required String nameA,
    required String nameB,
    required String birthDateA,
    required String birthDateB,
  }) async {
    _type = type;
    _nameA = nameA;
    _nameB = nameB;
    _birthDateA = birthDateA;
    _birthDateB = birthDateB;

    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.requestCompatibility(
      type: type,
      nameA: nameA,
      nameB: nameB,
      birthDateA: birthDateA,
      birthDateB: birthDateB,
    );

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '궁합 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_type == null || _nameA == null || _nameB == null) return;
    await request(
      type: _type!,
      nameA: _nameA!,
      nameB: _nameB!,
      birthDateA: _birthDateA ?? '',
      birthDateB: _birthDateB ?? '',
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
