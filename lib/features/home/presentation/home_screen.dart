import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../fortune/daily/application/daily_fortune_provider.dart';
import '../../notification/notification_provider.dart';
import '../../luckybag/application/luckybag_provider.dart';
import '../../amulet/application/amulet_provider.dart';
import '../../community/application/wish_post_provider.dart';
import '../../community/presentation/community_screen.dart';
import '../../lucky_number/application/lucky_number_provider.dart';
import '../../lucky_number/presentation/lucky_number_widget.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/domain/pass_model.dart';

/// 03단계 §3.3 홈 탭 - HomeScreen
/// [Sowoon.kr 리디자인 프롬프트] 화이트/골드 미니멀 테마로 전면 리디자인.
/// 구성: 인사/헤드라인 → 오늘의 우주 이야기 → 행운 리추얼 → AI 추천 행동
/// → 부적 & 소원게시판(좌우 2열) → 소원방 배너 → 운세 메뉴 2열 그리드
/// (연속 출석 섹션은 화면에서 숨김 - DB 기록/로드는 유지)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<DailyFortuneProvider>().loadToday();
      // 07단계 §14 행운 경험(Luck Experience) 리추얼 데이터 로드
      context.read<LuckyBagProvider>().load();
      context.read<AmuletProvider>().load();
      // [웹→앱 이식] 신통방통 index.html "소원게시판" 요약 카드용 데이터 로드
      context.read<WishPostProvider>().loadFeed();
      // [신규] 알림패스 — 상단 상태바 카운트다운 + 알림패스 섹션 CTA 카드 로드
      context.read<PassProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final notif = context.watch<NotificationProvider>();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '신통방통',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        // [신규] 알림패스 상단 상태바 — 활성 상태일 때만 AppBar 하단에 카운트다운 노출.
        bottom: const _AlarmPassStatusBar(),
        actions: [
          _HcCircleIconButton(
            icon: notif.unreadCount > 0
                ? AppIcons.notificationOn
                : AppIcons.notificationOff,
            background: AppColors.hcCardBg2,
            iconColor: AppColors.hcTextBody,
            showDot: notif.unreadCount > 0,
            onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
          ),
          const SizedBox(width: 8),
          _HcCircleIconButton(
            icon: Icons.person_rounded,
            background: AppColors.hcCream,
            iconColor: AppColors.hcGoldDark,
            onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // [현대카드 스타일 리디자인] 인사말 섹션 - 날짜 라벨 + 헤드라인 2단 구성.
            // [사용자 요청] "오늘의운세보기 크기의 폰트을 맨위 안녕하세요에 적욘하고" — 헤드라인
            // 폰트 크기/굵기를 "오늘의 운세 보기" 버튼과 동일한 13px/w700으로 축소한다.
            Text(
              '${now.year}년 ${now.month}월 ${now.day}일 · 오늘의 기운',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: AppColors.hcTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.hcTextDark,
                  height: 1.5,
                  letterSpacing: -0.2,
                ),
                children: [
                  const TextSpan(text: '안녕하세요, 오늘 당신의 '),
                  const TextSpan(
                    text: '운명',
                    style: TextStyle(color: AppColors.hcGoldDark),
                  ),
                  const TextSpan(text: '은\n어떤 이야기를 들려줄까요?'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // [웹→앱 이식] 신통방통 index.html "오늘의 우주 이야기" 카드
            const _DailyFortuneCard(),
            const SizedBox(height: AppSpacing.lg),
            // [Sowoon.kr 리디자인 프롬프트] 연속 출석 섹션은 화면에서 숨김(DB 기록/로드는 유지).
            // (initState의 AttendanceProvider.load()는 계속 호출되어 데이터는 갱신됨)
            // ★07단계 §14 행운 경험(Luck Experience) 리추얼 배너
            // [사용자 요청] "오늘에행운메세지와 오늘에추천행동 섹션을 숨김 처리" — "오늘의 행운
            // 메시지" 카드는 배너 캐러셀 내부에서 제거(행운 색상/숫자 카드는 유지),
            // "오늘의 추천 행동"(_AiRecommendationCard)은 아래에서 완전히 숨김 처리한다.
            const _LuckRitualBanner(),
            const SizedBox(height: AppSpacing.lg),
            // [신규] 알림패스(AlarmPass) 섹션 — 정책 CTA 카드(광고/파트너) 노출.
            // 이미 활성 상태면 섹션 자체를 숨긴다(상단 상태바로 충분히 안내됨).
            const _AlarmPassSection(),
            const SizedBox(height: AppSpacing.lg),
            // [웹→앱 이식] 신통방통 index.html "🔮 부적 & 소원게시판" 세로배치 섹션
            const _TalismanWishSection(),
            const SizedBox(height: AppSpacing.lg),
            // [웹→앱 이식] 신통방통 index.html "소원방(Wish Room)" 진입 배너
            const _WishRoomBanner(),
            const SizedBox(height: AppSpacing.lg),
            // [운세 앱 개발 프롬프트-메인 UI 리뉴얼] "운세 메뉴" 2열 그리드(신통방통 스크린샷 재현)
            _FortuneMenuSectionHeader(),
            const SizedBox(height: AppSpacing.md),
            const _FortuneMenuGrid(),
            const SizedBox(height: AppSpacing.lg),
            // 지갑 잔액은 우측 상단 프로필 아이콘 → 포인트 지갑에서 확인 가능(레이아웃 참고용 유지)
            if (wallet.balance < 0) const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

/// [운세 앱 개발 프롬프트-메인 UI 리뉴얼] AppBar 우측 원형 아이콘 버튼
/// (현대카드 앱 스타일 - 연한 색 원형 배경 + 아이콘, 알림 뱃지 도트 지원)
class _HcCircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final bool showDot;
  final VoidCallback onTap;

  const _HcCircleIconButton({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          if (showDot)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.hcBackground, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// [레퍼런스 스크린샷 리디자인] "오늘의 우주 이야기" 가로 배너형 카드
/// 세로로 긴 카드(헤더+본문+미니스코어3개+CTA) -> 컴팩트한 가로 직사각형 배너로 축소.
/// 라이트 라벤더 배경 + 타이틀행(아이콘+제목+달 아이콘) + 한줄 본문 + CTA 버튼(다크 필).
class _DailyFortuneCard extends StatelessWidget {
  const _DailyFortuneCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyFortuneProvider>();
    final today = provider.today;

    return GestureDetector(
      onTap: () =>
          Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.hcAccentSoft,
          borderRadius: BorderRadius.circular(AppRadius.hcCardLarge),
          // [현대카드 스타일 리디자인] 다른 메인 카드(부적 만들기 등)는 옅은 그림자로
          // 입체감을 주는데 이 카드만 플랫해서 위계가 어긋나 보였다. 톤을 맞춘다.
          boxShadow: const [
            BoxShadow(
              color: AppColors.hcCardShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.blur_circular_rounded,
                  color: AppColors.hcGoldDark,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '오늘의 우주 이야기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: AppColors.hcGoldDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.hcCardBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nights_stay_rounded,
                    color: AppColors.hcGoldDark,
                    size: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.isLoading)
              const SizedBox(
                height: 18,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.hcGoldDark,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else
              Text(
                today?.summaryText ?? '별은 언제나 당신을 비추고 있습니다.',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  color: AppColors.hcTextDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.hcButtonPill),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed('/home/daily-fortune-detail'),
                child: const Text('오늘의 운세 보기  →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceWidget extends StatelessWidget {
  const _AttendanceWidget();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.hcGoldDark,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '연속 출석 ${provider.streak}일째',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  provider.checkedToday
                      ? '오늘 출석을 완료했어요!'
                      : '오늘 출석하고 포인트를 받아보세요',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: provider.checkedToday
                ? null
                : () async {
                    final earned = await provider.checkIn();
                    if (!context.mounted) return;
                    if (earned > 0) {
                      // [실API 전환] 서버 checkin API가 지갑 적립까지 트랜잭션으로
                      // 처리했으므로, 여기서는 잔액만 새로고침한다(중복 적립 방지).
                      await context.read<WalletProvider>().load();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('출석 완료! +$earned P 지급')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.lastError ?? '출석 처리에 실패했습니다.',
                          ),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.checkedToday
                  ? AppColors.dividerOf(context)
                  : AppColors.hcGoldDark,
              foregroundColor: provider.checkedToday
                  ? AppColors.textHintOf(context)
                  : Colors.white,
            ),
            child: Text(provider.checkedToday ? '완료' : '출석'),
          ),
        ],
      ),
    );
  }
}

/// [신규] 알림패스(AlarmPass) 상단 상태바 — AppBar.bottom에 장착되는 카운트다운.
/// 활성 상태가 아니면 높이 0(공간 차지 없음)으로 접혀 있는 그대로 사라진다.
/// 서버 값(remainingSec)을 기준으로 1초 간격 로컬 타이머로 카운트다운만 표시하고,
/// 실제 만료 판정은 다음 PassProvider.load() 호출(홈 재진입/새로고침) 시 서버가 갖는다.
class _AlarmPassStatusBar extends StatefulWidget implements PreferredSizeWidget {
  const _AlarmPassStatusBar();

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  State<_AlarmPassStatusBar> createState() => _AlarmPassStatusBarState();
}

class _AlarmPassStatusBarState extends State<_AlarmPassStatusBar> {
  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    if (!pass.isActive) return const SizedBox.shrink();

    final remaining = pass.status.remainingSec;
    final h = remaining ~/ 3600;
    final m = (remaining % 3600) ~/ 60;
    final s = remaining % 60;
    final label = h > 0
        ? '$h시간 $m분 남음'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} 남음';

    return Container(
      height: 32,
      color: AppColors.hcAccentSoft,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 14,
            color: AppColors.hcGoldDark,
          ),
          const SizedBox(width: 4),
          Text(
            '알림패스 활성중 · ${pass.status.policyName ?? ''} · $label',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.hcGoldDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// [신규] 알림패스(AlarmPass) 섹션 — 광고 시청/파트너 방문 CTA 카드.
/// admin_web `GET /api/public/pass/policies` 정책 중 passType이 ad/partner인
/// 항목만 클라이언트에서 필터링해 노출한다(claim-ad/claim-partner API만 존재).
/// 이미 알림패스가 활성 상태면(상단 상태바로 충분히 안내되므로) 섹션을 숨긴다.
class _AlarmPassSection extends StatefulWidget {
  const _AlarmPassSection();

  @override
  State<_AlarmPassSection> createState() => _AlarmPassSectionState();
}

class _AlarmPassSectionState extends State<_AlarmPassSection> {
  bool _claiming = false;

  Future<void> _handleAdClaim(PassPolicyModel policy) async {
    final pass = context.read<PassProvider>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: policy.name,
      message: policy.ctaText ?? '광고를 시청하고 알림패스를 받으시겠습니까?',
      confirmLabel: '시청하기',
    );
    if (!confirmed || !mounted) return;

    setState(() => _claiming = true);
    // [주의] AdMob 등 실제 광고 SDK가 아직 연동되지 않아, 확인 다이얼로그로
    // "시청 완료"를 대신한다(관리자 정책/보너스 로직은 서버가 실제로 처리).
    final ok = await pass.claimAd(policyId: policy.id);
    if (!mounted) return;
    setState(() => _claiming = false);

    if (ok) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      AppToast.show(context, '알림패스가 발급되었습니다! (${policy.durationMin}분)');
    } else {
      AppToast.show(context, pass.lastError ?? '알림패스 발급에 실패했습니다.', isError: true);
    }
  }

  Future<void> _handlePartnerClaim(PassPolicyModel policy) async {
    final pass = context.read<PassProvider>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: policy.name,
      message: policy.ctaText ?? '파트너 페이지를 방문하고 알림패스를 받으시겠습니까?',
      confirmLabel: '방문하기',
    );
    if (!confirmed || !mounted) return;

    if (policy.linkUrl != null && policy.linkUrl!.isNotEmpty) {
      final uri = Uri.tryParse(policy.linkUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (!mounted) return;

    setState(() => _claiming = true);
    final ok = await pass.claimPartner(policyId: policy.id);
    if (!mounted) return;
    setState(() => _claiming = false);

    if (ok) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      AppToast.show(context, '알림패스가 발급되었습니다! (${policy.durationMin}분)');
    } else {
      AppToast.show(context, pass.lastError ?? '알림패스 발급에 실패했습니다.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    if (pass.isActive) return const SizedBox.shrink();

    final actionablePolicies = pass.policies
        .where(
          (p) => p.passType == PassType.ad || p.passType == PassType.partner,
        )
        .toList();
    if (actionablePolicies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⏱️ 알림패스 받기',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.hcTextDark,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...actionablePolicies.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AlarmPassCard(
              policy: p,
              isBusy: _claiming,
              onTap: () => p.passType == PassType.ad
                  ? _handleAdClaim(p)
                  : _handlePartnerClaim(p),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlarmPassCard extends StatelessWidget {
  final PassPolicyModel policy;
  final bool isBusy;
  final VoidCallback onTap;

  const _AlarmPassCard({
    required this.policy,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAd = policy.passType == PassType.ad;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.hcCardBg,
        borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
        border: Border.all(color: AppColors.hcBorderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.hcCream,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAd ? Icons.smart_display_rounded : Icons.storefront_rounded,
              color: AppColors.hcGoldDark,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.name,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hcTextDark,
                  ),
                ),
                Text(
                  '${policy.durationMin}분'
                  '${policy.bonusPoint > 0 ? ' · +${policy.bonusPoint}P' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.hcTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: isBusy ? null : onTap,
              child: Text(isAd ? '시청' : '방문'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 07단계 §6.4/§14 행운 경험(Luck Experience) 리추얼 배너
/// 홈 최상단에 배치, 가로 스와이프 5카드(행운메시지/행운색상/행운숫자/복주머니/디지털부적)
/// 앱 최초 진입(당일 1회) 시 자동 순환 하이라이트 후 정적 배너로 전환.
class _LuckRitualBanner extends StatefulWidget {
  const _LuckRitualBanner();

  @override
  State<_LuckRitualBanner> createState() => _LuckRitualBannerState();
}

class _LuckRitualBannerState extends State<_LuckRitualBanner> {
  final _controller = PageController(viewportFraction: 0.86);
  int _current = 0;
  bool _autoPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCycle();
      // [버그 수정] LuckyNumberProvider.load()가 어디에서도 호출되지 않아
      // "오늘의 행운숫자" 관리자 콘텐츠가 영원히 로드되지 않는 문제가 있었다.
      // (기존에는 LuckyNumberWidget.initState()에서만 load()를 호출했는데,
      // 그 위젯 자체가 hasContent==true일 때만 생성되는 조건 안에 있어
      // "콘텐츠가 없으면 로드 안 됨 → 로드가 안 되니 콘텐츠가 계속 없음"이라는
      // 순환 참조 상태에 빠져 있었다.) 배너가 뜰 때 한 번 명시적으로 로드한다.
      context.read<LuckyNumberProvider>().load();
    });
  }

  Future<void> _autoCycle() async {
    if (_autoPlayed || !mounted) return;
    _autoPlayed = true;
    // [사용자 요청] 복주머니/디지털부적 카드 숨김으로 카드 3개(행운메시지/색상/숫자)만 순환.
    for (var i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _controller.animateTo(
        i * (_controller.position.viewportDimension * 0.86 + AppSpacing.sm),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
      setState(() => _current = i);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = context.watch<DailyFortuneProvider>().today;
    // 03단계 §3.1 Luck Color 팔레트 중앙화(AppColors.luckColorPalette) 참조
    final luckyColorMap = AppColors.luckColorPalette;

    final cards = <Widget>[
      // [사용자 요청] "오늘에행운메세지... 섹션을 숨김 처리" — 캐러셀에서 "오늘의 행운
      // 메시지" 카드를 제거(행운 색상/숫자 카드는 유지).
      _RitualCard(
        emoji: '🍀',
        title: '오늘의 행운 색상',
        body: today?.luckyColor ?? '-',
        swatch: today != null ? luckyColorMap[today.luckyColor] : null,
        onTap: () =>
            Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      ),
      // [사용자 요청] "오늘의 행운숫자 섹션은 꼭 광고을 아니 하던것 진핼해" — 관리자가
      // admin_web에서 이미지/영상/소스 콘텐츠를 등록·활성화하면 그 콘텐츠를 카드로
      // 노출하고, 등록된 콘텐츠가 없으면 기존 숫자 표시로 폴백한다. 광고(ad_banner)
      // Provider와는 완전히 분리된 LuckyNumberProvider를 사용한다.
      Consumer<LuckyNumberProvider>(
        builder: (context, luckyNumberProvider, _) {
          if (luckyNumberProvider.hasContent) {
            return LuckyNumberWidget(
              height: 132,
              fallback: _RitualCard(
                emoji: '🔢',
                title: '오늘의 행운 숫자',
                body: today != null ? '${today.luckyNumber}' : '-',
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/home/daily-fortune-detail'),
              ),
            );
          }
          return _RitualCard(
            emoji: '🔢',
            title: '오늘의 행운 숫자',
            body: today != null ? '${today.luckyNumber}' : '-',
            onTap: () =>
                Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
          );
        },
      ),
      // [사용자 요청] "받을 수 있는 복주머니" 카드는 메인에서 숨김.
      // [Sowoon.kr 리디자인 프롬프트] "오늘의 디지털 부적" 카드도 메인에서 숨김.
    ];

    return Semantics(
      label: '오늘의 행운 경험 배너, ${cards.length}개 카드 중 ${_current + 1}번째',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == cards.length - 1 ? 0 : AppSpacing.sm,
                  ),
                  child: cards[index],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              cards.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _current
                      ? AppColors.hcGoldDark
                      : AppColors.dividerOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RitualCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  final Color? swatch;
  final VoidCallback onTap;

  const _RitualCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.onTap,
    this.swatch,
  });

  @override
  Widget build(BuildContext context) {
    // [현대카드 스타일 리디자인] "오늘의 행운" 캐러셀 카드 - 기존에는 플랫한 라이트그레이
    // 배경에 그림자/테두리가 없어 다른 카드(부적 만들기 등)와 위계가 어긋나 보였고,
    // 짧은 값(숫자 "8" 등)이 좌상단에 붙어 아래쪽에 빈 공간이 많이 남아 균형이 안 맞았다.
    // → 화이트 배경+옅은 테두리+그림자로 다른 메인 카드들과 통일하고, 본문을 카드
    // 중앙에 크고 굵게 배치 + 하단 화살표로 "탭 가능" 여지를 채워 여백을 정리한다.
    return Semantics(
      button: true,
      label: '$title: $body',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.hcCardItem),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.hcCardBg,
            borderRadius: BorderRadius.circular(AppRadius.hcCardItem),
            border: Border.all(color: AppColors.hcBorderLight),
            boxShadow: const [
              BoxShadow(
                color: AppColors.hcCardShadow,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.hcTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (swatch != null)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.hcTextDark,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.hcTextSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 07단계 §14.2 "오늘의 AI 추천 행동" 카드
/// 1차는 클라이언트 측 간단 규칙(최근 미사용 AI기능 우선 추천)으로 구현, API 추가 없음(§14.5).
class _AiRecommendationCard extends StatelessWidget {
  const _AiRecommendationCard();

  static const _recommendations = [
    (
      'AI상담사에게 오늘의 고민을 이야기해보세요',
      Icons.chat_bubble_rounded,
      '/ai-fortune/consultation/type',
    ),
    ('오늘은 타로로 빠른 답을 확인해보세요', Icons.style_rounded, '/ai-fortune/tarot/question'),
    (
      '궁합을 확인하고 소중한 사람과의 인연을 알아보세요',
      Icons.favorite_rounded,
      '/ai-fortune/compatibility/input',
    ),
    (
      '관상 분석으로 나의 숨은 매력을 발견해보세요',
      Icons.face_retouching_natural_rounded,
      '/ai-fortune/face/capture',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final seed = DateTime.now().day;
    final (text, icon, route) =
        _recommendations[seed % _recommendations.length];

    return Semantics(
      button: true,
      label: '오늘의 추천 행동: $text',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.hcGoldGradient,
            borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
            // [현대카드 스타일 리디자인] 골드 그라디언트 카드도 다른 화이트 카드들과
            // 동일한 옅은 그림자 톤을 적용해 섹션 전체의 입체감 위계를 통일한다.
            boxShadow: [
              BoxShadow(
                color: AppColors.hcGoldDark.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('✨', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 추천 행동',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// [Sowoon.kr 리디자인 프롬프트] "🔮 부적 & 소원게시판" 섹션
/// 좌우 2열 사이드바이사이드 카드 배치(부적 만들기 | 소원게시판)
class _TalismanWishSection extends StatelessWidget {
  const _TalismanWishSection();

  @override
  Widget build(BuildContext context) {
    // [사용자 요청] "밑에 부적 소원게시판 글씨을 없애주고" — "🔮 부적 & 소원게시판" 헤더
    // 텍스트(제목+"함께 참여해요" 배지)를 제거하고 카드만 바로 배치한다.
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // [Sowoon.kr 리디자인 프롬프트] 좌우 2열 사이드바이사이드 배치
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _TalismanCraftCard()),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _WishBoardSummaryCard()),
            ],
          ),
        ),
      ],
    );
  }
}

class _TalismanCraftCard extends StatelessWidget {
  const _TalismanCraftCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.hcCardBg,
        borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
        border: Border.all(color: AppColors.hcBorderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.hcCardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [사용자 요청] "부적만들기 소원게시판 운세메뉴을 오늘에 운세보기 폰트의
          // 크기로 줄여주고" — 제목 폰트 크기를 "오늘의 운세 보기" 버튼과 동일한
          // 13px/w700으로 축소.
          const Text(
            '🧧 부적 만들기',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.hcTextDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.hcGoldGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // [사용자 요청] "밑에부적만들기 소원게시판 까만박스도 좀더 가늘게" — 버튼
          // 높이를 40→32로 줄이고 세로 패딩도 축소해 더 슬림하게 만든다.
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                textStyle: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/reward/amulet/generate'),
              child: const Text('부적 만들기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishBoardSummaryCard extends StatelessWidget {
  const _WishBoardSummaryCard();

  @override
  Widget build(BuildContext context) {
    // [사용자 요청] "부적 만들기" 카드처럼 아이콘 + 버튼만 남기고 카운트/미리보기/
    // 보조버튼(최신 소원보기)은 제거해 좌우 2열 카드의 시각적 균형을 맞춘다.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.hcCardBg,
        borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
        border: Border.all(color: AppColors.hcBorderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.hcCardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [사용자 요청] "부적만들기 소원게시판 운세메뉴을 오늘에 운세보기 폰트의
          // 크기로 줄여주고" — 제목 폰트 크기를 "오늘의 운세 보기" 버튼과 동일한
          // 13px/w700으로 축소.
          const Text(
            '🌙 소원게시판',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.hcTextDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.hcGoldGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: const Icon(
                  Icons.nights_stay_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // [사용자 요청] "밑에부적만들기 소원게시판 까만박스도 좀더 가늘게" — 버튼
          // 높이를 40→32로 줄이고 세로 패딩도 축소해 더 슬림하게 만든다.
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                textStyle: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityScreen()),
              ),
              child: const Text('소원 작성하기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// [웹→앱 이식] 신통방통 index.html "소원방(Wish Room)" 진입 배너
/// 다크 브라운 그라디언트 배경의 가로 배너, 우측에 화살표 아이콘.
class _WishRoomBanner extends StatelessWidget {
  const _WishRoomBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '소원방 입장하기',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CommunityScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.hcWishRoomGradient,
            borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🏮', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '소원방(Wish Room) 입장하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    // [사용자 요청] "소원방 입장하기밑에 글씨 조금 더 줄여서 한줄로
                    // 나오게 해주세요" — 폰트를 10px로 축소하고 한 줄에 들어가도록
                    // maxLines/overflow를 지정한다.
                    Text(
                      '함께 소원 빌고 응원해요',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [운세 앱 개발 프롬프트-메인 UI 리뉴얼] "운세 메뉴" 섹션 헤더
class _FortuneMenuSectionHeader extends StatelessWidget {
  const _FortuneMenuSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '✨ 운세 메뉴',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.hcTextDark,
      ),
    );
  }
}

/// [운세 앱 개발 프롬프트-메인 UI 리뉴얼] "운세 메뉴" 2열 그리드(신통방통 스크린샷 재현)
/// 각 카드는 아이콘(원형 배경) + 라벨 + 설명 텍스트를 중앙 정렬로 배치.
class _FortuneMenuGrid extends StatelessWidget {
  const _FortuneMenuGrid();

  static const _items = [
    (
      'daily',
      AppIcons.fortuneDaily,
      '오늘의 운세',
      '매일 새로운 종합운',
      '/home/daily-fortune-detail',
      true,
    ),
    (
      'saju',
      AppIcons.saju,
      '사주',
      '타고난 인생의 지도',
      '/ai-fortune/saju/input',
      true,
    ),
    (
      'tarot',
      AppIcons.tarot,
      '타로점',
      '78장의 카드가 전하는 메시지',
      '/ai-fortune/tarot/question',
      true,
    ),
    (
      'compatibility',
      AppIcons.compatibility,
      '궁합',
      '두 사람의 인연',
      '/ai-fortune/compatibility/input',
      true,
    ),
    ('zodiac', Icons.star_rounded, '별자리', '12별자리 운세', '', true),
    (
      'palm',
      AppIcons.palm,
      '손금',
      '손바닥 속 인생 지도',
      '/ai-fortune/palm/capture',
      false,
    ),
    (
      'face',
      AppIcons.face,
      '관상',
      '얼굴에 담긴 운명',
      '/ai-fortune/face/capture',
      false,
    ),
    ('yearly', Icons.pets_rounded, '띠별운세', '12간지 운세', '', false),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final (key, icon, label, desc, route, popular) = _items[index];
        final iconColor =
            AppColors.hcCategoryIconColor[key] ?? AppColors.hcGoldDark;

        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
          splashColor: AppColors.hcCream,
          highlightColor: AppColors.hcCream,
          onTap: () {
            if (route.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label은 준비 중이에요. 곧 만나보실 수 있어요!')),
              );
            } else {
              Navigator.of(context).pushNamed(route);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.hcCardBg2,
              borderRadius: BorderRadius.circular(AppRadius.hcCardMenu),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (popular)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.hcCream,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Text(
                        '인기',
                        style: TextStyle(
                          color: AppColors.hcAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(height: 10),
                    // [사용자 요청] "부적만들기 소원게시판 운세메뉴을 오늘에 운세보기
                    // 폰트의 크기로 줄여주고" — "오늘의 운세 보기" 버튼과 동일한 13px로 축소.
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.hcTextDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        desc,
                        textAlign: TextAlign.center,
                        // [사용자 요청] "밑에 소원방 운세메뉴도 오늘에운세보게 촌트 굵기로
                        // 적용한다" — "오늘의 운세 보기" 버튼과 동일한 w700 굵기로 통일.
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hcTextSecondary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
