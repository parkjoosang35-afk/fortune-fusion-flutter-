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

  /// [Stage2 결함수정 — 결함-A10-01] 로그아웃 시 이전 계정의 타로 결과/이력이
  /// 잔존해 다음 계정에 노출되지 않도록 초기화한다.
  void clearOnLogout() {
    _state = const LoadState.initial();
    _history = [];
    notifyListeners();
  }

  /// [테스트 전용] 실제 서버 왕복(POST /api/public/fortune/tarot) 없이
  /// [TarotResultScreen] 등 화면 위젯 트리를 결과 성공 상태로 곧바로
  /// 전환하기 위한 헬퍼. 위젯 테스트에서만 사용하며, 앱 정상 동작 경로
  /// ([draw]/[retry]/[selectFromHistory])에는 전혀 영향을 주지 않는다.
  @visibleForTesting
  void debugInjectResult(TarotResultModel result) {
    _lastErrorReason = null;
    _state = LoadState.success(result);
    notifyListeners();
  }

  // [프리패스 카테고리 제한 안내 버그 수정] 서버가 draw() 실패 시 함께 내려주는
  // reason('CATEGORY_LIMIT_REACHED' 등)을 보존한다. PassProvider.lastErrorReason과
  // 동일한 목적 - 화면단이 "일반 오류"와 "이용횟수 초과"를 구분할 수 있게 한다.
  String? _lastErrorReason;
  String? get lastErrorReason => _lastErrorReason;

  String? _question;
  String _spreadType = 'one_card';
  String _topic = 'general';
  String? _optionA;
  String? _optionB;

  Future<void> draw({
    required String question,
    required String spreadType,
    String topic = 'general',
    String? optionA,
    String? optionB,
  }) async {
    _question = question;
    _spreadType = spreadType;
    _topic = topic;
    _optionA = optionA;
    _optionB = optionB;

    _state = const LoadState.loading();
    notifyListeners();

    // [65종 타로 리딩엔진 §계획3] 5카드 분기 추가. 기존에는 이 분기가
    // 없어 5카드 선택 시 else절(drawOneCard, topic 고정 'general')로
    // 떨어지는 버그가 있었다.
    // [65종 타로 리딩엔진 §계획1 - choice_ab] A/B 양자택일 분기 추가.
    final result = spreadType == 'choice_ab'
        ? await _repository.drawChoiceAb(
            question: question,
            optionA: optionA ?? '',
            optionB: optionB ?? '',
            topic: topic,
          )
        : spreadType == 'five_card'
        ? await _repository.drawFiveCards(question: question, topic: topic)
        : spreadType == 'three_card'
        ? await _repository.drawThreeCards(question: question, topic: topic)
        : spreadType == 'yes_no'
        ? await _repository.drawYesNo(question: question, topic: topic)
        : await _repository.drawOneCard(question: question);

    if (result.success && result.data != null) {
      _lastErrorReason = null;
      _state = LoadState.success(result.data!);
    } else {
      _lastErrorReason = result.errorCode;
      _state = LoadState.error(result.errorMessage ?? '타로 리딩에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_question == null) return;
    await draw(
      question: _question!,
      spreadType: _spreadType,
      topic: _topic,
      optionA: _optionA,
      optionB: _optionB,
    );
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
