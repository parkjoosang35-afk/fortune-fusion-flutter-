// shrine_read_screen.dart — 讀(의식 5단계: 재 읽기).
// 레퍼런스: 신당 디자인 핸드오프 screens/ritual.dart ReadScreen.
// 분석 4줄 1s 간격 체크 → 마지막 줄만 붉게(red-hot). 종료 0.9s 후 受(receive)로 전환.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

class ShrineReadScreen extends StatefulWidget {
  const ShrineReadScreen({super.key});
  @override
  State<ShrineReadScreen> createState() => _ShrineReadScreenState();
}

class _ShrineReadScreenState extends State<ShrineReadScreen> {
  static const lines = ['재의 결이 고르다', '연기가 곧게 오른다', '불씨가 남지 않았다', '한 가닥, 아래로 흘렀다'];
  int _n = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _n++);
      if (_n == 5) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) ShrineNav.go(context, 'receive', replace: true);
        });
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = context.watch<ShrineSessionProvider>().state.textSize;
    final double scale = ts.scale;
    return ShrineScreenScaffold(
      rail: const ShrinePhaseRail(3),
      settings: false,
      background: const [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: Alignment(0, -.2), radius: .8, colors: [Color(0xFF1C0C08), ShrineColor.bg]),
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 330, 52, 0),
        child: Column(
          children: [
            Text('재의 모양을 읽고 있습니다', style: ShrineType.say(scale)),
            const SizedBox(height: 30),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AnimatedOpacity(
                  opacity: _n > i ? 1 : .2,
                  duration: ShrineMotion.screen,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: _n > i && i == 3 ? ShrineColor.redHot : ShrineColor.goldLine),
                        ),
                        child: Text(_n > i ? '✓' : '',
                            style: ShrineType.ui(1, size: 10, w: FontWeight.w700, c: i == 3 ? ShrineColor.redHot : ShrineColor.gold)),
                      ),
                      const SizedBox(width: 12),
                      Text(lines[i],
                          style: ShrineType.saySmall(scale)
                              .copyWith(color: _n > i && i == 3 ? ShrineColor.redHot : ShrineColor.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
