import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';

/// [소원구슬 다중배치] 메인 오브제(촛불 제단) 주변에 최대 3개의 소원을
/// 떠다니는 빛의 구슬(orb)로 동시에 시각화하는 위젯.
///
/// [기존 구현과의 관계] `WishCardList`(가로 스크롤 카드 목록)는 소원의
/// "정보"(제목/상태)를 텍스트로 보여주는 기존 UI로 그대로 유지한다. 이
/// 위젯은 그 정보 UI를 대체하지 않고, 메인 오브제 바로 위 공간에 여러
/// 소원을 "빛의 구슬"로 동시에 배치해 보여주는 순수 시각 강화 레이어다
/// (사용자 지시: "소원구슬 다중배치"). 대표 소원은 중앙 오브제 정면 위에,
/// 나머지 서브 소원들은 좌우로 살짝 낮게 떠 있는 구도로 배치해 "제단을
/// 둘러싼 소원들"이라는 서사를 표현한다.
///
/// 성능 원칙: 오브의 부유(float) 움직임은 로컬 AnimationController 하나가
/// 여러 구슬에 공유되며(오브젝트/배경과 동일 패턴), 전체를 RepaintBoundary로
/// 감싼다. 탭하면 [onOrbTap]으로 해당 [WishItem]을 그대로 전달해 기존
/// `_handleWishCardTap` 로직(대표 소원 교체 확인 다이얼로그 등)을 100%
/// 재사용할 수 있게 한다.
class WishOrbCluster extends StatefulWidget {
  final List<WishItem> wishes;
  final void Function(WishItem wish)? onOrbTap;

  const WishOrbCluster({super.key, required this.wishes, this.onOrbTap});

  @override
  State<WishOrbCluster> createState() => _WishOrbClusterState();
}

class _WishOrbClusterState extends State<WishOrbCluster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  /// 구슬 배치 좌표(정규화, 0~1 기준의 Alignment 값). 대표 소원은 중앙 위쪽,
  /// 서브 소원들은 좌우로 낮게 벌려서 제단을 감싸는 구도를 만든다.
  static const List<Alignment> _slotAlignments = [
    Alignment(0.0, -1.15),
    Alignment(-0.85, -0.35),
    Alignment(0.85, -0.35),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.wishes.isEmpty) return const SizedBox.shrink();

    final visible = widget.wishes.take(3).toList();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: List.generate(visible.length, (i) {
              final wish = visible[i];
              final align = _slotAlignments[i % _slotAlignments.length];
              // 각 구슬마다 위상을 다르게 줘서 동시에 같은 리듬으로
              // 오르내리지 않도록 한다(자연스러운 개별 부유감).
              final phase = i * 2.1;
              final t = _floatController.value * 2 * pi;
              final floatDy = sin(t + phase) * 6.0;
              final floatDx = cos(t * 0.6 + phase) * 3.0;

              return Align(
                alignment: align,
                child: Transform.translate(
                  offset: Offset(floatDx, floatDy),
                  child: _WishOrb(
                    wish: wish,
                    isPrimary: i == 0,
                    onTap: widget.onOrbTap == null
                        ? null
                        : () => widget.onOrbTap!(wish),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _WishOrb extends StatefulWidget {
  final WishItem wish;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _WishOrb({required this.wish, required this.isPrimary, this.onTap});

  @override
  State<_WishOrb> createState() => _WishOrbState();
}

class _WishOrbState extends State<_WishOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkleController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // 구슬마다 반짝임 주기를 title 해시 기반으로 약간씩 다르게 줘서
    // 여러 구슬이 기계적으로 똑같이 반짝이지 않도록 한다.
    final variance = 400 + (widget.wish.title.hashCode.abs() % 600);
    _twinkleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + variance),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.wish.growthStage;
    final tone = WishRoomColors.forGrowthStage(stage);
    final size = widget.isPrimary ? 56.0 : 44.0;

    return Semantics(
      label: '${widget.wish.title} 소원 구슬',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedBuilder(
            animation: _twinkleController,
            builder: (context, child) {
              final glow = 0.35 + 0.35 * _twinkleController.value;
              // [순수 시각 레이어 원칙] 이 구슬은 wish.title 같은 정보 텍스트를
              // 표시하지 않는다. 소원의 "정보"는 기존 WishCardList가 전담하고,
              // 여기서는 대표 소원 카테고리 이모지 + 글로우만으로 시각적 존재감을
              // 표현한다(§테스트 회귀 원인이었던 중복 타이틀 라벨을 의도적으로 제거).
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.9),
                      tone,
                      tone.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tone.withValues(alpha: glow),
                      blurRadius: widget.isPrimary ? 24 : 16,
                      spreadRadius: widget.isPrimary ? 3 : 1,
                    ),
                  ],
                  border: widget.wish.isRepresentative
                      ? Border.all(
                          color: WishRoomColors.gold.withValues(alpha: 0.8),
                          width: 1.5,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.wish.category.emoji,
                  style: TextStyle(fontSize: size * 0.38),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
