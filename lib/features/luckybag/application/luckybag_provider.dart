import 'package:flutter/foundation.dart';
import '../data/luckybag_repository.dart';
import '../domain/luckybag_model.dart';

class LuckyBagProvider extends ChangeNotifier {
  final LuckyBagRepository _repository;
  LuckyBagProvider(this._repository);

  LuckyBagSummary? _summary;
  bool _isLoading = false;

  LuckyBagSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getPendingSummary();
    if (result.success) _summary = result.data;
    _isLoading = false;
    notifyListeners();
  }
}
