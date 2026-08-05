import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_badge.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../pass/presentation/pass_time_format.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 운세 허브 화면 (v2)
///
/// 기준 시안(홈 화면)의 "전체운세/사주/궁합/손금" 칩 구조 + 큰 라운드 카드를
/// 운세 탭 전체로 확장한다. 상단에 대표 히어로 카드(오늘의 운세 안내) +
/// 칩형 카테고리 필터 + 카테고리별 카드 리스트로 구성해 메인 화면과 같은
/// 세계관으로 보이게 만든다.
///
/// [주의] 진입 게이트체크 로직(navigateWithPassGate)과 PassProvider는 기존
/// 그대로 재사용한다 — 이번 작업은 디자인/레이아웃 정리이며 기능은 무변경.
class FortuneHubScreen extends StatefulWidget {
  const FortuneHubScreen({super.key});

  @override
  State<FortuneHubScreen> createState() => _FortuneHubScreenState();
}

class _FortuneHubScreenState extends State<FortuneHubScreen> {
  bool _checking = false;
  String _filter = '전체';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // [프리패스 테스트 인프라] §7/§13 — AccessChecker.openPassState가 expiresAt
    // 기준으로 실시간 재계산하므로, 1초마다 rebuild만 트리거하면 만료 순간
    // 자동으로 배지/히어로 카드가 잠금 상태로 전환된다(자동 재잠금).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static const _filters = ['전체', '무료', '사주', '타로', '손금'];

  static const _items = [
    (
      '오늘의 운세',
      '매일 새로운 종합운을 확인해보세요',
      Icons.wb_sunny_outlined,
      '무료',
      '/home/daily-fortune-detail',
      false,
      '전체',
    ),
    (
      '사주',
      'AI가 분석하는 나의 사주 명식',
      Icons.auto_stories_outlined,
      '프리패스',
      '/ai-fortune/saju/input',
      true,
      '사주',
    ),
    (
      '타로',
      '78장의 카드가 전하는 오늘의 메시지',
      Icons.style_outlined,
      '프리패스',
      // [타로 섹션 전면 개편 §2] 운세 허브의 타로 카드도 신규 타로 메인
      // 홈(①)으로 진입점을 변경한다.
      '/tarot/home',
      true,
      '타로',
    ),
    (
      '관상',
      '사진으로 보는 AI 관상 분석',
      Icons.face_outlined,
      '프리패스',
      '/ai-fortune/face/capture',
      true,
      '전체',
    ),
    (
      '손금',
      '손바닥 속에 숨겨진 나의 운명',
      Icons.back_hand_outlined,
      '프리패스',
      '/ai-fortune/palm/capture',
      true,
      '손금',
    ),
    // [남은 미세조정] 이름 운세(성명학) — AllCategoriesScreen(전체보기)에는
    // 이미 admin 데이터로 연결되어 있었으나, 이 허브(운세 탭)의 정적
    // 목록에는 빠져 있어 추가한다. 전용 필터 칩이 없으므로 관상/AI상담과
    // 동일하게 '전체' 필터에서만 노출되는 항목으로 둔다.
    (
      '이름 운세',
      '이름에 담긴 기운을 성명학으로 해석해요',
      Icons.badge_outlined,
      '프리패스',
      '/ai-fortune/name/input',
      true,
      '전체',
    ),
    (
      'AI 상담',
      '실시간 AI 운세 상담사와 대화하기',
      Icons.chat_bubble_outline_rounded,
      '프리패스',
      '/ai-fortune/consultation/type',
      true,
      '전체',
    ),
  ];

