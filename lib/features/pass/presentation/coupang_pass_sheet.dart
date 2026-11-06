import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../mypage/presentation/theme/mypage_minimal_theme.dart';
import '../../mypage/presentation/theme/mypage_dashed_border.dart';
import '../../mypage/presentation/theme/mypage_success_celebration.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/pass_provider.dart';
import '../domain/pass_model.dart';
import '../../ad_banner/presentation/ad_script_view.dart';
import 'pass_time_format.dart';

/// [프리패스 단순화 - 쿠팡파트너스 전용] §3/§4/§5/§7 신규 통합 바텀시트.
///
/// admin_web "CMS 쿠팡파트너스 배너(positionCode=open_pass)"가 곧 프리패스
/// 광고이므로, 화면은 정책 목록 중 passType=='ad' 단 하나만 사용한다
/// (§10 "프리패스는 쿠팡 파트너스 광고 전용 기능으로 운영").
///
/// 흐름(§4): "쿠팡 방문하기" 탭 1회 → 외부 브라우저에서 쿠팡 파트너스 광고 확인
/// → 앱으로 복귀 감지([WidgetsBindingObserver.didChangeAppLifecycleState]) →
/// 관리자가 설정한 대기시간(4/10초) 카운트다운 → 자동 지급([PassProvider.claimAd])
/// — 재탭 없이 자동으로 완료된다. 앱 라이프사이클 감지가 되지 않는 환경(웹 브라우저
/// 탭 전환 등)을 대비해, 복귀 대기 화면에 수동 확인 버튼도 함께 둔다(이중 안전장치).
///
/// [마이페이지 리뉴얼 · DEV 2026-10-11 §S02] 디자인 핸드오프
/// `design_handoff_mypage_minimal.zip` README §4 "S02 / S04 광고 바텀시트"
/// 스펙으로 전면 리스킨. 기존 `UnifiedColors`/`UnifiedText`(다크 테마) →
/// `MyPageColors`/`MyPageTextStyles`(한지/부적 라이트 테마, mypage_minimal_theme.dart)
/// 로 교체했을 뿐, 상태 머신(`_Phase`)·쿠팡 방문 URL 오픈·앱 복귀 감지·
/// 폴백 타이머·카운트다운·`claimAd` 지급 API 호출·성공 애니메이션 등
/// 기능 로직은 단 한 줄도 바꾸지 않았다(S01 my_screen.dart 리뉴얼과 동일한
/// "로직은 그대로, 스킨만 교체" 원칙).
Future<void> showCoupangPassSheet(
  BuildContext context, {
  String? categoryTitle,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MyPageColors.surface,
    // README §S02: dim rgba(30,18,10,.45). (blur 2px는 showModalBottomSheet의
    // barrierColor만으로는 표현할 수 없어 생략 — dim 색상만 적용한다.)
    barrierColor: const Color(0x731E120A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MyPageRadius.sheet),
      ),
    ),
    builder: (ctx) => _CoupangPassSheet(categoryTitle: categoryTitle),
  );
}

enum _Phase { idle, waitingReturn, counting, success }

class _CoupangPassSheet extends StatefulWidget {
  const _CoupangPassSheet({this.categoryTitle});

  final String? categoryTitle;

  @override
  State<_CoupangPassSheet> createState() => _CoupangPassSheetState();
}

