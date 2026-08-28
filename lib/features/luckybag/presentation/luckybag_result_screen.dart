import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_unified_style.dart';
import '../domain/luckybag_product_model.dart';
import '../domain/luckybag_reward_model.dart';

/// 03단계 §10.2 "복주머니 열기" 결과화면 - 결과 카드 페이드인.
/// 등급별 반짝임 강도 차등(best > rare > common > none, 03§10.2 가이드).
///
/// [복주머니 디자인 정합성 수정] 옛 다크 "신비로운 밤하늘" 그라디언트 배경
/// (AppColors.mysticGradient/goldGradient)와 화이트 텍스트를 걷어내고,
/// 허브/상점과 같은 화이트+라벤더 톤([UnifiedColors])으로 통일한다.
/// 애니메이션(스케일/페이드/스파클) 로직은 그대로 유지 — 색과 배경만 교체.
class LuckyBagResultScreen extends StatefulWidget {
  final LuckyBagOpenResult result;
  final LuckyBagProductModel product;

  const LuckyBagResultScreen({
    super.key,
    required this.result,
    required this.product,
  });

  @override
  State<LuckyBagResultScreen> createState() => _LuckyBagResultScreenState();
}

class _LuckyBagResultScreenState extends State<LuckyBagResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int get _sparkleCount {
    switch (widget.result.grade.code) {
      case 'best':
        return 16;
      case 'rare':
        return 10;
      case 'common':
        return 5;
      default:
        return 0;
    }
  }

  Color get _gradeColor {
    switch (widget.result.grade.code) {
      case 'best':
        return const Color(0xFFA9772F);
      case 'rare':
        return const Color(0xFF4DA8FF);
      case 'common':
        return const Color(0xFF5FE3B3);
      default:
        return UnifiedColors.textSecondary;
    }
  }

  String get _resultEmoji {
    switch (widget.result.rewardType) {
      case 'point':
        return '🪙';
      case 'amulet':
        return '🧿';
      case 'giftcard_fragment':
        return '🎟️';
      default:
        return '📭';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWin = widget.result.grade.code != 'none';

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXxl),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final fade = CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                ).value.clamp(0.0, 1.0);
                final scale = CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
                ).value.clamp(0.0, 1.3);
                final sparkleT = _controller.value;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_sparkleCount > 0) ..._buildSparkles(sparkleT),
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 120,
                              height: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isWin
                                    ? UnifiedColors.cardMain
                                    : UnifiedColors.chipInactiveBg,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _resultEmoji,
                                style: const TextStyle(fontSize: 52),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceXxl),
                    Opacity(
                      opacity: fade,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _gradeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                UnifiedTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              widget.result.grade.name,
                              style: UnifiedText.chipLabel(
                                color: _gradeColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: UnifiedTokens.spaceMd),
                          Text(
                            isWin ? '축하해요! 좋은 행운을 발견했어요' : '다음 기회에 만나요',
                            style: UnifiedText.titleLarge(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: UnifiedTokens.spaceSm),
                          Text(
                            widget.result.rewardLabel,
                            style: UnifiedText.title(
                              color: UnifiedColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: UnifiedTokens.spaceSm),
                          Text(
                            '남은 복주머니 ${widget.result.remainingBalance}개',
                            style: UnifiedText.caption(),
                          ),
                          const SizedBox(height: UnifiedTokens.spaceXxl),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).popUntil(
                                (r) => r.settings.name == '/home',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: UnifiedColors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    UnifiedTokens.radiusPill,
                                  ),
                                ),
                              ),
                              child: Text(
                                '확인',
                                style: UnifiedText.chipLabel(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSparkles(double t) {
    return List.generate(_sparkleCount, (i) {
      final angle = (2 * pi / _sparkleCount) * i;
      final distance = 55 + t * 45;
      final dx = cos(angle) * distance;
      final dy = sin(angle) * distance;
      final opacity = sin((t.clamp(0.0, 1.0)) * pi).clamp(0.0, 1.0);
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: opacity,
          child: Icon(
            Icons.star_rounded,
            size: 12 + (i % 3) * 4,
            color: _gradeColor,
          ),
        ),
      );
    });
  }
}
