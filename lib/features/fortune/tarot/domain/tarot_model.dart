/// 04A E-2 `fortune_results` + E-5 `tarot_draws` 대응 모델
/// 09단계 §3.2-③ 타로 프롬프트 출력 스키마(cards/positions/interpretation) 반영
class TarotCard {
  final String id;
  final String name; // 카드명 (예: The Fool, The Sun)
  final String nameKr; // 한글명 (예: 바보, 태양)
  final bool isReversed;

  const TarotCard({
    required this.id,
    required this.name,
    required this.nameKr,
    required this.isReversed,
  });
}

class TarotSpreadPosition {
  final String label; // 예: 과거/현재/미래, 원인/상황/결과
  final TarotCard card;
  final String interpretation;

  const TarotSpreadPosition({
    required this.label,
    required this.card,
    required this.interpretation,
  });
}

class TarotResultModel {
  final String id;
  final String question;
  final String spreadType; // one_card / three_card
  final List<TarotSpreadPosition> positions;
  final String summary;
  final DateTime createdAt;

  const TarotResultModel({
    required this.id,
    required this.question,
    required this.spreadType,
    required this.positions,
    required this.summary,
    required this.createdAt,
  });
}
