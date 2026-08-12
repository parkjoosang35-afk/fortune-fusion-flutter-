import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/wish_wall_seal.dart';
import '../widgets/wish_wall_sigil.dart';
import '../widgets/wish_wall_wish_card.dart';
import 'wish_wall_compose_screen.dart';
import 'wish_wall_detail_screen.dart';
import 'wish_wall_my_screen.dart';

/// 01. 신통방통 소원방 — 모두의 소원(피드) 화면.
///
/// [디자인 히스토리] 옛 "신통방통 소원방"(wish_room) `WishRoomFeedScreen`의
/// 화면 구성(상단 마법진 배경 + 중앙 큰 인장(合) + "모두의 소원" 타이틀 +
/// 응원 많은 순 정렬 + 익명 소원 카드 목록)을 그대로 재현한다. 데이터는
/// 지금의 [WishWallProvider.feed](WishPost)를 그대로 사용한다. 카테고리
/// 필터/작성 FAB는 지금 시스템에 필요한 기능이라 유지했다.
class WishWallBoardScreen extends StatefulWidget {
  const WishWallBoardScreen({super.key});

  @override
  State<WishWallBoardScreen> createState() => _WishWallBoardScreenState();
}

class _WishWallBoardScreenState extends State<WishWallBoardScreen> {
  WishCategory? _category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WishWallProvider>().ensureLoaded();
    });
  }

  List<WishPost> _applyFilters(List<WishPost> source) {
    var list = List<WishPost>.of(source);
    if (_category != null) {
      list = list.where((w) => w.categoryId == _category).toList();
    }
    list.sort((a, b) => b.supportCount.compareTo(a.supportCount));
    return list;
  }

  void _openDetail(WishPost wish) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WishWallDetailScreen(wishId: wish.id)),
    );
  }

  void _openCompose() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WishWallComposeScreen()),
    );
  }

  void _openMy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WishWallMyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishWallProvider>();
    final list = _applyFilters(provider.feed);

    return Scaffold(
      backgroundColor: WishWallColors.bg,
      body: Stack(
        children: [
          // 옛 피드 화면의 상단 마법진 배경.
          Positioned(
            top: -60,
            right: -40,
            child: WishWallSigil(
              size: 300,
              color: WishWallColors.accent,
              opacity: 0.16,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('FEED · 모두의 소원', style: WishWallText.mono()),
                      ),
                      IconButton(
                        onPressed: _openMy,
                        icon: const Icon(
                          Icons.person_outline_rounded,
                          color: WishWallColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                    children: [
                      const Center(
                        child: WishWallSeal(
                          text: '合',
                          color: WishWallColors.accent,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '모두의 소원',
                        textAlign: TextAlign.center,
                        style: WishWallText.title1(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '익명의 소원들이 모이는 자리입니다\n마음이 가는 곳에 함께 빌어주세요',
                        textAlign: TextAlign.center,
                        style: WishWallText.body(
                          color: WishWallColors.muted,
                        ).copyWith(height: 1.7),
                      ),
                      const SizedBox(height: 20),
                      _CategoryChipRow(
                        selected: _category,
                        onSelect: (c) => setState(() => _category = c),
                      ),
                      const SizedBox(height: 16),
                      if (provider.isLoading && list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: WishWallColors.accent,
                            ),
                          ),
                        )
                      else if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            '아직 모인 소원이 없어요\n나의 소원을 먼저 밝혀보세요',
                            textAlign: TextAlign.center,
                            style: WishWallText.body(color: WishWallColors.muted),
                          ),
                        )
                      else
                        ...list.map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: WishWallWishCard(
                              wish: w,
                              anonymous: true,
                              onTap: () => _openDetail(w),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 24,
            child: _ComposeFab(onPressed: _openCompose),
          ),
        ],
      ),
    );
  }
}

class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({required this.selected, required this.onSelect});
  final WishCategory? selected;
  final ValueChanged<WishCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryChip(
            label: '전체',
            active: selected == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 6),
          ...WishCategory.values.expand((c) => [
                _CategoryChip(
                  label: c.label,
                  active: selected == c,
                  onTap: () => onSelect(c),
                ),
                const SizedBox(width: 6),
              ]),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? WishWallColors.ink : WishWallColors.bg2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? WishWallColors.ink : WishWallColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: WishWallText.family,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.2,
            color: active ? WishWallColors.bg : WishWallColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: WishWallColors.accent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: WishWallColors.accent.withValues(alpha: 0.42),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('새 소원', style: WishWallText.label(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
