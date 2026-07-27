import 'dart:math';

import '../../../../core/api/api_result.dart';
import '../../../../core/utils/mock_delay.dart';
import '../domain/tarot_model.dart';
import '../domain/tarot_text_engine.dart';

/// 06단계 §4.3 `POST /v1/fortune/tarot/request` 대응 Mock Repository
/// 09단계 §3.2-③ 타로 프롬프트 출력 스키마(cards/positions/interpretation) 반영
///
/// 07단계(추가) §3.6 - 타로상담 기능 최적화: 기존 15장 고정 덱 기반
/// [drawOneCard]/[drawThreeCard]는 그대로 유지하고(하위 호환), 78장 풀덱
/// 기반의 [buildFullDeck]/[drawThreeCards]를 추가한다. 신규 메서드는
/// [TarotTextEngine]의 주제별 조합형 텍스트 생성 로직을 사용한다.
class TarotRepository {
  final List<TarotResultModel> _history = [];

  static const _deck = [
    ('The Fool', '바보'),
    ('The Magician', '마법사'),
    ('The High Priestess', '여사제'),
    ('The Empress', '여황제'),
    ('The Emperor', '황제'),
    ('The Lovers', '연인'),
    ('The Chariot', '전차'),
    ('Strength', '힘'),
    ('The Hermit', '은둔자'),
    ('Wheel of Fortune', '운명의 수레바퀴'),
    ('Justice', '정의'),
    ('The Star', '별'),
    ('The Sun', '태양'),
    ('The Moon', '달'),
    ('The World', '세계'),
  ];

  static const _oneCardMeanings = {
    '바보': '새로운 시작과 자유로운 도전을 의미합니다. 두려움 없이 첫걸음을 내딛어보세요.',
    '마법사': '스스로의 능력과 의지로 원하는 것을 만들어낼 수 있는 시기입니다.',
    '여사제': '직관을 믿고 내면의 목소리에 귀 기울여야 할 때입니다.',
    '여황제': '풍요와 안정, 따뜻한 결실이 찾아오는 흐름입니다.',
    '황제': '체계와 안정을 바탕으로 목표를 향해 꾸준히 나아가세요.',
    '연인': '관계에서의 조화와 선택의 순간이 다가오고 있습니다.',
    '전차': '강한 의지로 장애물을 극복하고 앞으로 나아갈 힘이 있습니다.',
    '힘': '부드러움 속의 강인함으로 어려움을 이겨낼 수 있습니다.',
    '은둔자': '잠시 멈추고 스스로를 돌아보는 시간이 필요합니다.',
    '운명의 수레바퀴': '변화의 흐름이 다가오고 있으니 유연하게 대응하세요.',
    '정의': '공정한 판단과 균형이 필요한 시기입니다.',
    '별': '희망과 치유, 밝은 미래에 대한 기대가 커지는 때입니다.',
    '태양': '성공과 활력, 밝은 에너지가 가득한 최고의 시기입니다.',
    '달': '불확실함 속에서도 직관을 믿고 나아가야 할 때입니다.',
    '세계': '완성과 성취, 하나의 여정이 마무리되는 순간입니다.',
  };

  Future<ApiResult<TarotResultModel>> drawOneCard({
    required String question,
  }) async {
    await mockDelay(ms: 1500);
    final seed =
        (question.hashCode.abs() + DateTime.now().millisecondsSinceEpoch) %
        _deck.length;
    final (name, nameKr) = _deck[seed];
    final reversed = DateTime.now().millisecond % 2 == 0;

    final card = TarotCard(
      id: 'card_$seed',
      name: name,
      nameKr: nameKr,
      isReversed: reversed,
    );
    final baseText = _oneCardMeanings[nameKr] ?? '변화와 성장의 기운이 감돌고 있습니다.';
    final interpretation = reversed
        ? '(역방향) $baseText 다만 지금은 조급함을 내려놓고 신중하게 접근하는 것이 좋습니다.'
        : baseText;

    final result = TarotResultModel(
      id: 'tarot_${DateTime.now().millisecondsSinceEpoch}',
      question: question,
      spreadType: 'one_card',
      positions: [
        TarotSpreadPosition(
          label: '오늘의 카드',
          card: card,
          interpretation: interpretation,
        ),
      ],
      summary: interpretation,
      createdAt: DateTime.now(),
    );

    _history.insert(0, result);
    return ApiResult.ok(result);
  }

