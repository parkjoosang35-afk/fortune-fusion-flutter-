import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/consultation_model.dart';

/// 06단계 §4.3 `POST /v1/fortune/consultation/*` 및 09단계 §1.2 AI Gateway
/// `generateStream()` (SSE 스트리밍) 대응 Mock Repository.
/// Mock 단계에서는 실제 SSE 연결 없이 Dart `Stream<String>`으로 토큰 단위 스트리밍을 재현하며,
/// 향후 실제 백엔드 연동 시 이 클래스만 실제 SSE/EventSource 기반 구현으로 교체하면 된다.
class ConsultationRepository {
  static const _welcomeTexts = {
    'saju': '안녕하세요! 사주 전문 AI 상담사입니다. 사주와 관련해 궁금한 점을 편하게 물어보세요.',
    'tarot': '안녕하세요! 타로 전문 AI 상담사입니다. 마음에 담고 있는 고민을 말씀해주시면 카드의 의미로 답해드릴게요.',
    'general': '안녕하세요! AI 운세 상담사입니다. 오늘 어떤 이야기가 궁금하신가요?',
  };

  static const _replyPool = {
    'saju': [
      '사주 명식을 보면 지금은 변화의 흐름이 강한 시기로 보여요. 서두르지 않고 차근차근 준비하신다면 좋은 결과로 이어질 가능성이 높습니다. 특히 재물운은 꾸준함이 핵심이 되는 시기예요.',
      '말씀해주신 상황을 사주적으로 보면, 대운의 흐름이 안정기에 들어서고 있어요. 주변 사람들과의 관계에서 신뢰를 쌓는 것이 앞으로의 운을 더 좋게 만들어줄 거예요.',
      '지금 겪고 있는 고민은 일시적인 흐름일 가능성이 높아요. 사주상 이 시기를 잘 넘기면 다음 계절에는 훨씬 편안한 기운이 들어오니 너무 걱정하지 않으셔도 됩니다.',
    ],
    'tarot': [
      '카드를 뽑아보니 \'별\' 카드의 기운이 느껴져요. 지금은 희망을 잃지 않고 자신을 믿어야 할 때라는 메시지네요. 조급해하지 않으셔도 좋은 흐름이 다가오고 있어요.',
      '\'전차\' 카드의 기운이 강하게 느껴집니다. 강한 의지로 밀고 나가면 지금의 장애물을 충분히 극복할 수 있다는 신호예요.',
      '\'달\' 카드가 보이네요. 지금은 불확실함이 있을 수 있지만, 직관을 믿고 한 걸음씩 나아가면 답이 서서히 보일 거예요.',
    ],
    'general': [
      '지금 겪고 있는 고민은 누구나 한번쯤 마주치는 흐름이에요. 조금 더 여유를 갖고 상황을 지켜보시면 좋은 방향으로 풀릴 가능성이 높아 보여요.',
      '말씀해주신 이야기를 들어보니, 지금은 새로운 시도를 하기에 나쁘지 않은 시기예요. 다만 중요한 결정은 조금 더 신중하게 접근하시는 게 좋겠어요.',
      '전체적인 기운을 보면 지금은 관계와 소통이 중요한 시기로 보여요. 주변 사람들과 솔직하게 이야기 나누시면 도움이 될 거예요.',
    ],
  };

  Future<ApiResult<ConsultationSessionModel>> createSession({
    required String type,
  }) async {
    await mockDelay(ms: 300);
    final session = ConsultationSessionModel(
      id: 'consult_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      messages: [
        ConsultationMessage(
          id: 'ai_welcome',
          role: ConsultationRole.ai,
          text: _welcomeTexts[type] ?? _welcomeTexts['general']!,
          createdAt: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
    );
    return ApiResult.ok(session);
  }

  /// 09단계 §1.2 `generateStream()` Mock 구현체
  /// 실제 SSE 대신 Dart Stream으로 토큰(어절) 단위 지연 방출을 재현한다.
  Stream<String> streamReply({
    required String type,
    required String userMessage,
  }) async* {
    final pool = _replyPool[type] ?? _replyPool['general']!;
    final seed = userMessage.hashCode.abs() % pool.length;
    final fullText = pool[seed];
    final tokens = fullText.split(' ');

    for (int i = 0; i < tokens.length; i++) {
      await Future.delayed(const Duration(milliseconds: 90));
      yield i == 0 ? tokens[i] : ' ${tokens[i]}';
    }
  }
}
