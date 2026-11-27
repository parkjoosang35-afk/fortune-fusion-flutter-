// [반응형 화면 규격 통일 전수조사 중 발견한 기존 수정의 테스트 공백을 메움 —
// 클리핑과는 별개 카테고리의 크래시 버그, 코드 자체는 이미 안전하게 고쳐져
// 있었으나(주석 참고) 전용 회귀 테스트가 없었다]
//
// ComposeScreen._themeCard()의 테마 아이콘(_BobGlyph)은 선택된(animate:true)
// 카드에서만 AnimationController를 만들어 위아래로 살짝 떠다니는 애니메이션을
// 준다. 과거 버전은 `late final _ctrl = AnimationController(...)`로 선언해,
// 한 번도 선택된 적 없는(animate가 항상 false였던) 테마 카드는 build()에서
// _ctrl을 전혀 참조하지 않다가, 화면을 벗어나 dispose()가 `_ctrl.dispose()`를
// 호출하는 순간 처음으로 지연 초기화가 실행됐다. 이 시점엔 State가 이미
// deactivate 중이라 AnimationController 생성자의 vsync(this) → TickerMode
// 조상 탐색이 "Looking up a deactivated widget's ancestor is unsafe"로
// 크래시했다 — 선택 안 된 테마 카드가 하나라도 있으면(기본 상태가 늘 그렇다,
// 테마 4종 중 1개만 기본 선택) 소원 작성 화면을 나갈 때마다 100% 재현되는
// 실제 버그였다.
//
// 현재 코드는 nullable 지연 생성(`AnimationController? _ctrl`)으로 이미
// 고쳐져 있다 — 이 테스트는 그 수정이 유효한지 고정하는 회귀 테스트다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/compose/compose_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '선택되지 않은 테마 카드가 있는 채로 소원 작성 화면을 벗어나도 '
    'Ticker dispose 시점에 크래시하지 않는다',
    (tester) async {
      await tester.runAsync(() => WrCatalog.load());
      // [기본 상태 그대로] ComposeScreen은 _theme = WrTheme.free로 시작하므로
      // 테마 4종(WrCatalog.I.themes) 중 1개만 선택된 상태이고, 나머지는
      // 한 번도 animate:true가 된 적 없는(즉 과거 버그에서 _ctrl이 지연
      // 초기화된 적 없는) 카드로 남는다 — 재현 조건을 그대로 유지한다.
      final provider = WishRoomProvider(_FakeWrRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<WishRoomProvider>.value(
          value: provider,
          child: const MaterialApp(home: ComposeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: '소원 작성 화면 최초 렌더');

      // 화면 전체를 다른 위젯으로 교체해 ComposeScreen과 그 안의 모든
      // _BobGlyphState(선택/비선택 전부)를 한꺼번에 dispose시킨다 — 과거
      // 버그의 정확한 재현 시점.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('다른 화면'))),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            '비선택 테마 카드의 _BobGlyphState dispose 시 "Looking up a '
            'deactivated widget\'s ancestor is unsafe" 회귀 시 재발',
      );
      expect(find.text('다른 화면'), findsOneWidget);
    },
  );
}
