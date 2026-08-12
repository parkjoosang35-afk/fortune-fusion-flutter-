import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../application/wish_room_tab_controller.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_pouch_widgets.dart';

/// 13. 담긴/나눈 내역(조용한 장부) — 출처: PouchScreens.jsx `ScreenLedger`
///
/// 하단 네비게이션 '기록' 탭의 실제 화면. [WishRoomShell]의 IndexedStack에서
/// 탭 루트로 쓰이는 동시에, [WishRoomPouchHomeScreen]의 "전체 →"에서
/// push로도 접근 가능(그 경우 상단 뒤로가기 버튼으로 복귀).
class WishRoomLedgerScreen extends StatefulWidget {
  const WishRoomLedgerScreen({super.key});

  @override
  State<WishRoomLedgerScreen> createState() => _WishRoomLedgerScreenState();
}

enum _LedgerFilter { all, earn, spend }

class _WishRoomLedgerScreenState extends State<WishRoomLedgerScreen> {
  _LedgerFilter _filter = _LedgerFilter.all;

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();

    final now = DateTime.now();
    final monthEntries = provider.ledger.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final monthEarned = monthEntries
        .where((e) => e.amount > 0)
        .fold<int>(0, (s, e) => s + e.amount);
    final monthSpent = monthEntries
        .where((e) => e.amount < 0)
        .fold<int>(0, (s, e) => s - e.amount);

    final filtered = provider.ledger.where((e) {
      switch (_filter) {
        case _LedgerFilter.earn:
          return e.amount > 0;
        case _LedgerFilter.spend:
          return e.amount < 0;
        case _LedgerFilter.all:
          return true;
      }
    }).toList();

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(
                          text: 'LEDGER · 조용한 장부',
                          palette: palette,
                        ),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '담긴 것과\n나눈 것',
                        style: WishRoomText.h1(
                          palette.fg,
                        ).copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: '이번 달 담긴',
                            amount: monthEarned,
                            positive: true,
                            palette: palette,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: '이번 달 나눈',
                            amount: monthSpent,
                            positive: false,
                            palette: palette,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _FilterChip(
                          label: '전체',
                          selected: _filter == _LedgerFilter.all,
                          palette: palette,
                          onTap: () =>
                              setState(() => _filter = _LedgerFilter.all),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '담김',
                          selected: _filter == _LedgerFilter.earn,
                          palette: palette,
                          onTap: () =>
                              setState(() => _filter = _LedgerFilter.earn),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '나눔',
                          selected: _filter == _LedgerFilter.spend,
                          palette: palette,
                          onTap: () =>
                              setState(() => _filter = _LedgerFilter.spend),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                '아직 흔적이 없어요',
                                style: WishRoomText.body(palette.muted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final e = filtered[i];
                                return WishRoomLedgerRow(
                                  label: e.label,
                                  sub: e.sub,
                                  amount: e.amount,
                                  date: WishRoomLedgerEntry.formatDate(e.date),
                                  palette: palette,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: WishRoomBottomNav(
                active: 'me',
                palette: palette,
                onSelect: (id) => context.read<WishRoomTabController>().go(id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    required this.positive,
    required this.palette,
  });

  final String label;
  final int amount;
  final bool positive;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: WishRoomText.monoSm(palette.muted)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WishRoomShard(size: 18),
              const SizedBox(width: 6),
              Text(
                '${positive ? '+' : '−'}$amount',
                style: TextStyle(
                  fontFamily: WishRoomText.fontDisplay,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: positive ? palette.glow : palette.fg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final WishRoomPaletteTokens palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? palette.glow : Colors.transparent,
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: WishRoomText.fontBody,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? WishRoomColors.onGlowText : palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}
