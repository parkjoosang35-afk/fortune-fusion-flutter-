import 'package:flutter/foundation.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation_ad_source_model.dart';
import '../domain/consultation_model.dart';
import '../../fortune/saju/application/saju_provider.dart';
import '../../fortune/saju/domain/saju_model.dart';
import '../../fortune/tarot/application/tarot_provider.dart';
import '../../fortune/tarot/domain/tarot_model.dart';
import '../../fortune/tarot/domain/tarot_text_engine.dart';

/// 07단계(추가) §3.5 - 상담 유형별 채팅 흐름에서 현재 어떤 입력을 기다리고 있는지를
/// 나타내는 단계. ConsultationChatScreen은 이 값을 기준으로 하단 입력 UI
/// (InputBar / 날짜·시간 피커 / 성별 버튼 / 카드 선택 버튼)를 동적으로 전환한다.
enum ConsultationStep {
  /// 자유 대화(일반상담 기본 상태, 사주 계산·타로 카드 해석 완료 이후에도
  /// 이 상태로 복귀해 후속 질문을 이어갈 수 있다).
  chatting,
  // ── 사주상담 정보 수집 단계 ──
  inputName,
  inputBirthDate,
  inputBirthTime,
  selectGender,
  calculatingSaju,
  // ── 타로상담 정보 수집 단계 ──
  inputTarotQuestion,
  // 07단계(추가) §3.6 - 20개 주제(연애/재물/취업 등) 중 하나를 선택하는 단계.
  // 고민 입력 이후, 카드를 뽑기 전에 진입한다.
  selectTarotTopic,
  selectTarotCard,
  drawingTarot,
}

/// [AI 상담 채팅 실연동] `POST /api/public/consultation/session` 호출 결과를
/// 화면단이 분기 처리할 수 있도록 하는 결과값.
///
/// - [started]: 세션이 정상 시작됨(신규 생성 또는 오늘 세션 재사용) — 즉시 채팅 화면으로 진입 가능.
/// - [needsAdReward]: 오늘 첫 세션인데 광고 시청 완료 기록이 없어 서버가 거부함
///   (`reason: AD_REWARD_REQUIRED`) — 화면이 `runConsultationAdGateAndStart()`로
///   광고 시청 게이트를 띄운 뒤 [ConsultationProvider.startSession]을 재호출해야 한다.
/// - [error]: 그 외 오류(네트워크/서버 오류 등) — [ConsultationProvider.lastErrorMessage] 참고.
enum ConsultationStartOutcome { started, needsAdReward, error }

/// 07단계 §2.1 화면 단위 지역 Provider - ConsultationProvider
/// 09단계 §1.2 스트리밍 응답을 메시지 리스트의 마지막 AI 메시지에 누적 반영한다.
///
/// 07단계(추가) §3.4 - 상담 유형 변경(사주/타로/일반) UX 지원을 위해
/// [clearMessages], [changeType]을 추가하고, 전송 버튼 활성/비활성 제어를 위한
/// [isLoading] 상태를 함께 노출한다.
///
/// 07단계(추가) §3.5 - 사주상담/타로상담을 별도 결과 화면으로 이동하지 않고
/// 채팅 흐름 안에서 완결시키기 위해 [currentStep] 기반의 단계형 정보 수집
/// ([userInfo]/[pendingQuestion])과 [SajuProvider]/[TarotProvider] 연동
/// ([_calculateSaju]/[_drawTarotCards])을 추가한다.
///
/// [AI 상담 채팅 실연동] 실제 서버(`ConsultationRepository`)와 통신하도록 교체하며,
/// 어뷰징 방지 3요소(세션당 20턴 한도, 유저당 하루 1세션 + 광고게이트, 메시지 500자
/// 제한)를 UI 상태([sessionId]/[turnCount]/[maxTurns]/[isSessionExhausted])로
/// 노출해 화면이 즉시 반응할 수 있게 한다. 최종 판정은 항상 서버가 내리며,
/// 이 상태들은 서버 응답을 그대로 미러링한 값이다(클라이언트 임의 재판단 없음).
class ConsultationProvider extends ChangeNotifier {
  final ConsultationRepository _repository;
  ConsultationProvider(this._repository);

