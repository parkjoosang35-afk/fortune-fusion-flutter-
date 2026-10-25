// 신당(THE SHRINE) U7 — 향 올리기 의식 (전체화면 연출, 약 6.2초)
// 원본: UPDATE_LOG_U1-U13.md "U7 · 2026-10-22 · 향 올리기 의식" 타임라인 1:1.
// [통합 지시서 §2-3 U7] "향 올리기 의식은 원안의 6.2초 전체 화면 연출을
// 기준으로 확인합니다. 간소화가 명시적인 승인으로 확인되지 않으면 임의로
// 생략하지 말고 원안을 복구합니다." — life_panel.dart의 "[범위 조정]" 주석이
// 유일한 간소화 근거였으나 명시적 승인 기록이 아니므로, 이번 지시에 따라
// 원안(전체화면 의식)을 복구한다. 기존 즉시처리(+SnackBar)는 제거하고 이
// 위젯으로 교체한다.
//
// 타임라인(원본 표 그대로, reduce 시 "연출 생략, 숫자만 바꾸고 1s 후 닫힘"):
//   0.0s 걸림 — 부적이 벽에 걸림(먹빛 바랜 상태) · 아래 향로 「香」
//   0.6s 꽂힘 — 향 한 대가 내려와 향로 재에 꽂힘
//   1.4s 점화 — 성냥불이 향 끝에 불 붙이고 물러남, 붉은 불씨 점멸
//   2.0s 연기 — 연기 3줄이 S자로 위로, 불티 9개 상승
//   2.8s 기운 — 부적에 금빛이 아래→위로 훑음, 먹빛 짙어짐, 금빛 광륜 맥동
//   3.4s 숫자 — 「기운 +3일」 알약 등장, 남은 날 숫자 카운트업
//        — 이 시점에 실제 tendTalis 저장(doTend 콜백)
//   4.6s 완료 — 「향을 올렸습니다」 + 민세레나 대사
//   6.2s 닫힘 — 자동(또는 4.6s 이후 화면 탭)
// 의식이 열려 있는 동안 신통방통 하단바는 이 위젯이 풀스크린 다이얼로그로
// 뜨므로 자연스럽게 가려진다(별도 처리 불필요).
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import 'shrine_fx.dart' show shrineHaptic, ShrineHapticLevel;

/// 전체화면 향 올리기 의식을 띄운다. [beforeLeft]는 의식 시작 시점의
/// 남은 기운(일), [doTend]는 "숫자" 단계(3.4s)에서 실제 저장을 수행하는
/// 콜백(tendTalisItem 적용)이며 결과로 저장 이후의 남은 기운을 돌려준다.
Future<void> showShrineIncenseRite(
  BuildContext context, {
  required int beforeLeft,
  required int tendDays,
  required VoidCallback doTend,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => _IncenseRiteScreen(beforeLeft: beforeLeft, tendDays: tendDays, doTend: doTend),
    transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );
}

enum _IncStep { hang, insert, light, smoke, qi, number, done }

class _IncenseRiteScreen extends StatefulWidget {
  final int beforeLeft;
  final int tendDays;
  final VoidCallback doTend;
  const _IncenseRiteScreen({required this.beforeLeft, required this.tendDays, required this.doTend});

  @override
  State<_IncenseRiteScreen> createState() => _IncenseRiteScreenState();
}

