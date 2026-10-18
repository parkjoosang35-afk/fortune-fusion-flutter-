// shrine_talk_screen.dart — 04 월화와 대화.
// 레퍼런스: design_files/screens-a.jsx S04Talk.
// 주제 4종(命/緣/財/流) 중 하나를 선택하면 세션에 저장 후 info로 전환.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';

class ShrineTalkScreen extends StatefulWidget {
  const ShrineTalkScreen({super.key});
  @override
  State<ShrineTalkScreen> createState() => _ShrineTalkScreenState();
}

class _ShrineTalkScreenState extends State<ShrineTalkScreen> {
  ShrineTopic? _picked;
  bool _showChoices = false;
  Timer? _showTimer;

  @override
  void initState() {
    super.initState();
    final rm = context.read<ShrineSessionProvider>().state.reduceMotion;
    _showTimer = Timer(rm ? Duration.zero : const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showChoices = true);
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  void _choose(ShrineTopic topic) {
    if (_picked != null) return;
    setState(() => _picked = topic);
    context.read<ShrineSessionProvider>().set((s) => s.copyWith(topic: topic));
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) ShrineNav.go(context, 'info');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    return ShrineScreenScaffold(
      background: [
        ShrineSafeVideo('talk', loop: true, reduceMotion: s.reduceMotion, align: const Alignment(0, -.6)),
        const ShrineBottomFade(.64),
      ],
      atmosphere: const ShrineAtmosphere(petals: 3),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShrineDialoguePanel(
                child: SizedBox(
                  height: 60,
                  child: ShrineTypewriter(
                    '오셨군요. 오래 기다렸습니다.\n무엇을 여쭈러 오셨습니까.',
                    speed: ShrineMotion.typeTalk,
                    instant: s.reduceMotion,
                    style: ShrineType.say(s.textSize.scale, size: 17).copyWith(height: 1.7),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in shrineTopics.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: ShrineSpace.buttonGap),
                  child: AnimatedOpacity(
                    opacity: _showChoices
                        ? (_picked != null && _picked != entry.key ? .35 : 1)
                        : 0,
                    duration: ShrineMotion.buttonIn,
                    child: IgnorePointer(
                      ignoring: !_showChoices,
                      child: ShrineTopicButton(
                        seal: entry.value.key,
                        label: entry.value.label,
                        ro: entry.value.ro,
                        selected: _picked == entry.key,
                        onTap: () => _choose(entry.key),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
