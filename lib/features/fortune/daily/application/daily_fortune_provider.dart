import 'package:flutter/foundation.dart';
import '../data/daily_fortune_repository.dart';
import '../domain/daily_fortune_model.dart';

class DailyFortuneProvider extends ChangeNotifier {
  final DailyFortuneRepository _repository;
  DailyFortuneProvider(this._repository);

  DailyFortuneModel? _today;
  bool _isLoading = false;
  String? _lastError;

  DailyFortuneModel? get today => _today;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// [오늘의 운세 표준 플로우 §3/§7] 로딩 화면에서 성공 여부를 판단해
  /// 실패 시 재시도 다이얼로그를 띄울 수 있도록 bool을 반환한다.
  /// (기존 호출부는 반환값을 쓰지 않아도 동작에 영향이 없다.)
  Future<bool> loadToday() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getToday();
    if (result.success) {
      _today = result.data;
      _lastError = null;
    } else {
      _lastError = result.errorMessage;
    }
    _isLoading = false;
    notifyListeners();
    return result.success;
  }
}
