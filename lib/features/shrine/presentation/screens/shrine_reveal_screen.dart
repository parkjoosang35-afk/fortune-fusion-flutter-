// shrine_reveal_screen.dart — 示(의식 4단계: 계시).
// 레퍼런스: 신당 디자인 핸드오프 screens/ritual.dart RevealScreen.
// 영상 어둡게 + 주제 한자 150px 먹번짐 2.4s + 계시 문구. 3.8s 후 + 여운 → 讀(read).
// [변경 금지 값 — 신당_개발지시서_v1.4.pdf §2] 150px redHot 한자 크기.
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

class ShrineRevealScreen extends StatefulWidget {
  const ShrineRevealScreen({super.key});
  @override
  State<ShrineRevealScreen> createState() => _ShrineRevealScreenState();
}

class _ShrineRevealScreenState extends State<ShrineRevealScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final rm = context.read<ShrineSessionProvider>().state.reduceMotion;
    _t = Timer(Duration(milliseconds: rm ? 2400 : 5800), () {
      if (mounted) ShrineNav.go(context, 'read', replace: true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final topic = shrineTopics[s.topic]!;
    return ShrineScreenScaffold(
      rail: const ShrinePhaseRail(2),
      settings: false,
      background: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(
                  [.35, 0, 0, 0, 0, 0, .35, 0, 0, 0, 0, 0, .35, 0, 0, 0, 0, 0, 1, 0]),
              child: Image.asset('${kShrineVideoBase}burn.jpg', fit: BoxFit.cover),
            ),
          ),
        ),
      ],
      atmosphere: const ShrineAtmosphere(petals: 0, embers: 6),
      child: Column(
        children: [
          const SizedBox(height: 150),
          ShrineInkBleed(
            child: Text(topic.key,
                style: ShrineType.display(150, c: ShrineColor.redHot)
                    .copyWith(height: 1, shadows: const [Shadow(color: ShrineColor.redGlow, blurRadius: 40)])),
          ),
          const SizedBox(height: 40),
          ShrineFadeRise(
            delay: const Duration(milliseconds: 1600),
            child: Text('${topic.name} · ${topic.hanja}', style: ShrineType.mono()),
          ),
          const SizedBox(height: 18),
          ShrineFadeRise(
            delay: const Duration(milliseconds: 2000),
            child: Text(
              '${topic.reveal[0]}\n${topic.reveal[1].replaceAll('{이름}', s.displayName)}',
              textAlign: TextAlign.center,
              style: ShrineType.say(s.textSize.scale, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}
