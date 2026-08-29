import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_bottom_nav.dart';
import '../widgets/wish_room_seal.dart';
import '../widgets/wish_room_seal_mapping.dart';
import '../widgets/wish_room_sigil.dart';
import 'wish_room_detail_screen.dart';

/// 소원방(Wish Room) — 06. 모두의 소원 둘러보기(Feed, "밤하늘에 뜬 마음들").
///
/// [디자인 핸드오프 — pixel-perfect 재현] `wish-screens.jsx`의 `ScreenFeed`
/// 컴포넌트를 그대로 재구현한다: 헤더(모두의 소원방/밤하늘에 뜬 마음들) →
/// 필터칩(전체/합격/건강/인연/재물/평안) → 카드 리스트(우상단 역회전
/// 마법진 장식+지역·나이대 메타+본문+구분선+"N명이 함께 빌었어요"+
/// "+ 함께 빌기" 버튼) → [WishRoomBottomNav](active='feed').
///
/// [절충 결정 — 데이터 요구사항 vs 실제 모델]
/// - 원본 목데이터의 `region`/`age`(예: "서울"/"30대")는 [WishPost] 모델에
///   대응 필드가 없다(발명 금지 원칙). 대신 이미 존재하는 데이터만 사용해
///   `◇ {카테고리 라벨}` + `{작성 후 경과 시간}`으로 메타 행을 채운다 —
///   시각적 레이아웃(구분점 포함 2단 메타)은 그대로 유지하되 내용만 실제
///   데이터로 교체했다.
/// - "N명이 함께 빌었어요" → [WishPost.supportCount](기존 응원 수, 이미
///   04 Home/05 Detail에서도 같은 의미로 쓰임)를 그대로 사용.
/// - "+ 함께 빌기" 버튼 → [WishWallProvider.support] 호출(무료 응원, 05
///   Detail의 "🔥 소원 더하기"와 동일한 액션 재사용 — 새 액션 발명 없음).
/// - 필터칩 → [primaryCategoryForSeal]로 [WishSeal] 6종 중 5종(합격/건강/
///   인연/재물)+전체를 [WishCategory]로 역매핑해 로컬 필터링한다. '평안'은
///   [primaryCategoryForSeal]이 growth로 근사하는 매핑을 그대로 재사용.
class WishRoomFeedScreen extends StatefulWidget {
  const WishRoomFeedScreen({super.key});

  @override
  State<WishRoomFeedScreen> createState() => _WishRoomFeedScreenState();
}

class _WishRoomFeedScreenState extends State<WishRoomFeedScreen> {
  static const List<String> _chipLabels = ['전체', '합격', '건강', '인연', '재물', '평안'];
  static const List<WishSeal?> _chipSeals = [
    null,
    WishSeal.pass,
    WishSeal.health,
    WishSeal.bond,
    WishSeal.wealth,
    WishSeal.wish, // '평안' 근사(primaryCategoryForSeal 매핑 재사용)
  ];

  int _selectedChip = 0;
  final Set<String> _busySendIds = {};
  // [STEP04 PART2 §8] 서버가 지원하는 sort 값('latest'|'popular')만
  // 그대로 전달한다. 임의의 인기점수 계산 없음.
  String _sort = 'latest';

