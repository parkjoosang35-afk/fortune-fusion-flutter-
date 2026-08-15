import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';

/// [미션 2 · 4축 관통 배선 + 사주 로딩] 결과 화면이 initState에서
/// jeontongProfileStore(SharedPreferences 백엔드)를 비동기로 조회하는
/// "사주 로딩" 상태를 추가하면서, 그 사이 [CircularProgressIndicator]
/// (무한 반복 애니메이션)를 보여준다. `pumpAndSettle()`은 스케줄된 프레임이
/// 완전히 없어질 때까지 기다리는데, 무한 반복 애니메이션이 떠 있는 동안은
/// 절대 "settle"되지 않아 타임아웃난다(Flutter 테스트의 잘 알려진 함정).
///
/// 따라서 이 헬퍼로 먼저 로딩 스피너가 사라질 때까지만 짧게 pump 하고,
/// 그 이후(실제 콘텐츠가 보이는 시점)부터 `pumpAndSettle()`로 "안정화
/// 프레임 수"를 측정한다 — 이 테스트가 원래 검증하려던 것(캐시/빌드
/// 성능)은 로딩 스피너가 아니라 실제 결과 콘텐츠 렌더링이므로 측정
/// 대상을 정확히 좁히는 것이 맞다.
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  var guard = 0;
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
      guard < 20) {
    await tester.pump(const Duration(milliseconds: 16));
    guard++;
  }
}

void main() {
  group('JeontongEightyResultScreen frame bench', () {
    setUp(() {
      // 각 테스트가 프로세스 캐시 상태와 독립되게 리셋.
      jeontongReportCache.clear();
      // [미션 2] SharedPreferences 목 초기화 — 이 화면이 initState에서
      // jeontongProfileStore.get()으로 SharedPreferences를 조회하므로,
      // 다른 jeontong_*_test.dart 파일들과 동일한 관례로 빈 값으로
      // 초기화해 결정론적으로 "저장된 프로필 없음" 경로를 타게 한다.
      SharedPreferences.setMockInitialValues({});
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
      await _pumpUntilLoaded(tester);
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
      await _pumpUntilLoaded(tester);
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
        await _pumpUntilLoaded(tester);
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
