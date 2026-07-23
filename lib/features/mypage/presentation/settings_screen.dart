import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';

/// 07단계 §10 다크모드 설계 - 마이페이지 설정 화면(테마 전환)
/// ThemeMode.system(기본값) / light / dark 3단 선택, 선택값은 shared_preferences에 저장되어 유지됨.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('화면 테마', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                children: [
                  _ThemeOption(
                    icon: Icons.brightness_auto_rounded,
                    label: '시스템 설정과 동일하게(기본)',
                    selected: themeProvider.mode == ThemeMode.system,
                    onTap: () => themeProvider.setMode(ThemeMode.system),
                  ),
                  const Divider(height: 1),
                  _ThemeOption(
                    icon: Icons.light_mode_rounded,
                    label: '라이트 모드',
                    selected: themeProvider.mode == ThemeMode.light,
                    onTap: () => themeProvider.setMode(ThemeMode.light),
                  ),
                  const Divider(height: 1),
                  _ThemeOption(
                    icon: Icons.dark_mode_rounded,
                    label: '다크 모드',
                    selected: themeProvider.mode == ThemeMode.dark,
                    onTap: () => themeProvider.setMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
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

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).iconTheme.color,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
