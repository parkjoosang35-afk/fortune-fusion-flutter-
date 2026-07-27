/// 04A E-2 `fortune_results` + E-5 `tarot_draws` 대응 모델
/// 09단계 §3.2-③ 타로 프롬프트 출력 스키마(cards/positions/interpretation) 반영
///
/// 07단계(추가) §3.6 - 타로상담 기능 최적화: 기존 15장 고정 덱을 메이저
/// 아르카나 22장 + 마이너 아르카나 56장(4수트 × 14랭크) = 78장 풀덱으로 확장한다.
/// 기존 화면(TarotResultScreen/TarotQuestionScreen/TarotHistoryScreen)과의
/// 하위 호환을 위해 [TarotCard]/[TarotSpreadPosition]/[TarotResultModel]의
/// 필드와 생성자 시그니처는 그대로 유지하고, 새로운 데이터/기능은 모두
/// 추가(additive) 방식으로만 확장한다.
library;

/// 카드가 메이저 아르카나인지 마이너 아르카나인지 구분한다.
enum TarotArcanaType { major, minor }

/// 78장 풀덱을 구성하는 카드 1장의 메타데이터(아이콘, 정/역방향 키워드,
/// 메이저/마이너 구분, 마이너인 경우 수트 정보를 포함).
/// 화면에 실제로 표시되는 [TarotCard](id/name/nameKr/isReversed)와는 별개로,
/// [TarotTextEngine]이 해석 텍스트를 생성할 때 참조하는 원본 데이터다.
class TarotCardMeta {
  final String name; // 예: The Fool, Ace of Wands
  final String nameKr; // 예: 바보, 완드 에이스
  final String icon; // 이모지 아이콘
  final TarotArcanaType type;
  final String? suit; // 마이너일 때만: wands/cups/swords/pentacles
  final String up; // 정방향 키워드 요약
  final String down; // 역방향 키워드 요약

  const TarotCardMeta({
    required this.name,
    required this.nameKr,
    required this.icon,
    required this.type,
    this.suit,
    required this.up,
    required this.down,
  });
}

/// 마이너 아르카나 수트(4개) 메타데이터.
class TarotSuitMeta {
  final String id; // wands/cups/swords/pentacles
  final String nameKr; // 완드/컵/소드/펜타클
  final String element; // 불/물/바람/흙
  final String icon;
  final String domain; // 해당 수트가 상징하는 삶의 영역(랭크 템플릿에 대입)

  const TarotSuitMeta({
    required this.id,
    required this.nameKr,
    required this.element,
    required this.icon,
    required this.domain,
  });
}

/// 마이너 아르카나 랭크(14개: Ace~King) 메타데이터.
/// [upTemplate]/[downTemplate]의 `{domain}` 자리에 [TarotSuitMeta.domain]이
/// 대입되어 56장의 개별 마이너 카드 의미가 만들어진다.
class TarotRankMeta {
  final String id; // ace, two, ..., king
  final String nameKr; // 에이스, 2, ..., 킹
  final String upTemplate;
  final String downTemplate;

  const TarotRankMeta({
    required this.id,
    required this.nameKr,
    required this.upTemplate,
    required this.downTemplate,
  });
}

