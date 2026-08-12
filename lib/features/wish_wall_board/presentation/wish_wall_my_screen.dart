import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/wish_wall_candle.dart';
import '../widgets/wish_wall_sigil.dart';
import '../widgets/wish_wall_wish_card.dart';
import 'wish_wall_detail_screen.dart';

/// 05. 나의 소원방(내 소원병) 화면.
///
/// [디자인 히스토리] 옛 "신통방통 소원방"(wish_room) `WishRoomHomeScreen`의
/// 화면 구성(상단 마법진 배경 + 중앙 촛불 + "나의 소원방" 타이틀 + 소원 개수
/// 요약 + 소원 카드 목록 + 빈 상태 CTA)을 그대로 재현한다. 데이터는 현재의
/// [WishWallProvider.myWishes](WishPost)를 그대로 사용하고, 화폐(조각) 관련
/// 요소는 전부 제외했다. 응원/기도/복주머니 필터·합계는 지금 시스템의
/// 언어에 맞게 유지한다.
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

  void _openDetail(WishPost wish) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WishWallDetailScreen(wishId: wish.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<WishWallProvider>().myWishes;
    final list = _applyFilter(all);
    final activeWishes = all.where((w) => !w.isGratitude).toList();
    final gratitudeCount = all.length - activeWishes.length;

    final totalSupport = all.fold<int>(0, (s, w) => s + w.supportCount);
    final totalPrayer = all.fold<int>(0, (s, w) => s + w.prayerCount);
    final totalPouch = all.fold<int>(0, (s, w) => s + w.pouchCount);

    return Scaffold(
      backgroundColor: WishWallColors.bg,
      body: Stack(
        children: [
          // 옛 소원방 홈 화면의 상단 마법진 배경 — 화면이 살짝 신비롭게
          // 움직이는 느낌을 재현.
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.62),
              child: WishWallSigil(
                size: 340,
                color: WishWallColors.accent,
                opacity: 0.18,
              ),
            ),
          ),
          SafeArea(
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
                          'HOME · 나의 소원',
                          textAlign: TextAlign.center,
                          style: WishWallText.mono(),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    children: [
                      // 옛 홈 화면의 중앙 촛불 — 밝힌(진행중) 소원이 있으면
                      // 불이 켜진다.
                      Center(
                        child: WishWallCandle(
                          size: 78,
                          lit: activeWishes.isNotEmpty,
                          color: WishWallColors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '나의 소원방',
                        textAlign: TextAlign.center,
                        style: WishWallText.title1(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        all.isEmpty
                            ? '아직 밝힌 소원이 없어요\n첫 소원을 두루마리에 적어보세요'
                            : '${activeWishes.length}개의 소원을 밝히고 있어요'
                                  '${gratitudeCount > 0 ? ' · $gratitudeCount개 이루어짐' : ''}',
                        textAlign: TextAlign.center,
                        style: WishWallText.body(
                          color: WishWallColors.muted,
                        ).copyWith(height: 1.7),
                      ),
                      const SizedBox(height: 20),
                      // 응원/기도/복주머니 합계 카드 — 지금 시스템 언어 유지.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: WishWallColors.bg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: WishWallColors.line),
                        ),
                        child: Row(
                          children: [
                            _MiniSummary(icon: '♥', label: '응원', value: totalSupport),
                            Container(width: 1, height: 30, color: WishWallColors.line),
                            _MiniSummary(icon: '✧', label: '기도', value: totalPrayer),
                            Container(width: 1, height: 30, color: WishWallColors.line),
                            _MiniSummary(icon: '✨', label: '복주머니', value: totalPouch),
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
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              all.isEmpty ? '' : '아직 이 분류엔 소원이 없어요',
                              style: WishWallText.body(color: WishWallColors.muted),
                            ),
                          ),
                        )
                      else
                        ...list.map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: WishWallWishCard(
                              wish: w,
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
        ],
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
