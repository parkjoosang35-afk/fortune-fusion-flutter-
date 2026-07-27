import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';

/// [Sowoon.kr 리디자인 프롬프트] 다크모드 토글 UI 완전 제거.
/// 앱은 항상 화이트/골드 라이트 테마로만 동작한다(ThemeProvider는 ThemeMode.light 고정).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('계정', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: () => _confirmWithdraw(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        color: AppColors.error,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Text('회원탈퇴', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phase2-3: 02번 §1.1 회원탈퇴(소프트삭제) - 확인 다이얼로그 → 탈퇴 처리 → 로그인화면 이동
  Future<void> _confirmWithdraw(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '회원탈퇴',
      message: '탈퇴 시 계정 정보와 이용 내역이 모두 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠어요?',
      confirmLabel: '탈퇴하기',
      isDanger: true,
    );
    if (!confirmed || !context.mounted) return;

    final ok = await context.read<AuthProvider>().withdraw();
    if (!context.mounted) return;

    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      AppToast.show(context, '탈퇴 처리에 실패했습니다.', isError: true);
    }
  }
}
