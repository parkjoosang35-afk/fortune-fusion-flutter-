import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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
import '../../amulet/presentation/amulet_shop_screen.dart';
import '../../matching/presentation/matching_discover_screen.dart';
import '../../ranking/presentation/ranking_screen.dart';
import '../../consultation/presentation/consultation_type_screen.dart';
import '../../compatibility/presentation/compatibility_input_screen.dart';

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
      backgroundColor: AppColors.premiumBgMain,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('커뮤니티', style: AppTypography.heroTitle),
                        const SizedBox(height: 4),
                        Text('오늘의 소원과 이야기를 나눠보세요', style: AppTypography.bodyMain),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                itemCount: _tabLabels.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) => PremiumChip(
                  label: _tabLabels[i],
                  selected: _tabIndex == i,
                  onTap: () => setState(() => _tabIndex = i),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: const [
                  _WishTab(),
                  _ShortcutTab(
                    emoji: '💬',
                    title: '자유게시판',
                    description: '자유롭게 이야기를 나눠보세요',
                    buttonLabel: '게시판 바로가기',
                    destination: CommunityBoardListScreen(),
                    hint: '글쓰기 · 댓글 작성 시 행복머니 적립',
                  ),
                  _ShortcutTab(
                    emoji: '🌟',
                    title: '후기',
                    description: '소원을 이룬 사람들의 진짜 이야기를 만나보세요',
                    buttonLabel: '명예의 전당 보기',
                    hint: '이룬 소원 인증 · 응원 누적 랭킹',
                  ),
                  _ShortcutTab(
                    emoji: '🧘',
                    title: '고민상담',
                    description: '사주·타로 상담사와 편하게 이야기해보세요',
                    buttonLabel: '상담 시작하기',
                    destination: ConsultationTypeScreen(),
                    hint: '상담 메시지 전송 시 행복머니 소비',
                  ),
                  _ShortcutTab(
                    emoji: '💞',
                    title: '궁합이야기',
                    description: '나와 그 사람, 얼마나 잘 맞을까요?',
                    buttonLabel: '궁합 보러가기',
                    destination: CompatibilityInputScreen(),
                    hint: '궁합 결과 확인 시 행복머니 소비',
                  ),
                  _ShortcutTab(
                    emoji: '🧧',
                    title: '부적',
                    description: '나를 지켜주는 디지털 부적을 만나보세요',
                    buttonLabel: '부적샵 바로가기',
                    destination: AmuletShopScreen(),
                    hint: '부적 만들기 시 행복머니 소비',
                  ),
                  _ShortcutTab(
                    emoji: '💫',
                    title: '동행',
                    description: '나와 인연이 될 사람을 찾아보세요',
                    buttonLabel: 'AI매칭 바로가기',
                    destination: MatchingDiscoverScreen(),
                    hint: '관심표시(좋아요) 시 행복머니 소비',
                  ),
                  _ShortcutTab(
                    emoji: '🏆',
                    title: '랭킹',
                    description: '이번 주 포인트 랭킹 TOP 유저 확인하기',
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
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: FadeSlideIn(
            child: PremiumCard(
              gradient: AppColors.premiumHeroGradient,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
              child: Stack(
                children: [
                  const Positioned(top: -4, right: 0, child: FloatingMoon(size: 24)),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '소원게시판',
                              style: AppTypography.cardTitle.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text('전체 소원 보기 · 나도 소원 남기기', style: AppTypography.caption),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.premiumTextTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: provider.isLoading && posts.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.premiumMainPurple,
                  ),
                )
              : posts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: const PremiumEmptyState(
                        emoji: '🌙',
                        title: '아직 등록된 소원이 없어요',
                        subtitle: '첫 번째 소원을 남겨보세요',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      itemCount: posts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumBadge(label: post.category, type: PremiumBadgeType.pass),
              const Spacer(),
              Text(
                post.isAnonymous ? '익명' : post.authorNickname,
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            post.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMain.copyWith(
              color: AppColors.premiumTextPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 13,
                color: AppColors.premiumCoralAccent,
              ),
              const SizedBox(width: 4),
              Text('${post.supportCount}', style: AppTypography.caption),
              const SizedBox(width: AppSpacing.md),
              const Icon(
                Icons.mode_comment_outlined,
                size: 13,
                color: AppColors.premiumTextTertiary,
              ),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: AppTypography.caption),
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
    required this.emoji,
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.destination,
    this.hint,
  });

  final String emoji;
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => destination!));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: FadeSlideIn(
        child: PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    const Positioned(top: 0, right: 30, child: SparkleDot(size: 9)),
                    const Positioned(right: 0, child: FloatingMoon(size: 26)),
                    Text(emoji, style: const TextStyle(fontSize: 34)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(description, style: AppTypography.bodyMain),
              if (hint != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PremiumBadge(label: hint!, type: PremiumBadgeType.luckyBag, emoji: '🍀'),
              ],
              const SizedBox(height: AppSpacing.lg),
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