class _IncenseRiteScreenState extends State<_IncenseRiteScreen> {
  late final bool _reduce = context.read<ShrineSessionProvider>().state.reduce;
  _IncStep _step = _IncStep.hang;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    if (_reduce) {
      // [U7 "움직임 줄이기"] 연출 생략, 숫자만 바꾸고 1s 후 닫힘.
      widget.doTend();
      _schedule(30, () => setState(() => _step = _IncStep.done));
      _schedule(1000, _closeIfMounted);
      return;
    }
    _schedule(600, () => setState(() => _step = _IncStep.insert));
    _schedule(1400, () {
      setState(() => _step = _IncStep.light);
      shrineHaptic(context, ShrineHapticLevel.light);
    });
    _schedule(2000, () => setState(() => _step = _IncStep.smoke));
    _schedule(2800, () {
      setState(() => _step = _IncStep.qi);
      shrineHaptic(context, ShrineHapticLevel.mid);
    });
    _schedule(3400, () {
      // 이 시점에 실제 저장(tendTalis)을 수행한다 — 원본 "이 시점에 실제
      // tendTalis 저장" 그대로.
      widget.doTend();
      setState(() => _step = _IncStep.number);
    });
    _schedule(4600, () {
      setState(() => _step = _IncStep.done);
      shrineHaptic(context, ShrineHapticLevel.light);
    });
    _schedule(6200, _closeIfMounted);
  }

  void _schedule(int ms, VoidCallback f) {
    _timers.add(Timer(Duration(milliseconds: ms), f));
  }

  void _closeIfMounted() {
    if (mounted) Navigator.of(context).maybePop();
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
    final canClose = _step == _IncStep.done || _step == _IncStep.number;
    return GestureDetector(
      onTap: canClose ? _closeIfMounted : null,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [Color(0xFF1C100A), Color(0xFF040202)], radius: 1.1),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IncenseStage(step: _step, reduce: _reduce, beforeLeft: widget.beforeLeft, tendDays: widget.tendDays),
                  const SizedBox(height: 26),
                  _IncenseCaption(step: _step),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncenseStage extends StatelessWidget {
  final _IncStep step;
  final bool reduce;
  final int beforeLeft;
  final int tendDays;
  const _IncenseStage({required this.step, required this.reduce, required this.beforeLeft, required this.tendDays});

  bool _atLeast(_IncStep s) => _IncStep.values.indexOf(step) >= _IncStep.values.indexOf(s);

  @override
  Widget build(BuildContext context) {
    final inserted = _atLeast(_IncStep.insert);
    final lit = _atLeast(_IncStep.light);
    final smoking = _atLeast(_IncStep.smoke);
    final qiRising = _atLeast(_IncStep.qi);
    final numbered = _atLeast(_IncStep.number);

    return SizedBox(
      width: 220,
      height: 300,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // 부적 — 위쪽 벽에 걸림. 기운(qi) 단계부터 금빛이 아래→위로
          // 훑으며 먹빛이 짙어진다(채도/밝기 상승 근사: 색 필터 보간).
          Positioned(
            top: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: qiRising ? 1 : 0),
              duration: Duration(milliseconds: reduce ? 30 : 900),
              curve: Curves.easeOut,
              builder: (_, qiT, __) {
                final fade = 1 - .22 * (1 - qiT); // .78(바랜 상태)→1.0
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (qiT > 0)
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [Color(0x80F8C900).withValues(alpha: .45 * qiT), Colors.transparent]),
                        ),
                      ),
                    Opacity(
                      opacity: fade,
                      child: Container(
                        width: 104,
                        height: 150,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFD9A8).withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: qiT > .5 ? const Color(0xFFF8C900) : C.goldLine, width: qiT > .5 ? 1.6 : 1),
                          boxShadow: qiT > .3 ? [BoxShadow(color: Color(0x80F8C900).withValues(alpha: .6 * qiT), blurRadius: 16)] : null,
                        ),
                        alignment: Alignment.center,
                        child: Text('符', style: T(1).display(28, w: FontWeight.w900, c: const Color(0xFF3A1A0E))),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 향로 — 아래쪽 놋쇠 「香」.
          Positioned(
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 연기 3줄 — S자로 위로, 좌우로 흔들림.
                if (smoking)
                  SizedBox(
                    height: 90,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        for (final i in [-1, 0, 1])
                          Positioned(
                            bottom: 40,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: reduce ? 30 : 1400 + i.abs() * 120),
                              curve: Curves.easeOut,
                              builder: (_, v, __) => Opacity(
                                opacity: (.55 * v).clamp(0.0, .55),
                                child: Transform.translate(
                                  offset: Offset(i * 8.0 * math.sin(v * math.pi * 2), -70 * v),
                                  child: Container(width: 4, height: 50 * v, decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: const Color(0xCCDCD2C2),
                                  )),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // 향로 + 꽂힌 향 + 불씨.
                Container(
                  width: 70,
                  height: 46,
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8A6A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD6AA64)),
                  ),
                  child: inserted
                      ? Transform.translate(
                          offset: const Offset(0, -34),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (lit)
                                _BlinkingEmber(reduce: reduce),
                              Container(width: 3, height: 34, color: const Color(0xFFBFA878)),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 6),
                Text('香', style: T(1).display(14, w: FontWeight.w900, c: C.gold)),
              ],
            ),
          ),
          // 「기운 +N일」 알약 — 숫자 단계부터 오른쪽에 등장.
          if (numbered)
            Positioned(
              top: 40,
              right: -10,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                builder: (_, v, __) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: v,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8C900),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Color(0x99F8C900), blurRadius: 12)],
                      ),
                      child: Text('기운 +$tendDays일', style: T(1).ui(12, w: FontWeight.w900, c: const Color(0xFF1A0D05))),
                    ),
                  ),
                ),
              ),
            ),
          // 남은 날 카운트업 — before → +tendDays, 0.18s 간격 1씩.
          if (numbered)
            Positioned(
              bottom: 70,
              child: _CountUp(from: beforeLeft, to: (beforeLeft + tendDays).clamp(0, 49)),
            ),
        ],
      ),
    );
  }
}

class _BlinkingEmber extends StatefulWidget {
  final bool reduce;
  const _BlinkingEmber({required this.reduce});
  @override
  State<_BlinkingEmber> createState() => _BlinkingEmberState();
}

class _BlinkingEmberState extends State<_BlinkingEmber> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduce) {
      return Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF5A2E)));
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: .5 + .5 * _c.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5A2E),
            boxShadow: [BoxShadow(color: Color(0xB3E0412F).withValues(alpha: .6 * _c.value), blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}

class _CountUp extends StatefulWidget {
  final int from;
  final int to;
  const _CountUp({required this.from, required this.to});
  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp> {
  late int _cur = widget.from;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.to <= widget.from) return;
    _t = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted) return;
      setState(() => _cur++);
      if (_cur >= widget.to) timer.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('기운 $_cur일 남음', style: T(1).mono.copyWith(color: C.gold, fontSize: 12));
  }
}

class _IncenseCaption extends StatelessWidget {
  final _IncStep step;
  const _IncenseCaption({required this.step});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String? sub;
    switch (step) {
      case _IncStep.hang:
      case _IncStep.insert:
        title = '香 · 향을 꽂는 중';
        sub = null;
        break;
      case _IncStep.light:
      case _IncStep.smoke:
        title = '火 · 불을 붙이는 중';
        sub = null;
        break;
      case _IncStep.qi:
      case _IncStep.number:
        title = '氣 · 기운이 스미는 중';
        sub = null;
        break;
      case _IncStep.done:
        title = '향을 올렸습니다';
        sub = '연기가 닿은 자리부터 먹빛이 다시 짙어집니다. 내일 또 뵙겠습니다.';
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(title),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: T(1).display(21, w: FontWeight.w900)),
          if (sub != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(sub, textAlign: TextAlign.center, style: T(1).body(13, c: C.muted, h: 1.5)),
            ),
          ],
        ],
      ),
    );
  }
}
