/// [타로 섹션 전면 개편 §10 상태 관리 구조]
///
/// 기존 [TarotProvider]는 "결과 조회/히스토리"라는 좁은 책임만 갖고 있다
/// (단일 `LoadState<TarotResultModel>` 관리). 사용자가 요구한 "카드 선택/
/// reveal/저장을 상태머신처럼" 관리하려면 세션 전체(카테고리 선택→질문→
/// 카드선택→셔플→결과→저장)를 아우르는 별도 컨트롤러가 필요하다.
///
/// [TarotProvider]는 폐기하지 않고 "결과 데이터 조회" 책임으로 유지하며,
/// 이 [TarotSessionController]가 "진행 중인 세션의 흐름"을 전담한다
/// (책임 분리). 실제 카드 뽑기(정/역방향, 어떤 카드인지)는 서버가 결정하므로
/// (`TarotRepository._draw`), 카드 선택 화면(⑤)에서 다루는 "셔플/선택"은
/// 아직 정체가 공개되지 않은 카드 뒷면 슬롯을 다루는 것이며, 실제 카드
/// 정보는 [reveal] 단계에서 서버 응답으로 채워진다.
library;

import 'package:flutter/foundation.dart';

import '../domain/tarot_category_model.dart';
import '../domain/tarot_model.dart';
import 'tarot_provider.dart';

/// [타로 섹션 전면 개편 §10-1] 세션 진행 단계.
enum TarotSessionStatus {
  idle, // 세션 시작 전
  categorySelected, // ③ 완료
  questionReady, // ④ 완료(질문/스프레드 확정)
  shuffling, // ⑤ 진입, 덱 셔플 중
  selectingCards, // ⑤ 카드 탭 대기 중
  cardsChosen, // ⑤ 필요 매수 다 선택함(확인 버튼 대기)
  revealing, // ⑥→⑦ API 호출 + 로딩 리추얼 + 리빌 연출 진행 중
  resultReady, // ⑦ 콘텐츠 표시 완료
  saved, // 저장 액션 완료(일시적 상태, resultReady로 복귀)
  error, // API 실패
}

/// 카드 선택 화면(⑤)에서 다루는 "아직 정체가 공개되지 않은" 카드 슬롯.
/// 실제 [TarotCard]/[TarotCardMeta]가 아니라, 화면에 몇 장이 놓여 있고
/// 그중 몇 번 슬롯이 선택되었는지만 관리하는 경량 값 객체.
class TarotFaceDownSlot {
  final int slotIndex;
  final bool isSelected;
  const TarotFaceDownSlot({required this.slotIndex, this.isSelected = false});

  TarotFaceDownSlot copyWith({bool? isSelected}) => TarotFaceDownSlot(
    slotIndex: slotIndex,
    isSelected: isSelected ?? this.isSelected,
  );
}

@immutable
class TarotSessionState {
  final TarotSessionStatus status;
  final TarotCategoryMeta? category;
  final String? spreadType; // one_card / three_card / yes_no
  final String? question;
  // [타로 섹션 전면 개편 §7 P2] 질문 확정(④) 시점에 함께 확정되는 주제 키.
  // 카테고리를 거쳐 왔으면 category.topicKey, 질문화면에서 직접 고른
  // 경우엔 그 선택값이 들어온다. reveal()이 이 값을 서버 topic으로 그대로
  // 사용해 "카테고리 없이 질문화면으로 바로 들어온" 레거시 경로도 주제
  // 정보를 잃지 않는다.
  final String topic;
  final List<TarotFaceDownSlot> deckSlots;
  final List<int> selectedSlotIndexes;
  final TarotResultModel? result;
  final String? errorMessage;

  const TarotSessionState({
    required this.status,
    this.category,
    this.spreadType,
    this.question,
    this.topic = 'general',
    this.deckSlots = const [],
    this.selectedSlotIndexes = const [],
    this.result,
    this.errorMessage,
  });

  const TarotSessionState.initial() : this(status: TarotSessionStatus.idle);

  int get requiredCardCount {
    switch (spreadType) {
      case 'three_card':
        return 3;
      case 'one_card':
      case 'yes_no':
        return 1;
      default:
        return 1;
    }
  }

  bool get isSelectionComplete =>
      selectedSlotIndexes.length >= requiredCardCount;

