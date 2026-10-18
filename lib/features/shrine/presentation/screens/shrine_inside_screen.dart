// shrine_inside_screen.dart — 03 신당 내부.
// 레퍼런스: design_files/screens-a.jsx S03Shrine.
// 화면 어디든 탭하면 talk(월화와 대화)로 전환.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';

class ShrineInsideScreen extends StatelessWidget {
  const ShrineInsideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    return ShrineScreenScaffold(
      back: false,
      background: [
        // [버그 수정] Positioned는 Stack의 직계 RenderObjectWidget 자식이어야
        // 한다. GestureDetector(child: Positioned.fill(...))처럼 감싸는 순서가
        // 뒤바뀌면 ParentData 타입 불일치 예외가 매 프레임 반복되며
        // "RangeError: Maximum call stack size exceeded"(Stack Overflow)로
        // 이어진다(영상 재현·Playwright 콘솔 스택 트레이스로 확인). 반드시
        // Positioned.fill(child: GestureDetector(...)) 순서를 유지한다
        // (shrine_receive_screen.dart의 기존 올바른 패턴과 동일).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ShrineNav.go(context, 'talk'),
            child: Image.asset('${kShrineImageBase}shrine.jpg', fit: BoxFit.cover),
          ),
        ),
        // [버그 수정 2] 이 비네트 그라디언트는 순수 시각 효과이지만,
        // BoxDecoration.hitTest()는 shape가 rectangle이고 borderRadius가
        // 없으면 항상 true를 반환한다(Flutter box_decoration.dart). 따라서
        // IgnorePointer 없이 Positioned.fill로 전체 화면을 덮으면 Stack의
        // 히트테스트(역순 순회, 첫 히트에서 중단)가 여기서 멈춰버려, 바로
        // 아래 레이어(배경 GestureDetector)까지 탭이 전달되지 않는다 —
        // 이것이 "화면을 눌러도 talk로 안 넘어감" 버그의 실제 원인이다.
        // ShrineBottomFade(동일 패턴)는 자체적으로 IgnorePointer를 쓰고
        // 있으므로 여기도 동일하게 감싼다.
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.1),
                  radius: 1.1,
                  colors: [Color(0x00000000), Color(0x8A000000)],
                  stops: [.5, 1],
                ),
              ),
            ),
          ),
        ),
        const ShrineBottomFade(.45),
      ],
      atmosphere: const ShrineAtmosphere(petals: 5),
      overlay: const ShrineTapInvite(at: Alignment(0, -.03)),
      child: Align(
        alignment: const Alignment(0, .68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('堂內 · INSIDE', style: ShrineType.mono()),
              const SizedBox(height: 14),
              SizedBox(
                height: 64,
                child: ShrineTypewriter(
                  '향이 아직 꺼지지 않았습니다.\n누군가, 당신이 올 줄 알았던 모양입니다.',
                  speed: ShrineMotion.typeEntry,
                  instant: s.reduceMotion,
                  style: ShrineType.say(s.textSize.scale, size: 18).copyWith(height: 1.7),
                ),
              ),
              const SizedBox(height: 26),
              Text('화면 어디든 눌러 다가가기',
                  style: ShrineType.ui(1, size: 12, c: ShrineColor.faint)),
            ],
          ),
        ),
      ),
    );
  }
}
