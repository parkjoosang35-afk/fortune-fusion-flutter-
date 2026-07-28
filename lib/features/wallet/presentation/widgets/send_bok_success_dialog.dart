import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// [Phase22-3 보강] "복 나누기" 성공 시 재생되는 화려한 축하 애니메이션 다이얼로그.
///
/// 03단계 §10.2 "부적 획득"(amulet_acquired_dialog.dart) 패턴 — 봉투펼침+골드스윕
/// 1.3초 다이얼로그 — 을 그대로 계승하되, "받는 느낌"을 더 강조하기 위해
/// 스파클 파티클(방사형으로 퍼지는 점)과 환급액 카운트업 숫자를 추가한 확장판이다.
/// 신규 원자단위(패키지/서비스) 추가 없이 순수 AnimationController 조합으로 구현.
class SendBokSuccessDialog extends StatefulWidget {
  final String recipientNickname;
  final int sentAmount;
  final int refundAmount;

  const SendBokSuccessDialog({
    super.key,
    required this.recipientNickname,
    required this.sentAmount,
    required this.refundAmount,
  });

  static Future<void> show(
    BuildContext context, {
    required String recipientNickname,
    required int sentAmount,
    required int refundAmount,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => SendBokSuccessDialog(
        recipientNickname: recipientNickname,
        sentAmount: sentAmount,
        refundAmount: refundAmount,
      ),
    );
  }

  @override
  State<SendBokSuccessDialog> createState() => _SendBokSuccessDialogState();
}

class _SendBokSuccessDialogState extends State<SendBokSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_SparkleSpec> _sparkles;

  @override
  void initState() {
    super.initState();
    // 부적 획득 다이얼로그와 동일한 1.3초 기준(03§10.2), 파티클 여운을 위해
    // 살짝 늘려 1.5초로 고정한다.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    final rand = Random(42);
    _sparkles = List.generate(14, (i) {
      final angle = (i / 14) * 2 * pi + rand.nextDouble() * 0.3;
      final distance = 70.0 + rand.nextDouble() * 40;
      return _SparkleSpec(
        angle: angle,
        distance: distance,
        size: 4.0 + rand.nextDouble() * 5,
        delay: rand.nextDouble() * 0.25,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
    );
    final sweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    );
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    final sparkleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
    );
    final countUp = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scaleValue = scale.value.clamp(0.0, 1.3);
          final sweepValue = sweep.value.clamp(0.0, 1.0);
          final fadeValue = fade.value.clamp(0.0, 1.0);
          final refundShown = (widget.refundAmount * countUp.value).round();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 방사형 스파클 파티클
                    ..._sparkles.map((s) {
                      final t = ((_controller.value - s.delay) / (1 - s.delay))
                          .clamp(0.0, 1.0);
                      final eased = Curves.easeOut.transform(t);
                      final opacity =
                          (sparkleFade.value * (1 - eased)).clamp(0.0, 1.0);
                      final dx = cos(s.angle) * s.distance * eased;
                      final dy = sin(s.angle) * s.distance * eased;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: s.size,
                            height: s.size,
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryLight,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // 골드 원형 배경 + 복주머니 아이콘
                    Transform.scale(
                      scale: scaleValue,
                      child: ClipOval(
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.goldGradient,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(-160 + sweepValue * 280, 0),
                                child: Transform.rotate(
                                  angle: -0.5,
                                  child: Container(
                                    width: 36,
                                    height: 220,
                                    color: Colors.white.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                              ),
                              const Text(
                                '🧧',
                                style: TextStyle(fontSize: 48),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Opacity(
                opacity: fadeValue,
                child: Column(
                  children: [
                    Text(
                      '${widget.recipientNickname} 님에게\n복을 나눴어요',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '-${widget.sentAmount}복',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$refundShown복 환급 🍀',
                      style: const TextStyle(
                        color: AppColors.secondaryLight,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: '확인',
                      fullWidth: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SparkleSpec {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  const _SparkleSpec({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}
