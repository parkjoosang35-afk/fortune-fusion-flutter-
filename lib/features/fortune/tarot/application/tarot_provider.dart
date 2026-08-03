import 'package:flutter/foundation.dart';
import '../../../../core/utils/load_state.dart';
import '../data/tarot_repository.dart';
import '../domain/tarot_model.dart';

/// 07단계 §2.1 화면 단위 지역 Provider - TarotProvider
///
/// 07단계(추가) §3.6 - 타로상담 기능 최적화: [draw]에 선택적 [topic]
/// 파라미터를 추가한다(기본값 'general'). `spreadType == 'three_card'`인
/// 경우 78장 풀덱 + 주제별 해석을 지원하는 [TarotRepository.drawThreeCards]로
/// 라우팅하고, `one_card`는 기존 [TarotRepository.drawOneCard](15장 고정
/// 덱)를 그대로 유지한다. 기존 호출부([TarotQuestionScreen] 등)는 topic을
/// 넘기지 않아도 동작이 그대로 유지된다(하위 호환).
class TarotProvider extends ChangeNotifier {
  final TarotRepository _repository;
  TarotProvider(this._repository);

  LoadState<TarotResultModel> _state = const LoadState.initial();
  LoadState<TarotResultModel> get state => _state;

  List<TarotResultModel> _history = [];
  List<TarotResultModel> get history => _history;

  String? _question;
  String _spreadType = 'one_card';
  String _topic = 'general';

  Future<void> draw({
    required String question,
    required String spreadType,
    String topic = 'general',
  }) async {
    _question = question;
    _spreadType = spreadType;
    _topic = topic;

    _state = const LoadState.loading();
    notifyListeners();

    final result = spreadType == 'three_card'
        ? await _repository.drawThreeCards(question: question, topic: topic)
        : spreadType == 'yes_no'
        ? await _repository.drawYesNo(question: question, topic: topic)
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
    await draw(question: _question!, spreadType: _spreadType, topic: _topic);
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
