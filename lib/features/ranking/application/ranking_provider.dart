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

  /// [Stage2 결함수정 — 결함-A10-01] 로그아웃 시 이전 계정 기준으로 계산된
  /// "나의 순위" 표시(`isMe` 플래그 등)가 잔존하지 않도록 초기화한다.
  void clearOnLogout() {
    _entries = [];
    _isLoading = false;
    notifyListeners();
  }

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
