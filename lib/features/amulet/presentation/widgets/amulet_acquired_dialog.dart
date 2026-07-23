import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/amulet_item_model.dart';

/// 03단계 §10.2 "부적 획득" 애니메이션 - 봉투펼침+골드광택스윕(1~1.5초) 공용 컴포넌트.
/// 설계원칙(03§9.2): 신규 원자 단위 증설 금지, 기존 조합으로 구성 → 이 다이얼로그를
/// 구매(AmuletShopScreen)/AI생성(AmuletGenerateScreen)/향후 선물수령 화면에서
/// 공통 재사용하여 "획득 순간" 경험을 통일한다.
class AmuletAcquiredDialog extends StatefulWidget {
  final AmuletItemModel item;
  final String title;

  const AmuletAcquiredDialog({
    super.key,
    required this.item,
    this.title = '당신을 지켜줄 부적이 도착했어요',
  });

  /// 획득 애니메이션 다이얼로그 표시 - Future는 사용자가 "확인"을 누를 때 완료된다.
  static Future<void> show(
    BuildContext context, {
    required AmuletItemModel item,
    String title = '당신을 지켜줄 부적이 도착했어요',
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) =>
          AmuletAcquiredDialog(item: item, title: title),
    );
  }

  @override
  State<AmuletAcquiredDialog> createState() => _AmuletAcquiredDialogState();
}

class _AmuletAcquiredDialogState extends State<AmuletAcquiredDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 03§10.2 지속시간 가이드: 1~1.5초 (여기서는 1.3초로 고정)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
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
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    final sweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.85, curve: Curves.easeInOut),
    );
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
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

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        // 골드 광택 스윕 밴드
                        Transform.translate(
                          offset: Offset(-160 + sweepValue * 280, 0),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              width: 36,
                              height: 220,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Text(
                          widget.item.iconEmoji,
                          style: const TextStyle(fontSize: 48),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Opacity(
                opacity: fadeValue,
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.secondary,
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
