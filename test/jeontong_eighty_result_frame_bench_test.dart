import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';

void main() {
  group('JeontongEightyResultScreen frame bench', () {
    setUp(() {
      // 각 테스트가 프로세스 캐시 상태와 독립되게 리셋.
      jeontongReportCache.clear();
    });

    // 벤치용 harness — MaterialApp + 화면 인스턴스.
    // 실제 컨스트럭터는 4축이 아니라 categoryId(String?) 단일 필드만 받는다
    // (STEP 0-B raw 확인). 나머지 축(userId/birthDateTimeUtc/gender/isLunar)은
    // 이 화면 컨스트럭터에 존재하지 않으므로 삭제.
    Widget harness({required String categoryId}) {
      return MaterialApp(
        home: JeontongEightyResultScreen(categoryId: categoryId),
      );
    }

    testWidgets('cache-warm 시 진입 안정화 프레임 ≤ 3', (tester) async {
      // 워밍업: 같은 키로 캐시 채워둔다.
      final entry = JeontongEightyMatrix.byId('A01')!;
      jeontongReportCache.getOrBuild(entry: entry);

      await tester.pumpWidget(harness(categoryId: 'A01'));
      final frames = await tester.pumpAndSettle();

      expect(
        frames,
        lessThanOrEqualTo(3),
        reason: '캐시 웜 상태에서 안정화까지 프레임이 3 초과. '
            'build() 안에 무거운 동기 작업이 들어갔을 가능성.',
      );
      expect(find.byType(JeontongEightyResultScreen), findsOneWidget);
    });

    testWidgets('cache-cold 시 진입 안정화 프레임 ≤ 6', (tester) async {
      // 캐시가 비어 있는 상태에서 최초 진입.
      expect(jeontongReportCache.hits, 0);
      expect(jeontongReportCache.misses, 0);

      await tester.pumpWidget(harness(categoryId: 'A02'));
      final frames = await tester.pumpAndSettle();

      expect(
        frames,
        lessThanOrEqualTo(6),
        reason: '캐시 콜드 상태에서 안정화까지 프레임이 6 초과. '
            '룰 계산이 build() 내부에서 반복 실행되거나 setState 폭주 가능성.',
      );
      // 최초 진입은 miss 1건.
      expect(jeontongReportCache.misses, greaterThanOrEqualTo(1));
    });

    testWidgets('연속 진입 3회에서 3회차는 반드시 hit', (tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(harness(categoryId: 'A03'));
        await tester.pumpAndSettle();
      }
      // build() 가 캐시를 관통해서 부르는 게 맞다면 hit ≥ 2 여야 한다.
      expect(
        jeontongReportCache.hits,
        greaterThanOrEqualTo(2),
        reason: '반복 진입인데 hit 이 2 미만 = 화면이 캐시를 우회하고 있음.',
      );
    });
  });
}
