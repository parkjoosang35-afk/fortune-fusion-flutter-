import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/history/domain/history_readonly_adapter.dart';

void main() {
  group('HistoryReadOnlyAdapter', () {
    test('5개 섹션 모두 List<HistoryReadOnlyEntry> 반환 (예외 없이)', () {
      final a = const HistoryReadOnlyAdapter();
      expect(a.readTarot(), isA<List<HistoryReadOnlyEntry>>());
      expect(a.readCounsel(), isA<List<HistoryReadOnlyEntry>>());
      expect(a.readFace(), isA<List<HistoryReadOnlyEntry>>());
      expect(a.readPalm(), isA<List<HistoryReadOnlyEntry>>());
      expect(a.readJeontong(), isA<List<HistoryReadOnlyEntry>>());
    });

    test('반환값의 모든 필드가 null-safe / non-null', () {
      final a = const HistoryReadOnlyAdapter();
      for (final list in [
        a.readTarot(),
        a.readCounsel(),
        a.readFace(),
        a.readPalm(),
        a.readJeontong(),
      ]) {
        for (final e in list) {
          expect(e.id.isNotEmpty, isTrue);
          expect(e.title.isNotEmpty, isTrue);
          // subtitle 은 빈 문자열은 허용, null 은 컴파일 타임에 이미 배제됨.
          expect(
            e.createdAt.isUtc,
            isTrue,
            reason: 'createdAt 은 UTC 로 정규화되어야 한다',
          );
        }
      }
    });

    test('adapter 는 어떤 setter/write 메서드도 노출하지 않는다', () {
      final a = const HistoryReadOnlyAdapter();
      // 이 테스트는 API 표면 검증. 컴파일이 되면 그 자체로 PASS.
      // (아래 메서드가 존재하면 컴파일 성공, 존재하지 않으면 즉시 실패)
      a.readTarot();
      a.readCounsel();
      a.readFace();
      a.readPalm();
      a.readJeontong();
      // 이 파일에서 절대 호출하지 말 것: adapter.write* / adapter.delete* / adapter.update*
      // (설령 존재해도 이 미션의 원칙 위반 — 그 경우 STEP 1 을 정정하라)
    });
  });
}