  TarotSessionState copyWith({
    TarotSessionStatus? status,
    TarotCategoryMeta? category,
    String? spreadType,
    String? question,
    String? topic,
    List<TarotFaceDownSlot>? deckSlots,
    List<int>? selectedSlotIndexes,
    TarotResultModel? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TarotSessionState(
      status: status ?? this.status,
      category: category ?? this.category,
      spreadType: spreadType ?? this.spreadType,
      question: question ?? this.question,
      topic: topic ?? this.topic,
      deckSlots: deckSlots ?? this.deckSlots,
      selectedSlotIndexes: selectedSlotIndexes ?? this.selectedSlotIndexes,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// [타로 섹션 전면 개편 §10-2] 상태 전이 가드를 갖는 세션 컨트롤러.
///
/// 각 메서드는 진입 시 현재 상태가 해당 액션을 허용하는지 먼저 체크한다.
/// 이것이 "상태머신처럼 관리"의 실질적 구현이다 - 중복 탭/빠른 연속 탭 등
/// 임의 순서로 메서드가 호출돼도 상태가 깨지지 않는다.
class TarotSessionController extends ChangeNotifier {
  static const int _faceDownDeckSize = 12; // 화면에 부채꼴로 펼칠 카드 뒷면 수

  TarotSessionState _state = const TarotSessionState.initial();
  TarotSessionState get state => _state;

  /// ③ 카테고리 상세 진입 완료.
  void selectCategory(TarotCategoryMeta category) {
    _state = _state.copyWith(
      status: TarotSessionStatus.categorySelected,
      category: category,
      clearError: true,
    );
    notifyListeners();
  }

  /// ④ 질문/스프레드 확정 완료. 카드 뒷면 슬롯을 새로 생성해 준비한다.
  ///
  /// [topic]을 명시하지 않으면 이미 선택된 카테고리의 topicKey를 쓰고,
  /// 카테고리도 없으면(질문화면 직접 진입) 'general'로 폴백한다 - 어떤
  /// 진입 경로로 와도 topic이 유실되지 않는다.
  void confirmQuestion({
    required String spreadType,
    required String question,
    String? topic,
  }) {
    // 카테고리 없이도(직접 진입) 질문 확정은 허용하되, 이미 카드 선택이
    // 진행된 이후(shuffling 이후) 되돌아와 재확정하는 것도 막지 않고
    // 새 세션으로 취급해 슬롯을 리셋한다(상태 가드를 두지 않는 이유).
    _state = _state.copyWith(
      status: TarotSessionStatus.questionReady,
      spreadType: spreadType,
      question: question,
      topic: topic ?? _state.category?.topicKey ?? _state.topic,
      deckSlots: List.generate(
        _faceDownDeckSize,
        (i) => TarotFaceDownSlot(slotIndex: i),
      ),
      selectedSlotIndexes: const [],
      clearError: true,
    );
    notifyListeners();
  }

  /// ⑤ 진입 - 셔플 연출 시작.
  void beginShuffle() {
    if (_state.status != TarotSessionStatus.questionReady) return;
    _state = _state.copyWith(status: TarotSessionStatus.shuffling);
    notifyListeners();
  }

  /// 셔플 연출(약 1200ms) 완료 콜백 - 카드 탭 대기 상태로 전이.
  void shuffleFinished() {
    if (_state.status != TarotSessionStatus.shuffling) return;
    _state = _state.copyWith(status: TarotSessionStatus.selectingCards);
    notifyListeners();
  }

  /// ⑤ 카드 탭. `selectingCards` 상태에서만 허용(상태 가드).
  void selectSlot(int slotIndex) {
    if (_state.status != TarotSessionStatus.selectingCards) return;
    if (_state.selectedSlotIndexes.contains(slotIndex)) return; // 중복 탭 방지
    if (_state.isSelectionComplete) return;

    final updatedSlots = _state.deckSlots
        .map((s) => s.slotIndex == slotIndex ? s.copyWith(isSelected: true) : s)
        .toList();
    final updatedSelection = [..._state.selectedSlotIndexes, slotIndex];
    final nowComplete = updatedSelection.length >= _state.requiredCardCount;

    _state = _state.copyWith(
      deckSlots: updatedSlots,
      selectedSlotIndexes: updatedSelection,
      status: nowComplete
          ? TarotSessionStatus.cardsChosen
          : TarotSessionStatus.selectingCards,
    );
    notifyListeners();
  }

  /// ⑥→⑦ 결과 요청. 실제 API 호출은 [tarotProvider]에 위임하고, 성공하면
  /// 결과를 세션 상태에 반영한다.
  Future<void> reveal(TarotProvider tarotProvider) async {
    if (_state.status != TarotSessionStatus.cardsChosen) return;
    if (_state.question == null || _state.spreadType == null) return;

    _state = _state.copyWith(status: TarotSessionStatus.revealing);
    notifyListeners();

    try {
      await tarotProvider.draw(
        question: _state.question!,
        spreadType: _state.spreadType!,
        topic: _state.topic,
      );
      final providerState = tarotProvider.state;
      if (providerState.isSuccess && providerState.data != null) {
        _state = _state.copyWith(
          status: TarotSessionStatus.resultReady,
          result: providerState.data,
        );
      } else {
        _state = _state.copyWith(
          status: TarotSessionStatus.error,
          errorMessage: providerState.errorMessage ?? '타로 리딩에 실패했습니다.',
        );
      }
    } catch (e) {
      _state = _state.copyWith(
        status: TarotSessionStatus.error,
        errorMessage: '타로 리딩에 실패했습니다: $e',
      );
    }
    notifyListeners();
  }

  /// ⑦ 저장 완료 처리(일시적 상태 → 짧은 시간 후 resultReady로 복귀).
  void markSaved() {
    if (_state.status != TarotSessionStatus.resultReady) return;
    _state = _state.copyWith(status: TarotSessionStatus.saved);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_state.status == TarotSessionStatus.saved) {
        _state = _state.copyWith(status: TarotSessionStatus.resultReady);
        notifyListeners();
      }
    });
  }

  /// 에러 상태에서 재시도.
  Future<void> retryReveal(TarotProvider tarotProvider) async {
    if (_state.status != TarotSessionStatus.error) return;
    _state = _state.copyWith(
      status: TarotSessionStatus.cardsChosen,
      clearError: true,
    );
    notifyListeners();
    await reveal(tarotProvider);
  }

  /// 타로 서브트리를 벗어날 때 세션 상태를 완전히 초기화한다(§10-3 -
  /// "세션은 한 번의 리추얼"이라는 개념적 일치, 메모리 누수 방지).
  void reset() {
    _state = const TarotSessionState.initial();
    notifyListeners();
  }
}
