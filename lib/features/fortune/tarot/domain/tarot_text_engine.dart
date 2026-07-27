/// 07단계(추가) §3.6 - 타로상담 기능 최적화 프로젝트
///
/// 사용자가 제시한 웹 버전(js/fortune-engine.js)의 "OPENERS / BODY_POOLS /
/// ADVICE_LINES / CAUTION_LINES / CLOSERS 조합형 텍스트 생성" 방식을 그대로
/// 따르되, 원본 웹 파일에 접근할 수 없어 콘텐츠는 이 프로젝트에 맞게 새로
/// 작성했다. 20개 주제(연애/재물/취업 등)별로 미리 정의된 문장 풀에서
/// 무작위로 조합해 매번 다른 느낌의 자연스러운 해석 텍스트를 만들어낸다.
///
/// - TarotTopic: 20개 상담 주제 메타데이터(라벨/키워드/관심사).
/// - TarotTextEngine의 OPENERS/BODY_POOLS/ADVICE_LINES/CAUTION_LINES/CLOSERS:
///   주제별 문장 풀(내부적으로 `_TopicTemplates`의 범용 템플릿에 주제 키워드를
///   대입해 생성 - `Map<String, List<String>>` 구조는 요구사항과 동일하게 유지된다).
/// - [TarotTextEngine.generateCardInterpretation]: 카드 1장 해석 텍스트 생성.
/// - [TarotTextEngine.generateSummary]: 여러 장의 카드를 종합한 총평 생성.
/// - [TarotTextEngine.buildResult]: 위 두 함수를 조합해 [TarotResult]를 만든다.
library;

import 'dart:math';

import 'tarot_model.dart';

/// 20개 상담 주제 메타데이터.
class TarotTopic {
  final String id;
  final String label; // 화면 표시용 한글 라벨
  final String keyword; // 문장에 자연스럽게 들어가는 주제어 (예: 연애, 재물)
  final String subject; // 문장에서 다루는 구체적 관심사 (예: 두 사람의 관계)

  const TarotTopic({
    required this.id,
    required this.label,
    required this.keyword,
    required this.subject,
  });
}

/// 07단계(추가) §3.6 - 20개 주제 목록. 'general'(종합)을 포함한다.
const List<TarotTopic> tarotTopics = [
  TarotTopic(
    id: 'general',
    label: '종합운',
    keyword: '전체적인 흐름',
    subject: '전반적인 흐름',
  ),
  TarotTopic(id: 'love', label: '연애운', keyword: '연애', subject: '두 사람의 관계'),
  TarotTopic(id: 'reunion', label: '재회운', keyword: '재회', subject: '다시 이어질 인연'),
  TarotTopic(id: 'crush', label: '짝사랑운', keyword: '짝사랑', subject: '마음을 전할 타이밍'),
  TarotTopic(
    id: 'marriage',
    label: '결혼운',
    keyword: '결혼',
    subject: '평생을 함께할 결정',
  ),
  TarotTopic(id: 'wealth', label: '재물운', keyword: '재물', subject: '돈의 흐름'),
  TarotTopic(id: 'job', label: '취업운', keyword: '취업', subject: '합격과 채용 소식'),
  TarotTopic(
    id: 'career_change',
    label: '이직운',
    keyword: '이직',
    subject: '새로운 커리어의 방향',
  ),
  TarotTopic(id: 'business', label: '사업운', keyword: '사업', subject: '사업의 성패'),
  TarotTopic(id: 'study', label: '학업운', keyword: '학업', subject: '배움의 성과'),
  TarotTopic(id: 'exam', label: '시험운', keyword: '시험', subject: '시험 결과'),
  TarotTopic(id: 'health', label: '건강운', keyword: '건강', subject: '몸과 마음의 상태'),
  TarotTopic(
    id: 'relationship',
    label: '인간관계운',
    keyword: '인간관계',
    subject: '주변 사람들과의 관계',
  ),
  TarotTopic(id: 'family', label: '가족운', keyword: '가족', subject: '가족 간의 화합'),
  TarotTopic(id: 'travel', label: '여행운', keyword: '여행', subject: '여행길의 흐름'),
  TarotTopic(id: 'contract', label: '계약운', keyword: '계약', subject: '계약의 성사 여부'),
  TarotTopic(id: 'lawsuit', label: '소송운', keyword: '소송', subject: '다툼의 결과'),
  TarotTopic(id: 'move', label: '이사운', keyword: '이사', subject: '이사와 거주지 변화'),
  TarotTopic(
    id: 'today',
    label: '오늘의 운세',
    keyword: '오늘 하루',
    subject: '오늘 하루의 흐름',
  ),
  TarotTopic(
    id: 'choice',
    label: '선택운',
    keyword: '지금의 선택',
    subject: '지금 앞에 놓인 선택',
  ),
];

