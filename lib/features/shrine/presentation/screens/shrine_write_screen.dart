// shrine_write_screen.dart — 筆(의식 1단계: 부적 쓰기 영상).
// 레퍼런스: 신당 디자인 핸드오프(screens/ritual.dart) WriteScreen.
// write.mp4 1회 재생 · 자막 · SKIP · 안전 타이머. 종료 시 paper(符)로 자동 전환.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

class ShrineWriteScreen extends StatelessWidget {
  const ShrineWriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    return ShrineScreenScaffold(
      rail: const ShrinePhaseRail(0),
      settings: false,
      skip: () => ShrineNav.go(context, 'paper', replace: true),
      background: [
        ShrineSafeVideo('write', reduceMotion: s.reduceMotion, onEnd: () => ShrineNav.go(context, 'paper', replace: true)),
        const ShrineBottomFade(.42),
      ],
      atmosphere: const ShrineAtmosphere(petals: 3),
      child: Align(
        alignment: const Alignment(0, .78),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: SizedBox(
            height: 64,
            child: ShrineTypewriter(
              '${s.displayName}… ${s.displayName}.\n이름을 적겠습니다.',
              speed: ShrineMotion.typeTalk,
              instant: s.reduceMotion,
              style: ShrineType.say(s.textSize.scale, size: 18).copyWith(height: 1.75),
            ),
          ),
        ),
      ),
    );
  }
}
