// shrine_paper_screen.dart — 符(의식 2단계: 부적 완성).
// 레퍼런스: 신당 디자인 핸드오프 screens/ritual.dart PaperScreen.
// 勅·令 → 부호 → 이름 각 글자 → 인장 순서로 붓글씨가 완성된 뒤, "부적을
// 누르십시오." 안내 + 탭 유도 원이 뜬다. 탭하면 奉(burn)으로 전환.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_bujeok.dart';
import '../widgets/shrine_burn_stage.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

class ShrinePaperScreen extends StatefulWidget {
  const ShrinePaperScreen({super.key});
  @override
  State<ShrinePaperScreen> createState() => _ShrinePaperScreenState();
}

class _ShrinePaperScreenState extends State<ShrinePaperScreen> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final topic = shrineTopics[s.topic]!;
    return ShrineScreenScaffold(
      rail: const ShrinePhaseRail(1),
      settings: false,
      background: [
        ShrineBurnStage(
          paper: GestureDetector(
            onTap: _ready ? () => ShrineNav.go(context, 'burn') : null,
            child: ShrineEmberPulse(
              on: _ready,
              child: ShrineAnimatedBujeok(
                name: s.name,
                birth: s.birth,
                hour: s.hour,
                topic: topic,
                ratio: ShrineBurnStage.ratio,
                reduceMotion: s.reduceMotion,
                onDone: () => setState(() => _ready = true),
              ),
            ),
          ),
        ),
        const ShrineBottomFade(.30),
      ],
      atmosphere: const ShrineAtmosphere(petals: 0, embers: 4),
      overlay: _ready ? const ShrineTapInvite(at: Alignment(0, -.12)) : null,
      child: Align(
        alignment: const Alignment(0, .84),
        child: AnimatedOpacity(
          opacity: _ready ? 1 : 0,
          duration: const Duration(milliseconds: 1200),
          child: Text('부적을 누르십시오.', style: ShrineType.say(s.textSize.scale, size: 18)),
        ),
      ),
    );
  }
}
