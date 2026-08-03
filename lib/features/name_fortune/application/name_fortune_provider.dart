import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/name_fortune_repository.dart';
import '../domain/name_fortune_model.dart';

/// [운세 카테고리 확장] 이름 운세(성명학) 화면 단위 지역 Provider.
/// SajuProvider/CompatibilityProvider와 동일한 LoadState 기반 패턴을 그대로
/// 재사용한다(신규 상태관리 구조 없음).
class NameFortuneProvider extends ChangeNotifier {
  final NameFortuneRepository _repository;
  NameFortuneProvider(this._repository);

  LoadState<NameFortuneResultModel> _state = const LoadState.initial();
  LoadState<NameFortuneResultModel> get state => _state;

  List<NameFortuneResultModel> _history = [];
  List<NameFortuneResultModel> get history => _history;

  String? _name;
  String? _hanja;
  String? _birthDate;
  String? _gender;

  Future<void> request({
    required String name,
    String? hanja,
    String? birthDate,
    String? gender,
  }) async {
    _name = name;
    _hanja = hanja;
    _birthDate = birthDate;
    _gender = gender;

    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.requestNameFortune(
      name: name,
      hanja: hanja,
      birthDate: birthDate,
      gender: gender,
    );

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '이름 운세 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_name == null) return;
    await request(
      name: _name!,
      hanja: _hanja,
      birthDate: _birthDate,
      gender: _gender,
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
