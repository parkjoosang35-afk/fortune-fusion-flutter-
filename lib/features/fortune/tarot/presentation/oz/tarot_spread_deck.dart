/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1] 78장 진열용 표시 데이터.
///
/// 디자인 핸드오프(`design_handoffs/tarot_picker/tarot-data.js`)의
/// `TAROT_DECK` 배열을 그대로 Dart 상수로 포팅한다. 이 파일이 갖는 이름/
/// 심볼/키워드는 **순수 진열(장식) 용도**로만 쓰인다 - 5장을 다 뽑은 뒤
/// 나머지 73장이 앞면으로 뒤집힐 때 보여줄 레이블이며, 실제로 사용자가
/// "뽑은" 5장의 정체는 여기서 절대 결정되지 않는다(그 정체는 여전히
/// [TarotSessionController.reveal]이 서버 응답을 받아야만 확정된다).
///
/// 즉 화면에 뒤집혀 보이는 73장은 "어차피 못 고르는, 이미 제외된 카드들이
/// 재미로 공개되는 것"이고, 슬롯에 담긴 5장은 끝까지 뒷면 그대로 유지된다
/// (디자인 스펙 §5.3 "슬롯의 5장은 뒷면 유지" 원칙 그대로 준수).
///
/// `name` 필드는 기존 [tarotCardImageFile]의 키와 정확히 일치시켜, 실제
/// 카드 아트(webp)를 그대로 재사용할 수 있게 한다(스펙은 SVG를 권장하지만
/// 이 앱은 이미 78장 실사 아트를 보유하고 있으므로 그대로 사용 - README
/// "브랜드 문양만" 원칙은 스톡 사진이 아닌 자체 제작 카드 아트이므로 준수).
library;

class TarotSpreadCardMeta {
  /// 진열 그리드 내에서의 안정적 식별자(0..77). 실제 서버 카드 id와는 무관.
  final int id;
  final String name;
  final String en;
  final String symbol;
  final String keyword;
  final String? suitColor; // hex ARGB 문자열 없이, Color 값을 바로 든다(아래 참고)

  const TarotSpreadCardMeta({
    required this.id,
    required this.name,
    required this.en,
    required this.symbol,
    required this.keyword,
    this.suitColor,
  });
}

const List<TarotSpreadCardMeta> _majorArcana = [
  TarotSpreadCardMeta(id: 0, name: 'The Fool', en: 'The Fool', symbol: '☉', keyword: '시작·자유'),
  TarotSpreadCardMeta(id: 1, name: 'The Magician', en: 'The Magician', symbol: '∞', keyword: '창조·의지'),
  TarotSpreadCardMeta(id: 2, name: 'The High Priestess', en: 'The High Priestess', symbol: '☾', keyword: '직관·비밀'),
  TarotSpreadCardMeta(id: 3, name: 'The Empress', en: 'The Empress', symbol: '♀', keyword: '풍요·사랑'),
  TarotSpreadCardMeta(id: 4, name: 'The Emperor', en: 'The Emperor', symbol: '♂', keyword: '권위·안정'),
  TarotSpreadCardMeta(id: 5, name: 'The Hierophant', en: 'The Hierophant', symbol: '☩', keyword: '전통·신뢰'),
  TarotSpreadCardMeta(id: 6, name: 'The Lovers', en: 'The Lovers', symbol: '♥', keyword: '선택·조화'),
  TarotSpreadCardMeta(id: 7, name: 'The Chariot', en: 'The Chariot', symbol: '⚔', keyword: '전진·의지'),
  TarotSpreadCardMeta(id: 8, name: 'Strength', en: 'Strength', symbol: '∞', keyword: '용기·인내'),
  TarotSpreadCardMeta(id: 9, name: 'The Hermit', en: 'The Hermit', symbol: '✦', keyword: '성찰·지혜'),
  TarotSpreadCardMeta(id: 10, name: 'Wheel of Fortune', en: 'Wheel of Fortune', symbol: '☸', keyword: '변화·운명'),
  TarotSpreadCardMeta(id: 11, name: 'Justice', en: 'Justice', symbol: '⚖', keyword: '균형·진실'),
  TarotSpreadCardMeta(id: 12, name: 'The Hanged Man', en: 'The Hanged Man', symbol: '✟', keyword: '희생·관점'),
  TarotSpreadCardMeta(id: 13, name: 'Death', en: 'Death', symbol: '☠', keyword: '변화·끝'),
  TarotSpreadCardMeta(id: 14, name: 'Temperance', en: 'Temperance', symbol: '⚗', keyword: '조화·인내'),
  TarotSpreadCardMeta(id: 15, name: 'The Devil', en: 'The Devil', symbol: '⛧', keyword: '집착·유혹'),
  TarotSpreadCardMeta(id: 16, name: 'The Tower', en: 'The Tower', symbol: '⚡', keyword: '붕괴·각성'),
  TarotSpreadCardMeta(id: 17, name: 'The Star', en: 'The Star', symbol: '★', keyword: '희망·영감'),
  TarotSpreadCardMeta(id: 18, name: 'The Moon', en: 'The Moon', symbol: '☽', keyword: '환상·불안'),
  TarotSpreadCardMeta(id: 19, name: 'The Sun', en: 'The Sun', symbol: '☀', keyword: '기쁨·성공'),
  TarotSpreadCardMeta(id: 20, name: 'Judgement', en: 'Judgement', symbol: '⚞', keyword: '부활·결단'),
  TarotSpreadCardMeta(id: 21, name: 'The World', en: 'The World', symbol: '⊕', keyword: '완성·성취'),
];

class _SuitDef {
  final String key;
  final String nameKo;
  final String symbol;
  const _SuitDef(this.key, this.nameKo, this.symbol);
}

const List<_SuitDef> _suits = [
  _SuitDef('완드', '완드', '⚔'),
  _SuitDef('컵', '컵', '♥'),
  _SuitDef('소드', '소드', '✦'),
  _SuitDef('펜타클', '펜타클', '★'),
];

const List<String> _ranks = [
  '에이스', '2', '3', '4', '5', '6', '7', '8', '9', '10', '페이지', '나이트', '퀸', '킹',
];

List<TarotSpreadCardMeta> _buildMinorArcana() {
  final list = <TarotSpreadCardMeta>[];
  var idx = 0;
  for (final suit in _suits) {
    for (final rank in _ranks) {
      list.add(
        TarotSpreadCardMeta(
          id: 100 + idx,
          name: '$rank of ${suit.nameKo}',
          en: '$rank of ${suit.key}',
          symbol: suit.symbol,
          keyword: '${suit.nameKo}·$rank',
        ),
      );
      idx++;
    }
  }
  return list;
}

/// 78장 진열용 전체 덱(메이저 22 + 마이너 56).
final List<TarotSpreadCardMeta> tarotSpreadDeck = [
  ..._majorArcana,
  ..._buildMinorArcana(),
];
