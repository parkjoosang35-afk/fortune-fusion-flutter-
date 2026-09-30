import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../pass/application/pass_provider.dart';
import '../../ads_test/domain/admob_ad_ids.dart';
import '../../ads_test/presentation/admob_test_rewarded_ad.dart';
import '../../notification/data/notification_preference_repository.dart';

/// [Sowoon.kr 리디자인 프롬프트] 다크모드 토글 UI 완전 제거.
/// 앱은 항상 화이트/골드 라이트 테마로만 동작한다(ThemeProvider는 ThemeMode.light 고정).
///
/// [2026-11 설정 화면 정리] "소원방 저녁 종소리" 알림 토글 섹션을 완전히
/// 제거했다(사용자 요청: "설정에소원방 저녁종소리 삭제 종소리 삭제하라는
/// 예기임"). EveningBellNotificationService 자체는 다른 곳(온보딩 다이얼로그
/// 등)에서도 참조될 수 있어 삭제하지 않고, 이 화면에서의 노출/토글 UI만
/// 제거한다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // [알림 실제 발송 연동] 카테고리별 on/off 토글. admin_web
  // `notification_preferences` 테이블의 04A N-3 확정 화이트리스트
  // (marketing/fortune_update/matching/community)를 그대로 노출한다.
  final _notificationPrefRepo = NotificationPreferenceRepository();
  List<NotificationPreferenceItem> _notificationPrefs = [];
  bool _notificationPrefsLoading = true;

  // [DEV-2026-001 작업2-4-3 버전 가시화] 앱(클라이언트) 버전과 서버
  // (/app/version.txt, flutter_web 배포 시 커밋해시+배포시각을 기록)를
  // 나란히 노출해 "서버-앱 버전 불일치"를 사용자/운영자가 이 화면 하나로
  // 즉시 판별할 수 있게 한다. 서버 조회 실패는 네트워크 문제일 뿐 앱 자체
  // 버전 표시와는 무관하므로 별도 상태로 분리해 앱 버전 표시를 막지 않는다.
  String? _appVersionLabel; // 예: "1.0.0 (1)"
  String? _serverVersionText; // /app/version.txt 원문(commit=...\ndeployed_at=...)
  bool _serverVersionLoading = true;
  String? _serverVersionError;

  static const Map<String, String> _categoryLabels = {
    'community': '소원방 응원 · 댓글 · 복주머니',
    'fortune_update': '운세 업데이트',
    'matching': '매칭 알림',
    'marketing': '이벤트 · 마케팅',
  };

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
    _loadAppVersion();
    _loadServerVersion();
  }

  /// [DEV-2026-001 작업2-4-3] package_info_plus로 현재 실행 중인 앱의
  /// versionName(pubspec.yaml version 필드 앞부분)과 versionCode(+ 뒤 숫자,
  /// Android에서는 build.gradle.kts의 flutter.versionCode로 그대로 반영됨)를
  /// 읽어온다.
  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = '${info.version} (${info.buildNumber})';
      });
    } catch (e) {
      debugPrint('[SettingsScreen] [_loadAppVersion] 실패 -> $e');
      if (!mounted) return;
      setState(() {
        _appVersionLabel = '확인 불가';
      });
    }
  }

  /// [DEV-2026-001 작업2-4-3] 서버 배포 스크립트(deploy_flutter_web_to_prod.sh)가
  /// 배포 시점마다 갱신하는 /app/version.txt(commit=.../deployed_at=...)를
  /// 그대로 가져와 화면에 노출한다. 인증이 필요 없는 정적 파일이라
  /// AuthTokenStore 헤더는 붙이지 않는다.
  Future<void> _loadServerVersion() async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/app/version.txt');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        setState(() {
          _serverVersionText = response.body.trim();
          _serverVersionLoading = false;
        });
      } else {
        setState(() {
          _serverVersionError = '서버 버전 정보를 불러오지 못했습니다 (${response.statusCode})';
          _serverVersionLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SettingsScreen] [_loadServerVersion] 실패 -> $e');
      if (!mounted) return;
      setState(() {
        _serverVersionError = '서버 버전 정보를 불러오지 못했습니다';
        _serverVersionLoading = false;
      });
    }
  }

  Future<void> _loadNotificationPrefs() async {
    final result = await _notificationPrefRepo.getPreferences();
    if (!mounted) return;
    setState(() {
      if (result.success && result.data != null) {
        _notificationPrefs = result.data!;
      }
      _notificationPrefsLoading = false;
    });
  }

  Future<void> _toggleNotificationPref(
    NotificationPreferenceItem item,
    bool value,
  ) async {
    final index = _notificationPrefs.indexWhere(
      (e) => e.category == item.category,
    );
    if (index < 0) return;
    setState(() {
      _notificationPrefs[index] = NotificationPreferenceItem(
        category: item.category,
        isEnabled: value,
      );
    });

    final result = await _notificationPrefRepo.updatePreference(
      category: item.category,
      isEnabled: value,
    );
    if (!mounted) return;
    if (!result.success) {
      // 실패 시 로컬 상태를 원복하고 사용자에게 알린다.
      setState(() {
        _notificationPrefs[index] = item;
      });
      AppToast.show(context, result.errorMessage ?? '설정 저장에 실패했습니다.', isError: true);
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

            // [알림 실제 발송 연동] 카테고리별 알림 수신 on/off 토글 섹션.
            // 서버 NotificationPreference(userId, category)와 1:1 연동되며,
            // 여기서 끄면 해당 category의 알림(예: 소원방 응원/댓글/복주머니)이
            // 서버 notification-engine.ts에서 실제로 생성되지 않는다.
            const SizedBox(height: UnifiedTokens.spaceXxl),
            Text('알림 설정', style: UnifiedText.title()),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Container(
              decoration: BoxDecoration(
                color: UnifiedColors.bg,
                border: Border.all(color: UnifiedColors.border),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              ),
              child: _notificationPrefsLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: UnifiedTokens.spaceLg,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (
                          int i = 0;
                          i < _notificationPrefs.length;
                          i++
                        ) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: UnifiedColors.border,
                            ),
                          _NotificationPrefRow(
                            title:
                                _categoryLabels[_notificationPrefs[i]
                                    .category] ??
                                _notificationPrefs[i].category,
                            value: _notificationPrefs[i].isEnabled,
                            onChanged: (v) => _toggleNotificationPref(
                              _notificationPrefs[i],
                              v,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),

            // [애드몹 테스트 연동] 구글 공식 테스트 Ad Unit ID로 보상형 광고를
            // 로드/재생해보는 QA 전용 진입점. 여기서 지급되는 보상은 실제
            // 복주머니 잔액에 반영되지 않는다(순수 SDK 동작 확인용).
            // Web에서는 애드몹 SDK 자체가 동작하지 않아 섹션을 숨긴다.
            if (!kIsWeb && AdmobAdIds.isSupportedPlatform) ...[
              const SizedBox(height: UnifiedTokens.spaceXxl),
              Text('애드몹 테스트', style: UnifiedText.title()),
              const SizedBox(height: UnifiedTokens.spaceSm),
              Container(
                decoration: BoxDecoration(
                  color: UnifiedColors.bg,
                  border: Border.all(color: UnifiedColors.border),
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                  onTap: () => _showTestRewardedAd(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UnifiedTokens.spaceLg,
                      vertical: UnifiedTokens.spaceMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.smart_display_outlined,
                          color: UnifiedColors.textSecondary,
                          size: UnifiedTokens.iconLg,
                        ),
                        const SizedBox(width: UnifiedTokens.spaceMd),
                        Expanded(
                          child: Text(
                            '테스트 리워드 광고 보기',
                            style: UnifiedText.bodyStrong(),
                          ),
                        ),
                        Text(
                          '구글 공식 테스트 ID',
                          style: UnifiedText.caption(
                            color: UnifiedColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // [DEV-2026-001 작업2-4-3 버전 가시화] 앱 버전 vs 서버 버전을
            // 나란히 표시한다. 두 값이 배포 직후 달라 보이는 것은 정상
            // (Android APK는 별도 채널로 배포되므로 즉시 반영되지 않음)이며,
            // 여기서는 "지금 실행 중인 앱"과 "지금 서버에 배포된 최신본"을
            // 사용자가 직접 비교할 수 있게 하는 것이 목적이다.
            const SizedBox(height: UnifiedTokens.spaceXxl),
            Text('버전 정보', style: UnifiedText.title()),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Container(
              decoration: BoxDecoration(
                color: UnifiedColors.bg,
                border: Border.all(color: UnifiedColors.border),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: UnifiedTokens.spaceLg,
                vertical: UnifiedTokens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('앱 버전', style: UnifiedText.bodyStrong()),
                      ),
                      Text(
                        _appVersionLabel ?? '확인 중...',
                        style: UnifiedText.caption(
                          color: UnifiedColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: UnifiedTokens.spaceSm),
                  const Divider(height: 1, color: UnifiedColors.border),
                  const SizedBox(height: UnifiedTokens.spaceSm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('서버 버전', style: UnifiedText.bodyStrong()),
                      const SizedBox(width: UnifiedTokens.spaceMd),
                      Expanded(
                        child: _serverVersionLoading
                            ? Text(
                                '확인 중...',
                                textAlign: TextAlign.right,
                                style: UnifiedText.caption(
                                  color: UnifiedColors.textSecondary,
                                ),
                              )
                            : Text(
                                _serverVersionError ??
                                    _serverVersionText ??
                                    '-',
                                textAlign: TextAlign.right,
                                style: UnifiedText.caption(
                                  color: _serverVersionError != null
                                      ? Colors.red
                                      : UnifiedColors.textSecondary,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [애드몹 테스트 연동] "테스트 리워드 광고 보기" 버튼 탭 핸들러.
  void _showTestRewardedAd(BuildContext context) {
    AppToast.show(context, '테스트 광고를 불러오는 중...');
    AdmobTestRewardedAd.loadAndShow(
      context,
      onResult: (rewarded, message) {
        if (!context.mounted) return;
        AppToast.show(context, message, isError: !rewarded);
      },
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

/// [알림 실제 발송 연동] 알림 설정 섹션 전용 토글 행. 약관 링크 행
/// (`_PolicyLinkRow`)과 동일한 패딩/보더 스타일을 유지하되, 우측에
/// 외부링크 아이콘 대신 Switch를 배치한다.
class _NotificationPrefRow extends StatelessWidget {
  const _NotificationPrefRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceLg,
        vertical: UnifiedTokens.spaceXs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
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
