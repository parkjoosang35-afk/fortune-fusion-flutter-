import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_version/data/app_version_repository.dart';
import 'theme/mypage_minimal_theme.dart';
import 'theme/mypage_toast.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S16] "앱 정보" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S16 앱 정보" 스펙(로고
/// "神通萬通" 40px 900 빨강 + "신통방통", 버전 pill "최신 버전 1.0.0"
/// (업데이트가 있으면 "업데이트 하기"), 행: 오픈소스 라이선스 / 고객센터)에
/// 따른 전면 신규 화면이다. 기존 `SettingsMinimalScreen`에서는 "앱 정보"
/// 행이 버전 번호만 토스트로 보여주는 임시 구현이었는데, 이 화면으로
/// 교체해 README가 요구하는 전용 서브화면을 제공한다.
///
/// [로직 재사용, 스킨만 교체]
/// - 버전 표시/업데이트 체크: 새 API를 만들지 않고 기존
///   [AppVersionRepository.checkVersion] (`GET /api/public/app-version`,
///   `ForceUpdateGate`가 이미 쓰는 바로 그 API)과
///   [AppVersionPolicy.hasNewerVersion]을 그대로 재사용한다.
///   `ForceUpdateGate`와 동일하게 Web 플랫폼은 APK 배포 채널과 무관하므로
///   (항상 최신 소스로 즉시 재배포) 이 체크 대상에서 제외한다(kIsWeb이면
///   스킵하고 "최신 버전"으로만 표시).
/// - 오픈소스 라이선스: 새 라이선스 목록 UI를 만들지 않고 Flutter 표준
///   [showLicensePage]를 그대로 사용한다 — pubspec.yaml 의존성의 실제
///   라이선스 정보를 정확히 보여주는 유일한 신뢰 가능한 소스다.
/// - 고객센터: 프로토타입(`prototype/subs.js` `about()`)도 실제 연결 없이
///   `data-toast="고객센터로 연결해요"`로만 구현되어 있고, 코드베이스 전체를
///   검색해도 고객센터 채널(이메일/카카오톡 채널/웹뷰 등) 정보가 전혀
///   존재하지 않는다 — README §11 "기획 확인이 필요한 항목"에 명시되지
///   않았지만 실질적으로 동일한 성격(미확정 외부 채널)이라, 새 연결처를
///   임의로 만들지 않고 프로토타입과 동일한 안내 토스트로 남겨둔다.
class AppInfoMinimalScreen extends StatefulWidget {
  const AppInfoMinimalScreen({super.key});

  @override
  State<AppInfoMinimalScreen> createState() => _AppInfoMinimalScreenState();
}

class _AppInfoMinimalScreenState extends State<AppInfoMinimalScreen> {
  String? _versionLabel;
  AppVersionPolicy? _policy;
  int? _currentVersionCode;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = info.version;
        _currentVersionCode = int.tryParse(info.buildNumber) ?? 0;
      });
    } catch (e) {
      debugPrint('[AppInfoMinimalScreen] [_loadVersionInfo] 실패 -> $e');
      if (!mounted) return;
      setState(() => _versionLabel = '확인 불가');
    }

    // [ForceUpdateGate와 동일 원칙] Web은 APK 배포 채널과 무관하므로 업데이트
    // 체크 대상에서 제외한다. 실패해도(fail-open) "최신 버전"으로만 표시하고
    // 서비스 흐름을 막지 않는다.
    if (kIsWeb) return;
    try {
      final result = await AppVersionRepository().checkVersion();
      if (!mounted) return;
      if (result.success && result.data != null) {
        setState(() => _policy = result.data);
      }
    } catch (e) {
      debugPrint('[AppInfoMinimalScreen] [_loadVersionInfo] 업데이트 체크 예외 -> $e');
    }
  }

  bool get _hasNewerVersion {
    final policy = _policy;
    final current = _currentVersionCode;
    if (policy == null || current == null) return false;
    return policy.hasNewerVersion(current);
  }

  Future<void> _handleVersionPillTap(BuildContext context) async {
    final policy = _policy;
    if (!_hasNewerVersion || policy == null) return;
    final uri = Uri.tryParse(policy.updateUrl);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showMyPageToast(context, '업데이트 페이지를 열 수 없습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // README "서브화면 공통 셸" 상단바.
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
                        '앱 정보',
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
                  // README ".about" — 40px/900 빨강 한자 로고 + 국문명 +
                  // 버전 pill, 가운데 정렬, padding 40 0 30.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 40, 0, 30),
                    child: Column(
                      children: [
                        const Text(
                          '神通萬通',
                          style: TextStyle(
                            fontFamily: MyPageFonts.hanja,
                            fontWeight: FontWeight.w900,
                            fontSize: 40,
                            letterSpacing: 3.2, // 40px 기준 0.08em
                            color: MyPageColors.red,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '신통방통',
                          style: TextStyle(
                            fontFamily: MyPageFonts.ui,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: MyPageColors.ink,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _VersionPill(
                          label: _hasNewerVersion
                              ? '업데이트 하기'
                              : '최신 버전 ${_versionLabel ?? '...'}',
                          tappable: _hasNewerVersion,
                          onTap: () => _handleVersionPillTap(context),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          '"마음이 머무는 곳에 복이 깃듭니다"',
                          textAlign: TextAlign.center,
                          style: MyPageTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                  _SettingsRow(
                    title: '오픈소스 라이선스',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: '신통방통',
                      applicationVersion: _versionLabel,
                    ),
                  ),
                  _SettingsRow(
                    title: '고객센터',
                    showDivider: false,
                    onTap: () =>
                        showMyPageToast(context, '고객센터로 연결해요'),
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

/// README ".about .ver" — pill(radius 999, bg rgba(139,44,31,.08), fg red,
/// 12px/600). 업데이트가 있으면 탭 가능한 "업데이트 하기"로 바뀐다.
class _VersionPill extends StatelessWidget {
  const _VersionPill({
    required this.label,
    required this.tappable,
    required this.onTap,
  });

  final String label;
  final bool tappable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: MyPageColors.redSoft,
        borderRadius: BorderRadius.circular(MyPageRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: MyPageFonts.ui,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: MyPageColors.red,
        ),
      ),
    );
    if (!tappable) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MyPageRadius.pill),
      child: pill,
    );
  }
}

/// `settings_minimal_screen.dart`의 `_SettingsRow`와 동일한 스펙(padding
/// 17 0, hair 구분선)을 쓰는 자기완결 복제본 — 각 S화면 자기완결 관례를
/// 따른다(공용 private 위젯을 두지 않음).
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
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
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: MyPageColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