final Map<String, TarotTopic> _topicById = {
  for (final t in tarotTopics) t.id: t,
};

TarotTopic _resolveTopic(String topicId) =>
    _topicById[topicId] ?? _topicById['general']!;

/// 주제 무관 범용 문장 템플릿(내부용). `{keyword}`/`{subject}`가
/// [TarotTopic]의 값으로 치환되어 주제별 문장 풀을 만든다.
class _TopicTemplates {
  _TopicTemplates._();

  // 07단계(추가) §3.6 - OPENERS(주제별 8개): 해석을 시작하는 도입 문장.
  static const List<String> openers = [
    '{keyword}에 대해 카드가 조용히 이야기를 시작해요. {subject}을(를) 중심으로 살펴볼게요.',
    '지금 마음에 담아두신 {keyword} 고민, 카드들이 하나씩 답을 보여주고 있어요.',
    '{subject}에 대한 흐름을 카드들이 선명하게 그려내고 있어요.',
    '질문하신 {keyword} 이야기를 카드에 비춰보니 흥미로운 신호들이 보이네요.',
    '{keyword}의 기운을 살펴보면, {subject}이(가) 서서히 방향을 잡아가고 있어요.',
    '카드 속에 담긴 {keyword}의 메시지를 함께 풀어볼게요.',
    '{subject}을(를) 향한 마음이 카드에 고스란히 비치고 있네요.',
    '지금 이 순간의 {keyword} 기운을 카드가 대신 전해드릴게요.',
  ];

  // 07단계(추가) §3.6 - BODY_POOLS(주제별 4개): 카드 1장을 감싸는 문장 틀.
  // `{card}`에는 해당 카드의 정/역방향 키워드 문장(TarotCardMeta.up/down)이 들어간다.
  static const List<String> bodyPools = [
    '{name} 카드가 나왔어요. {card}',
    '{name} 카드는 지금, {card}',
    '이 자리에 {name} 카드가 자리했어요. {card}',
    '{name} 카드를 통해 보면, {card}',
  ];

  // 07단계(추가) §3.6 - ADVICE_LINES(주제별 8개): 조언 문장.
  static const List<String> adviceLines = [
    '지금은 {subject}에 조급해하지 말고 흐름을 지켜보는 것이 좋아요.',
    '작은 신호에도 귀 기울이면 {keyword}에서 좋은 기회를 잡을 수 있어요.',
    '스스로의 마음을 먼저 정리하면 {subject}이(가) 훨씬 명확해질 거예요.',
    '주변 사람들과 솔직하게 소통하는 것이 {keyword}에 도움이 될 수 있어요.',
    '지금까지의 노력을 믿고 한 걸음씩 나아가 보세요.',
    '완벽함보다는 유연함으로 {subject}에 접근해보세요.',
    '필요하다면 잠시 쉬어가는 것도 {keyword}에 좋은 선택이 될 수 있어요.',
    '직감이 말해주는 방향을 무시하지 마세요.',
  ];

