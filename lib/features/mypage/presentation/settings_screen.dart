import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../pass/application/pass_provider.dart';
import '../../wish_room/domain/evening_bell_notification_service.dart';

/// [Sowoon.kr 리디자인 프롬프트] 다크모드 토글 UI 완전 제거.
/// 앱은 항상 화이트/골드 라이트 테마로만 동작한다(ThemeProvider는 ThemeMode.light 고정).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _bellEnabled; // null = 로딩 중

  @override
  void initState() {
    super.initState();
    _loadBellState();
  }

  Future<void> _loadBellState() async {
    final enabled = await EveningBellNotificationService.isEnabled();
    if (!mounted) return;
    setState(() => _bellEnabled = enabled);
  }

  Future<void> _onBellToggled(bool value) async {
    setState(() => _bellEnabled = value);
    if (value) {
      final granted = await EveningBellNotificationService.enable();
      if (!mounted) return;
      if (!granted) {
        setState(() => _bellEnabled = false);
        AppToast.show(
          context,
          '알림 권한이 허용되지 않아 종소리를 보내드릴 수 없어요.',
          isError: true,
        );
      }
    } else {
      await EveningBellNotificationService.disable();
    }
  }

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
            Text('알림', style: UnifiedText.title()),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Container(
              decoration: BoxDecoration(
                color: UnifiedColors.bg,
                border: Border.all(color: UnifiedColors.border),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.spaceLg,
                  vertical: UnifiedTokens.spaceSm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: UnifiedColors.textSecondary,
                      size: UnifiedTokens.iconLg,
                    ),
                    const SizedBox(width: UnifiedTokens.spaceMd),
                    Expanded(
                      child: Text('소원방 저녁 종소리', style: UnifiedText.bodyStrong()),
                    ),
                    Switch(
                      value: _bellEnabled ?? false,
                      onChanged: _bellEnabled == null ? null : _onBellToggled,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

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
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [6-7-4-B-4] 약관 및 정책 섹션 - admin_web 공개 페이지(이용약관/
            // 개인정보처리방침/계정삭제 안내)를 외부 브라우저로 연결한다.
            // 계정삭제는 이미 위 "회원탈퇴"로 앱 내에서 처리 가능하나, Google Play
            // 정책상 앱 설치 없이도 확인 가능한 계정삭제 안내 경로를 함께 제공한다.
            Text('약관 및 정책', style: UnifiedText.title()),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Container(
              decoration: BoxDecoration(
                color: UnifiedColors.bg,
                border: Border.all(color: UnifiedColors.border),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              ),
              child: Column(
                children: [
                  _PolicyLinkRow(
                    icon: Icons.description_outlined,
                    title: '이용약관',
                    onTap: () => _openPolicyLink(context, '/terms'),
                  ),
                  _PolicyLinkRow(
                    icon: Icons.privacy_tip_outlined,
                    title: '개인정보처리방침',
                    onTap: () => _openPolicyLink(context, '/privacy-policy'),
                  ),
                  _PolicyLinkRow(
                    icon: Icons.no_accounts_outlined,
                    title: '계정삭제 안내',
                    onTap: () => _openPolicyLink(context, '/account-deletion'),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [6-7-4-B-4] admin_web 공개 페이지(이용약관/개인정보처리방침/계정삭제 안내)를
  /// 외부 브라우저로 연다.
  Future<void> _openPolicyLink(BuildContext context, String path) async {
    final uri = Uri.tryParse('${EnvConfig.adminApiBaseUrl}$path');
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.show(context, '페이지를 열 수 없습니다.', isError: true);
    }
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

/// [6-7-4-B-4] 약관/정책 섹션 전용 메뉴 행. 기존 "회원탈퇴" 행과 동일한
/// 시각 스타일(Icon+Text+chevron)을 유지하되, 외부 브라우저로 연결됨을 알리기
/// 위해 화살표 아이콘을 open_in_new로 표시한다.
class _PolicyLinkRow extends StatelessWidget {
  const _PolicyLinkRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedTokens.spaceLg,
          vertical: UnifiedTokens.spaceMd,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: UnifiedColors.border, width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: UnifiedColors.textSecondary,
              size: UnifiedTokens.iconLg,
            ),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
            Icon(
              Icons.open_in_new_rounded,
              color: UnifiedColors.textCaption,
              size: UnifiedTokens.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}
