import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../pass/application/pass_provider.dart';

/// [Sowoon.kr 리디자인 프롬프트] 다크모드 토글 UI 완전 제거.
/// 앱은 항상 화이트/골드 라이트 테마로만 동작한다(ThemeProvider는 ThemeMode.light 고정).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('설정', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
          children: [
            Text('계정', style: UnifiedText.title()),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Container(
              decoration: BoxDecoration(
                color: UnifiedColors.bg,
                border: Border.all(color: UnifiedColors.border),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                onTap: () => _confirmWithdraw(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.spaceLg,
                    vertical: UnifiedTokens.spaceMd,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        color: UnifiedColors.textSecondary,
                        size: UnifiedTokens.iconLg,
                      ),
                      const SizedBox(width: UnifiedTokens.spaceMd),
                      Text('회원탈퇴', style: UnifiedText.bodyStrong()),
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

    // [6-6 QA Low#5 최소 수정] 로그아웃 흐름(my_screen.dart)과 동일하게,
    // 인증 토큰이 아직 살아있는 동안(AuthProvider.withdraw()가 토큰을 지우기 전)
    // PassProvider.resetOnLogout()을 먼저 호출해 서버측 프리패스를 만료시키고
    // 화면 상태를 초기화한다. 순서를 바꾸면 userId를 얻을 수 없어 로그아웃과
    // 동일하게 서버측 만료가 누락되는 문제가 재발한다.
    await context.read<PassProvider>().resetOnLogout();
    if (!context.mounted) return;

    final ok = await context.read<AuthProvider>().withdraw();
    if (!context.mounted) return;

    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      AppToast.show(context, '탈퇴 처리에 실패했습니다.', isError: true);
    }
  }
}
