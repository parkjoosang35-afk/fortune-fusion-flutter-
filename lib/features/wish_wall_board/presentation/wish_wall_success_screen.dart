import 'package:flutter/material.dart';

import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/bottle_widget.dart';
import 'wish_wall_my_screen.dart';

/// 04. 소원 봉인완료 화면.
///
/// [handoff.zip] design/wb3-compose.jsx `BottleSuccess`를 Flutter로 이식.
/// 0.9초 드롭인 애니메이션 + halo pulse, 복주머니 +5 적립 배너,
/// "내 소원병 보기"/"소원벽으로" 두 버튼으로 구성된다.
class WishWallSuccessScreen extends StatefulWidget {
  const WishWallSuccessScreen({super.key, required this.wish});
  final WishPost wish;

  @override
  State<WishWallSuccessScreen> createState() => _WishWallSuccessScreenState();
}

class _WishWallSuccessScreenState extends State<WishWallSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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

  void _openMy() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WishWallMyScreen()),
      (route) => route.isFirst,
    );
  }

  void _backToWall() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;
    return Scaffold(
      backgroundColor: WishWallColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final drop = Curves.easeOutBack.transform(_controller.value);
                  final fade = (_controller.value * 2).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: fade,
                    child: Transform.translate(
                      offset: Offset(0, -40 * (1 - drop)),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          _PulseHalo(controller: _controller, color: wish.categoryId.lightColor),
                          BottleWidget(
                            category: wish.categoryId,
                            size: 150,
                            glow: 0.9,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                '소원이 병 속에 봉인되었어요',
                textAlign: TextAlign.center,
                style: WishWallText.title1().copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                '조용히 흘러가 누군가의 마음에 닿을 거예요',
                textAlign: TextAlign.center,
                style: WishWallText.body(color: WishWallColors.muted),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: WishWallColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: WishWallColors.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      '복주머니 +5 적립되었어요',
                      style: WishWallText.label(color: WishWallColors.accent2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _openMy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WishWallColors.ink,
                    foregroundColor: WishWallColors.bg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '내 소원병 보기',
                    style: WishWallText.label(color: WishWallColors.bg).copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _backToWall,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WishWallColors.ink,
                    side: const BorderSide(color: WishWallColors.line2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '소원방으로',
                    style: WishWallText.label().copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseHalo extends StatelessWidget {
  const _PulseHalo({required this.controller, required this.color});
  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return Container(
          width: 200 + 20 * t,
          height: 200 + 20 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.28 * t),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        );
      },
    );
  }
}
