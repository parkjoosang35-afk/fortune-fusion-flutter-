import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';

/// 14. 담긴/나눈 내역(장부) — 출처: PouchScreens.jsx `ScreenLedger`
class WishRoomLedgerScreen extends StatefulWidget {
  const WishRoomLedgerScreen({super.key});

  @override
  State<WishRoomLedgerScreen> createState() => _WishRoomLedgerScreenState();
}

class _WishRoomLedgerScreenState extends State<WishRoomLedgerScreen> {
  int _filter = 0; // 0=전체, 1=담김, 2=나눔

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final now = DateTime.now();

    final monthEarned = provider.ledger
        .where((e) => e.amount > 0 && e.date.year == now.year && e.date.month == now.month)
        .fold<int>(0, (sum, e) => sum + e.amount);
    final monthSpent = provider.ledger
        .where((e) => e.amount < 0 && e.date.year == now.year && e.date.month == now.month)
        .fold<int>(0, (sum, e) => sum - e.amount);

    final filtered = provider.ledger.where((e) {
      if (_filter == 1) return e.amount > 0;
      if (_filter == 2) return e.amount < 0;
      return true;
    }).toList();

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(size: 220, color: palette.sigil, opacity: 0.13),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(text: 'LEDGER · 조용한 장부', palette: palette),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('담긴 것과\n나눈 것', style: WishRoomText.h1(palette.fg).copyWith(fontSize: 22)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: '이번 달 담긴',
                            value: '+$monthEarned',
                            color: palette.glow,
                            palette: palette,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: '이번 달 나눈',
                            value: '−$monthSpent',
                            color: palette.fg,
                            palette: palette,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ['전체', '담김', '나눔'].asMap().entries.map((entry) {
                        final i = entry.key;
                        final label = entry.value;
                        final selected = i == _filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('아직 기록이 없어요', style: WishRoomText.body(palette.muted)),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final e = filtered[i];
                                return WishRoomLedgerRow(
                                  label: e.label,
                                  sub: e.sub,
                                  amount: e.amount,
                                  date: _formatDate(e.date),
                                  palette: palette,
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
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return '오늘 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return '어제';
    if (diff < 7) return '$diff일 전';
    return WishRoomLedgerEntry.formatDate(d);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.palette});

  final String label;
  final String value;
  final Color color;
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
          Text(label, style: WishRoomText.monoSm(palette.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              const WishRoomShard(size: 18),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontFamily: WishRoomText.fontDisplay,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
