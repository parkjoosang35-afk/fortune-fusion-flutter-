import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_badge.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../community/presentation/community_screen.dart';
import '../../community/presentation/community_hub_screen.dart';
import '../../community/presentation/widgets/wish_hall_of_fame_sheet.dart';

/// [전체보기 카테고리 허브] Fortune Fusion(신통방통) 앱 전체 카테고리를 한 화면에서
/// 파악·탐색할 수 있게 만드는 허브 페이지.
///
/// 점신류 앱의 "카테고리 풍부함"을 벤치마킹하되 그대로 베끼지 않고, 우리 서비스
/// 구조(열림패스/행복머니/부적/소원게시판·소원방/AI상담/커뮤니티)에 맞춰 재구성한다.
/// 화면 순서: ①헤더 ②오늘 추천 ③대표카테고리4개 ④전체 8개 그룹 ⑤빠른진입
/// ⑥열림패스 상태 ⑦하단 연결 CTA.
///
/// [주의] 이 페이지는 Presentation 레이어 신규 화면이며, 기존 Provider(Pass/Wallet)
/// 와 공용 위젯(PremiumCard/PremiumButton/PremiumChip 등), 공용 헬퍼
/// (navigateWithPassGate/showPassRequiredSheet/showWishHallOfFameSheet)를 그대로
/// 재사용한다. 상세 결과 화면/커뮤니티 상세 화면은 이번 작업 범위에서 손대지 않는다.
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassProvider>().load();
      context.read<WalletProvider>().load();
    });
  }

  /// 카테고리(대표4개/그룹칩/빠른진입) 공통 진입 핸들러.
  /// - route가 null이면 아직 상세 화면이 없는 카테고리 → "준비중" 안내만 표시.
  /// - route가 있으면 기존 [navigateWithPassGate]로 열림패스 게이트체크 후 이동.
  Future<void> _open(
    BuildContext context, {
    required String label,
    String? route,
    bool requiresPass = false,
  }) async {
    if (route == null) {
      AppToast.show(context, '$label · 준비 중이에요! 곧 만나볼 수 있어요 🙏');
      return;
    }
    if (requiresPass) setState(() => _checking = true);
    await navigateWithPassGate(
      context,
      title: label,
      route: route,
      requiresPass: requiresPass,
    );
    if (mounted && requiresPass) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.spaceXl,
            UnifiedTokens.spaceMd,
            UnifiedTokens.spaceXl,
            UnifiedTokens.spaceXxl,
          ),
          children: [
            _Header(balance: wallet.balance),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              child: _TrendingRow(
                onTap: (label, route, pass) => _open(
                  context,
                  label: label,
                  route: route,
                  requiresPass: pass,
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: const PremiumSectionTitleLite(
                title: '대표 카테고리',
                subtitle: '오늘 가장 먼저 확인해볼 4가지',
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _FeaturedGrid(
                pass: pass,
                busy: _checking,
                onTap: (label, route, requiresPass) => _open(
                  context,
                  label: label,
                  route: route,
                  requiresPass: requiresPass,
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: const PremiumSectionTitleLite(
                title: '전체 카테고리',
                subtitle: '당신에게 맞는 해석을 골라보세요',
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            ...List.generate(_categoryGroups.length, (index) {
              final group = _categoryGroups[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 40 * index),
                  child: _CategoryGroupCard(
                    group: group,
                    onTapItem: (label, route, requiresPass) => _open(
                      context,
                      label: label,
                      route: route,
                      requiresPass: requiresPass,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: UnifiedTokens.spaceSm),

            FadeSlideIn(
              child: const PremiumSectionTitleLite(
                title: '지금 많이 찾는 기능',
                subtitle: '운세 그 이상, 마음을 나누는 순간들',
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: const _QuickEntryRow(),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(child: _PassStatusStrip(pass: pass)),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: const _BottomConnectRow(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ① 상단 헤더 - 뒤로가기 + 타이틀/보조카피 + 행복머니 소형 상태 표시.
///
/// [행복머니 노출 정책] 이 페이지의 주인공은 운세 카테고리 탐색이므로, 행복머니는
/// 숫자를 크게 강조하지 않고 상단의 아주 작은 보조 pill로만 노출한다(탭하면
/// 지갑 화면으로 연결). 적립/구매 구조는 지갑 화면에서 다룬다.
class _Header extends StatelessWidget {
  const _Header({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UnifiedColors.cardAllMenu,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('전체보기', style: UnifiedText.titleLarge()),
              const SizedBox(height: 4),
              Text('오늘 필요한 운세와 해석을 한 번에 만나보세요', style: UnifiedText.body()),
            ],
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceSm),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: UnifiedColors.cardAllMenu,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: UnifiedTokens.iconSm,
                  color: UnifiedColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text('$balance', style: UnifiedText.chipLabel()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 섹션 타이틀 + 보조 카피 1줄(감성 톤 유지) - 이 화면 전용 라이트 버전.
/// 기존 [PremiumSectionTitle]은 "제목+우측 액션"용이라, 이 화면처럼 제목 아래
/// 감성 서브카피가 필요한 곳엔 별도의 얇은 위젯으로 통일해 재사용한다.
class PremiumSectionTitleLite extends StatelessWidget {
  const PremiumSectionTitleLite({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: UnifiedText.title()),
        const SizedBox(height: 3),
        Text(subtitle, style: UnifiedText.caption()),
      ],
    );
  }
}

/// ② 오늘 추천 / 인기 카테고리 - 가로 스크롤 미니 칩. 대표카테고리(큰 카드)보다
/// 가볍게, "지금 많이 보는" 느낌만 전달하는 보조 진입 스트립.
class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.onTap});

  final void Function(String label, String? route, bool requiresPass) onTap;

  static const _items = [
    (Icons.wb_sunny_outlined, '오늘의 운세', '/home/daily-fortune-detail', false),
    (Icons.style_outlined, '타로', '/ai-fortune/tarot/question', true),
    (
      Icons.chat_bubble_outline_rounded,
      'AI 상담',
      '/ai-fortune/consultation/type',
      true,
    ),
    (Icons.shield_outlined, '부적 만들기', '/reward/amulet/generate', false),
    (
      Icons.favorite_outline_rounded,
      '궁합',
      '/ai-fortune/compatibility/input',
      true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: UnifiedTokens.spaceSm),
        itemBuilder: (context, i) {
          final (icon, label, route, requiresPass) = _items[i];
          return PremiumChip(
            label: label,
            icon: icon,
            selected: false,
            onTap: () => onTap(label, route, requiresPass),
            inactiveBg: UnifiedColors.chipInactiveBg,
            inactiveFg: UnifiedColors.textSecondary,
            labelStyle: UnifiedText.chipLabel(),
          );
        },
      ),
    );
  }
}

/// ③ 대표 카테고리 4개(오늘의 운세/정통사주/궁합/타로) - 2x2 큰 카드 그리드.
/// 그룹 칩보다 훨씬 크게 보여, "가장 먼저 눌러볼 카테고리"임을 시각적으로 강조한다.
class _FeaturedGrid extends StatelessWidget {
  const _FeaturedGrid({
    required this.pass,
    required this.busy,
    required this.onTap,
  });

  final PassProvider pass;
  final bool busy;
  final void Function(String label, String route, bool requiresPass) onTap;

  static const _items = [
    (
      '오늘의 운세',
      '오늘 하루의 흐름과 행운 포인트',
      Icons.wb_sunny_outlined,
      '/home/daily-fortune-detail',
      false,
    ),
    (
      '정통사주',
      '타고난 기운과 인생의 방향',
      Icons.auto_stories_outlined,
      '/ai-fortune/saju/input',
      true,
    ),
    (
      '궁합',
      '나와 상대의 감정과 관계 흐름',
      Icons.favorite_outline_rounded,
      '/ai-fortune/compatibility/input',
      true,
    ),
    (
      '타로',
      '지금 마음과 선택의 해석',
      Icons.style_outlined,
      '/ai-fortune/tarot/question',
      true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: UnifiedTokens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: UnifiedTokens.spaceSm),
                Expanded(
                  child: _FeaturedCard(
                    item: _items[row * 2 + col],
                    pass: pass,
                    busy: busy,
                    onTap: onTap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.item,
    required this.pass,
    required this.busy,
    required this.onTap,
  });

  final (String, String, IconData, String, bool) item;
  final PassProvider pass;
  final bool busy;
  final void Function(String label, String route, bool requiresPass) onTap;

  @override
  Widget build(BuildContext context) {
    final (title, desc, icon, route, requiresPass) = item;
    final isFree = !requiresPass;
    final badgeLabel = isFree ? '무료' : (pass.isActive ? '이용가능' : '열림패스');
    final badgeType = isFree || pass.isActive
        ? PremiumBadgeType.done
        : PremiumBadgeType.pass;

    return SizedBox(
      height: 138,
      child: PremiumCard(
        backgroundColor: UnifiedColors.cardAllMenu,
        borderColor: Colors.transparent,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        showShadow: false,
        padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
        onTap: busy ? null : () => onTap(title, route, requiresPass),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: UnifiedTokens.iconCircleLg,
                  height: UnifiedTokens.iconCircleLg,
                  alignment: Alignment.center,
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
                const Spacer(),
                PremiumBadge(label: badgeLabel, type: badgeType),
              ],
            ),
            const Spacer(),
            Text(title, style: UnifiedText.title()),
            const SizedBox(height: 3),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: UnifiedText.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ④ 전체 카테고리 8개 그룹의 데이터 정의.
/// route가 null인 하위 항목은 아직 상세 화면이 없는 카테고리 → 탭 시 "준비중" 안내.
/// requiresPass가 true인 항목은 [navigateWithPassGate]로 열림패스 게이트를 거친다.
const List<
  ({
    IconData icon,
    String title,
    String desc,
    List<({String label, String? route, bool pass})> items,
  })
>
_categoryGroups = [
  (
    icon: Icons.wb_sunny_outlined,
    title: '오늘/기간 운세',
    desc: '오늘 하루부터 신년까지, 흐름을 확인해보세요',
    items: [
      (label: '오늘의 운세', route: '/home/daily-fortune-detail', pass: false),
      (label: '시간대별 운세', route: null, pass: false),
      (label: '내일 운세', route: null, pass: false),
      (label: '주간 운세', route: null, pass: false),
      (label: '월간 운세', route: null, pass: false),
      (label: '신년운세', route: null, pass: false),
    ],
  ),
  (
    icon: Icons.auto_stories_outlined,
    title: '사주',
    desc: '타고난 기운과 흐름을 깊게 해석해보세요',
    items: [
      (label: '정통사주', route: '/ai-fortune/saju/input', pass: true),
      (label: '오늘의 사주', route: '/ai-fortune/saju/input', pass: true),
      (label: '만세력', route: null, pass: false),
      (label: '오행 흐름', route: null, pass: false),
      (label: '대운/세운', route: null, pass: false),
    ],
  ),
  (
    icon: Icons.favorite_outline_rounded,
    title: '궁합',
    desc: '나와 상대, 서로의 마음을 확인해보세요',
    items: [
      (label: '정통궁합', route: '/ai-fortune/compatibility/input', pass: true),
      (label: '연애궁합', route: '/ai-fortune/compatibility/input', pass: true),
      (label: '썸궁합', route: null, pass: false),
      (label: '인맥궁합', route: null, pass: false),
    ],
  ),
  (
    icon: Icons.style_outlined,
    title: '타로',
    desc: '지금 마음이 궁금할 때, 카드에게 물어보세요',
    items: [
      (label: '오늘의 타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '연애타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '재물타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '선택타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '속마음 타로', route: '/ai-fortune/tarot/question', pass: true),
    ],
  ),
  (
    icon: Icons.face_outlined,
    title: '얼굴/손금',
    desc: '얼굴과 손에 담긴 이야기를 읽어보세요',
    items: [
      (label: '오늘의 관상', route: '/ai-fortune/face/capture', pass: true),
      (label: '손금', route: '/ai-fortune/palm/capture', pass: true),
      (label: '성향 해석', route: null, pass: false),
    ],
  ),
  (
    icon: Icons.nights_stay_outlined,
    title: '테마 운세',
    desc: '가볍게 즐기는 오늘의 재미 운세',
    items: [
      (label: '별자리 운세', route: null, pass: false),
      (label: '혈액형 운세', route: null, pass: false),
      (label: '꿈해몽', route: null, pass: false),
      (label: '포춘쿠키', route: null, pass: false),
      (label: '능력평가', route: null, pass: false),
    ],
  ),
  (
    icon: Icons.auto_awesome_outlined,
    title: '행운/정화',
    desc: '나를 지키고 채워주는 행운 아이템',
    items: [
      (label: '행운의 번호', route: null, pass: false),
      (label: '행운의 부적', route: '/reward/amulet', pass: false),
      (label: '살풀이', route: null, pass: false),
      (label: '부적 만들기', route: '/reward/amulet/generate', pass: false),
    ],
  ),
  (
    icon: Icons.chat_bubble_outline_rounded,
    title: '상담/해석',
    desc: '혼자 고민하지 말고 함께 이야기해요',
    items: [
      (label: 'AI 상담', route: '/ai-fortune/consultation/type', pass: true),
      (label: '고민상담', route: '/ai-fortune/consultation/type', pass: true),
      (label: '전문가 상담(오픈 예정)', route: null, pass: false),
    ],
  ),
];

/// 그룹 1개를 카드로 렌더링 - 제목/설명 + 하위 카테고리 미니 칩(Wrap).
class _CategoryGroupCard extends StatelessWidget {
  const _CategoryGroupCard({required this.group, required this.onTapItem});

  final ({
    IconData icon,
    String title,
    String desc,
    List<({String label, String? route, bool pass})> items,
  })
  group;
  final void Function(String label, String? route, bool requiresPass) onTapItem;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                group.icon,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(group.title, style: UnifiedText.title()),
            ],
          ),
          const SizedBox(height: 3),
          Text(group.desc, style: UnifiedText.caption()),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.items
                .map(
                  (item) => _SubCategoryChip(
                    label: item.label,
                    isReady: item.route != null,
                    onTap: () => onTapItem(item.label, item.route, item.pass),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 그룹 내부 하위 카테고리 미니 칩 - 상세 화면이 없는 항목은 살짝 옅게 표시해
/// "곧 만나볼 카테고리"임을 은은하게 구분한다(그래도 탭은 가능 - 준비중 안내).
class _SubCategoryChip extends StatelessWidget {
  const _SubCategoryChip({
    required this.label,
    required this.isReady,
    required this.onTap,
  });

  final String label;
  final bool isReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isReady ? UnifiedColors.bg : UnifiedColors.chipInactiveBg,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
          border: Border.all(color: Colors.transparent),
        ),
        child: Text(
          label,
          style: UnifiedText.chipLabel(
            color: isReady
                ? UnifiedColors.textPrimary
                : UnifiedColors.textCaption,
          ),
        ),
      ),
    );
  }
}

/// ⑤ 빠른 진입 기능 섹션 - AI상담/부적만들기/행운의번호/소원게시판/소원방.
/// 우리 서비스 고유 감성 기능·커뮤니티로 이어주는 짧은 CTA 카드 5개.
class _QuickEntryRow extends StatelessWidget {
  const _QuickEntryRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) =>
            const SizedBox(width: UnifiedTokens.spaceSm),
        itemBuilder: (context, i) {
          switch (i) {
            case 0:
              return _QuickEntryCard(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'AI 상담',
                onTap: () async {
                  final pass = context.read<PassProvider>();
                  if (pass.isActive) {
                    Navigator.of(
                      context,
                    ).pushNamed('/ai-fortune/consultation/type');
                  } else {
                    await navigateWithPassGate(
                      context,
                      title: 'AI 상담',
                      route: '/ai-fortune/consultation/type',
                      requiresPass: true,
                    );
                  }
                },
              );
            case 1:
              return _QuickEntryCard(
                icon: Icons.shield_outlined,
                label: '부적 만들기',
                onTap: () =>
                    Navigator.of(context).pushNamed('/reward/amulet/generate'),
              );
            case 2:
              return _QuickEntryCard(
                icon: Icons.auto_awesome_outlined,
                label: '행운의 번호',
                onTap: () =>
                    AppToast.show(context, '오늘의 행운숫자는 홈 화면에서 곧 만나볼 수 있어요 ✨'),
              );
            case 3:
              return _QuickEntryCard(
                icon: Icons.star_border_rounded,
                label: '소원게시판',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                ),
              );
            default:
              return _QuickEntryCard(
                icon: Icons.nights_stay_outlined,
                label: '소원방',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                ),
              );
          }
        },
      ),
    );
  }
}

class _QuickEntryCard extends StatelessWidget {
  const _QuickEntryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: PremiumCard(
        backgroundColor: UnifiedColors.cardAllMenu,
        borderColor: Colors.transparent,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        showShadow: false,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: UnifiedText.chipLabel(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⑥ 열림패스 상태 영역 - 이 페이지의 주인공이 아닌 "카테고리 탐색을 돕는 보조
/// 구조"로만 취급한다.
/// - 비활성: 옅은 안내 배너 + "광고 보고 열기" 버튼(기존 [showPassRequiredSheet] 재사용)
/// - 활성: 홍보 문구를 완전히 숨기고 "남은 시간"만 깔끔하게 표시
class _PassStatusStrip extends StatelessWidget {
  const _PassStatusStrip({required this.pass});

  final PassProvider pass;

  @override
  Widget build(BuildContext context) {
    if (pass.isActive) {
      final sec = pass.status.remainingSec;
      final h = sec ~/ 3600;
      final m = (sec % 3600) ~/ 60;
      final timeLabel = h > 0 ? '$h시간 $m분 남음' : '$m분 남음';

      return PremiumCard(
        backgroundColor: UnifiedColors.passBar,
        borderColor: Colors.transparent,
        showShadow: false,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              Icons.lock_open_rounded,
              size: UnifiedTokens.iconMd,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '열림패스 이용 중',
                style: UnifiedText.bodyStrong(color: Colors.white),
              ),
            ),
            Text(
              timeLabel,
              style: UnifiedText.chipLabel(color: UnifiedColors.neon),
            ),
          ],
        ),
      );
    }

    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('열림패스로 더 많은 운세 보기', style: UnifiedText.bodyStrong()),
                const SizedBox(height: 3),
                Text('광고 보고 전체 운세 열기', style: UnifiedText.caption()),
              ],
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          SizedBox(
            width: 96,
            child: PremiumButton.secondary(
              label: '열어보기',
              height: 36,
              onPressed: () =>
                  showPassRequiredSheet(context, categoryTitle: '전체 운세'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⑦ 하단 연결 CTA - 커뮤니티 가기 / 후기 보기 / 고민상담 보기.
/// 전체보기가 "운세 메뉴판"에서 끝나지 않고 커뮤니티·감성 기능까지 이어지도록
/// 마지막에 가볍게 3개의 연결 지점을 배치한다.
class _BottomConnectRow extends StatelessWidget {
  const _BottomConnectRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ConnectTile(
            icon: Icons.forum_rounded,
            label: '커뮤니티 가기',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
            ),
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceSm),
        Expanded(
          child: _ConnectTile(
            icon: Icons.emoji_events_rounded,
            label: '후기 보기',
            onTap: () => showWishHallOfFameSheet(context),
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceSm),
        Expanded(
          child: _ConnectTile(
            icon: Icons.chat_bubble_rounded,
            label: '고민상담 보기',
            onTap: () => Navigator.of(
              context,
            ).pushNamed('/ai-fortune/consultation/type'),
          ),
        ),
      ],
    );
  }
}

class _ConnectTile extends StatelessWidget {
  const _ConnectTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: UnifiedColors.cardAllMenu,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: UnifiedText.chipLabel(),
            ),
          ],
        ),
      ),
    );
  }
}