class _CoupangPassSheetState extends State<_CoupangPassSheet>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  int _secondsLeft = 0;
  Timer? _countdownTimer;
  bool _launchedAd = false;
  bool _claiming = false;
  late final AnimationController _glowController;

  // [프리패스 "로딩만 돌고 멈춤" 버그 수정] didChangeAppLifecycleState
  // (AppLifecycleState.resumed) 기반 자동 복귀 감지는 모바일 브라우저(삼성
  // 인터넷 등)에서 Flutter Web 앱을 직접 열어 쓰는 환경에서는 신뢰할 수
  // 없다 - 새 탭이 백그라운드/포그라운드 전환 이벤트를 브라우저 탭에
  // 정확히 전달하지 않거나, 팝업 차단으로 탭 자체가 새 브라우징 컨텍스트로
  // 인식되지 않는 경우가 흔하다. 그 결과 "쿠팡 페이지 확인 중..." 로딩
  // 배너만 계속 돌고 자동 진행이 영원히 트리거되지 않는 증상이 발생한다.
  // 자동 감지에만 의존하지 않고, 쿠팡 방문 버튼을 누른 뒤 일정 시간이
  // 지나면 (사용자가 이미 쿠팡을 확인하고 돌아왔을 가능성이 높다고 보고)
  // 자동 감지가 오지 않았어도 스스로 카운트다운을 시작하는 안전장치를 둔다.
  Timer? _waitingReturnFallbackTimer;
  static const Duration _waitingReturnFallbackDelay = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // §9: 시트를 열 때마다 admin_web 최신 데이터(광고 이미지/링크/이용시간/
    // 대기시간)를 다시 조회해, 관리자가 방금 수정한 값이 즉시 반영되게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PassProvider>().load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _waitingReturnFallbackTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // §4: 쿠팡 방문 후 앱으로 복귀하는 순간을 자동 감지한다.
    if (state == AppLifecycleState.resumed &&
        _launchedAd &&
        _phase == _Phase.waitingReturn) {
      final policy = _adPolicy;
      if (policy != null) _startCountdown(policy);
    }
  }

  PassPolicyModel? get _adPolicy {
    final pass = context.read<PassProvider>();
    for (final p in pass.policies) {
      if (p.passType == PassType.ad) return p;
    }
    return null;
  }

  Future<void> _handleVisit(PassPolicyModel policy) async {
    // [진단용 로그 - 클릭이 실제로 콜백에 도달하는지 확인]
    debugPrint(
      '[CoupangPassSheet] [_handleVisit] 진입 -> policyId=${policy.id}, linkUrl=${policy.linkUrl}',
    );
    // [쿠팡 방문하기 버튼 ↔ 광고 URL 연결] admin_web `/api/public/pass/policies`가
    // CMS 배너(positionCode='open_pass')의 linkUrl을 그대로 내려주거나, 관리자가
    // adType='script'(iframe 임베드 코드)만 등록한 경우에는 서버가 adScript
    // 안의 URL(iframe src 등)을 자동 추출해 linkUrl로 채워 내려준다. 따라서
    // 여기서는 정책에 담긴 linkUrl을 신뢰하고 그대로 열기만 하면 된다.
    final targetUrl = policy.linkUrl;
    if (targetUrl == null || targetUrl.isEmpty) {
      debugPrint('[CoupangPassSheet] [_handleVisit] 실패 -> targetUrl이 비어있음');
      AppToast.show(context, '아직 쿠팡 파트너스 광고가 설정되지 않았어요.', isError: true);
      return;
    }
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      debugPrint(
        '[CoupangPassSheet] [_handleVisit] 실패 -> URI 파싱 실패: $targetUrl',
      );
      AppToast.show(context, '광고 링크가 올바르지 않아요.', isError: true);
      return;
    }

    // [쿠팡 페이지가 안 열리는 문제 수정] Custom Tabs 기반 인앱 브라우저
    // (LaunchMode.inAppWebView)는 기기에 Custom Tabs를 지원하는 브라우저가
    // 없거나 Flutter Web 프리뷰(iframe 내 팝업 차단) 환경에서 조용히 실패할
    // 수 있다. 프로젝트 내 다른 모든 외부 링크(홈 배너 등)가 이미 사용 중인
    // 검증된 방식인 externalApplication(기기 기본 브라우저로 전체 이동)으로
    // 통일해 안정성을 확보한다.
    bool launched = false;
    try {
      debugPrint('[CoupangPassSheet] [_handleVisit] launchUrl 호출 시작 -> $uri');
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint(
        '[CoupangPassSheet] [_handleVisit] launchUrl 결과 -> launched=$launched',
      );
    } catch (e, st) {
      debugPrint('[CoupangPassSheet] [_handleVisit] launchUrl 예외 -> $e\n$st');
      launched = false;
    }

    if (!mounted) return;

    if (!launched) {
      // 실행 자체가 실패했다면 "대기 중" 상태로 넘어가지 않고 원래 화면으로
      // 되돌려, 열리지도 않았는데 자동으로 프리패스가 지급되는 문제를 막는다.
      setState(() => _phase = _Phase.idle);
      AppToast.show(context, '쿠팡 페이지를 열 수 없어요. 잠시 후 다시 시도해주세요.', isError: true);
      return;
    }

    setState(() {
      _phase = _Phase.waitingReturn;
      _launchedAd = true;
    });

    // [프리패스 "로딩만 돌고 멈춤" 버그 수정] 자동 복귀 감지(생명주기
    // 이벤트)가 오지 않는 모바일 브라우저 환경을 대비한 안전장치. 일정
    // 시간 뒤 waitingReturn 상태가 그대로면 사용자가 이미 쿠팡을 확인하고
    // 돌아왔다고 간주하고 자동으로 카운트다운을 시작한다.
    _waitingReturnFallbackTimer?.cancel();
    _waitingReturnFallbackTimer = Timer(_waitingReturnFallbackDelay, () {
      if (!mounted) return;
      if (_phase == _Phase.waitingReturn) {
        _startCountdown(policy);
      }
    });
  }

  void _startCountdown(PassPolicyModel policy) {
    if (_phase == _Phase.counting || _phase == _Phase.success) return;
    _waitingReturnFallbackTimer?.cancel();
    setState(() {
      _phase = _Phase.counting;
      _secondsLeft = policy.adWaitSeconds;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _claimPass(policy);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _claimPass(PassPolicyModel policy) async {
    if (_claiming) return;
    _claiming = true;
    final pass = context.read<PassProvider>();
    final ok = await pass.claimAd(policyId: policy.id);
    if (!mounted) return;

    if (ok) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      setState(() => _phase = _Phase.success);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).pop();
    } else {
      _claiming = false;
      setState(() => _phase = _Phase.idle);
      AppToast.show(
        context,
        pass.lastError ?? '프리패스 발급에 실패했습니다. 다시 시도해주세요.',
        isError: true,
      );
    }
  }

  // [프리패스 UI 문구 관리자 연동] 관리자가 값을 입력하지 않았을 때(null) 화면이
  // 비어 보이지 않도록 하는 기본 문구. admin_web 쪽 기본값과 동일하게 유지한다.
  static const _defaultHelpMessage =
      '쿠팡 파트너스 활동을 통해 일정 수수료를 지급받는 제휴 광고예요.\n'
      '쿠팡 방문 후 앱으로 돌아오면 잠시 후 자동으로 프리패스가 지급됩니다.';

  void _showHelp(PassPolicyModel? policy) {
    showAppInfoDialog(
      context,
      title: '프리패스 안내',
      message: policy?.adHelpMessage?.isNotEmpty == true
          ? policy!.adHelpMessage!
          : _defaultHelpMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final policy = () {
      for (final p in pass.policies) {
        if (p.passType == PassType.ad) return p;
      }
      return null;
    }();

    // README §S02: 시트 padding `12 24 40`.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: MyPageSpacing.sp6,
            right: MyPageSpacing.sp6,
            top: MyPageSpacing.sp3,
            bottom: 40 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHandle(),
              _buildHeaderRow(policy),
              const SizedBox(height: MyPageSpacing.sp1),
              if (policy == null)
                _buildEmptyState(pass.isLoading)
              else if (_phase == _Phase.success)
                MyPageSuccessCelebration(
                  title: '프리패스가 발급되었어요!',
                  subtitle: policy.grantCount != null
                      ? '결과보기 ${_passAmountLabel(policy)}가 지급되었어요'
                      : '${_passAmountLabel(policy)} 동안 모든 콘텐츠를 자유롭게 이용하세요',
                )
              else
                _buildContent(policy),
            ],
          ),
        ),
      ),
    );
  }

  // README §S02: 그랩바 40×4.
  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: MyPageSpacing.sp4),
        decoration: BoxDecoration(
          color: MyPageColors.hair,
          borderRadius: BorderRadius.circular(MyPageRadius.pill),
        ),
      ),
    );
  }

  // README §S02: 우상단 ✕ 36×36. (좌측 도움말 아이콘은 기존 기능을
  // 유지하기 위해 그대로 두되, 톤을 --mp-ink-3으로 맞춘다.)
  Widget _buildHeaderRow(PassPolicyModel? policy) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _showHelp(policy),
          icon: const Icon(
            Icons.help_outline_rounded,
            color: MyPageColors.ink3,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 22,
        ),
        const Spacer(),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: MyPageColors.ink3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MyPageSpacing.sp8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '프리패스가\n필요하신가요',
            style: TextStyle(
              fontFamily: MyPageFonts.ui,
              fontWeight: FontWeight.w800,
              fontSize: 21,
              height: 1.3,
              color: MyPageColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MyPageSpacing.sp2),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: MyPageColors.red),
            )
          else
            Text(
              '아직 프리패스 광고가 준비되지 않았어요. 잠시 후 다시 시도해주세요.',
              style: MyPageTextStyles.body,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  // [결과보기 통합 권한 시스템 v1.0, 2026-09-28] §1/§3 시간제→횟수제 전환.
  // policy.grantCount != null(현재는 쿠팡 정책 id=11)이면 화면 전체가 "N회"
  // 문구를 쓰고, null이면(레거시 시간제 정책) 기존 durationMin 기반 "N시간/분"
  // 문구를 그대로 유지한다 — 이 한 곳에서만 분기하면 아래 모든 호출부가
  // 자동으로 올바른 라벨을 받는다.
  String _passAmountLabel(PassPolicyModel policy) {
    final grantCount = policy.grantCount;
    if (grantCount != null && grantCount > 0) return formatPassGrantCount(grantCount);
    // [프리패스 2회지급 전환 지시서 §3.4-2, 2026-09-28] 쿠팡 정책(id=11)은
    // 이제 회수제(grantCount)로 확정 운영되므로, grantCount 값이 서버에서
    // 아직 반영되지 않았거나 누락된 예외 상황에서도 durationMin(시간제) 문구
    // ("1시간" 등)로 폴백하지 않는다 — "1시간" 문구가 재발하는 것을 막기
    // 위한 방어 코드다(시간제 정책으로의 복원 금지, 지시서 §2.2 명시).
    return '지급 준비 중';
  }

  Widget _buildContent(PassPolicyModel policy) {
    if (policy.grantCount == null || policy.grantCount! <= 0) {
      return _buildEmptyState(false);
    }
    const isCountBased = true;
    final durationLabel = _passAmountLabel(policy);
    final isCounting = _phase == _Phase.counting;
    final isWaitingReturn = _phase == _Phase.waitingReturn;

    // [프리패스 UI 문구 관리자 연동] 관리자가 입력한 안내 제목/문구를 우선
    // 사용하고, 값이 없으면(null/빈 문자열) README §S02 기본 문구로 폴백한다.
    // README §S02: 기본 타이틀 "프리패스가 / 필요하신가요", 기본 리드
    // "짧은 광고를 끝까지 보면 결과보기 2회를 무료로 쓸 수 있어요".
    final guideTitle = policy.adGuideTitle?.isNotEmpty == true
        ? policy.adGuideTitle!
        : (widget.categoryTitle != null
              ? '"${widget.categoryTitle}"는\n프리패스로 열람할 수 있어요'
              : '프리패스가\n필요하신가요');
    // isCountBased는 현재 항상 true(회수제)지만, 향후 레거시 시간제 정책이
    // 부활할 가능성에 대비해 분기 구조 자체는 유지한다(기존 로직 그대로 —
    // 원본 파일에도 동일한 패턴/동일한 dead_code 경고가 있었다).
    final guideText = policy.adGuideText?.isNotEmpty == true
        ? policy.adGuideText!
        : isCountBased
            ? '짧은 광고를 끝까지 보면 결과보기 $durationLabel를\n무료로 쓸 수 있어요.'
            : '쿠팡 파트너스 광고를 확인하면 $durationLabel 동안\n모든 콘텐츠를 무료로 이용할 수 있어요.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // README §S02: 제목 21px/800 2줄.
        Text(
          guideTitle,
          style: const TextStyle(
            fontFamily: MyPageFonts.ui,
            fontWeight: FontWeight.w800,
            fontSize: 21,
            height: 1.3,
            color: MyPageColors.ink,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MyPageSpacing.sp2),
        Text(
          guideText,
          style: MyPageTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MyPageSpacing.sp4),

        // README §S02: 광고 영역 150px, radius 16, 1px dashed, 하단 3px
        // 빨강 진행바. 여기에 실제 광고 SDK 뷰(스크립트/배너)를 넣는다.
        _buildAdMedia(policy, isCounting: isCounting),
        const SizedBox(height: MyPageSpacing.sp3),

        // "쿠팡 방문하기" 버튼
        InkWell(
          onTap: isCounting || _claiming ? null : () => _handleVisit(policy),
          borderRadius: BorderRadius.circular(MyPageRadius.btn),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MyPageSpacing.sp2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: MyPageColors.ink,
                ),
                const SizedBox(width: MyPageSpacing.sp2),
                Text(
                  '쿠팡 방문하기',
                  style: MyPageTextStyles.row.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(
          '파트너스 활동을 통해 일정액의 수수료를 지급받을 수 있어요',
          style: MyPageTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MyPageSpacing.sp4),

        // 대기/카운트다운 상태 안내
        if (isWaitingReturn) _buildWaitingBanner(policy),
        if (isCounting) _buildCountingBanner(),

        // 이용시간/횟수 뱃지
        _buildDurationPill(durationLabel, isCountBased: isCountBased),
        const SizedBox(height: MyPageSpacing.sp4),

        // 메인 CTA
        _buildMainCta(policy, durationLabel, isCountBased: isCountBased),

        const SizedBox(height: MyPageSpacing.sp2),
        TextButton(
          onPressed: (isCounting || _claiming)
              ? null
              : () => Navigator.of(context).pop(),
          child: Text('나중에 할게요', style: MyPageTextStyles.caption),
        ),
      ],
    );
  }

  // README §S02: 광고 영역 150px, radius 16, 1px dashed border, 하단 3px
  // 빨강 진행바(카운트다운 진행률을 시각화).
  Widget _buildAdMedia(PassPolicyModel policy, {required bool isCounting}) {
    const height = 150.0;
    final progress = isCounting && policy.adWaitSeconds > 0
        ? (policy.adWaitSeconds - _secondsLeft) / policy.adWaitSeconds
        : 0.0;

    Widget media;
    if (policy.adType == 'script' &&
        policy.adScript != null &&
        policy.adScript!.isNotEmpty) {
      media = SizedBox(
        height: height,
        width: double.infinity,
        child: buildAdScriptView(policy.adScript!, height: height),
      );
    } else if (policy.bannerImageUrl != null &&
        policy.bannerImageUrl!.isNotEmpty) {
      media = Image.network(
        policy.bannerImageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _adPlaceholder(height),
      );
    } else {
      media = _adPlaceholder(height);
    }

    return MyPageDashedBorderBox(
      radius: MyPageRadius.btn,
      height: height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(MyPageRadius.btn - 1),
            child: media,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(MyPageRadius.btn - 1),
              ),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  color: MyPageColors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adPlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: MyPageColors.paper2,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_offer_outlined,
        size: 36,
        color: MyPageColors.ink3,
      ),
    );
  }

  Widget _buildWaitingBanner(PassPolicyModel policy) {
    return Container(
      margin: const EdgeInsets.only(bottom: MyPageSpacing.sp3),
      padding: const EdgeInsets.all(MyPageSpacing.sp3),
      decoration: BoxDecoration(
        color: MyPageColors.paper2,
        borderRadius: BorderRadius.circular(MyPageRadius.btn),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MyPageColors.red,
            ),
          ),
          const SizedBox(width: MyPageSpacing.sp2),
          Expanded(
            child: Text(
              // [프리패스 "로딩만 돌고 멈춤" 버그 수정] 자동 복귀 감지가 되지
              // 않는 환경(모바일 브라우저 등)을 대비해 잠시 후 자동으로도
              // 진행된다는 점과, 바로 아래 큰 버튼을 눌러도 된다는 점을
              // 함께 안내한다.
              '쿠팡 페이지를 확인하셨다면 아래 버튼을 눌러주세요.\n잠시 기다리면 자동으로도 진행돼요.',
              style: MyPageTextStyles.caption.copyWith(color: MyPageColors.ink2),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: () => _startCountdown(policy),
            style: TextButton.styleFrom(foregroundColor: MyPageColors.red),
            child: const Text('돌아왔어요'),
          ),
        ],
      ),
    );
  }

  // README §S02: CTA가 "광고 재생 중…"으로 바뀌는 동안의 상태 안내 배너.
  Widget _buildCountingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: MyPageSpacing.sp3),
      padding: const EdgeInsets.all(MyPageSpacing.sp3),
      decoration: BoxDecoration(
        color: MyPageColors.redSoft,
        borderRadius: BorderRadius.circular(MyPageRadius.btn),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(MyPageColors.red),
              value: null,
            ),
          ),
          const SizedBox(width: MyPageSpacing.sp2),
          Expanded(
            child: Text(
              '광고 재생 중... $_secondsLeft초 후 자동 지급',
              style: MyPageTextStyles.caption.copyWith(
                color: MyPageColors.redDeep,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPill(String durationLabel, {required bool isCountBased}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MyPageSpacing.sp3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: MyPageColors.paper2,
        borderRadius: BorderRadius.circular(MyPageRadius.pill),
      ),
      // [버그수정 — 반응형 화면 규격 통일 작업 중 실제 테스트로 발견]
      // 이 뱃지는 시트 폭에 맞춘 Row(mainAxisSize: min)인데, 안의 Text가
      // Flexible 없이 고정 폭을 요구해 시스템 글자 확대 2.0배 조합에서
      // 40px, 2.5배 조합에서 112px씩 "오른쪽"으로 넘쳤다(RenderFlex
      // overflowed on the right) — 다른 세로 오버플로와 달리 가로 오버플로라
      // SingleChildScrollView로는 고칠 수 없다. Text를 Flexible로 감싸
      // 공간이 부족하면 줄임표(ellipsis)로 축약되게 한다(평소 폭에는
      // 영향 없음, 문구·아이콘·색상·배경은 그대로 유지).
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCountBased ? Icons.confirmation_num_outlined : Icons.timer_outlined,
            size: 16,
            color: MyPageColors.ink2,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isCountBased
                  ? '프리패스 지급 · $durationLabel'
                  : '프리패스 이용시간 · $durationLabel',
              style: MyPageTextStyles.caption.copyWith(color: MyPageColors.ink2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // README §S02: CTA "프리패스 N회 받기" → 누르면 "광고 재생 중…"으로
  // 바뀌고 비활성 → 광고 완료 콜백 → 보상 API → 시트 닫힘 + 토스트.
  // (카운트다운 숫자는 기존처럼 함께 표시해 사용자가 남은 시간을 알 수
  // 있게 한다 — 기능 손실 없이 문구만 README 톤에 맞춘다.)
  Widget _buildMainCta(
    PassPolicyModel policy,
    String durationLabel, {
    required bool isCountBased,
  }) {
    final isCounting = _phase == _Phase.counting;
    final disabled = isCounting || _claiming;

    String label;
    switch (_phase) {
      case _Phase.idle:
        label = '프리패스 $durationLabel 받기';
        break;
      case _Phase.waitingReturn:
        // [프리패스 "로딩만 돌고 멈춤" 버그 수정] 이 문구는 단순 안내가
        // 아니라 실제로 탭 가능한 버튼이다(onTap이 _startCountdown 호출).
        // 기존 "쿠팡 방문 후 앱으로 돌아와주세요"는 지시문처럼 읽혀
        // 버튼인지 알아채기 어려웠으므로, "눌러야 할 동작"임을 명확히
        // 드러내는 문구로 교체한다.
        label = '쿠팡 확인했어요, 프리패스 받기';
        break;
      case _Phase.counting:
        label = '광고 재생 중... $_secondsLeft초';
        break;
      case _Phase.success:
        label = '지급 완료';
        break;
    }

    final onTap = disabled
        ? null
        : () {
            if (_phase == _Phase.waitingReturn) {
              _startCountdown(policy);
            } else {
              _handleVisit(policy);
            }
          };

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = disabled ? 0.0 : 0.15 + (_glowController.value * 0.25);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyPageRadius.pill),
            boxShadow: glow > 0
                ? [
                    BoxShadow(
                      color: MyPageColors.red.withValues(alpha: glow),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: MyPageColors.red,
            disabledBackgroundColor: MyPageColors.red.withValues(alpha: 0.5),
            foregroundColor: const Color(0xFFFBF1DE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MyPageRadius.pill),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
