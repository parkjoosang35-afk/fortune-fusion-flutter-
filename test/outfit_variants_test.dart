import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/features/characters/outfit_variants.dart';

OutfitOffer offer(String theme, {String? id, String? name}) => OutfitOffer.fromJson({
  'theme': theme, 'id': id, 'name': name, 'price': 100, 'hasArt': true,
});
void main() {
  test('기존 테마 4종을 색조로 부풀리지 않는다', () {
    final cards = wrExpandOutfitVariants(WrTheme.values.map((t) => offer(t.name)).toList());
    expect(cards.length, 4);
    expect(cards.every((v) => v.tint == null), true);
    expect(cards.map((v) => v.offer.theme), WrTheme.values);
  });
  test('신규 의상 번호와 이름을 그대로 보존한다', () {
    final cards = wrExpandOutfitVariants([
      offer('free', id: 'O_free_01', name: '봄 벚꽃 한복'),
      offer('free', id: 'O_free_02', name: '여름 린넨 셔츠'),
    ]);
    expect(cards.length, 2);
    expect(cards.map((v) => v.offer.id), ['O_free_01', 'O_free_02']);
    expect(cards.map((v) => v.label), ['봄 벚꽃 한복', '여름 린넨 셔츠']);
    expect(cards.every((v) => v.tint == null), true);
  });
}
