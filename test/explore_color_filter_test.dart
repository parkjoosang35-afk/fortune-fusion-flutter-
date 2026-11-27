import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';

/// [모두의 소원방 재배치 — 사용자 요청 2026-10-14]
/// 정렬 칩 자리에 들어갈 소원빛깔 카테고리의 데이터 기반을 검증한다
/// (전체 칩 + 8색 칩이 id·한자·라벨을 모두 갖춰야 빛깔 필터가 동작한다).
/// 화면 배치 자체는 정적 분석으로 검증하고 실기기에서 최종 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('소원빛깔 카테고리는 8색이며 id·한자·라벨을 모두 갖춘다', () async {
    await WrCatalog.load();
    final colors = WrCatalog.I.wishColors;
    expect(colors.length, 8);
    for (final w in colors) {
      expect(w['id'], isNotEmpty);
      expect(w['hanja'], isNotEmpty);
      expect(w['label'], isNotEmpty);
    }
    expect(colors.any((w) => w['id'] == 'hope'), isTrue);
  });
}
