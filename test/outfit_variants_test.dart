import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/features/characters/outfit_variants.dart';

/// [의상 20종 확장 — 사용자 요청 2026-10-14]
/// 샵 offers(기본+신·부처·무당 4종)가 5색조 변형으로 확장되어 총 20종이
/// 되는지 검증. 테마는 실제 WrTheme enum 값에서 가져온다.
final List<String> _themeNames = WrTheme.values.map((t) => t.name).toList();

OutfitOffer _offer(String theme) => OutfitOffer.fromJson({
  'theme': theme,
  'price': 100,
  'hasArt': true,
  'owned': false,
});

void main() {
  test('4종 의상은 5색조 변형으로 확장되어 총 20종이 된다', () {
    expect(_themeNames.length, 4);
    final expanded = wrExpandOutfitVariants(_themeNames.map(_offer).toList());
    expect(expanded.length, 20);
    expect(expanded.map((v) => v.label).toSet().length, 5);
    expect(expanded.first.label, '기본');
    expect(expanded.first.tint, isNull);
    expect(expanded[1].tint, isNotNull);
  });

  test('변형은 같은 테마끼리 5개씩 묶여 나오고 순서가 보존된다', () {
    final expanded = wrExpandOutfitVariants([
      _offer(_themeNames[0]),
      _offer(_themeNames[1]),
    ]);
    expect(expanded.length, 10);
    expect(
      expanded.take(5).every((v) => v.offer.theme.name == _themeNames[0]),
      isTrue,
    );
    expect(
      expanded.skip(5).every((v) => v.offer.theme.name == _themeNames[1]),
      isTrue,
    );
  });
}
