// 신당(THE SHRINE) U6 — 부적 저장 의식 (사진첩 저장 전체화면 연출)
// 원본: UPDATE_LOG_U1-U13.md "U6 · 2026-10-22 · 부적 저장 의식" 타임라인 1:1.
// [통합 지시서 §2-3 U6] "설계에 명시된 4.7초 전체 화면 저장 의식을
// 복구합니다" — 기존에는 토스트(SnackBar)로 간소화되어 있었다. 실제 PNG
// 저장(renderBujeokPng + Gal.putImageBytes)은 이 연출이 뜨는 즉시 병렬로
// 시작해, 연출이 끝나는 시점에는 이미 저장이 완료(또는 실패 확정)되어
// 있도록 한다 — 원본 "실제 PNG 저장은 누르는 즉시 시작해 연출과 동시에
// 진행. 실패 시 마지막 단계에서 오류 안내" 그대로.
//
// 타임라인(원본 표 그대로, reduce(움직임 줄이기) 시에는 생략):
//   0.0s 光聚 가라앉음 — 먹색 radial로 어두워짐(0.5s)
//   0.5s 떠오름 — 부적이 아래에서 가운데로 떠오름(1s, 살짝 튕김) + 금빛 광륜
//   1.3s 藏 인장 — 붉은 인장이 떨어져 쾅(0.32s 튕김) + 파문 3겹 + 불티 28개
//   2.1s 一閃 — 흰 금빛 띠가 왼→오 훑고 「寫眞帖 사진첩」 함 등장
//   2.6s 들어감 — 부적이 줄며 함 속으로 빨려 들어감(0.8s)
//   3.4s 완료 — 함 뚜껑 닫힘 + 「간직하였습니다」 문구
//   4.7s 닫힘 — 자동으로 닫힘(또는 화면 탭)
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import 'bujeok.dart' show BujeokSheet;
import '../engine/shrine_engine.dart' show TalismanSpec;
import 'shrine_fx.dart' show shrineHaptic, ShrineHapticLevel;

/// 전체화면 저장 의식을 띄우고, 실제 PNG 저장 작업(doSave)을 병렬로
/// 실행한다. 저장 성공 여부와 무관하게 애니메이션은 설계된 타임라인대로
/// 진행하되, 실패했을 경우 마지막 완료 문구만 오류 메시지로 바뀐다.
/// [반환] 사용자가 닫을 때(자동 또는 탭) Future가 완료된다.
Future<void> showShrineSaveRite(
  BuildContext context, {
  required String name,
  required TalismanSpec spec,
  required Future<bool> Function() doSave,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => _SaveRiteScreen(name: name, spec: spec, doSave: doSave),
    transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );
}

enum _SaveStep { sink, rise, stamp, flash, enter, done }

class _SaveRiteScreen extends StatefulWidget {
  final String name;
  final TalismanSpec spec;
  final Future<bool> Function() doSave;
  const _SaveRiteScreen({required this.name, required this.spec, required this.doSave});

  @override
  State<_SaveRiteScreen> createState() => _SaveRiteScreenState();
}

class _SaveRiteScreenState extends State<_SaveRiteScreen> with TickerProviderStateMixin {
  late final bool _reduce = context.read<ShrineSessionProvider>().state.reduce;
  _SaveStep _step = _SaveStep.sink;
  bool? _success; // null=저장 진행 중, true/false=완료
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    // 실제 저장은 연출 시작과 동시에(0.0s) 병렬로 진행한다.
    widget.doSave().then((ok) {
      if (mounted) setState(() => _success = ok);
    }).catchError((_) {
      if (mounted) setState(() => _success = false);
    });

