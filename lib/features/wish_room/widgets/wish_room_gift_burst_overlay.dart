import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/wish_wall_theme.dart';

/// [소원방 개편 · 7 — 복주머니 주고받기 연출 강화] 복주머니를 "보낼 때"와
/// "받을 때(답례 도장)" 양쪽 모두에서 재생되는 화면 전체 연출.
///
/// 사용자 지시("주고 받울때 애니메이션 효괴 확실하게")에 따라, 기존
/// [_SendSuccessView] 내부의 작은 카드 연출만으로는 부족하다고 판단해
/// [wish_room_candle_ignite_overlay.dart]와 동일한 [Overlay] 삽입 패턴으로
/// 화면 전체를 덮는 골든 플래시 + 확산 링 + 이모지 파티클(🧧/✨/🎁) 폭죽을
/// 추가했다. 촛불 점화 연출과 톤을 맞추되, "주고받는" 느낌을 살리기 위해
/// [inbound]가 true면 파티클이 중앙으로 모였다가 터지는(선물을 "받는")
/// 느낌으로, false면 중앙에서 바깥으로 즉시 퍼지는(선물을 "보내는") 느낌으로
/// 방향을 다르게 연출한다.
Future<void> playWishRoomGiftBurst(
  BuildContext context, {
  String centerEmoji = '🧧',
  bool inbound = false,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _GiftBurstOverlay(
      centerEmoji: centerEmoji,
      inbound: inbound,
      onDone: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _GiftBurstOverlay extends StatefulWidget {
  const _GiftBurstOverlay({
    required this.centerEmoji,
    required this.inbound,
    required this.onDone,
  });

  final String centerEmoji;
  final bool inbound;
  final VoidCallback onDone;

  @override
  State<_GiftBurstOverlay> createState() => _GiftBurstOverlayState();
}

class _GiftBurstOverlayState extends State<_GiftBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_GiftParticle> _particles;

  static const _emojiPool = ['✨', '🧧', '💛', '⭐'];

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _particles = List.generate(18, (i) {
      final angle = (i / 18) * 2 * pi + rand.nextDouble() * 0.35;
      return _GiftParticle(
        angle: angle,
        distance: 90 + rand.nextDouble() * 110,
        delay: rand.nextDouble() * 0.2,
        size: 14 + rand.nextDouble() * 12,
        emoji: _emojiPool[rand.nextInt(_emojiPool.length)],
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final flashOpacity = t < 0.12
              ? (t / 0.12) * 0.4
              : ((1 - ((t - 0.12) / 0.88)).clamp(0.0, 1.0)) * 0.4;

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: WishWallColors.accent.withValues(alpha: flashOpacity),
                ),
              ),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 겹쳐 퍼지는 3중 링
                    for (final ringDelay in [0.0, 0.12, 0.24])
                      _buildRing(t, ringDelay),
                    // 중심 이모지(🧧/🎁) — 등장 후 살짝 통통 튀며 사라짐
                    _buildCenterEmoji(t),
                    ..._particles.map((p) => _buildParticle(p, t)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRing(double t, double delay) {
    final localT = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    final scale = 0.2 + Curves.easeOutCubic.transform(localT) * 3.0;
    final opacity = (1 - localT).clamp(0.0, 1.0) * 0.85;
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: WishWallColors.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: WishWallColors.accent.withValues(alpha: 0.55),
                blurRadius: 26,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterEmoji(double t) {
    // 0~30%: 등장하며 확대 바운스, 30~65%: 유지, 65~100%: 서서히 사라짐
    double scale;
    if (t < 0.3) {
      final localT = t / 0.3;
      scale = Curves.elasticOut.transform(localT) * 1.0;
    } else {
      scale = 1.0;
    }
    final opacity = t < 0.65 ? 1.0 : (1 - ((t - 0.65) / 0.35)).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale.clamp(0.0, 1.3),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WishWallColors.accentSoft,
            boxShadow: [
              BoxShadow(
                color: WishWallColors.accent.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(widget.centerEmoji, style: const TextStyle(fontSize: 38)),
        ),
      ),
    );
  }

  Widget _buildParticle(_GiftParticle p, double t) {
    final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    if (localT <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOutQuart.transform(localT);
    // inbound: 파티클이 바깥에서 시작해 중앙으로 모였다가 다시 퍼짐
    final travel = widget.inbound
        ? (localT < 0.5 ? (1 - eased) : eased)
        : eased;
    final dx = cos(p.angle) * p.distance * travel;
    final dy = sin(p.angle) * p.distance * travel * 0.75 - eased * 30;
    final opacity = (1 - localT).clamp(0.0, 1.0);
    final rotation = eased * pi * (widget.inbound ? -1 : 1);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation,
          child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
        ),
      ),
    );
  }
}

class _GiftParticle {
  const _GiftParticle({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.size,
    required this.emoji,
  });

  final double angle;
  final double distance;
  final double delay;
  final double size;
  final String emoji;
}