/// 메이저 아르카나 22장.
const List<TarotCardMeta> majorArcana = [
  TarotCardMeta(
    name: 'The Fool',
    nameKr: '바보',
    icon: '🤹',
    type: TarotArcanaType.major,
    up: '두려움 없는 새로운 시작과 순수한 도전',
    down: '무모한 행동이나 준비 부족을 주의',
  ),
  TarotCardMeta(
    name: 'The Magician',
    nameKr: '마법사',
    icon: '🎩',
    type: TarotArcanaType.major,
    up: '가진 능력과 자원으로 원하는 것을 이루는 힘',
    down: '재능을 낭비하거나 자만하는 태도 주의',
  ),
  TarotCardMeta(
    name: 'The High Priestess',
    nameKr: '여사제',
    icon: '🔮',
    type: TarotArcanaType.major,
    up: '내면의 직관과 감춰진 진실에 대한 통찰',
    down: '직관을 무시하거나 혼란스러운 판단',
  ),
  TarotCardMeta(
    name: 'The Empress',
    nameKr: '여황제',
    icon: '👑',
    type: TarotArcanaType.major,
    up: '풍요와 창조, 따뜻한 결실이 찾아오는 흐름',
    down: '과잉보호나 나태함으로 인한 정체',
  ),
  TarotCardMeta(
    name: 'The Emperor',
    nameKr: '황제',
    icon: '🏛️',
    type: TarotArcanaType.major,
    up: '체계와 안정, 확고한 리더십으로 나아가는 힘',
    down: '고집이나 지나친 통제로 인한 갈등',
  ),
  TarotCardMeta(
    name: 'The Hierophant',
    nameKr: '교황',
    icon: '⛪',
    type: TarotArcanaType.major,
    up: '전통과 배움, 신뢰할 수 있는 조언이 도움이 되는 때',
    down: '관습에 얽매이거나 융통성 부족',
  ),
  TarotCardMeta(
    name: 'The Lovers',
    nameKr: '연인',
    icon: '💞',
    type: TarotArcanaType.major,
    up: '관계 속 조화와 의미 있는 선택의 순간',
    down: '관계의 불균형이나 우유부단한 선택',
  ),
  TarotCardMeta(
    name: 'The Chariot',
    nameKr: '전차',
    icon: '🏇',
    type: TarotArcanaType.major,
    up: '강한 의지로 장애물을 돌파하는 추진력',
    down: '방향을 잃거나 통제력을 상실할 위험',
  ),
  TarotCardMeta(
    name: 'Strength',
    nameKr: '힘',
    icon: '🦁',
    type: TarotArcanaType.major,
    up: '부드러움 속에 담긴 단단한 내면의 힘',
    down: '자신감 부족이나 감정 조절의 어려움',
  ),
  TarotCardMeta(
    name: 'The Hermit',
    nameKr: '은둔자',
    icon: '🕯️',
    type: TarotArcanaType.major,
    up: '잠시 멈춰 스스로를 돌아보는 성찰의 시간',
    down: '고립감이나 지나친 회피 성향 주의',
  ),
  TarotCardMeta(
    name: 'Wheel of Fortune',
    nameKr: '운명의 수레바퀴',
    icon: '🎡',
    type: TarotArcanaType.major,
    up: '피할 수 없는 변화의 흐름이 유리하게 작용',
    down: '뜻하지 않은 변수나 불운한 타이밍',
  ),
  TarotCardMeta(
    name: 'Justice',
    nameKr: '정의',
    icon: '⚖️',
    type: TarotArcanaType.major,
    up: '공정한 판단과 균형 잡힌 결과',
    down: '불공정함이나 왜곡된 판단에 대한 경계',
  ),
  TarotCardMeta(
    name: 'The Hanged Man',
    nameKr: '매달린 사람',
    icon: '🙃',
    type: TarotArcanaType.major,
    up: '관점을 바꾸면 보이는 새로운 답',
    down: '정체되거나 희생이 헛되이 느껴지는 시기',
  ),
  TarotCardMeta(
    name: 'Death',
    nameKr: '죽음',
    icon: '💀',
    type: TarotArcanaType.major,
    up: '묵은 것을 끝내고 새롭게 태어나는 전환점',
    down: '변화에 대한 저항이나 미련이 발목을 잡음',
  ),
  TarotCardMeta(
    name: 'Temperance',
    nameKr: '절제',
    icon: '🧪',
    type: TarotArcanaType.major,
    up: '균형과 조화를 통한 안정적인 흐름',
    down: '과유불급, 극단으로 치우칠 위험',
  ),
  TarotCardMeta(
    name: 'The Devil',
    nameKr: '악마',
    icon: '😈',
    type: TarotArcanaType.major,
    up: '집착이나 유혹의 실체를 직시해야 할 때',
    down: '억눌린 욕망에서 벗어나는 해방의 신호',
  ),
  TarotCardMeta(
    name: 'The Tower',
    nameKr: '탑',
    icon: '🗼',
    type: TarotArcanaType.major,
    up: '갑작스러운 붕괴 뒤에 찾아오는 근본적 각성',
    down: '충격을 최소화하려는 방어적 태도가 필요',
  ),
  TarotCardMeta(
    name: 'The Star',
    nameKr: '별',
    icon: '⭐',
    type: TarotArcanaType.major,
    up: '희망과 치유, 회복에 대한 밝은 기대',
    down: '자신감 상실이나 막막함이 느껴질 수 있음',
  ),
  TarotCardMeta(
    name: 'The Moon',
    nameKr: '달',
    icon: '🌙',
    type: TarotArcanaType.major,
    up: '불확실함 속에서도 직관을 믿어야 하는 시기',
    down: '불안과 혼란, 숨겨진 진실에 대한 경계',
  ),
  TarotCardMeta(
    name: 'The Sun',
    nameKr: '태양',
    icon: '☀️',
    type: TarotArcanaType.major,
    up: '성공과 활력, 가장 밝고 긍정적인 에너지',
    down: '지나친 낙관이나 과시욕을 주의',
  ),
  TarotCardMeta(
    name: 'Judgement',
    nameKr: '심판',
    icon: '📯',
    type: TarotArcanaType.major,
    up: '지난 시간을 정리하고 새로운 소명을 깨닫는 순간',
    down: '자기 비판에 갇히거나 결단을 미루는 상태',
  ),
  TarotCardMeta(
    name: 'The World',
    nameKr: '세계',
    icon: '🌍',
    type: TarotArcanaType.major,
    up: '하나의 여정이 완성되고 성취를 맞이하는 순간',
    down: '마무리가 지연되거나 미완성으로 남는 아쉬움',
  ),
];

