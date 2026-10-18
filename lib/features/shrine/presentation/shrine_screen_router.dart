// shrine_screen_router.dart — [통합 Fix 04] shrine_navigation.dart가 참조하는
// 화면 매핑 함수. 신당 스타터의 go_router GoRoute 선언부 + screens_todo.dart의
// TodoScreen을 이 프로젝트의 Navigator 1.0 구조에 맞게 치환했다.
//
// P1(입장계열 5화면)만 실제 화면으로 연결하고, 나머지 17개 라우트(P2~P6
// 범위: write/paper/burn/reveal/read/receive/use* /story/memory/branch/
// surprised/ending/scroll/more)는 신당 스타터의 TodoScreen과 동일한 역할의
// _ShrineTodoScreen 플레이스홀더로 연결해, 지금 단계에서도 앱이 컴파일되고
// 화면 전환 흐름을 웹 프리뷰로 검증할 수 있도록 한다. 각 단계가 실제로
// 구현될 때 이 매핑만 교체하면 된다(rite.dart/shrine_rite_data.dart의
// "데이터만 추가하면 된다" 설계를 그대로 따름).
import 'package:flutter/widgets.dart';
import '../domain/shrine_rite_data.dart';
import '../domain/shrine_tokens.dart';
import 'screens/shrine_door_screen.dart';
import 'screens/shrine_entry_screen.dart';
import 'screens/shrine_info_screen.dart';
import 'screens/shrine_inside_screen.dart';
import 'screens/shrine_talk_screen.dart';
import 'shrine_navigation.dart';
import 'widgets/shrine_chrome.dart';
import 'widgets/shrine_scaffold.dart';

/// rite.dart(shrine_rite_data.dart)의 라우트 id → 실제 화면 위젯.
Widget shrineScreenFor(String id) {
  switch (id) {
    case 'entry':
      return const ShrineEntryScreen();
    case 'door':
      return const ShrineDoorScreen();
    case 'shrine':
      return const ShrineInsideScreen();
    case 'talk':
      return const ShrineTalkScreen();
    case 'info':
      return const ShrineInfoScreen();
    default:
      // [P2/P3/P4/P5/P6 범위] 아직 구현되지 않은 화면 — 신당 스타터
      // screens_todo.dart의 TodoScreen과 동일한 자리 표시자.
      return _ShrineTodoScreen(id);
  }
}

class _ShrineTodoScreen extends StatelessWidget {
  final String id;
  const _ShrineTodoScreen(this.id);

  @override
  Widget build(BuildContext context) {
    final route = shrineRouteById(id);
    final idx = shrineRoutes.indexOf(route);
    final next = idx + 1 < shrineRoutes.length ? shrineRoutes[idx + 1] : shrineRoutes.first;
    return ShrineScreenScaffold(
      rail: Text('${route.k} · ${route.ko}', style: ShrineType.mono()),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(route.k, style: ShrineType.display(96, c: ShrineColor.gold)),
            const SizedBox(height: 16),
            Text('${route.ko} — 구현 대기', style: ShrineType.say(1)),
            const SizedBox(height: 8),
            Text('P2~P6 단계에서 순차 구현 예정', style: ShrineType.ui(1, size: 12, c: ShrineColor.faint)),
            const SizedBox(height: 32),
            SizedBox(
              width: 260,
              child: ShrineRedButton('다음 · ${next.ko}', onTap: () => ShrineNav.go(context, next.id)),
            ),
          ],
        ),
      ),
    );
  }
}
