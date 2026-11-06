import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/shrine_v3_provider.dart';
import '../../domain/shrine_order.dart';
import '../theme/shrine_v3_theme.dart';
import 'shrine_asset_path.dart';

/// README/HTML 프로토타입 `IncenseRite3` — 향 올리기 6단계 연출을 그대로
/// 옮긴 전체화면 다이얼로그. 실제 "+3일" 계산은 전혀 하지 않는다 — 연출이
/// 끝나는 시점에 [ShrineV3Provider.lightIncense]를 단 한 번 호출하고,
/// 서버가 반환한 [ShrineIncenseResult.daysAfter]를 그대로 숫자 카운트업
/// 애니메이션의 종착값으로만 사용한다(§8 서버 전담 원칙 — 클라이언트는
/// before→after 사이를 "보여주기"만 하지, 그 값을 스스로 산출하지 않는다).
///
/// 반환값: 성공적으로 향을 올렸으면 [ShrineIncenseResult], 사용자가
/// 건너뛰었거나 실패했으면 null.
Future<ShrineIncenseResult?> showIncenseRiteDialog(
  BuildContext context, {
  required ShrineV3Provider provider,
  required ShrineOrder order,
}) {
  return showDialog<ShrineIncenseResult?>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (_) => _IncenseRiteDialog(provider: provider, order: order),
  );
}

class _IncenseRiteDialog extends StatefulWidget {
  const _IncenseRiteDialog({required this.provider, required this.order});
  final ShrineV3Provider provider;
  final ShrineOrder order;

  @override
  State<_IncenseRiteDialog> createState() => _IncenseRiteDialogState();
}

class _IncenseRiteDialogState extends State<_IncenseRiteDialog> {
  int _ph = 0;
  int _num = 0;
  final List<Timer> _timers = [];
  Timer? _countTimer;
  ShrineIncenseResult? _result;
  bool _requestSent = false;
  bool _closed = false;

  static const List<List<int>> _steps = [
    [1, 600],
    [2, 1400],
    [3, 2000],
    [4, 2800],
    [5, 3400],
    [6, 4600],
  ];

  @override
  void initState() {
    super.initState();
    _num = widget.order.daysRemaining;
    for (final step in _steps) {
      _timers.add(
        Timer(Duration(milliseconds: step[1]), () => _onPhase(step[0])),
      );
    }
    _timers.add(Timer(const Duration(milliseconds: 7200), _close));
  }

  void _onPhase(int p) {
    if (!mounted) return;
    setState(() => _ph = p);
    if (p == 1) {
      HapticFeedback.lightImpact();
    }
    if (p == 5) {
      _requestIncense();
    }
  }

