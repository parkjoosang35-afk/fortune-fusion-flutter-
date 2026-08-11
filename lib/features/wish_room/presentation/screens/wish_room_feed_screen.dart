import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_sigil.dart';

/// [디자인 핸드오프 8개 화면 재구현] "모두의 소원" 피드 — `ScreenFeed` 스펙.
///
/// `wish-screens.jsx`(416-511줄) / README `6. Feed` 정확한 값을 그대로
/// 재구현: BgAtmosphere(200, 0.15) → 헤더(eyebrow "모두의 소원방" + 타이틀
/// "밤하늘에 뜬 마음들") → 필터 칩 6개(전체/합격/건강/인연/재물/평안, 가로
/// 스크롤, "전체"만 기본 활성) → 포스트 카드 4개(우상단 역회전 마법진
/// 장식 + 지역·연령 meta + 인용구 + 구분선 + "N명이 함께 빌었어요" +
/// "+ 함께 빌기" 버튼).
///
/// [데이터 소스 — 미확정 갭] community `WishPostRepository`/
/// `WishPostProvider`와의 연동 방식은 아직 확정되지 않았다(TodoWrite
/// 미결정 갭 항목 참고 — wish_room 모듈은 community 'Wish Castle'과 완전히
/// 독립적으로 설계되어 재화/데이터가 섞이면 안 된다는 원칙이 이미 있고,
/// 두 모듈을 연결하려면 별도의 설계 검토가 필요하다). 이 화면은 그 갭을
/// 메우는 임시 조치로 README가 명시한 4개 샘플 문구(정적, 서버 응답 아님)를
/// 그대로 사용하고, "+ 함께 빌기"는 순수 로컬 UI 카운터 증가(비영속,
/// 새로고침 시 초기화)로만 구현해 실제 재화/서버 상태에는 어떤 영향도 주지
/// 않는다 — 절대 이 카운터가 복주머니 등 실제 재화로 취급되지 않는다.
class WishRoomFeedScreen extends StatefulWidget {
  const WishRoomFeedScreen({super.key});

  @override
  State<WishRoomFeedScreen> createState() => _WishRoomFeedScreenState();
}

class _FeedPost {
  final String text;
  final String region;
  final String age;
  int wishCount;
  bool joined;

  _FeedPost({
    required this.text,
    required this.region,
    required this.age,
    required this.wishCount,
    this.joined = false,
  });
}

class _WishRoomFeedScreenState extends State<WishRoomFeedScreen> {
  static const _filters = ['전체', '합격', '건강', '인연', '재물', '평안'];
  int _selectedFilter = 0;

  // README `6. Feed` "Sample content" 4건을 그대로 사용(정적 데모 데이터).
  final List<_FeedPost> _posts = [
    _FeedPost(
      text: '아빠가 오래오래 곁에 있어주기를',
      region: '서울',
      age: '30대',
      wishCount: 128,
    ),
    _FeedPost(
      text: '새로 시작한 가게가 잘 되기를',
      region: '부산',
      age: '40대',
      wishCount: 87,
    ),
    _FeedPost(
      text: '이별한 그 사람 잊게 해주세요',
      region: '익명',
      age: '20대',
      wishCount: 342,
    ),
    _FeedPost(
      text: '엄마 항암치료 잘 이겨내기를',
      region: '대구',
      age: '20대',
      wishCount: 561,
    ),
  ];

  void _toggleJoin(_FeedPost post) {
    setState(() {
      if (post.joined) {
        post.joined = false;
        post.wishCount -= 1;
      } else {
        post.joined = true;
        post.wishCount += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBackground(
              mainSigilSize: 200,
              mainSigilOpacity: 0.15,
            ),
          ),
          SafeArea(
            child: DramaticEntrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: WishRoomSpacing.sm),
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      WishRoomSpacing.lg,
                      4,
                      WishRoomSpacing.lg,
                      WishRoomSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('모두의 소원방', style: WishRoomTextStyles.eyebrow),
                        const SizedBox(height: 4),
                        Text(
                          '밤하늘에 뜬 마음들',
                          style: WishRoomTextStyles.sectionTitle,
                        ),
                      ],
                    ),
                  ),
                  // ── Filter chips ──
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: WishRoomSpacing.lg,
                      ),
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: WishRoomSpacing.sm),
                      itemBuilder: (context, index) {
                        final isActive = index == _selectedFilter;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedFilter = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                WishRoomRadius.pill,
                              ),
                              border: Border.all(
                                color: WishRoomColors.surfaceCardBorder,
                              ),
                              color: isActive
                                  ? WishRoomColors.glow
                                  : Colors.transparent,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _filters[index],
                              style: TextStyle(
                                fontFamily: 'GowunBatangWish',
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isActive
                                    ? const Color(0xFF3A2515)
                                    : WishRoomColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: WishRoomSpacing.md),
                  // ── Feed cards ──
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        WishRoomSpacing.lg,
                        0,
                        WishRoomSpacing.lg,
                        100,
                      ),
                      itemCount: _posts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: WishRoomSpacing.md),
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        return _FeedCard(
                          post: post,
                          onJoinTap: () => _toggleJoin(post),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final _FeedPost post;
  final VoidCallback onJoinTap;

  const _FeedCard({required this.post, required this.onJoinTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // 우상단 역회전 마법진 장식(70px, opacity 0.4).
          Positioned(
            top: -20,
            right: -20,
            child: Opacity(
              opacity: 0.4,
              child: WishRoomSigilRing(
                size: 70,
                color: WishRoomColors.sigil,
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
                    '◇ ${post.region}',
                    style: WishRoomTextStyles.metaMono.copyWith(
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('·', style: WishRoomTextStyles.metaMono),
                  const SizedBox(width: 6),
                  Text(post.age, style: WishRoomTextStyles.metaMono),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '"${post.text}"',
                style: WishRoomTextStyles.wishBodyList.copyWith(fontSize: 15),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: WishRoomColors.surfaceCardBorder),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '🕯 ${post.wishCount}명이 함께 빌었어요',
                            style: WishRoomTextStyles.metaMono.copyWith(
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TapBounce(
                          onTap: onJoinTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: WishRoomColors.glowShadow,
                              borderRadius: BorderRadius.circular(
                                WishRoomRadius.pill,
                              ),
                              border: Border.all(color: WishRoomColors.glow),
                            ),
                            child: Text(
                              post.joined ? '함께 빌었어요 ✓' : '+ 함께 빌기',
                              style: TextStyle(
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