  // [소원방 마무리 - Phase B] daily_feed_visit(+1, 1일 1회) — bokjumeoni-plan
  // §02 EARN "모두의 소원방을 스크롤해서 바닥까지 읽다 · 3소원 이상 읽어야
  // 인정". "3소원 이상 노출"을 itemBuilder가 실제로 그 인덱스까지 빌드했는지
  // 로 판정한다(스크롤 이벤트 델타 누적 대신, 실제로 화면에 렌더링된 카드
  // 개수를 근거로 삼아야 "스크롤해서 읽었다"는 의도에 더 부합함). 이 화면
  // 인스턴스당 1회만 요청하도록 플래그로 방어한다(서버도 scope='daily'로
  // 최종 방어하지만, 불필요한 중복 네트워크 호출을 줄이기 위함).
  bool _feedVisitClaimed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishWallProvider>().ensureLoaded();
    });
  }

  void _changeSort(String sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    context.read<WishWallProvider>().loadFeed(sort: sort);
  }

  void _maybeClaimFeedVisitBonus(int builtIndex) {
    // index는 0부터 시작하므로 "3소원 이상"은 index >= 2를 의미한다.
    if (_feedVisitClaimed || builtIndex < 2) return;
    _feedVisitClaimed = true;
    context.read<WishWallProvider>().policy.earnDailyFeedVisitBonus();
  }

  List<WishPost> _filtered(List<WishPost> feed) {
    final seal = _chipSeals[_selectedChip];
    if (seal == null) return feed;
    final category = primaryCategoryForSeal(seal);
    return feed.where((w) => w.categoryId == category).toList();
  }

  String _timeAgoLabel(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Future<void> _joinWish(WishPost wish) async {
    if (wish.hasSupportedByMe || _busySendIds.contains(wish.id)) return;
    setState(() => _busySendIds.add(wish.id));
    await context.read<WishWallProvider>().support(wish.id);
    if (!mounted) return;
    setState(() => _busySendIds.remove(wish.id));
  }

  void _openDetail(WishPost wish, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WishRoomDetailScreen(wishId: wish.id, index: index + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 200, sigilOpacity: 0.15),
          ),
          SafeArea(
            child: Consumer<WishWallProvider>(
              builder: (context, provider, _) {
                final loading = provider.isLoading && !provider.loaded;
                final posts = _filtered(provider.feed);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '모두의 소원방',
                            style: TextStyle(
                              fontFamily: 'IBMPlexMonoWish',
                              fontSize: 10,
                              letterSpacing: 3.0,
                              color: WishRoomColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '밤하늘에 뜬 마음들',
                            style: TextStyle(
                              fontFamily: 'NotoSerifKRWish',
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: WishRoomColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _chipLabels.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final selected = i == _selectedChip;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedChip = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: WishRoomColors.surfaceCardBorder,
                                ),
                                color: selected
                                    ? WishRoomColors.glow
                                    : Colors.transparent,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _chipLabels[i],
                                style: TextStyle(
                                  fontFamily: 'GowunBatangWish',
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: selected
                                      ? const Color(0xFF3A2515)
                                      : WishRoomColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        children: [
                          _SortChip(
                            label: '✨ 최신',
                            selected: _sort == 'latest',
                            onTap: () => _changeSort('latest'),
                          ),
                          const SizedBox(width: 8),
                          _SortChip(
                            label: '🔥 응원 많은 소원',
                            selected: _sort == 'popular',
                            onTap: () => _changeSort('popular'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: WishRoomColors.glow,
                              ),
                            )
                          : posts.isEmpty
                          ? Center(
                              child: Text(
                                '아직 이 마음엔\n소원이 없어요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'GowunBatangWish',
                                  color: WishRoomColors.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                16,
                              ),
                              itemCount: posts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final wish = posts[i];
                                // [Phase B] 카드가 실제로 빌드되는 시점 =
                                // 사용자가 그만큼 스크롤해서 읽은 시점으로
                                // 간주한다(ListView.separated는 기본적으로
                                // 화면에 보이거나 곧 보일 위치까지만 빌드).
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _maybeClaimFeedVisitBonus(i),
                                );
                                return _FeedCard(
                                  wish: wish,
                                  timeLabel: _timeAgoLabel(wish.createdAt),
                                  joined: wish.hasSupportedByMe,
                                  busy: _busySendIds.contains(wish.id),
                                  onJoin: () => _joinWish(wish),
                                  onTap: () => _openDetail(wish, i),
                                );
                              },
                            ),
                    ),
                    WishRoomBottomNav(
                      active: 'feed',
                      onHome: () => Navigator.of(context).pop(),
                      onFeed: () {},
                      onRecord: () => Navigator.of(context).pop(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
          color: selected ? WishRoomColors.glow : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GowunBatangWish',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? const Color(0xFF3A2515)
                : WishRoomColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.wish,
    required this.timeLabel,
    required this.joined,
    required this.busy,
    required this.onJoin,
    required this.onTap,
  });

  final WishPost wish;
  final String timeLabel;
  final bool joined;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Opacity(
                opacity: 0.4,
                child: WishRoomSigilRing(
                  size: 70,
                  opacity: 0.5,
                  reverse: true,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '◇ ${wish.categoryId.label}',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMonoWish',
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: WishRoomColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '·',
                      style: TextStyle(color: WishRoomColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMonoWish',
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: WishRoomColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"${wish.text}"',
                  style: const TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.5,
                    color: WishRoomColors.textPrimary,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: WishRoomColors.surfaceCardBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '💛 ${wish.supportCount}명이 함께 빌고 있어요',
                          style: const TextStyle(
                            fontFamily: 'IBMPlexMonoWish',
                            fontSize: 11,
                            letterSpacing: 1.0,
                            color: WishRoomColors.textSecondary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: joined || busy ? null : onJoin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: WishRoomColors.glowShadow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: WishRoomColors.glow),
                          ),
                          child: Text(
                            joined ? '✨ 함께 응원했어요' : '💛 응원',
                            style: const TextStyle(
                              fontFamily: 'GowunBatangWish',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: WishRoomColors.glow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