/// 마이너 아르카나 수트 4개.
const List<TarotSuitMeta> minorSuits = [
  TarotSuitMeta(
    id: 'wands',
    nameKr: '완드',
    element: '불',
    icon: '🔥',
    domain: '열정과 행동',
  ),
  TarotSuitMeta(
    id: 'cups',
    nameKr: '컵',
    element: '물',
    icon: '💧',
    domain: '감정과 관계',
  ),
  TarotSuitMeta(
    id: 'swords',
    nameKr: '소드',
    element: '바람',
    icon: '🌬️',
    domain: '생각과 갈등',
  ),
  TarotSuitMeta(
    id: 'pentacles',
    nameKr: '펜타클',
    element: '흙',
    icon: '🌿',
    domain: '현실과 물질',
  ),
];

/// 마이너 아르카나 랭크 14개(Ace~King).
/// `{domain}`은 실제 카드 생성 시 해당 수트의 [TarotSuitMeta.domain]으로 치환된다.
const List<TarotRankMeta> minorRanks = [
  TarotRankMeta(
    id: 'ace',
    nameKr: '에이스',
    upTemplate: '{domain}의 새로운 시작을 알리는 신호가 나타났어요',
    downTemplate: '{domain}에서 시작이 늦어지거나 주저함이 느껴져요',
  ),
  TarotRankMeta(
    id: 'two',
    nameKr: '2',
    upTemplate: '{domain} 안에서 균형과 선택의 순간이 찾아왔어요',
    downTemplate: '{domain}에서 결정을 미루거나 우유부단해질 수 있어요',
  ),
  TarotRankMeta(
    id: 'three',
    nameKr: '3',
    upTemplate: '{domain}이(가) 조금씩 결실을 맺기 시작해요',
    downTemplate: '{domain}에서 계획이 지연되거나 협업에 어려움이 생겨요',
  ),
  TarotRankMeta(
    id: 'four',
    nameKr: '4',
    upTemplate: '{domain}에서 안정과 잠시의 휴식이 필요한 때예요',
    downTemplate: '{domain}이(가) 정체되거나 권태로움이 느껴질 수 있어요',
  ),
  TarotRankMeta(
    id: 'five',
    nameKr: '5',
    upTemplate: '{domain}에서 갈등이나 경쟁을 통해 배움을 얻어요',
    downTemplate: '{domain}에서의 다툼이나 손실을 주의해야 해요',
  ),
  TarotRankMeta(
    id: 'six',
    nameKr: '6',
    upTemplate: '{domain}에서 협력과 나눔으로 좋은 결과를 얻어요',
    downTemplate: '{domain}에서 과거에 얽매이거나 균형을 잃을 수 있어요',
  ),
  TarotRankMeta(
    id: 'seven',
    nameKr: '7',
    upTemplate: '{domain}을(를) 향한 인내와 노력이 결실로 이어져요',
    downTemplate: '{domain}에서 방향을 잃거나 노력이 흩어질 수 있어요',
  ),
  TarotRankMeta(
    id: 'eight',
    nameKr: '8',
    upTemplate: '{domain}에서 꾸준한 발전과 숙련이 이루어져요',
    downTemplate: '{domain}에서 제약이나 스스로 만든 한계가 느껴져요',
  ),
  TarotRankMeta(
    id: 'nine',
    nameKr: '9',
    upTemplate: '{domain}에서 거의 완성 단계에 다다랐어요',
    downTemplate: '{domain}에서 불안이나 피로가 쌓여있을 수 있어요',
  ),
  TarotRankMeta(
    id: 'ten',
    nameKr: '10',
    upTemplate: '{domain}의 한 사이클이 완성되고 다음 단계로 넘어가요',
    downTemplate: '{domain}에서 부담과 과부하를 느낄 수 있어요',
  ),
  TarotRankMeta(
    id: 'page',
    nameKr: '페이지',
    upTemplate: '{domain}에 대한 호기심과 배움의 자세가 필요해요',
    downTemplate: '{domain}에서 미숙함이나 성급한 판단을 조심하세요',
  ),
  TarotRankMeta(
    id: 'knight',
    nameKr: '나이트',
    upTemplate: '{domain}을(를) 향해 적극적으로 나아갈 때예요',
    downTemplate: '{domain}에서 성급하거나 무모한 행동을 주의하세요',
  ),
  TarotRankMeta(
    id: 'queen',
    nameKr: '퀸',
    upTemplate: '{domain}을(를) 성숙하고 너그럽게 다루는 지혜가 있어요',
    downTemplate: '{domain}에서 감정 기복이나 과도한 예민함을 조심하세요',
  ),
  TarotRankMeta(
    id: 'king',
    nameKr: '킹',
    upTemplate: '{domain}을(를) 주도적으로 이끌어갈 힘이 있어요',
    downTemplate: '{domain}에서 독단적이거나 경직된 태도를 주의하세요',
  ),
];

