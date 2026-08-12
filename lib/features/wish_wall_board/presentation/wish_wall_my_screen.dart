import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/bottle_widget.dart';
import 'wish_wall_detail_screen.dart';

/// 05. 내 소원병 화면.
///
/// [handoff.zip] design/wb3-my.jsx `MyWall`을 Flutter로 이식.
/// Summary 카드(총 병 수 + 응원/기도/복주머니 미니 합계) + 필터칩
/// (전체/진행중/감사/나만보기) + 3열 선반(ShelfRow) 그리드.
class WishWallMyScreen extends StatefulWidget {
  const WishWallMyScreen({super.key});

  @override
  State<WishWallMyScreen> createState() => _WishWallMyScreenState();
}

enum _MyFilter { all, active, gratitude, private }

class _WishWallMyScreenState extends State<WishWallMyScreen> {
  _MyFilter _filter = _MyFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WishWallProvider>().loadMyWishes();
    });
  }

  List<WishPost> _applyFilter(List<WishPost> source) {
    switch (_filter) {
      case _MyFilter.all:
        return source;
      case _MyFilter.active:
        return source.where((w) => !w.isGratitude && !w.isPrivate).toList();
      case _MyFilter.gratitude:
        return source.where((w) => w.isGratitude).toList();
      case _MyFilter.private:
        return source.where((w) => w.isPrivate).toList();
    }
  }

  List<List<WishPost>> _chunk(List<WishPost> list, int n) {
    final result = <List<WishPost>>[];
    for (var i = 0; i < list.length; i += n) {
      result.add(list.sublist(i, i + n > list.length ? list.length : i + n));
    }
    return result;
  }

  void _openDetail(WishPost wish) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WishWallDetailScreen(wishId: wish.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<WishWallProvider>().myWishes;
    final list = _applyFilter(all);
    final rows = _chunk(list, 3);

    final totalSupport = all.fold<int>(0, (s, w) => s + w.supportCount);
    final totalPrayer = all.fold<int>(0, (s, w) => s + w.prayerCount);
    final totalPouch = all.fold<int>(0, (s, w) => s + w.pouchCount);

    return Scaffold(
      backgroundColor: WishWallColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: WishWallColors.ink,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '내 소원병',
                      textAlign: TextAlign.center,
                      style: WishWallText.title2(),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  // Summary 카드
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: WishWallColors.bg2,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: WishWallColors.line),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '${all.length}',
                              style: WishWallText.display().copyWith(fontSize: 34),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '개의 소원병을 담았어요',
                                style: WishWallText.body(color: WishWallColors.muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _MiniSummary(icon: '♥', label: '응원', value: totalSupport),
                            Container(width: 1, height: 30, color: WishWallColors.line),
                            _MiniSummary(icon: '✧', label: '기도', value: totalPrayer),
                            Container(width: 1, height: 30, color: WishWallColors.line),
                            _MiniSummary(icon: '✨', label: '복주머니', value: totalPouch),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 필터칩
                  Row(
                    children: [
                      _FilterChip(
                        label: '전체',
                        active: _filter == _MyFilter.all,
                        onTap: () => setState(() => _filter = _MyFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '진행중',
                        active: _filter == _MyFilter.active,
                        onTap: () => setState(() => _filter = _MyFilter.active),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '감사',
                        active: _filter == _MyFilter.gratitude,
                        onTap: () => setState(() => _filter = _MyFilter.gratitude),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '나만보기',
                        active: _filter == _MyFilter.private,
                        onTap: () => setState(() => _filter = _MyFilter.private),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          '아직 이 분류엔 소원병이 없어요',
                          style: WishWallText.body(color: WishWallColors.muted),
                        ),
                      ),
                    )
                  else
                    ...rows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Row(
                          children: [
                            for (var i = 0; i < 3; i++)
                              Expanded(
                                child: i < row.length
                                    ? _ShelfBottle(
                                        wish: row[i],
                                        onTap: () => _openDetail(row[i]),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ),
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

class _MiniSummary extends StatelessWidget {
  const _MiniSummary({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: WishWallText.title2().copyWith(fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(label, style: WishWallText.caption()),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
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
            color: active ? WishWallColors.bg : WishWallColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _ShelfBottle extends StatelessWidget {
  const _ShelfBottle({required this.wish, required this.onTap});
  final WishPost wish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tilt = wish.isPrivate ? -6.0 : 0.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            SizedBox(
              height: 96,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  BottleWidget(
                    category: wish.categoryId,
                    size: 62,
                    glow: wish.glow,
                    tilt: tilt,
                  ),
                  if (wish.hasNewReaction)
                    Positioned(
                      top: 0,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: WishWallColors.red,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (wish.isGratitude)
                    const Positioned(
                      bottom: 6,
                      right: 2,
                      child: Text('✨', style: TextStyle(fontSize: 14)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              wish.categoryId.label,
              style: WishWallText.caption().copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
