import 'package:flutter/foundation.dart';
import '../data/amulet_repository.dart';
import '../domain/amulet_model.dart';

class AmuletProvider extends ChangeNotifier {
  final AmuletRepository _repository;
  AmuletProvider(this._repository);

  AmuletSummary? _summary;
  bool _isLoading = false;

  AmuletSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getActiveSummary();
    if (result.success) _summary = result.data;
    _isLoading = false;
    notifyListeners();
  }
}