  // 07단계(추가) §3.6 - CAUTION_LINES(주제별 7개): 주의 문장.
  static const List<String> cautionLines = [
    '성급한 결정은 {subject}에 아쉬움을 남길 수 있어요.',
    '감정에 치우친 판단은 잠시 미뤄두는 게 좋겠어요.',
    '주변의 부정적인 말에 흔들리지 않도록 중심을 잡으세요.',
    '지나친 기대는 오히려 {keyword}에 부담이 될 수 있어요.',
    '중요한 결정을 내리기 전, 한 번 더 확인하는 신중함이 필요해요.',
    '혼자 짊어지려 하지 말고 도움을 요청해도 괜찮아요.',
    '지금의 불안함이 {subject}을(를) 왜곡해서 보이게 할 수 있으니 주의하세요.',
  ];

  // 07단계(추가) §3.6 - CLOSERS(5개): 주제 구분 없이 공용으로 사용되는 마무리 문장.
  static const List<String> closers = [
    '오늘의 리딩이 작은 위안이 되었길 바라요.',
    '카드는 힌트일 뿐, 답을 만들어가는 건 당신의 몫이에요.',
    '필요할 때 언제든 다시 카드를 뽑아보세요.',
    '지금 이 순간의 마음가짐이 앞으로의 흐름을 바꿀 수 있어요.',
    '당신의 선택을 응원할게요.',
  ];

  static String _fill(String template, TarotTopic topic) {
    return template
        .replaceAll('{keyword}', topic.keyword)
        .replaceAll('{subject}', topic.subject);
  }

  static List<String> fillAll(List<String> templates, TarotTopic topic) =>
      templates.map((t) => _fill(t, topic)).toList(growable: false);
}

/// 07단계(추가) §3.6 - 타로 해석 텍스트 생성 엔진.
/// 모든 public 메서드는 순수 함수(입력이 같으면 [seed]가 같을 때 동일 출력)로
/// 설계되어 있어, 질문 텍스트를 시드로 사용하면 동일 질문에 대해 일관된
/// 결과를 재현할 수 있다([TarotRepository]에서 활용).
class TarotTextEngine {
  TarotTextEngine._();

  /// 주제별 OPENERS 8개 (요구사항: `OPENERS` Map 구조).
  static Map<String, List<String>> get OPENERS => {
    for (final topic in tarotTopics)
      topic.id: _TopicTemplates.fillAll(_TopicTemplates.openers, topic),
  };

  /// 주제별 BODY_POOLS 4개 (요구사항: `BODY_POOLS` Map 구조).
  /// `{card}`는 카드별 해석 문장 생성 시점([generateCardInterpretation])에
  /// 최종 치환되므로, 여기서는 `{keyword}`/`{subject}`만 채워진 템플릿을 보관한다.
  static Map<String, List<String>> get BODY_POOLS => {
    for (final topic in tarotTopics)
      topic.id: _TopicTemplates.fillAll(_TopicTemplates.bodyPools, topic),
  };

  /// 주제별 ADVICE_LINES 8개 (요구사항: `ADVICE_LINES` Map 구조).
  static Map<String, List<String>> get ADVICE_LINES => {
    for (final topic in tarotTopics)
      topic.id: _TopicTemplates.fillAll(_TopicTemplates.adviceLines, topic),
  };

  /// 주제별 CAUTION_LINES 7개 (요구사항: `CAUTION_LINES` Map 구조).
  static Map<String, List<String>> get CAUTION_LINES => {
    for (final topic in tarotTopics)
      topic.id: _TopicTemplates.fillAll(_TopicTemplates.cautionLines, topic),
  };

  /// CLOSERS 5개 (요구사항: 주제 구분 없는 공용 마무리 문장 5개).
  static List<String> get CLOSERS => List.unmodifiable(_TopicTemplates.closers);

  static TarotTopic topicMeta(String topicId) => _resolveTopic(topicId);

  /// [seed]를 기반으로 한 결정론적 난수 생성기.
  /// 같은 질문+카드 조합이면 항상 같은 문장 조합을 재현할 수 있도록,
  /// 호출부([TarotRepository])에서 질문 해시 등을 시드로 전달하는 것을 권장한다.
  static Random _rngFor(int seed) => Random(seed);

