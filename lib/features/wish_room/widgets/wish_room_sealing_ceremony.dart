import 'dart:math';

import 'package:flutter/material.dart';

import '../../shop/domain/shop_item_visuals.dart';
import '../theme/wish_room_theme.dart';
import 'wish_room_candle.dart';
import 'wish_room_dust.dart';
import 'wish_room_seal.dart';

/// [상점 기획 결함 수정 — 소원 봉인 결합 애니메이션] 소원 작성(Compose) 화면에서
/// "촛불에 봉인하기"를 눌렀을 때, 선택한 촛불/인장/부적이 실제로 소원과
/// "결합"되는 느낌을 주는 전면 시퀀스 애니메이션.
///
/// [배경] 기존에는 서버 호출 성공 후 SnackBar 텍스트 한 줄("🕯 소원이
/// 봉인되었어요")만 뜨고 화면이 곧바로 pop되어, 아이템을 골라도 아무 체감이
/// 없다는 지적을 받았다. 이 위젯은 (1) 촛불이 켜지고 (2) 인장이 쿵 찍히고
/// (3) 부적이 감싸듯 빛나는 3단계를 순서대로 보여준 뒤 완료 문구로 마무리한다.
/// 선택하지 않은 슬롯은 건너뛰어 시간을 단축한다(항상 최소 촛불 단계는 표시).
///
/// 사용법: `await showWishSealingCeremony(context, candleItemCode: ..., ...)`
Future<void> showWishSealingCeremony(
  BuildContext context, {
  String? candleItemCode,
  String? sealItemCode,
  String? talismanItemCode,
  int grantedAmount = 0,
}) async {
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.001),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _WishSealingCeremonyScreen(
            candleItemCode: candleItemCode,
            sealItemCode: sealItemCode,
            talismanItemCode: talismanItemCode,
            grantedAmount: grantedAmount,
          ),
        );
      },
    ),
  );
}

class _WishSealingCeremonyScreen extends StatefulWidget {
  const _WishSealingCeremonyScreen({
    this.candleItemCode,
    this.sealItemCode,
    this.talismanItemCode,
    this.grantedAmount = 0,
  });

  final String? candleItemCode;
  final String? sealItemCode;
  final String? talismanItemCode;
  final int grantedAmount;

  @override
  State<_WishSealingCeremonyScreen> createState() =>
      _WishSealingCeremonyScreenState();
}

enum _Stage { candle, seal, talisman, done }

class _WishSealingCeremonyScreenState extends State<_WishSealingCeremonyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stageController;
  late final List<_Stage> _stages;
  int _stageIndex = 0;

  @override
  void initState() {
    super.initState();
    _stages = [
      _Stage.candle,
      if (widget.sealItemCode != null) _Stage.seal,
      if (widget.talismanItemCode != null) _Stage.talisman,
      _Stage.done,
    ];
    _stageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _runSequence();
  }

  Future<void> _runSequence() async {
    for (var i = 0; i < _stages.length; i++) {
      if (!mounted) return;
      setState(() => _stageIndex = i);
      _stageController.forward(from: 0);
      await Future.delayed(
        _stages[i] == _Stage.done
            ? const Duration(milliseconds: 1300)
            : const Duration(milliseconds: 900),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stages[_stageIndex];
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.72),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: KeyedSubtree(
            key: ValueKey(stage),
            child: switch (stage) {
              _Stage.candle => _CandleStage(itemCode: widget.candleItemCode),
              _Stage.seal => _SealStage(itemCode: widget.sealItemCode!),
              _Stage.talisman => _TalismanStage(
                itemCode: widget.talismanItemCode!,
              ),
              _Stage.done => _DoneStage(grantedAmount: widget.grantedAmount),
            },
          ),
        ),
      ),
    );
  }
}

class _CandleStage extends StatelessWidget {
  const _CandleStage({this.itemCode});
  final String? itemCode;

  @override
  Widget build(BuildContext context) {
    final color = itemCode != null
        ? candleColorFor(itemCode!)
        : WishRoomColors.glow;
    return _CeremonyFrame(
      caption: '촛불을 밝힙니다',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, t, _) {
          return Transform.scale(
            scale: 0.5 + 0.5 * t,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: WishRoomCandle(size: 70, color: color, lit: true),
            ),
          );
        },
      ),
    );
  }
}

class _SealStage extends StatefulWidget {
  const _SealStage({required this.itemCode});
  final String itemCode;

  @override
  State<_SealStage> createState() => _SealStageState();
}

class _SealStageState extends State<_SealStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = sealVisualFor(widget.itemCode);
    return _CeremonyFrame(
      caption: '인장을 찍어 봉인합니다',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // 위에서 쿵 하고 찍히는 느낌: 처음엔 크고 위에 떠 있다가 빠르게
          // 축소되며 자리에 안착(overshoot 살짝) + 임팩트 링.
          final dropT = Curves.easeIn.transform((t / 0.55).clamp(0.0, 1.0));
          final settleT = t > 0.55
              ? Curves.elasticOut.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0))
              : 0.0;
          final dy = -60 * (1 - dropT);
          final scale = t <= 0.55 ? (1.4 - 0.2 * dropT) : (1.2 - 0.2 * settleT);
          final impactOpacity = t > 0.5 ? (1 - ((t - 0.5) / 0.5)) : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (impactOpacity > 0)
                Container(
                  width: 90 + 60 * (1 - impactOpacity),
                  height: 90 + 60 * (1 - impactOpacity),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: WishRoomColors.glow.withValues(
                        alpha: impactOpacity * 0.6,
                      ),
                      width: 2,
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: WishRoomSeal(
                    text: visual.glyph,
                    color: visual.rare
                        ? const Color(0xFFD4AF37)
                        : WishRoomColors.accent,
                    size: 72,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TalismanStage extends StatelessWidget {
  const _TalismanStage({required this.itemCode});
  final String itemCode;

  @override
  Widget build(BuildContext context) {
    final visual = talismanVisualFor(itemCode);
    return _CeremonyFrame(
      caption: '부적이 소원을 감쌉니다',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final angle = (1 - t) * 2 * pi * 0.4;
          return Transform.rotate(
            angle: angle,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visual.color.withValues(alpha: 0.22 * t),
                  border: Border.all(
                    color: visual.color.withValues(alpha: t),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: visual.color.withValues(alpha: 0.45 * t),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Text(visual.icon, style: const TextStyle(fontSize: 44)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DoneStage extends StatelessWidget {
  const _DoneStage({this.grantedAmount = 0});
  final int grantedAmount;

  @override
  Widget build(BuildContext context) {
    return _CeremonyFrame(
      caption: null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, t, _) {
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + 0.2 * t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🕯', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 12),
                  const Text(
                    '봉인이 완료되었어요',
                    style: TextStyle(
                      fontFamily: 'NotoSerifKRWish',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: WishRoomColors.textPrimary,
                    ),
                  ),
                  if (grantedAmount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🎁 복주머니 +$grantedAmount개',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMonoWish',
                        fontSize: 12,
                        letterSpacing: 1.0,
                        color: WishRoomColors.glow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 3단계 공용 프레임: 중앙 컨텐츠 + 상승 먼지 배경 + 하단 캡션.
class _CeremonyFrame extends StatelessWidget {
  const _CeremonyFrame({required this.child, this.caption});

  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: WishRoomDust(
                  count: 12,
                  color: WishRoomColors.glow,
                  duration: Duration(milliseconds: 1800),
                ),
              ),
              child,
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 0.5,
              color: WishRoomColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
