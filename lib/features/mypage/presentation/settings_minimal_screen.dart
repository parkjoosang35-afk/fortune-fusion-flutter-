import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../auth/application/auth_provider.dart';
import '../../notification/data/notification_preference_repository.dart';
import '../../pass/application/pass_provider.dart';
import '../../saju_renewal/screens/birth_input_screen.dart';
import 'theme/mypage_minimal_theme.dart';
import 'theme/mypage_toast.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S12] "설정" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S12 설정" 스펙(그룹
/// 라벨 13px/600 ink3, 행 padding 17 0)에 따른 전면 신규 화면이다. 기존
/// `SettingsScreen`(다크 `UnifiedColors` 톤, Container+Border 그룹박스)은
/// README가 요구하는 레이아웃(구분선만 있는 플랫 리스트, 그룹 라벨 스타일)과
/// 크게 달라 같은 파일을 리스킨하는 대신 새 파일로 작성했다 — 기존 파일은
/// 프로젝트 관례에 따라 삭제하지 않고 코드베이스에 유지한다. 대신
/// `/my/settings` 라우트만 이 화면을 가리키도록 app_router.dart를
/// 교체한다(S03/S05/S09/S11과 동일한 "신규 파일 + 라우트만 교체" 패턴).
///
/// 데이터 소스(변경 없음, 기존 Provider/Repository 재사용):
/// - [AuthProvider]: currentUser(realName/birthDate/birthTime/isLunar/
///   birthTimeUnknown), withdraw()
/// - [NotificationPreferenceRepository]: getPreferences()/updatePreference()
///   — 서버 화이트리스트(marketing/fortune_update/community 3종)를 그대로
///   노출한다. README가 요구하는 4행(앱 푸시/소원 소식/야간 알림/혜택·이벤트)
///   중 "앱 푸시 알림"은 마이 메인의 전체 토글과 동일한 개념이나 서버에
///   전체 on/off 단일 필드가 없으므로, 기존 SettingsScreen과 동일하게
///   "서버가 지원하는 카테고리만 그대로 렌더링"한다 — "야간 알림" 전용
///   서버 필드가 없다는 점은 README §11 "기획 확인이 필요한 항목"에
///   명시적으로 남아 있는 사항이라 새 서버 필드를 임의로 만들지 않는다
///   ("로직은 그대로, 스킨만 교체" 원칙).
///
/// [범위 결정] README S13(출생정보 수정)/S14(실명 등록)/S15(약관 문서)/
/// S16(앱 정보)/S17(회원탈퇴) 서브 화면은 이번 S12 작업 범위가 아니다.
/// 이 화면에서는 기존 인프라를 그대로 재사용한다:
/// - "실명 등록·수정"/"출생정보 수정": 기존 BirthInputScreen(수정모드)/
///   AuthProvider.updateProfile 다이얼로그 흐름을 그대로 호출(S13/S14
///   전용 신규 화면이 아직 없으므로 임시로 기존 진입점 재사용)
/// - "약관"/"앱 정보": 외부 브라우저 또는 안내 토스트로 임시 대체
///   (S15/S16 전용 화면 완성 전까지)
class SettingsMinimalScreen extends StatefulWidget {
  const SettingsMinimalScreen({super.key});

  @override
  State<SettingsMinimalScreen> createState() => _SettingsMinimalScreenState();
}

class _SettingsMinimalScreenState extends State<SettingsMinimalScreen> {
  final _notificationPrefRepo = NotificationPreferenceRepository();
  List<NotificationPreferenceItem> _notificationPrefs = [];
  bool _notificationPrefsLoading = true;

  String? _appVersionLabel;