  Future<void> _handleTap({
    required String title,
    required String route,
    required bool requiresPass,
  }) async {
    if (requiresPass) setState(() => _checking = true);
    await navigateWithPassGate(
      context,
      title: title,
      route: route,
      requiresPass: requiresPass,
    );
    if (mounted && requiresPass) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final passState = access.openPassState;
    final isPassActive = passState.isActive;
    final filtered = _filter == '전체'
        ? _items
        : _filter == '무료'
        ? _items.where((e) => !e.$6).toList()
        : _items.where((e) => e.$7 == _filter).toList();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceMd,
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceXxl,
          ),
          children: [
            Text('운세', style: UnifiedText.titleLarge()),
            const SizedBox(height: 4),
            Text('오늘 당신의 운명은 어떤 이야기를 담고 있을까요?', style: UnifiedText.body()),
            const SizedBox(height: UnifiedTokens.spaceXl),

            // 열림패스 상태 히어로 카드 - 기준 시안의 "오늘의 운세 이야기" 카드 톤 재사용.
            FadeSlideIn(
              child: _PassHeroCard(
                isActive: isPassActive,
                remainingSec: passState.remaining.inSeconds,
                isBusy: _checking,
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // 카테고리 칩 필터
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: UnifiedTokens.spaceSm),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  return PremiumChip(
                    label: f,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                    activeBg: UnifiedColors.neon,
                    activeFg: UnifiedColors.black,
                    inactiveBg: UnifiedColors.chipInactiveBg,
                    inactiveFg: UnifiedColors.textSecondary,
                    labelStyle: UnifiedText.chipLabel(),
                  );
                },
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXl),

            ...List.generate(filtered.length, (index) {
              final (title, desc, icon, cost, route, requiresPass, _) =
                  filtered[index];
              final isFree = !requiresPass;
              final badgeLabel = isFree ? '무료' : (isPassActive ? '이용가능' : cost);
              final badgeType = isFree || isPassActive
                  ? PremiumBadgeType.done
                  : PremiumBadgeType.pass;

              return Padding(
                padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 40 * index),
                  child: _FortuneCategoryCard(
                    title: title,
                    desc: desc,
                    icon: icon,
                    badgeLabel: badgeLabel,
                    badgeType: badgeType,
                    onTap: _checking
                        ? null
                        : () => _handleTap(
                            title: title,
                            route: route,
                            requiresPass: requiresPass,
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 열림패스 상태를 알리는 히어로 카드 - 연라벤더 그라디언트 + 은은한 그래픽.
class _PassHeroCard extends StatelessWidget {
  const _PassHeroCard({
    required this.isActive,
    required this.remainingSec,
    required this.isBusy,
  });

  final bool isActive;
  final int remainingSec;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    // [프리패스 단순화 - 쿠팡파트너스 전용] §6 — HH:MM:SS 형식으로 통일.
    final timeLabel = '${formatPassHms(Duration(seconds: remainingSec))} 남음';

    return PremiumCard(
      backgroundColor: UnifiedColors.cardMain,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textPrimary,
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text(
                isBusy
                    ? '프리패스 확인 중...'
                    : isActive
                    ? '프리패스 활성중 · $timeLabel'
                    : '프리패스가 없어요',
                style: UnifiedText.title(),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceXs),
          Text(
            isActive
                ? '지금 모든 운세 카테고리를 자유롭게 열람할 수 있어요'
                : '카테고리 진입 시 발급 방법을 안내해드려요',
            style: UnifiedText.caption(),
          ),
        ],
      ),
    );
  }
}

/// 운세 카테고리 카드 - 큰 라운드 카드 + 좌측 정렬 텍스트 + 우측 배지.
class _FortuneCategoryCard extends StatelessWidget {
  const _FortuneCategoryCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.badgeLabel,
    required this.badgeType,
    required this.onTap,
  });

  final String title;
  final String desc;
  final IconData icon;
  final String badgeLabel;
  final PremiumBadgeType badgeType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleLg,
            height: UnifiedTokens.iconCircleLg,
            decoration: BoxDecoration(
              color: UnifiedColors.bg,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              icon,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: UnifiedText.bodyStrong()),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UnifiedText.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          PremiumBadge(label: badgeLabel, type: badgeType),
        ],
      ),
    );
  }
}
