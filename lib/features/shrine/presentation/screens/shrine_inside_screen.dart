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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ShrineNav.go(context, 'talk'),
          child: Positioned.fill(
            child: Image.asset('${kShrineImageBase}shrine.jpg', fit: BoxFit.cover),
          ),
        ),
        const Positioned.fill(
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