  // 07단계(추가) §3.5 - app.dart의 ChangeNotifierProxyProvider2에서 주입된다.
  // ConsultationProvider가 SajuProvider/TarotProvider를 직접 생성하지 않고
  // 앱 전역에 이미 등록된 인스턴스를 재사용해, 사주/타로 히스토리 화면과 상태를 공유한다.
  SajuProvider? _sajuProvider;
  TarotProvider? _tarotProvider;

  /// 07단계(추가) §3.5 - app.dart ProxyProvider의 update 콜백에서 매 빌드마다 호출된다.
  /// 참조만 갱신하며 notifyListeners()는 호출하지 않는다(불필요한 리빌드 방지).
  void attachFortuneProviders(SajuProvider saju, TarotProvider tarot) {
    _sajuProvider = saju;
    _tarotProvider = tarot;
  }

  String? _type;
  String get type => _type ?? 'general';

  // [AI 상담 채팅 실연동] 서버가 발급한 세션 식별자. null이면 아직 세션이
  // 시작되지 않은 상태(자유 대화 전송 자체가 불가능해야 함).
  int? _sessionId;
  int? get sessionId => _sessionId;

  int _turnCount = 0;
  int get turnCount => _turnCount;

  int _maxTurns = ConsultationLimits.defaultMaxTurns;
  int get maxTurns => _maxTurns;

  /// 오늘 이 세션에서 이용 가능한 대화 횟수(20턴)를 모두 사용했는지 여부.
  /// true면 자유 대화 전송을 막고 안내 메시지만 노출한다.
  bool get isSessionExhausted => _turnCount >= _maxTurns;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  List<ConsultationMessage> _messages = [];
  List<ConsultationMessage> get messages => _messages;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  bool _isStarting = false;
  bool get isStarting => _isStarting;

  // 07단계(추가) §3.5 - 사주 계산/타로 카드 뽑기 중(로딩)일 때 true.
  bool _isCalculating = false;
  bool get isCalculating => _isCalculating;

  // 07단계(추가) §3.4/3.5 - 세션 시작·스트리밍·계산 중 어느 하나라도 진행 중이면 true.
  // ConsultationChatScreen의 전송 버튼/선택 버튼 활성·비활성 제어에 사용된다.
  bool get isLoading => _isStarting || _isStreaming || _isCalculating;

  // 07단계(추가) §3.5 - 현재 입력 대기 단계. 기본값은 자유 대화.
  ConsultationStep _currentStep = ConsultationStep.chatting;
  ConsultationStep get currentStep => _currentStep;

  // 07단계(추가) §3.5 - 사주상담용 수집 정보(name/birthDate/birthTime/gender).
  Map<String, String> _userInfo = {};
  Map<String, String> get userInfo => _userInfo;

  // 07단계(추가) §3.5 - 타로상담에서 사용자가 입력한 질문을 카드 선택 전까지 임시 보관.
  String? _pendingQuestion;
  String? get pendingQuestion => _pendingQuestion;

  // 07단계(추가) §3.6 - 타로상담에서 사용자가 선택한 주제(20개 중 하나).
  // 카드를 뽑기 전, 고민 입력 다음 단계에서 선택하며 기본값은 'general'(종합운).
  String _selectedTopic = 'general';
  String get selectedTopic => _selectedTopic;

  /// 07단계(추가) §3.6 - 화면(ConsultationChatScreen)에서 주제 선택 버튼 목록을
  /// 렌더링할 때 참조하는 20개 주제 메타데이터.
  List<TarotTopic> get tarotTopicOptions => tarotTopics;

