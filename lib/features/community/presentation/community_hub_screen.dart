import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_badge.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../application/wish_post_provider.dart';
import '../domain/wish_post_model.dart';
import 'community_screen.dart';
import 'community_board_list_screen.dart';
import 'widgets/wish_hall_of_fame_sheet.dart';
import '../../ranking/presentation/ranking_screen.dart';
import '../../consultation/presentation/consultation_type_screen.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 커뮤니티 허브 화면 (v2)
///
/// 8개 서브탭(소원/자유/후기/고민상담/궁합이야기/부적/동행/랭킹)을 기존 구조
/// 그대로 유지하되, 상단 탭바를 칩형 필터로 교체하고 전체를 화이트 프리미엄
/// 카드형 톤으로 통일한다. 정보량이 많아도 카드 분할로 산만하지 않게 정리.
///
/// [주의] 각 서브탭의 실제 기능(WishPostProvider, 게시판, 명예의 전당, 상담,
/// 궁합, 부적샵, 매칭, 랭킹)은 기존 화면/Provider를 그대로 재사용한다.
class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  int _tabIndex = 0;

  static const _tabLabels = [
    '소원',
    '자유',
    '후기',
    '고민상담',
    '궁합이야기',
    '부적',
    '동행',
    '랭킹',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishPostProvider>().loadFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UnifiedTokens.screenPadding,
                UnifiedTokens.spaceMd,
                UnifiedTokens.screenPadding,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('커뮤니티', style: UnifiedText.titleLarge()),
                        const SizedBox(height: 4),
                        Text('오늘의 소원과 이야기를 나눠보세요', style: UnifiedText.body()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.screenPadding,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _tabLabels.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: UnifiedTokens.spaceSm),
                itemBuilder: (context, i) => PremiumChip(
                  label: _tabLabels[i],
                  selected: _tabIndex == i,
                  onTap: () => setState(() => _tabIndex = i),
                  activeBg: UnifiedColors.neon,
                  activeFg: UnifiedColors.black,
                  inactiveBg: UnifiedColors.chipInactiveBg,
                  inactiveFg: UnifiedColors.textSecondary,
                  labelStyle: UnifiedText.chipLabel(),
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: const [
                  _WishTab(),
                  _ShortcutTab(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: '자유게시판',
                    description: '자유롭게 이야기를 나눠보세요',
                    buttonLabel: '게시판 바로가기',
                    destination: CommunityBoardListScreen(),
                    hint: '글쓰기 · 댓글 작성 시 복주머니 적립',
                  ),
                  _ShortcutTab(
                    icon: Icons.star_border_rounded,
                    title: '후기',
                    description: '소원을 이룬 사람들의 진짜 이야기를 만나보세요',
                    buttonLabel: '명예의 전당 보기',
                    hint: '이룬 소원 인증 · 응원 누적 랭킹',
                  ),
                  _ShortcutTab(
                    icon: Icons.self_improvement_outlined,
                    title: '고민상담',
                    description: '사주·타로 상담사와 편하게 이야기해보세요',
                    buttonLabel: '상담 시작하기',
                    destination: ConsultationTypeScreen(),
                    hint: '상담 메시지 전송 시 복주머니 소비',
                  ),
                  _ShortcutTab(
                    icon: Icons.emoji_events_outlined,
                    title: '랭킹',
                    description: '이번 주 복주머니 랭킹 TOP 유저 확인하기',
                    buttonLabel: '랭킹 바로가기',
                    destination: RankingScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "소원" 탭 - 홈과 톤을 맞춘 카드 리스트로 WishPostProvider 피드를 직접 노출.
class _WishTab extends StatelessWidget {
  const _WishTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();
    final posts = provider.posts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.screenPadding,
            0,
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceMd,
          ),
          child: FadeSlideIn(
            child: PremiumCard(
              backgroundColor: UnifiedColors.cardWish,
              borderColor: Colors.transparent,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityScreen()),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('소원게시판', style: UnifiedText.bodyStrong()),
                        const SizedBox(height: 2),
                        Text(
                          '전체 소원 보기 · 나도 소원 남기기',
                          style: UnifiedText.caption(),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: UnifiedTokens.iconSm,
                    color: UnifiedColors.textCaption,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: provider.isLoading && posts.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: UnifiedColors.black),
                )
              : posts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.screenPadding,
                  ),
                  child: const PremiumEmptyState(
                    icon: Icons.nights_stay_outlined,
                    title: '아직 등록된 소원이 없어요',
                    subtitle: '첫 번째 소원을 남겨보세요',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    UnifiedTokens.screenPadding,
                    0,
                    UnifiedTokens.screenPadding,
                    UnifiedTokens.screenPadding,
                  ),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: UnifiedTokens.spaceMd),
                  itemBuilder: (context, index) => FadeSlideIn(
                    delay: Duration(milliseconds: 30 * index),
                    child: _WishCard(post: posts[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({required this.post});

  final WishPostModel post;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => Navigator.of(
        context,
      ).pushNamed('/community/wish/detail', arguments: post),
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumBadge(label: post.category, type: PremiumBadgeType.pass),
              const Spacer(),
              Text(
                post.isAnonymous ? '익명' : post.authorNickname,
                style: UnifiedText.caption(),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            post.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: UnifiedText.body(color: UnifiedColors.textPrimary),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: UnifiedTokens.iconSm,
                color: UnifiedColors.textCaption,
              ),
              const SizedBox(width: 4),
              Text('${post.supportCount}', style: UnifiedText.caption()),
              const SizedBox(width: UnifiedTokens.spaceMd),
              Icon(
                Icons.mode_comment_outlined,
                size: UnifiedTokens.iconSm,
                color: UnifiedColors.textCaption,
              ),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: UnifiedText.caption()),
            ],
          ),
        ],
      ),
    );
  }
}

/// 자유/후기/고민상담/궁합이야기/부적/동행/랭킹 탭 공통 - 기존 완성 화면(또는
/// 바텀시트)으로 진입하는 바로가기 카드. 큰 라운드 카드 + 감성 그래픽 +
/// 블랙 CTA 버튼으로 기준 시안 톤을 유지한다.
class _ShortcutTab extends StatelessWidget {
  const _ShortcutTab({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.destination,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Widget? destination;
  final String? hint;

  void _handleTap(BuildContext context) {
    if (destination == null) {
      showWishHallOfFameSheet(context);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination!));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.screenPadding,
      ),
      child: FadeSlideIn(
        child: PremiumCard(
          backgroundColor: UnifiedColors.cardAllMenu,
          borderColor: Colors.transparent,
          showShadow: false,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: UnifiedTokens.spaceMd),
              Text(title, style: UnifiedText.title()),
              const SizedBox(height: UnifiedTokens.spaceXs),
              Text(description, style: UnifiedText.body()),
              if (hint != null) ...[
                const SizedBox(height: UnifiedTokens.spaceSm),
                PremiumBadge(
                  label: hint!,
                  type: PremiumBadgeType.luckyBag,
                  emoji: '🍀',
                ),
              ],
              const SizedBox(height: UnifiedTokens.spaceLg),
              PremiumButton.black(
                label: buttonLabel,
                onPressed: () => _handleTap(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
