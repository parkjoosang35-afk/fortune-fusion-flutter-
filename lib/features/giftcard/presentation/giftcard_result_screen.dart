import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/giftcard_model.dart';

/// 03단계 §7.6 카탈로그형 표준패턴 "완료화면" - GiftcardResultScreen(발급 결과)
/// 발급 성공(issued): 코드/유효기간 안내. 발급 실패(failed): 환불 안내(호출측에서 이미 환불 처리 완료).
class GiftcardResultScreen extends StatelessWidget {
  final GiftcardIssueModel issue;

  const GiftcardResultScreen({super.key, required this.issue});

  bool get _succeeded => issue.status == GiftcardIssueStatus.issued;

  String get _dateLabel {
    final d = issue.expiresAt;
    if (d == null) return '';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}까지';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _succeeded ? AppColors.goldGradient : null,
                      color: _succeeded
                          ? null
                          : Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _succeeded ? issue.product.imageEmoji : '😢',
                      style: const TextStyle(fontSize: 52),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    _succeeded ? '교환이 완료되었어요!' : '발급에 실패했어요',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    issue.product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_succeeded) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '발급 코드',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            issue.issuedCode ?? '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '유효기간 $_dateLabel',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '내 상품권함에서 언제든 다시 확인할 수 있어요',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ] else
                    const Text(
                      '사용한 행복머니는 자동으로 환불되었습니다',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: 200,
                    child: AppButton(
                      label: '확인',
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((r) => r.settings.name == '/reward/giftcard'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
