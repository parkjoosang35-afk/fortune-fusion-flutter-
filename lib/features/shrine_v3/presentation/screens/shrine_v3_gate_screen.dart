import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/application/auth_provider.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/shrine_asset_path.dart';
import 'shrine_v3_main_screen.dart';

/// 신당(THE SHRINE) v3 — 02 입장 연출. README/HTML 프로토타입 `Gate`
/// 컴포넌트와 동일한 타이밍(0.4s/1.5s/4.0s 단계 전환 + 4.8s 후 자동으로
/// 03 메인 이동)을 그대로 재현한다. 화면을 탭하면 바로 넘어간다.
class ShrineV3GateScreen extends StatefulWidget {
  const ShrineV3GateScreen({super.key});

  @override
  State<ShrineV3GateScreen> createState() => _ShrineV3GateScreenState();
}

class _ShrineV3GateScreenState extends State<ShrineV3GateScreen> {
  int _phase = 0;
  final List<Timer> _timers = [];
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timers.addAll([
      Timer(const Duration(milliseconds: 400), () => _setPhase(1)),
      Timer(const Duration(milliseconds: 1500), () => _setPhase(2)),
      Timer(const Duration(milliseconds: 4000), () => _setPhase(3)),
      Timer(const Duration(milliseconds: 4800), _goMain),
    ]);
  }

  void _setPhase(int p) {
    if (!mounted) return;
    setState(() => _phase = p);
  }

  void _goMain() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShrineV3MainScreen()),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nickname = context.read<AuthProvider>().currentUser?.nickname;
    return GestureDetector(
      onTap: _goMain,
      child: Scaffold(
        backgroundColor: ShrineV3Colors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: _phase >= 1 ? 1 : 0,
              duration: const Duration(milliseconds: 900),
              child: Image.asset(
                shrineSceneImage('hall'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: ShrineV3Colors.ink),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35)),
            ),
            // 좌우로 열리는 문짝(door) 연출 — 프로토타입의 .lf/.rt 역할.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              left: _phase >= 2 ? -MediaQuery.of(context).size.width / 2 : 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width / 2,
              child: Container(color: ShrineV3Colors.ink),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              right: _phase >= 2 ? -MediaQuery.of(context).size.width / 2 : 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width / 2,
              child: Container(color: ShrineV3Colors.ink),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _phase < 2
                        ? '방울 소리와 함께 문이 열립니다'
                        : '어서 오십시오${nickname != null ? ', $nickname님' : ''}',
                    key: ValueKey(_phase < 2),
                    style: ShrineV3TextStyles.ui.copyWith(
                      color: ShrineV3Colors.paper,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
