import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cosmic_card.dart';
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

/// [7단계 - 커뮤니티 탭 재화흐름 정리] CommunityHubScreen - 커뮤니티 탭
/// 8개 서브탭: 소원 / 자유 / 후기 / 고민상담 / 궁합이야기 / 부적 / 동행 / 랭킹
/// (마스터 지시 순서: 소원/자유/후기/고민상담/궁합이야기/부적/동행 + 기존 랭킹은
/// 지시 목록에 없으나 기존 기능이므로 제거하지 않고 맨 뒤에 유지)
///
/// [주의] 각 서브탭의 실제 기능(WishPostProvider, 게시판, 명예의 전당, 상담,
/// 궁합, 부적샵, 매칭, 랭킹)은 기존 화면/Provider를 그대로 재사용한다. "소원" 탭은
/// 홈 화면과 톤을 맞춘 간단한 카드 리스트로 직접 렌더링하고, 나머지 탭은 기존
/// 완성된 화면(자체 Scaffold 보유) 또는 바텀시트로 진입하는 바로가기 카드를 배치한다.
/// 각 카드에는 복주머니 적립/소비 정보를 `hint`로 노출해 재화 흐름을 명확히 보여준다.
class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishPostProvider>().loadFeed();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text(
          '커뮤니티',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.accentPurple,
          unselectedLabelColor: AppColors.cosmicTextTertiary,
          indicatorColor: AppColors.accentPurple,
          tabs: _tabLabels.map((e) => Tab(text: e)).toList(),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            const _WishTab(),
            const _ShortcutTab(
              emoji: '💬',
              title: '자유게시판',
              description: '자유롭게 이야기를 나눠보세요',
              buttonLabel: '게시판 바로가기',
              destination: CommunityBoardListScreen(),
              hint: '글쓰기 · 댓글 작성 시 복주머니 적립',
            ),
            // [7단계] "후기" - 소원성 명예의 전당 바텀시트를 그대로 재사용
            // (신규 화면을 만들지 않고 기존 바텀시트 함수를 onTap으로 호출).
            _ShortcutTab(
              emoji: '🌟',
              title: '후기',
              description: '소원을 이룬 사람들의 진짜 이야기를 만나보세요',
              buttonLabel: '명예의 전당 보기',
              onTapOverride: () => showWishHallOfFameSheet(context),
              hint: '이룬 소원 인증 · 응원 누적 랭킹',
            ),
            const _ShortcutTab(
              emoji: '🧘',
              title: '고민상담',
              description: '사주·타로 상담사와 편하게 이야기해보세요',
              buttonLabel: '상담 시작하기',
              destination: ConsultationTypeScreen(),
              hint: '상담 메시지 전송 시 복주머니 소비',
            ),
            const _ShortcutTab(
              emoji: '💞',
              title: '궁합이야기',
              description: '나와 그 사람, 얼마나 잘 맞을까요?',
              buttonLabel: '궁합 보러가기',
              destination: CompatibilityInputScreen(),
              hint: '궁합 결과 확인 시 복주머니 소비',
            ),
            const _ShortcutTab(
              emoji: '🧧',
              title: '부적',
              description: '나를 지켜주는 디지털 부적을 만나보세요',
              buttonLabel: '부적샵 바로가기',
              destination: AmuletShopScreen(),
              hint: '부적 만들기 시 복주머니 소비',
            ),
            const _ShortcutTab(
              emoji: '💫',
              title: '동행',
              description: '나와 인연이 될 사람을 찾아보세요',
              buttonLabel: 'AI매칭 바로가기',
              destination: MatchingDiscoverScreen(),
              hint: '관심표시(좋아요) 시 복주머니 소비',
            ),
            const _ShortcutTab(
              emoji: '🏆',
              title: '랭킹',
              description: '이번 주 포인트 랭킹 TOP 유저 확인하기',
              buttonLabel: '랭킹 바로가기',
              destination: RankingScreen(),
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: CosmicCard(
            gradient: AppColors.gradientWish,
            padding: const EdgeInsets.all(AppSpacing.md),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    '전체 소원 목록 · 소원 작성하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: provider.isLoading && posts.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentPurple,
                  ),
                )
              : posts.isEmpty
              ? const Center(
                  child: Text(
                    '아직 등록된 소원이 없어요',
                    style: TextStyle(color: AppColors.cosmicTextTertiary),
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
                  itemBuilder: (context, index) =>
                      _WishCard(post: posts[index]),
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
    return CosmicCard(
      showGlow: false,
      onTap: () => Navigator.of(
        context,
      ).pushNamed('/community/wish/detail', arguments: post),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  post.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPink,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                post.isAnonymous ? '익명' : post.authorNickname,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.cosmicTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            post.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.cosmicTextPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 13,
                color: AppColors.accentPink,
              ),
              const SizedBox(width: 4),
              Text(
                '${post.supportCount}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.cosmicTextTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Icon(
                Icons.mode_comment_outlined,
                size: 13,
                color: AppColors.cosmicTextTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${post.commentCount}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.cosmicTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 자유/후기/고민상담/궁합이야기/부적/동행/랭킹 탭 공통 - 기존 완성 화면(또는
/// 바텀시트)으로 진입하는 바로가기 카드.
///
/// [7단계] `destination`(화면 push) 또는 `onTapOverride`(임의 동작, 예:
/// 바텀시트 호출) 중 하나를 지정한다. `hint`가 있으면 카드 하단에 복주머니
/// 적립/소비 정보를 작은 뱃지로 노출해 재화 흐름을 명확히 보여준다.
class _ShortcutTab extends StatelessWidget {
  const _ShortcutTab({
    required this.emoji,
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.destination,
    this.onTapOverride,
    this.hint,
  }) : assert(
         destination != null || onTapOverride != null,
         'destination 또는 onTapOverride 중 하나는 필수입니다.',
       );

  final String emoji;
  final String title;
  final String description;
  final String buttonLabel;
  final Widget? destination;
  final VoidCallback? onTapOverride;
  final String? hint;

  void _handleTap(BuildContext context) {
    if (onTapOverride != null) {
      onTapOverride!();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => destination!));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: CosmicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.cosmicTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.cosmicTextSecondary,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍀', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      hint!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleTap(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
