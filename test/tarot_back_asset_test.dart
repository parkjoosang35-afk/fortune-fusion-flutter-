import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/fortune/tarot/domain/tarot_card_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('미등록 카드 이름은 실제 등록된 카드 뒷면으로 연결된다', () async {
    expect(tarotCardImagePath('미등록 카드'), tarotDefaultBackAsset);
    expect(tarotCardThumbPath('미등록 카드'), tarotDefaultBackAsset);
    expect((await rootBundle.load(tarotDefaultBackAsset)).lengthInBytes, greaterThan(0));
  });
}