  // 메시지 id 충돌 방지용 시퀀스(동일 밀리초 내 연속 추가 대비).
  int _msgSeq = 0;
  String _nextId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_msgSeq++}';

  /// [AI 상담 채팅 실연동] 상담 세션을 시작한다.
  ///
  /// 1) [adRewardLogId] 없이 먼저 시도한다 — 오늘 이미 세션이 있으면 서버가
  ///    광고 재검증 없이 그대로 재사용해 반환한다(idempotent).
  /// 2) 오늘 첫 세션인데 [adRewardLogId]가 없으면 서버가 403 +
  ///    `reason: AD_REWARD_REQUIRED`로 거부하며, 이 메서드는
  ///    [ConsultationStartOutcome.needsAdReward]를 반환한다 — 화면이
  ///    `runConsultationAdGateAndStart()`로 광고를 시청시킨 뒤 발급받은
  ///    adRewardLogId로 이 메서드를 다시 호출해야 한다.
  Future<ConsultationStartOutcome> startSession(
    String type, {
    int? adRewardLogId,
  }) async {
    _isStarting = true;
    _messages = [];
    _userInfo = {};
    _pendingQuestion = null;
    _currentStep = ConsultationStep.chatting;
    _lastErrorMessage = null;
    notifyListeners();

    final result = await _repository.createSession(
      type: type,
      adRewardLogId: adRewardLogId,
    );

    if (!result.success || result.data == null) {
      _isStarting = false;
      _lastErrorMessage = result.errorMessage;
      notifyListeners();
      if (result.errorCode == 'AD_REWARD_REQUIRED') {
        return ConsultationStartOutcome.needsAdReward;
      }
      return ConsultationStartOutcome.error;
    }

    final session = result.data!;
    // 오늘 세션을 재사용한 경우 서버가 실제 세션의 type을 내려준다(요청한
    // type과 다를 수 있음 — 예: 오늘 이미 saju 세션이 있는데 general로 재진입).
    _type = session.type;
    _sessionId = session.sessionId;
    _turnCount = session.turnCount;
    _maxTurns = session.maxTurns;
    _messages = List.of(session.messages);

    // 07단계(추가) §3.5 - 유형별 최초 안내 메시지 + 첫 입력 단계 지정.
    // [AI 상담 채팅 실연동] 오늘 처음 생성된 세션(isNew=true)일 때만 사주/타로
    // 정보 수집 흐름으로 진입한다. 기존 세션을 재사용한 경우(isNew=false)에는
    // 이미 오간 대화 히스토리를 그대로 보여주고 자유 대화 상태로 이어간다.
    if (session.isNew) {
      if (session.type == 'saju') {
        _currentStep = ConsultationStep.inputName;
        _appendAiMessage('먼저 몇 가지 정보를 알려주시면 정확한 사주를 봐드릴게요. 성함을 알려주세요.');
      } else if (session.type == 'tarot') {
        _currentStep = ConsultationStep.inputTarotQuestion;
        _appendAiMessage('마음에 담고 있는 고민을 편하게 말씀해주세요.');
      } else {
        _currentStep = ConsultationStep.chatting;
      }
    } else {
      _currentStep = ConsultationStep.chatting;
    }

    _isStarting = false;
    notifyListeners();
    return ConsultationStartOutcome.started;
  }

  /// [AI 상담 채팅 실연동] 세션 시작 전 광고게이트에 노출할 리워드 광고소스
  /// 목록을 조회한다. 실패 시 빈 목록을 반환하며 [lastErrorMessage]에 사유를 남긴다.
  Future<List<ConsultationAdSourceModel>> fetchAdSources() async {
    final result = await _repository.getAdSources();
    if (!result.success || result.data == null) {
      _lastErrorMessage = result.errorMessage;
      return const [];
    }
    return result.data!;
  }

  /// [AI 상담 채팅 실연동] 광고 시청 완료 후 시청기록(OpenPassAdRewardLog)만
  /// 생성한다(PassPolicy/UserPass는 발급하지 않음). 성공 시 이 값을
  /// [startSession]의 `adRewardLogId`로 전달해 세션 생성을 재시도해야 한다.
  Future<int?> completeAdReward(int adSourceId) async {
    final result = await _repository.completeAdReward(adSourceId: adSourceId);
    if (!result.success || result.data == null) {
      _lastErrorMessage = result.errorMessage;
      return null;
    }
    return result.data;
  }

  /// 07단계(추가) §3.4 - 현재 대화 내용을 모두 비운다.
  /// 07단계(추가) §3.5 - 사주 수집 정보/타로 질문/입력 단계도 함께 초기화한다.
  void clearMessages() {
    _messages = [];
    _userInfo = {};
    _pendingQuestion = null;
    _selectedTopic = 'general';
    _currentStep = ConsultationStep.chatting;
    notifyListeners();
  }

  /// 07단계(추가) §3.4 - 상담 유형을 [newType]으로 변경하고, 해당 유형의
  /// 새 웰컴 메시지로 세션을 재시작한다. 내부적으로 [clearMessages] 후
  /// [startSession]과 동일한 흐름(Repository.createSession 호출)을 재사용한다.
  ///
  /// [AI 상담 채팅 실연동] 유형 변경은 "오늘 이미 있는 세션"에 대한 재진입이므로
  /// 대부분 광고 재게이트가 필요 없지만(서버가 idempotent 재사용으로 응답),
  /// 이론상 세션이 만료/삭제된 경합 상태 대비 [ConsultationStartOutcome]을
  /// 그대로 반환해 호출부가 [ConsultationStartOutcome.needsAdReward]도 처리할 수 있게 한다.
  Future<ConsultationStartOutcome> changeType(String newType) async {
    if (isLoading) return ConsultationStartOutcome.error;
    clearMessages();
    return startSession(newType);
  }

  /// 07단계(추가) §3.5 - 사주/타로 정보 수집 도중 사용자가 흐름을 취소하면
  /// 수집된 정보를 버리고 자유 대화 상태로 되돌린다. (요구사항: 취소 처리 방안)
  void cancelInputFlow() {
    if (_currentStep == ConsultationStep.chatting || isLoading) return;
    _userInfo = {};
    _pendingQuestion = null;
    _selectedTopic = 'general';
    _currentStep = ConsultationStep.chatting;
    _appendAiMessage('입력을 취소했어요. 편하게 다른 이야기를 나눠볼까요?');
  }

  void _addUserMessage(String text) {
    _messages.add(
      ConsultationMessage(
        id: _nextId('u'),
        role: ConsultationRole.user,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// 07단계(추가) §3.5 - 스트리밍 없이 즉시 표시되는 AI 안내/결과 메시지.
  void _appendAiMessage(String text) {
    _messages.add(
      ConsultationMessage(
        id: _nextId('ai'),
        role: ConsultationRole.ai,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// 07단계(추가) §3.5 - 사주 정보 수집(성명 → 생년월일 → 출생시간)을 한 단계씩 진행한다.
  /// 텍스트 직접 입력([sendMessage] 경유)과 날짜/시간 피커 선택
  /// (ConsultationChatScreen에서 직접 호출) 양쪽에서 공통으로 사용되는 단일 진입점이다.
  Future<void> setUserInfo({
    required String field,
    required String value,
  }) async {
    if (isLoading) return;
    _userInfo[field] = value;

    switch (field) {
      case 'name':
        _addUserMessage(value);
        _currentStep = ConsultationStep.inputBirthDate;
        notifyListeners();
        _appendAiMessage('$value님, 반가워요! 생년월일을 입력해주세요. (예: 1995-03-15)');
        break;
      case 'birthDate':
        _addUserMessage(value);
        _currentStep = ConsultationStep.inputBirthTime;
        notifyListeners();
        _appendAiMessage(
          '태어난 시간을 알고 계신가요? 알고 있다면 입력해주세요. (예: 14:30, 모르면 건너뛰기를 눌러주세요)',
        );
        break;
      case 'birthTime':
        _addUserMessage(value.isEmpty ? '시간 모름' : value);
        _currentStep = ConsultationStep.selectGender;
        notifyListeners();
        _appendAiMessage('마지막으로 성별을 선택해주세요.');
        break;
    }
  }

  /// 07단계(추가) §3.5 - "건너뛰기" 버튼: 출생시간을 모름 처리하고 다음 단계로 진행한다.
  Future<void> skipBirthTime() async {
    if (_currentStep != ConsultationStep.inputBirthTime || isLoading) return;
    await setUserInfo(field: 'birthTime', value: '');
  }

  /// 07단계(추가) §3.5 - 성별 선택 완료 → 사주 계산([_calculateSaju]) 트리거.
  Future<void> selectGender(String gender) async {
    if (_currentStep != ConsultationStep.selectGender || isLoading) return;
    _userInfo['gender'] = gender;
    _addUserMessage(gender == 'male' ? '남성' : '여성');
    _currentStep = ConsultationStep.calculatingSaju;
    notifyListeners();
    await _calculateSaju();
  }

  /// 07단계(추가) §3.5 - [SajuProvider.requestSaju] 호출 후 결과를 AI 메시지로 변환한다.
  Future<void> _calculateSaju() async {
    final saju = _sajuProvider;
    if (saju == null) {
      _appendAiMessage('사주 계산 서비스에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
      _currentStep = ConsultationStep.chatting;
      notifyListeners();
      return;
    }

    _isCalculating = true;
    notifyListeners();

    final birthTimeRaw = _userInfo['birthTime'];
    final birthTime = (birthTimeRaw == null || birthTimeRaw.isEmpty)
        ? null
        : birthTimeRaw;

    await saju.requestSaju(
      birthDate: _userInfo['birthDate'] ?? '',
      birthTime: birthTime,
      isLunar: false,
      topics: const ['종합', '재물', '애정', '직업', '건강'],
    );

    final state = saju.state;
    if (state.isSuccess && state.data != null) {
      _appendAiMessage(_formatSajuResult(state.data!));
    } else {
      _appendAiMessage(state.errorMessage ?? '사주 분석에 실패했어요. 다시 시도해 볼까요?');
    }

    _isCalculating = false;
    _currentStep = ConsultationStep.chatting;
    notifyListeners();
  }

  String _formatSajuResult(SajuResultModel result) {
    final name = _userInfo['name'] ?? '';
    final p = result.pillars;
    final pillarsText =
        '${p.year} ${p.month} ${p.day}${p.hour != null ? ' ${p.hour}' : ''}';
    final elementsText = result.fiveElements.entries
        .map((e) => '${e.key} ${e.value}')
        .join(' · ');

    final buffer = StringBuffer()
      ..writeln('$name님의 사주를 살펴봤어요. 🔮')
      ..writeln()
      ..writeln('▸ 사주 명식: $pillarsText')
      ..writeln('▸ 오행 분포: $elementsText')
      ..writeln()
      ..writeln(result.summary)
      ..writeln()
      ..write('더 궁금한 점이 있다면 편하게 이어서 물어보세요!');
    return buffer.toString();
  }

  /// 07단계(추가) §3.6 - 주제(20개 중 하나) 선택 완료 → 카드 선택 단계로 진행한다.
  /// 타로 고민 입력([sendMessage]의 inputTarotQuestion 분기) 직후에 호출된다.
  Future<void> selectTarotTopic(String topicId) async {
    if (_currentStep != ConsultationStep.selectTarotTopic || isLoading) return;
    final topic = TarotTextEngine.topicMeta(topicId);
    _selectedTopic = topic.id;
    _addUserMessage(topic.label);
    _currentStep = ConsultationStep.selectTarotCard;
    notifyListeners();
    _appendAiMessage('${topic.label}(으)로 살펴볼게요. 마음이 가는 카드를 한 장 골라주세요.');
  }

  /// 07단계(추가) §3.5/3.6 - 타로 카드 선택 완료 → 3카드 스프레드 뽑기([_drawTarotCards]) 트리거.
  /// [cardLabel]은 실제 카드 결정에는 사용되지 않는다(Repository가 질문 해시를
  /// 시드로 78장 풀덱에서 3장을 결정론적으로 뽑는다). 사용자에게는 "카드를
  /// 직접 골랐다"는 상호작용 경험을 제공하기 위한 UI 표시용 값이다.
  Future<void> selectTarotCard(String cardLabel) async {
    if (_currentStep != ConsultationStep.selectTarotCard || isLoading) return;
    _addUserMessage('$cardLabel 카드를 선택했어요');
    _currentStep = ConsultationStep.drawingTarot;
    notifyListeners();
    await _drawTarotCards();
  }

  /// 07단계(추가) §3.6 - 카드 인덱스(0/1/2) 기반으로도 선택할 수 있도록 지원하는
  /// 오버로드 성격의 메서드(요구사항 예시 코드의 `selectTarotCard(int cardIndex)`
  /// 시그니처 대응). 내부적으로 기존 [selectTarotCard]를 재사용해 흐름을 통일한다.
  Future<void> selectTarotCardByIndex(int cardIndex) async {
    const labels = ['첫번째 카드', '두번째 카드', '세번째 카드'];
    final label = (cardIndex >= 0 && cardIndex < labels.length)
        ? labels[cardIndex]
        : '카드';
    await selectTarotCard(label);
  }

  /// 07단계(추가) §3.5 - [TarotProvider.draw] 호출 후 결과를 AI 메시지로 변환한다.
  /// 07단계(추가) §3.6 - [_selectedTopic]을 함께 전달해 78장 풀덱 + 주제별
  /// 해석([TarotTextEngine])이 적용된 결과를 받는다.
  Future<void> _drawTarotCards() async {
    final tarot = _tarotProvider;
    final question = _pendingQuestion;
    if (tarot == null || question == null) {
      _appendAiMessage('타로 카드를 뽑는 중 문제가 발생했어요. 다시 시도해주세요.');
      _currentStep = ConsultationStep.chatting;
      notifyListeners();
      return;
    }

    _isCalculating = true;
    notifyListeners();

    await tarot.draw(
      question: question,
      spreadType: 'three_card',
      topic: _selectedTopic,
    );

    final state = tarot.state;
    if (state.isSuccess && state.data != null) {
      _appendAiMessage(_formatTarotResult(state.data!));
    } else {
      _appendAiMessage(state.errorMessage ?? '타로 카드를 뽑는데 실패했어요. 다시 시도해 볼까요?');
    }

    _isCalculating = false;
    _pendingQuestion = null;
    _selectedTopic = 'general';
    _currentStep = ConsultationStep.chatting;
    notifyListeners();
  }

  String _formatTarotResult(TarotResultModel result) {
    final topic = TarotTextEngine.topicMeta(result.topic);
    final buffer = StringBuffer()
      ..writeln('${topic.label} 카드를 살펴봤어요. 🃏')
      ..writeln();
    for (final pos in result.positions) {
      final reversedTag = pos.card.isReversed ? '(역방향) ' : '';
      buffer
        ..writeln(
          '▸ ${pos.label}: $reversedTag${pos.card.icon} ${pos.card.nameKr}',
        )
        ..writeln(pos.interpretation)
        ..writeln();
    }
    buffer.write(result.summary);
    return buffer.toString();
  }

  static final RegExp _dateRegex = RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$');
  static final RegExp _timeRegex = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');

  Future<void> _handleBirthDateText(String trimmed) async {
    if (!_dateRegex.hasMatch(trimmed)) {
      _addUserMessage(trimmed);
      _appendAiMessage(
        '날짜 형식을 확인해주세요. YYYY-MM-DD 형식으로 입력하거나, 아래 날짜 선택 버튼을 이용해주세요. (예: 1995-03-15)',
      );
      return;
    }
    await setUserInfo(field: 'birthDate', value: trimmed);
  }

  Future<void> _handleBirthTimeText(String trimmed) async {
    if (trimmed.contains('모름') || trimmed.contains('몰라') || trimmed == '-') {
      await setUserInfo(field: 'birthTime', value: '');
      return;
    }
    if (!_timeRegex.hasMatch(trimmed)) {
      _addUserMessage(trimmed);
      _appendAiMessage(
        '시간 형식을 확인해주세요. HH:MM 형식으로 입력하거나(예: 14:30), 모르면 건너뛰기를 눌러주세요.',
      );
      return;
    }
    await setUserInfo(field: 'birthTime', value: trimmed);
  }

  /// 07단계 §2.1 / 09단계 §1.2 기존 sendMessage.
  /// 07단계(추가) §3.5 - [currentStep]에 따라 텍스트 입력을 "자유 대화(스트리밍)"
  /// 또는 "단계별 정보 수집"으로 분기한다. 시그니처와 외부 호출 방식은 변경되지 않는다.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isLoading) return;

    switch (_currentStep) {
      case ConsultationStep.inputName:
        await setUserInfo(field: 'name', value: trimmed);
        return;
      case ConsultationStep.inputBirthDate:
        await _handleBirthDateText(trimmed);
        return;
      case ConsultationStep.inputBirthTime:
        await _handleBirthTimeText(trimmed);
        return;
      case ConsultationStep.inputTarotQuestion:
        _addUserMessage(trimmed);
        _pendingQuestion = trimmed;
        _currentStep = ConsultationStep.selectTarotTopic;
        notifyListeners();
        _appendAiMessage('어떤 주제로 살펴볼까요? 궁금한 주제를 골라주세요.');
        return;
      case ConsultationStep.selectGender:
      case ConsultationStep.selectTarotTopic:
      case ConsultationStep.selectTarotCard:
      case ConsultationStep.calculatingSaju:
      case ConsultationStep.drawingTarot:
        // 이 단계들은 버튼형 UI로만 진행하며 텍스트 입력창 자체가 표시되지 않으므로 무시한다.
        return;
      case ConsultationStep.chatting:
        await _sendFreeChat(trimmed);
        return;
    }
  }

  /// 07단계 §2.1 / 09단계 §1.2 기존 일반 자유대화 스트리밍 로직.
  /// [AI 상담 채팅 실연동] admin_web 실LLM API(`POST /message`)와 통신하도록
  /// 교체하며, 전송 전 클라이언트 측에서도 500자 제한/20턴 한도를 먼저 확인해
  /// 불필요한 네트워크 호출과 지연 없이 즉시 안내한다(최종 판정은 서버가 내림).
  Future<void> _sendFreeChat(String trimmed) async {
    if (trimmed.length > ConsultationLimits.maxMessageLength) {
      _addUserMessage(trimmed);
      _appendAiMessage(
        '메시지는 최대 ${ConsultationLimits.maxMessageLength}자까지 입력할 수 있어요. '
        '조금 줄여서 다시 보내주시겠어요? (현재 ${trimmed.length}자)',
      );
      return;
    }
    if (isSessionExhausted) {
      _addUserMessage(trimmed);
      _appendAiMessage(
        '오늘 상담 세션에서 이용 가능한 대화 횟수($_maxTurns회)를 모두 사용했어요. 내일 새 세션으로 다시 만나요.',
      );
      return;
    }
    final sessionId = _sessionId;
    if (sessionId == null) {
      _addUserMessage(trimmed);
      _appendAiMessage('상담 세션이 아직 준비되지 않았어요. 화면을 다시 열어 다시 시도해주세요.');
      return;
    }

    _addUserMessage(trimmed);

    _isStreaming = true;
    notifyListeners();
    final aiId = _nextId('ai');
    _messages.add(
      ConsultationMessage(
        id: aiId,
        role: ConsultationRole.ai,
        text: '',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();

    final buffer = StringBuffer();
    try {
      await for (final chunk in _repository.streamReply(
        sessionId: sessionId,
        userMessage: trimmed,
      )) {
        buffer.write(chunk);
        final idx = _messages.indexWhere((m) => m.id == aiId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(text: buffer.toString());
          notifyListeners();
        }
      }
      final turn = _repository.lastTurnResult;
      if (turn != null) {
        _turnCount = turn.turnCount;
        _maxTurns = turn.maxTurns;
      }
    } on ConsultationRequestException catch (e) {
      final idx = _messages.indexWhere((m) => m.id == aiId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(text: e.message);
      }
      if (e.turnCount != null) _turnCount = e.turnCount!;
      if (e.maxTurns != null) _maxTurns = e.maxTurns!;
      _lastErrorMessage = e.message;
    } finally {
      _isStreaming = false;
      notifyListeners();
    }
  }
}
