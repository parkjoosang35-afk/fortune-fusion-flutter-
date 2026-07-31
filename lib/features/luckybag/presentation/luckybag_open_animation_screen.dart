import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/luckybag_provider.dart';
import '../domain/luckybag_product_model.dart';

/// 03단계 §10.2 "행복머니 열기" 애니메이션 - 흔들림→확대→반짝임 파티클(1.5~2초).
/// 06§4.9 `POST /v1/luckybags/:id/open` 대응 화면. 개봉(구매+추첨)이 완료되면
/// LuckyBagResultScreen으로 결과를 전달하며 pushReplacement한다.
class LuckyBagOpenAnimationScreen extends StatefulWidget {
  final LuckyBagProductModel product;

  const LuckyBagOpenAnimationScreen({super.key, required this.product});

  @override
  State<LuckyBagOpenAnimationScreen> createState() =>
      _LuckyBagOpenAnimationScreenState();
}

class _LuckyBagOpenAnimationScreenState
    extends State<LuckyBagOpenAnimationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // 03§10.2 지속시간 가이드: 1.5~2초 (여기서는 1.8초로 고정)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;

    final wallet = context.read<WalletProvider>();
    final luckybag = context.read<LuckyBagProvider>();
    final product = widget.product;

    final animationFuture = _controller.forward();

    // [방법 A] 서버(admin_web `POST /api/public/luckybag/open`)가 행복머니 차감 +
    // 확률 추첨 + 보상 지급 + 로그 기록을 단일 트랜잭션으로 원자적으로 처리한다.
    // 클라이언트는 더 이상 wallet.spend()/wallet.earn()을 직접 호출하지 않는다
    // (그렇게 하면 서버가 이미 차감한 금액이 중복 차감/환불되는 버그가 발생한다).
    final result = await luckybag.open(product.id, wallet.balance);
    await animationFuture; // 최소 애니메이션 지속시간 보장
    if (!mounted) return;

    if (result == null) {
      AppToast.show(
        context,
        luckybag.actionError ?? '개봉에 실패했습니다.',
        isError: true,
      );
      Navigator.of(context).pop();
      return;
    }

    // 서버가 확정한 최신 잔액을 반영(재조회하여 이력까지 동기화).
    await wallet.load();
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      '/reward/luckybag/result',
      arguments: {'result': result, 'product': product},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                // 0~0.4: 흔들림, 0.4~0.7: 확대, 0.7~1.0: 반짝임
                final shakeT = (t / 0.4).clamp(0.0, 1.0);
                final scaleT = ((t - 0.4) / 0.3).clamp(0.0, 1.0);
                final sparkleT = ((t - 0.7) / 0.3).clamp(0.0, 1.0);

                final shakeOffset = shakeT < 1.0
                    ? sin(shakeT * pi * 8) * (1 - shakeT) * 10
                    : 0.0;
                final scale = 1.0 + Curves.easeOutBack.transform(scaleT) * 0.4;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (sparkleT > 0) ..._buildSparkles(sparkleT),
                          Transform.translate(
                            offset: Offset(shakeOffset, 0),
                            child: Transform.scale(
                              scale: scale,
                              child: Text(
                                widget.product.iconEmoji,
                                style: const TextStyle(fontSize: 88),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '${widget.product.name}을 열고 있어요...',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '두근두근, 어떤 행운이 담겨있을까요?',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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

  List<Widget> _buildSparkles(double sparkleT) {
    const count = 8;
    return List.generate(count, (i) {
      final angle = (2 * pi / count) * i;
      final distance = 60 + sparkleT * 40;
      final dx = cos(angle) * distance;
      final dy = sin(angle) * distance;
      final opacity = (sin(sparkleT * pi)).clamp(0.0, 1.0);
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: opacity,
          child: Icon(
            Icons.star_rounded,
            size: 14 + (i % 3) * 4,
            color: AppColors.secondary,
          ),
        ),
      );
    });
  }
}