  /// 07단계(추가) §3.6 - 카드 한 장의 해석 텍스트를 생성한다.
  /// [topic]에 대응하는 BODY_POOLS에서 문장 틀을 하나 골라 카드명과
  /// 정/역방향 키워드([TarotCardMeta.up]/[down])를 채워 넣는다.
  /// [seed]가 주어지면 재현 가능한 결과를, 없으면 매번 다른 결과를 만든다.
  static String generateCardInterpretation(
    TarotCard card,
    String topic, {
    int? seed,
  }) {
    final topicMetaObj = _resolveTopic(topic);
    final pool = BODY_POOLS[topicMetaObj.id] ?? BODY_POOLS['general']!;
    final rng = _rngFor(seed ?? card.id.hashCode ^ topic.hashCode);
    final template = pool[rng.nextInt(pool.length)];

    final meta = TarotDeckData.metaForName(card.name);
    final meaningText = meta == null
        ? (card.isReversed ? '지금은 신중함이 필요한 흐름이에요.' : '긍정적인 변화가 다가오고 있어요.')
        : (card.isReversed ? meta.down : meta.up);

    final reversedTag = card.isReversed ? '(역방향) ' : '';
    final filled = template
        .replaceAll('{name}', '$reversedTag${card.nameKr}')
        .replaceAll('{card}', meaningText);
    return filled;
  }

  /// 07단계(추가) §3.6 - 여러 장의 카드를 종합한 총평 텍스트를 생성한다.
  /// 구성: OPENERS 1개 → 카드별 간단 요약 → ADVICE_LINES 1개 →
  /// CAUTION_LINES 1개 → CLOSERS 1개.
  static String generateSummary(
    List<TarotCard> cards,
    String question,
    String topic, {
    int? seed,
  }) {
    final topicMetaObj = _resolveTopic(topic);
    final rng = _rngFor(
      seed ?? (question.hashCode ^ topic.hashCode ^ cards.length),
    );

    final openerPool = OPENERS[topicMetaObj.id] ?? OPENERS['general']!;
    final advicePool =
        ADVICE_LINES[topicMetaObj.id] ?? ADVICE_LINES['general']!;
    final cautionPool =
        CAUTION_LINES[topicMetaObj.id] ?? CAUTION_LINES['general']!;
    final closerPool = CLOSERS;

    final opener = openerPool[rng.nextInt(openerPool.length)];
    final advice = advicePool[rng.nextInt(advicePool.length)];
    final caution = cautionPool[rng.nextInt(cautionPool.length)];
    final closer = closerPool[rng.nextInt(closerPool.length)];

    final cardNames = cards
        .map((c) => '${c.isReversed ? '역방향 ' : ''}${c.nameKr}')
        .join(', ');

    final buffer = StringBuffer()
      ..writeln(opener)
      ..writeln()
      ..writeln('이번에 뽑힌 카드는 $cardNames 예요.')
      ..writeln()
      ..writeln(advice)
      ..writeln(caution)
      ..writeln()
      ..write(closer);
    return buffer.toString();
  }

  /// 07단계(추가) §3.6 - [generateCardInterpretation]과 [generateSummary]를
  /// 조합해 하나의 [TarotResult](cards/question/topic/interpretation)를 만든다.
  /// [interpretation]에는 카드별 해석 + 총평이 순서대로 이어져 담긴다.
  static TarotResult buildResult({
    required List<TarotCard> cards,
    required String question,
    required String topic,
    int? seed,
  }) {
    final buffer = StringBuffer();
    for (var i = 0; i < cards.length; i++) {
      final cardSeed = seed == null ? null : seed + i * 31;
      buffer.writeln(
        generateCardInterpretation(cards[i], topic, seed: cardSeed),
      );
      buffer.writeln();
    }
    buffer.write(generateSummary(cards, question, topic, seed: seed));

    return TarotResult(
      cards: cards,
      question: question,
      topic: topic,
      interpretation: buffer.toString(),
    );
  }
}
