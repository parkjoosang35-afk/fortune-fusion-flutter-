// shrine_burn_screen.dart — 奉(의식 3단계: 봉헌/소각).
// 레퍼런스: 신당 디자인 핸드오프 screens/ritual.dart BurnScreen.
// burn.mp4 진행률로 burnLine = clamp((t − shrineBurnStart) / shrineBurnSpan)
// [변경 금지 값]. 영상과 이름이 같은 불에 탄다. 종료 후 示(reveal)로 전환.
import 'dart:async';
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

class ShrineBurnScreen extends StatefulWidget {
  const ShrineBurnScreen({super.key});
  @override
  State<ShrineBurnScreen> createState() => _ShrineBurnScreenState();
}

class _ShrineBurnScreenState extends State<ShrineBurnScreen> {
  double _t = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final topic = shrineTopics[s.topic]!;
    final line = s.reduceMotion ? 1.0 : ((_t - shrineBurnStart) / shrineBurnSpan).clamp(0.0, 1.0);
    return ShrineScreenScaffold(
      rail: const ShrinePhaseRail(1),
      settings: false,
      background: [
        ShrineBurnStage(
          video: ShrineSafeVideo(
            'burn',
            reduceMotion: s.reduceMotion,
            safety: const Duration(seconds: 7),
            onProgress: (v) => setState(() => _t = v),
            onEnd: () => Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) ShrineNav.go(context, 'reveal', replace: true);
            }),
          ),
          paper: ShrineBujeok(name: s.name, birth: s.birth, hour: s.hour, topic: topic, burn: line),
        ),
        const ShrineBottomFade(.30),
      ],
      atmosphere: ShrineAtmosphere(petals: 0, embers: line > 0 ? 26 : 6),
      child: Align(
        alignment: const Alignment(0, .84),
        child: Text('한 장을, 신께 올립니다.', style: ShrineType.say(s.textSize.scale)),
      ),
    );
  }
}