  static const Map<String, String> _categoryLabels = {
    'community': '소원 소식',
    'fortune_update': '운세 업데이트',
    'marketing': '혜택 · 이벤트 소식',
  };

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersionLabel = info.version);
    } catch (e) {
      debugPrint('[SettingsMinimalScreen] [_loadAppVersion] 실패 -> $e');
      if (!mounted) return;
      setState(() => _appVersionLabel = '확인 불가');
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
      // 실패 시 로컬 상태를 원복한다(README §7 "낙관적 업데이트, 실패하면
      // 되돌림" 스펙 그대로).
      setState(() => _notificationPrefs[index] = item);
      showMyPageToast(context, result.errorMessage ?? '설정 저장에 실패했습니다.');
    }
  }

  /// README S13 스펙의 "1980.08.09 양력 · 巳時" 포맷 서브텍스트.
  /// 12지지 시간대 경계(子時 23–01 … 亥時 21–23)는 명리학의 고정된 관례값이라
  /// README §11 "기획 확인 필요" 목록에 없는 상수로 간주해 하드코딩한다.
  String _birthSubtitle(dynamic user) {
    final birthDate = user?.birthDate as String?;
    if (birthDate == null || birthDate.isEmpty) return '아직 등록하지 않았어요';
    final calendar = (user.isLunar as bool? ?? false) ? '음력' : '양력';
    final dateLabel = birthDate.replaceAll('-', '.');
    final birthTimeUnknown = user.birthTimeUnknown as bool? ?? false;
    final birthTime = user.birthTime as String?;
    if (birthTimeUnknown || birthTime == null || birthTime.isEmpty) {
      return '$dateLabel $calendar';
    }
    final hour = int.tryParse(birthTime.split(':').first) ?? -1;
    final hourZhiLabel = _hourZhiLabel(hour);
    if (hourZhiLabel == null) return '$dateLabel $calendar';
    return '$dateLabel $calendar · $hourZhiLabel';
  }

  static const List<String> _hourZhiNames = [
    '子時', '丑時', '寅時', '卯時', '辰時', '巳時',
    '午時', '未時', '申時', '酉時', '戌時', '亥時',
  ];

  /// 0~23시 → 12지지 시간대 라벨. 子時는 23:00~00:59로 경계가 걸쳐 있다.
  String? _hourZhiLabel(int hour) {
    if (hour < 0 || hour > 23) return null;
    final index = ((hour + 1) ~/ 2) % 12;
    return _hourZhiNames[index];
  }

  Future<void> _editRealName(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController(
      text: auth.currentUser?.realName ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MyPageColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MyPageRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('실명 등록', style: MyPageTextStyles.cardTitle),
              const SizedBox(height: 10),
              const Text(
                '신당(THE SHRINE)에서 발급하는 부적에 새길 이름입니다.\n'
                '닉네임과는 별도로 실명을 입력해 주세요.',
                style: MyPageTextStyles.caption,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: MyPageTextStyles.row,
                decoration: InputDecoration(
                  hintText: '예) 홍길동',
                  filled: true,
                  fillColor: MyPageColors.paper2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0x122A1F14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: MyPageColors.ink2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(controller.text.trim()),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: MyPageColors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    if (result.isEmpty) {
      showMyPageToast(context, '실명을 입력해 주세요.');
      return;
    }
    final ok = await auth.updateProfile(realName: result);
    if (!context.mounted) return;
    showMyPageToast(
      context,
      ok ? '실명이 저장되었어요' : (auth.lastProfileUpdateError ?? '실명 저장에 실패했습니다.'),
    );
  }

  Future<void> _openPolicyLink(BuildContext context, String path) async {
    final uri = Uri.tryParse('${EnvConfig.adminApiBaseUrl}$path');
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showMyPageToast(context, '페이지를 열 수 없습니다.');
    }
  }

  /// README "다이얼로그 공통 (D1–D3)" 시각 스펙(도장 44×44 rotate(-6°),
  /// 제목 19px/800, 버튼 2열)을 따르는 확인 다이얼로그. D3(회원탈퇴
  /// 확인)에서 사용한다 — 글리프 別, 빨강 강조.
  Future<bool> _showMyPageConfirmDialog(
    BuildContext context, {
    required String glyph,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MyPageColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MyPageRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -6 * 3.14159265 / 180,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MyPageColors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    glyph,
                    style: const TextStyle(
                      fontFamily: MyPageFonts.hanja,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  height: 1.3,
                  color: MyPageColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.5,
                  color: MyPageColors.ink2,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0x122A1F14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: MyPageColors.ink2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: MyPageColors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmWithdraw(BuildContext context) async {
    final confirmed = await _showMyPageConfirmDialog(
      context,
      glyph: '別',
      title: '정말 떠나시겠어요',
      message: '담아둔 소원과 복주머니가 모두 사라져요',
      confirmLabel: '탈퇴',
    );
    if (!confirmed || !context.mounted) return;

    // [6-6 QA Low#5 최소 수정과 동일한 순서] 인증 토큰이 아직 살아있는
    // 동안(AuthProvider.withdraw()가 토큰을 지우기 전) PassProvider.
    // resetOnLogout()을 먼저 호출해 서버측 프리패스를 만료시킨다.
    await context.read<PassProvider>().resetOnLogout();
    if (!context.mounted) return;

    final ok = await context.read<AuthProvider>().withdraw();
    if (!context.mounted) return;

    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      showMyPageToast(context, '탈퇴 처리에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // README "서브화면 공통 셸" 상단바: padding 52 12 10,
            // grid 44 1fr 44, 가운데 타이틀 17px/800.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 40,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: MyPageColors.ink,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '설정',
                        textAlign: TextAlign.center,
                        style: MyPageTextStyles.header,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                MyPageSpacing.subX,
                0,
                MyPageSpacing.subX,
                60,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (isLoggedIn) ...[
                    const _GroupLabel('계정'),
                    _SettingsRow(
                      title: '실명 등록 · 수정',
                      subtitle: (user?.realName == null ||
                              user!.realName!.trim().isEmpty)
                          ? '미등록'
                          : user.realName,
                      onTap: () => _editRealName(context),
                    ),
                    _SettingsRow(
                      title: '출생정보 수정',
                      subtitle: _birthSubtitle(user),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const BirthInputScreen(isEditMode: true),
                        ),
                      ),
                    ),
                  ],
                  const _GroupLabel('알림'),
                  if (_notificationPrefsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MyPageColors.red,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final pref in _notificationPrefs)
                      _SettingsToggleRow(
                        title: _categoryLabels[pref.category] ?? pref.category,
                        value: pref.isEnabled,
                        onChanged: (v) => _toggleNotificationPref(pref, v),
                      ),
                  const _GroupLabel('약관 및 정책'),
                  _SettingsRow(
                    title: '이용약관',
                    onTap: () => _openPolicyLink(context, '/terms'),
                  ),
                  _SettingsRow(
                    title: '개인정보처리방침',
                    onTap: () => _openPolicyLink(context, '/privacy-policy'),
                  ),
                  _SettingsRow(
                    title: '계정삭제 안내',
                    onTap: () => _openPolicyLink(context, '/account-deletion'),
                  ),
                  const _GroupLabel(''),
                  _SettingsRow(
                    title: '앱 정보',
                    valueLabel: _appVersionLabel ?? '확인 중...',
                    onTap: () => showMyPageToast(
                      context,
                      '버전 ${_appVersionLabel ?? ''}',
                    ),
                  ),
                  if (isLoggedIn)
                    _SettingsRow(
                      title: '회원탈퇴',
                      isDanger: true,
                      showDivider: false,
                      onTap: () => _confirmWithdraw(context),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// README §S12 그룹 라벨: 13px/600 ink3, margin 30 0 4.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(height: 26);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 30, 0, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: MyPageFonts.ui,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: MyPageColors.ink3,
        ),
      ),
    );
  }
}

/// README §S12 행: padding 17 0, 15px/600, 서브 12px/600, 우측 › 또는 값.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.valueLabel,
    this.isDanger = false,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final String? valueLabel;
  final VoidCallback onTap;
  final bool isDanger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDanger ? MyPageColors.red2 : MyPageColors.ink;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: MyPageColors.hair, width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: MyPageFonts.ui,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: MyPageColors.ink3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (valueLabel != null)
              Text(
                valueLabel!,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: MyPageColors.ink3,
                ),
              )
            else if (!isDanger)
              const Icon(
                Icons.chevron_right_rounded,
                color: MyPageColors.ink3,
              ),
          ],
        ),
      ),
    );
  }
}

/// README §S12 알림 토글 행: 행 padding 17 0, 제목 15px/600 + 우측 Switch.
class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MyPageColors.hair, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: MyPageFonts.ui,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: MyPageColors.ink,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: MyPageColors.red,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0x1F2A1F14),
          ),
        ],
      ),
    );
  }
}