/// 07단계(추가) §3.6 - 메이저 22장 + 마이너 56장(4수트 × 14랭크) = 78장
/// 풀덱 메타데이터를 조합해 반환한다. [TarotRepository.buildFullDeck]이
/// 이 함수를 감싸 실제 뽑기에 사용할 [TarotCardMeta] 리스트를 제공한다.
List<TarotCardMeta> buildFullTarotDeckMeta() {
  final deck = <TarotCardMeta>[...majorArcana];
  for (final suit in minorSuits) {
    for (final rank in minorRanks) {
      deck.add(
        TarotCardMeta(
          name: '${rank.nameKr} of ${suit.nameKr}',
          nameKr: '${suit.nameKr} ${rank.nameKr}',
          icon: suit.icon,
          type: TarotArcanaType.minor,
          suit: suit.id,
          up: rank.upTemplate.replaceAll('{domain}', suit.domain),
          down: rank.downTemplate.replaceAll('{domain}', suit.domain),
        ),
      );
    }
  }
  return deck;
}

/// 78장 풀덱 메타데이터를 이름으로 빠르게 조회하기 위한 헬퍼.
/// [TarotCard.icon] 등 기존 화면에 영향을 주지 않는 추가(additive) 기능에서만 사용된다.
class TarotDeckData {
  TarotDeckData._();

  static final List<TarotCardMeta> _fullDeck = buildFullTarotDeckMeta();
  static final Map<String, TarotCardMeta> _byName = {
    for (final meta in _fullDeck) meta.name: meta,
  };

  static List<TarotCardMeta> get fullDeck => List.unmodifiable(_fullDeck);

  static TarotCardMeta? metaForName(String name) => _byName[name];

  static String iconFor(String name) => _byName[name]?.icon ?? '🃏';
}

/// 화면(TarotResultScreen 등)에 실제로 표시되는 카드 1장.
/// 07단계(추가) §3.6 - 기존 필드/생성자는 그대로 유지하고(하위 호환),
/// [icon]/[reversed] getter만 추가한다.
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

  /// 78장 풀덱 메타데이터로부터 카드 인스턴스를 생성하는 팩토리.
  factory TarotCard.fromMeta(
    TarotCardMeta meta, {
    required String id,
    required bool isReversed,
  }) {
    return TarotCard(
      id: id,
      name: meta.name,
      nameKr: meta.nameKr,
      isReversed: isReversed,
    );
  }

  /// 07단계(추가) §3.6 - [isReversed]의 별칭 getter(요구사항의 `reversed` 네이밍 지원).
  bool get reversed => isReversed;

  /// 07단계(추가) §3.6 - 카드명으로 78장 풀덱에서 아이콘을 조회한다.
  /// 풀덱에 없는 이름(레거시 데이터 등)이면 기본 카드 아이콘을 반환한다.
  String get icon => TarotDeckData.iconFor(name);
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

  /// 07단계(추가) §3.6 - 20개 주제(연애/재물/취업 등) 중 이 리딩에 적용된 주제.
  /// 명시 지정이 없으면 'general'(종합)로 기본값이 채워지며, 기존 생성자
  /// 호출부(및 [TarotResultModel]을 읽기만 하는 화면들)에는 영향을 주지 않는다.
  final String topic;

  const TarotResultModel({
    required this.id,
    required this.question,
    required this.spreadType,
    required this.positions,
    required this.summary,
    required this.createdAt,
    this.topic = 'general',
  });
}

/// 07단계(추가) §3.6 - 타로상담 최적화 요구사항에서 명시한
/// "cards/question/topic/interpretation" 구조의 경량 결과 모델.
/// [TarotTextEngine.buildResult]가 생성하며, [TarotResultModel]과 달리
/// 포지션(과거/현재/미래) 구분 없이 뽑힌 카드 리스트와 하나의 종합 해석
/// 텍스트만 담는다. [TarotRepository]에서 화면 표시용 [TarotResultModel]로
/// 변환되어 최종적으로 UI에 전달된다.
class TarotResult {
  final List<TarotCard> cards;
  final String question;
  final String topic;
  final String interpretation;

  const TarotResult({
    required this.cards,
    required this.question,
    required this.topic,
    required this.interpretation,
  });
}