  Future<void> _requestIncense() async {
    if (_requestSent) return;
    _requestSent = true;
    final before = widget.order.daysRemaining;
    final result = await widget.provider.lightIncense(widget.order.orderId);
    if (!mounted) return;
    _result = result;
    final after = result?.daysAfter ?? before;
    int n = before;
    _countTimer = Timer.periodic(const Duration(milliseconds: 180), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      n++;
      setState(() => _num = n > after ? after : n);
      if (n >= after) t.cancel();
    });
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _countTimer?.cancel();
    if (mounted) Navigator.of(context).pop(_result);
  }

  void _skip() {
    for (final t in _timers) {
      t.cancel();
    }
    _countTimer?.cancel();
    if (!_requestSent) {
      _requestIncense().then((_) => _close());
    } else {
      _close();
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _countTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final life = kShrineLifeDays;
    final revived = _ph >= 4; // 프로토타입 .p4~.p6: 부적 채도/광택 회복 + 글로우 펄스 시작
    return GestureDetector(
      onTap: () {
        if (_ph >= 6) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ir-dim: 중앙이 밝고 가장자리가 짙은 radial 어둠(프로토타입 .ir-dim 근사)
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.25),
                  radius: 0.9,
                  colors: [Color(0xE6240E0A), Color(0xFA040202)],
                ),
              ),
            ),
            // ir-glow: phase>=4부터 금빛 펄스 글로우 (mix-blend screen 근사)
            Center(
              child: AnimatedOpacity(
                opacity: revived ? 1 : 0,
                duration: const Duration(milliseconds: 1000),
                child: _PulsingGlow(active: revived),
              ),
            ),
            Center(
              child: AnimatedOpacity(
                opacity: _ph >= 1 ? 1 : 0.3,
                duration: const Duration(milliseconds: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ir-talis: 부적이 위에 걸려 연기를 맞으며 되살아나는 연출
                    _HangingTalisman(order: widget.order, revived: revived),
                    const SizedBox(height: 18),
                    _Burner(phase: _ph),
                    const SizedBox(height: 28),
                    Column(
                      children: [
                        const Text(
                          '기운 +3일',
                          style: TextStyle(
                            color: ShrineV3Colors.gold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_num',
                              style: ShrineV3TextStyles.title.copyWith(
                                fontSize: 40,
                                color: ShrineV3Colors.paper,
                              ),
                            ),
                            Text(
                              '일 남음',
                              style: ShrineV3TextStyles.ui.copyWith(
                                fontSize: 13,
                                color: ShrineV3Colors.paper,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (_num / life).clamp(0, 1),
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(
                                ShrineV3Colors.gold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: _ph < 3
                    ? Text(
                        '香 · ${widget.order.talisman.name}에 향을 올리는 중',
                        style: ShrineV3TextStyles.ui.copyWith(
                          color: ShrineV3Colors.paper,
                          fontSize: 12,
                        ),
                      )
                    : _ph < 6
                    ? Text(
                        '煙 · 연기가 부적에 닿는 중',
                        style: ShrineV3TextStyles.ui.copyWith(
                          color: ShrineV3Colors.paper,
                          fontSize: 12,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '향을 올렸습니다',
                            style: ShrineV3TextStyles.body.copyWith(
                              color: ShrineV3Colors.paper,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              '“연기가 닿은 자리부터 먹빛이 다시 짙어집니다. 내일 또 뵙겠습니다.”',
                              textAlign: TextAlign.center,
                              style: ShrineV3TextStyles.ui.copyWith(
                                color: ShrineV3Colors.paper.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '— 민세레나 · 閔',
                            style: ShrineV3TextStyles.ui.copyWith(
                              color: ShrineV3Colors.gold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '화면을 누르면 닫힙니다',
                            style: ShrineV3TextStyles.ui.copyWith(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_ph < 6)
              Positioned(
                top: 48,
                right: 20,
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 향로 + 연기(간소화된 CSS 연출을 Flutter AnimatedContainer로 근사) —
/// phase>=3부터 은은한 상승 연기, phase>=1부터 불씨 점등.
class _Burner extends StatelessWidget {
  const _Burner({required this.phase});
  final int phase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 160,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (phase >= 3)
            AnimatedOpacity(
              opacity: phase >= 3 ? 0.7 : 0,
              duration: const Duration(milliseconds: 600),
              child: Container(
                width: 36,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      ShrineV3Colors.paper.withValues(alpha: 0.5),
                      ShrineV3Colors.paper.withValues(alpha: 0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          Container(
            width: 64,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF3A2A1C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ShrineV3Colors.goldDeep, width: 2),
            ),
            alignment: Alignment.center,
            child: const Text(
              '香',
              style: TextStyle(
                color: ShrineV3Colors.gold,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          Positioned(
            bottom: 44,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 4,
              height: 54,
              decoration: BoxDecoration(
                color: phase >= 1
                    ? ShrineV3Colors.goldDeep
                    : ShrineV3Colors.ink3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (phase >= 1)
            Positioned(
              bottom: 96,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF8A3D),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF8A3D),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ir-talis: 부적이 실에 매달려 내려오고(hang-in), 연기가 닿기 시작하는
/// phase 4부터 탈색(saturate(.5) brightness(.7)) 상태에서 본래 채도/광택
/// (saturate(1.15) brightness(1.08) + 금빛 drop-shadow)으로 되살아나는
/// 프로토타입 연출을 ColorFiltered + AnimatedContainer로 근사한다.
class _HangingTalisman extends StatelessWidget {
  const _HangingTalisman({required this.order, required this.revived});
  final ShrineOrder order;
  final bool revived;

  @override
  Widget build(BuildContext context) {
    final talisman = order.talisman;
    final path = (talisman.thumbPath != null && talisman.thumbPath!.isNotEmpty)
        ? shrineAssetPath(talisman.thumbPath!)
        : shrineAssetPath(talisman.imagePath);
    const w = 78.0;
    const h = 168.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, hang, child) {
        return Transform.translate(
          offset: Offset(0, -14 * (1 - hang)),
          child: Opacity(opacity: hang.clamp(0, 1), child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 매단 실
          Container(width: 2, height: 12, color: const Color(0xFF6B4A2E)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: revived
                  ? const [
                      BoxShadow(
                        color: Color(0x8CF8C900),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(
                revived ? _kVividMatrix : _kFadedMatrix,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  path,
                  width: w,
                  height: h,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: w,
                    height: h,
                    color: ShrineV3Colors.paperDark,
                    alignment: Alignment.center,
                    child: Text(
                      talisman.hanja,
                      style: ShrineV3TextStyles.title.copyWith(
                        fontSize: w * 0.4,
                        color: ShrineV3Colors.seal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// saturate(.5) brightness(.7) 근사 — ColorFilter 5x4 매트릭스.
const List<double> _kFadedMatrix = [
  0.46,
  0.35,
  0.19,
  0,
  0,
  0.16,
  0.65,
  0.19,
  0,
  0,
  0.16,
  0.35,
  0.49,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

// saturate(1.15) brightness(1.08) 근사.
const List<double> _kVividMatrix = [
  1.17,
  -0.11,
  -0.06,
  0,
  6,
  -0.05,
  1.21,
  -0.06,
  0,
  6,
  -0.05,
  -0.11,
  1.26,
  0,
  6,
  0,
  0,
  0,
  1,
  0,
];

/// ir-glow: phase>=4부터 켜지는 금빛 radial 펄스 글로우(2.4s 주기 scale
/// 1→1.12 + opacity 1→.7).
class _PulsingGlow extends StatefulWidget {
  const _PulsingGlow({required this.active});
  final bool active;

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox(width: 320, height: 320);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final scale = 1 + 0.12 * t;
        final opacity = 1 - 0.3 * t;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x52F8C900), Color(0x00F8C900)],
                  stops: [0, 0.62],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