  Future<ApiResult<TarotResultModel>> drawThreeCard({
    required String question,
  }) async {
    await mockDelay(ms: 1800);
    final seedBase = question.hashCode.abs();
    const labels = ['과거', '현재', '미래'];
    final positions = <TarotSpreadPosition>[];

    for (int i = 0; i < 3; i++) {
      final idx = (seedBase + i * 5) % _deck.length;
      final (name, nameKr) = _deck[idx];
      final reversed = (seedBase + i) % 3 == 0;
      final card = TarotCard(
        id: 'card_${idx}_$i',
        name: name,
        nameKr: nameKr,
        isReversed: reversed,
      );
      final baseText = _oneCardMeanings[nameKr] ?? '변화와 성장의 기운이 감돌고 있습니다.';
      final text = reversed ? '(역방향) $baseText' : baseText;
      positions.add(
        TarotSpreadPosition(label: labels[i], card: card, interpretation: text),
      );
    }

    final result = TarotResultModel(
      id: 'tarot_${DateTime.now().millisecondsSinceEpoch}',
      question: question,
      spreadType: 'three_card',
      positions: positions,
      summary:
          '과거의 흐름이 현재에 영향을 주고 있으며, 지금의 선택이 앞으로의 결과를 결정짓게 됩니다. ${positions[2].interpretation}',
      createdAt: DateTime.now(),
    );

    _history.insert(0, result);
    return ApiResult.ok(result);
  }

  Future<ApiResult<List<TarotResultModel>>> getHistory() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_history));
  }

  // ── 07단계(추가) §3.6 - 78장 풀덱 기반 신규 기능 ──

  /// 메이저 22장 + 마이너 56장(4수트 × 14랭크) = 78장 풀덱 메타데이터를 반환한다.
  /// [tarot_model.dart]의 [buildFullTarotDeckMeta]를 그대로 노출하는 얇은 래퍼로,
  /// Repository 계층에서 덱에 접근하는 단일 진입점을 제공한다.
  List<TarotCardMeta> buildFullDeck() => TarotDeckData.fullDeck;

  /// 07단계(추가) §3.6 - [question]의 해시값을 시드로 사용해 78장 풀덱에서
  /// 3장을 정방향/역방향과 함께 결정론적으로 뽑고, [TarotTextEngine]으로
  /// 주제별 해석을 생성해 [TarotResultModel]로 반환한다.
  /// 같은 질문 + 같은 주제로 다시 호출하면 항상 같은 3장이 나온다(요구사항:
  /// "질문 해시 시드 기반" 뽑기).
  Future<ApiResult<TarotResultModel>> drawThreeCards({
    required String question,
    String topic = 'general',
  }) async {
    await mockDelay(ms: 1800);

    final deck = buildFullDeck();
    final seed = question.hashCode.abs();
    final rng = Random(seed);

    // 중복 없이 3장 인덱스 선택
    final indices = <int>{};
    while (indices.length < 3) {
      indices.add(rng.nextInt(deck.length));
    }
    final chosenIndices = indices.toList();

    const labels = ['과거', '현재', '미래'];
    final cards = <TarotCard>[];
    for (int i = 0; i < chosenIndices.length; i++) {
      final meta = deck[chosenIndices[i]];
      final reversed = Random(seed + chosenIndices[i]).nextBool();
      cards.add(
        TarotCard.fromMeta(
          meta,
          id: 'card_${chosenIndices[i]}_$i',
          isReversed: reversed,
        ),
      );
    }

    final positions = <TarotSpreadPosition>[];
    for (int i = 0; i < cards.length; i++) {
      positions.add(
        TarotSpreadPosition(
          label: labels[i],
          card: cards[i],
          interpretation: TarotTextEngine.generateCardInterpretation(
            cards[i],
            topic,
            seed: seed + i,
          ),
        ),
      );
    }

    final summary = TarotTextEngine.generateSummary(
      cards,
      question,
      topic,
      seed: seed,
    );

    final result = TarotResultModel(
      id: 'tarot_${DateTime.now().millisecondsSinceEpoch}',
      question: question,
      spreadType: 'three_card',
      positions: positions,
      summary: summary,
      createdAt: DateTime.now(),
      topic: topic,
    );

    _history.insert(0, result);
    return ApiResult.ok(result);
  }
}
