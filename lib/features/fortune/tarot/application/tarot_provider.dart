import 'package:flutter/foundation.dart';
import '../../../../core/utils/load_state.dart';
import '../data/tarot_repository.dart';
import '../domain/tarot_model.dart';

/// 07단계 §2.1 화면 단위 지역 Provider - TarotProvider
class TarotProvider extends ChangeNotifier {
  final TarotRepository _repository;
  TarotProvider(this._repository);

  LoadState<TarotResultModel> _state = const LoadState.initial();
  LoadState<TarotResultModel> get state => _state;

  List<TarotResultModel> _history = [];
  List<TarotResultModel> get history => _history;

  String? _question;
  String _spreadType = 'one_card';

  Future<void> draw({
    required String question,
    required String spreadType,
  }) async {
    _question = question;
    _spreadType = spreadType;

    _state = const LoadState.loading();
    notifyListeners();

    final result = spreadType == 'three_card'
        ? await _repository.drawThreeCard(question: question)
        : await _repository.drawOneCard(question: question);

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '타로 리딩에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_question == null) return;
    await draw(question: _question!, spreadType: _spreadType);
  }

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = result.data!;
      notifyListeners();
    }
  }

  void selectFromHistory(String id) {
    final found = _history.where((e) => e.id == id).toList();
    if (found.isNotEmpty) {
      _state = LoadState.success(found.first);
      notifyListeners();
    }
  }
}
