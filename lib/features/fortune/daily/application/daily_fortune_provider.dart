import 'package:flutter/foundation.dart';
import '../data/daily_fortune_repository.dart';
import '../domain/daily_fortune_model.dart';

class DailyFortuneProvider extends ChangeNotifier {
  final DailyFortuneRepository _repository;
  DailyFortuneProvider(this._repository);

  DailyFortuneModel? _today;
  bool _isLoading = false;

  DailyFortuneModel? get today => _today;
  bool get isLoading => _isLoading;

  Future<void> loadToday() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getToday();
    if (result.success) _today = result.data;
    _isLoading = false;
    notifyListeners();
  }
}