    if (_reduce) {
      // [U6 "움직임 줄이기"] 연출 생략, 인장만 0.05s → 완료 0.6s.
      _schedule(50, () => setState(() => _step = _SaveStep.stamp));
      _schedule(650, () => setState(() => _step = _SaveStep.done));
      _schedule(1250, _closeIfMounted);
      return;
    }
    _schedule(500, () {
      setState(() => _step = _SaveStep.rise);
      shrineHaptic(context, ShrineHapticLevel.light);
    });
    _schedule(1300, () {
      setState(() => _step = _SaveStep.stamp);
      shrineHaptic(context, ShrineHapticLevel.strong);
    });
    _schedule(2100, () => setState(() => _step = _SaveStep.flash));
    _schedule(2600, () {
      setState(() => _step = _SaveStep.enter);
      shrineHaptic(context, ShrineHapticLevel.light);
    });
    _schedule(3400, () {
      setState(() => _step = _SaveStep.done);
      shrineHaptic(context, ShrineHapticLevel.mid);
    });
    _schedule(4700, _closeIfMounted);
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
    final done = _step == _SaveStep.done;
    return GestureDetector(
      onTap: done ? _closeIfMounted : null,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 光聚 가라앉음 — 먹색 radial 배경(0.5s).
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 500),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF1C0A08), Color(0xFF040202)],
                    radius: 1.1,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SaveStage(step: _step, reduce: _reduce, name: widget.name, spec: widget.spec),
                  const SizedBox(height: 28),
                  _SaveCaption(step: _step, success: _success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveStage extends StatelessWidget {
  final _SaveStep step;
  final bool reduce;
  final String name;
  final TalismanSpec spec;
  const _SaveStage({required this.step, required this.reduce, required this.name, required this.spec});

  @override
  Widget build(BuildContext context) {
    final idx = _SaveStep.values.indexOf(step);
    final risen = idx >= _SaveStep.values.indexOf(_SaveStep.rise);
    final stamped = idx >= _SaveStep.values.indexOf(_SaveStep.stamp);
    final flashed = idx >= _SaveStep.values.indexOf(_SaveStep.flash);
    final entering = step == _SaveStep.enter;
    final entered = idx >= _SaveStep.values.indexOf(_SaveStep.enter);

    return SizedBox(
      width: 220,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 금빛 광륜 — 떠오름과 함께 0.2→1배.
          if (risen && !entered)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: reduce ? 50 : 900),
              curve: Curves.easeOut,
              builder: (_, v, __) => Opacity(
                opacity: v,
                child: Transform.scale(
                  scale: .2 + .8 * v,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x80F8C900).withValues(alpha: .5 * v), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 부적 본체 — 아래(70%)에서 떠올라 가운데로. 들어감(enter) 단계에서
          // 0.18배로 줄며 함 속으로 빨려 들어간다.
          TweenAnimationBuilder<double>(
            key: ValueKey('rise-$risen'),
            tween: Tween(begin: risen ? 0 : 1, end: 0),
            duration: Duration(milliseconds: reduce ? 50 : 1000),
            curve: const Cubic(.3, 1.2, .3, 1),
            builder: (_, riseT, __) {
              final offsetY = 160 * riseT;
              final rot = -6 * (math.pi / 180) * riseT;
              final baseScale = .7 + .3 * (1 - riseT);
              final enterScale = entering || entered ? .18 : 1.0;
              return AnimatedOpacity(
                opacity: entered && !entering ? 0 : 1,
                duration: Duration(milliseconds: reduce ? 50 : 300),
                child: Transform.translate(
                  offset: Offset(0, offsetY),
                  child: Transform.rotate(
                    angle: rot,
                    child: AnimatedScale(
                      scale: baseScale * enterScale,
                      duration: Duration(milliseconds: reduce ? 50 : 800),
                      curve: Curves.easeInCubic,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          BujeokSheet(w: 150, name: name, spec: spec),
                          // 藏 인장 — 위에서 떨어져 쾅.
                          if (stamped)
                            Positioned(
                              top: -10,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 2.4, end: 1),
                                duration: Duration(milliseconds: reduce ? 30 : 320),
                                curve: Curves.elasticOut,
                                builder: (_, v, __) => Transform.rotate(
                                  angle: -8 * math.pi / 180,
                                  child: Transform.scale(
                                    scale: v,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC8170F),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: const [BoxShadow(color: Color(0xB3E0412F), blurRadius: 18, spreadRadius: 2)],
                                      ),
                                      child: Text('藏', style: T(1).display(28, w: FontWeight.w900, c: const Color(0xFFFFE9D6))),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // 파문 3겹.
                          if (stamped)
                            for (final i in [0, 1, 2])
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(milliseconds: (reduce ? 20 : 500) + i * (reduce ? 10 : 140)),
                                builder: (_, v, __) => Opacity(
                                  opacity: (1 - v).clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: 1 + v * 5,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: i.isEven ? const Color(0x99E0412F) : const Color(0x99F8C900), width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // 一閃 — 흰 금빛 띠가 왼→오로 훑음.
          if (flashed && !entered)
            Positioned(
              top: 60,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: -1, end: 1),
                duration: Duration(milliseconds: reduce ? 20 : 550),
                curve: Curves.easeInOut,
                builder: (_, v, __) => Opacity(
                  opacity: (1 - v.abs()).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(90 * v, 0),
                    child: Container(
                      width: 56,
                      height: 170,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.white.withValues(alpha: .85), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 寫眞帖 사진첩 함 — 一閃 이후 아래에 등장, 들어감 단계에서 뚜껑 닫힘.
          if (flashed)
            Positioned(
              bottom: 0,
              child: _PhotoBox(closed: entered && step != _SaveStep.enter),
            ),
        ],
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final bool closed;
  const _PhotoBox({required this.closed});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 96,
          height: closed ? 10 : 56,
          decoration: BoxDecoration(
            color: const Color(0xFF3A241A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.goldLine),
            boxShadow: closed ? [const BoxShadow(color: Color(0x99F8C900), blurRadius: 24, spreadRadius: 2)] : null,
          ),
        ),
        const SizedBox(height: 6),
        Text('寫眞帖 사진첩', style: T(1).mono.copyWith(color: C.muted, fontSize: 10)),
      ],
    );
  }
}

class _SaveCaption extends StatelessWidget {
  final _SaveStep step;
  final bool? success;
  const _SaveCaption({required this.step, required this.success});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String? sub;
    switch (step) {
      case _SaveStep.sink:
      case _SaveStep.rise:
      case _SaveStep.stamp:
        title = '符 · 부적을 거두는 중';
        sub = null;
        break;
      case _SaveStep.flash:
      case _SaveStep.enter:
        title = '藏 · 인을 찍어 봉하는 중';
        sub = null;
        break;
      case _SaveStep.done:
        if (success == false) {
          title = '부적을 담지 못했습니다';
          sub = '사진 권한을 열어 주시면 다시 담겠습니다.';
        } else {
          title = '간직하였습니다';
          sub = '사진첩에 저장되었습니다 · 화면을 누르면 닫힙니다';
        }
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(title),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: T(1).display(22, w: FontWeight.w900, c: success == false ? const Color(0xFFFF9A86) : C.fg)),
          if (sub != null) ...[
            const SizedBox(height: 8),
            Text(sub, textAlign: TextAlign.center, style: T(1).body(13, c: C.muted)),
          ],
        ],
      ),
    );
  }
}
