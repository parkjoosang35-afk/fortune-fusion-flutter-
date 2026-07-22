import 'package:flutter/foundation.dart';
import '../data/ranking_repository.dart';
import '../domain/ranking_model.dart';

class RankingProvider extends ChangeNotifier {
  final RankingRepository _repository;
  RankingProvider(this._repository);

  List<RankingEntryModel> _entries = [];
  List<RankingEntryModel> get entries => _entries;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> load({required int myPoints}) async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getWeeklyRanking(myPoints: myPoints);
    if (result.success) {
      _entries = result.data!;
    }
    _isLoading = false;
    notifyListeners();
  }
}
