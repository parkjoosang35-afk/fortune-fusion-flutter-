import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/shrine_v3_provider.dart';
import '../../domain/shrine_order.dart';
import '../theme/shrine_v3_theme.dart';
import 'shrine_v3_owned_screen.dart';

/// 신당(THE SHRINE) v3 — 09 부적함. 서버가 계산한 daysRemaining/
/// displayStatus/incenseLitToday를 그대로 표시만 한다(클라이언트 재계산
/// 없음 — §8 서버 전담 원칙).
class ShrineV3BoxScreen extends StatefulWidget {
  const ShrineV3BoxScreen({super.key});

  @override
  State<ShrineV3BoxScreen> createState() => _ShrineV3BoxScreenState();
}

class _ShrineV3BoxScreenState extends State<ShrineV3BoxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShrineV3Provider>().loadBox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineV3Provider>();
    final items = provider.boxItems;
    final summary = provider.boxSummary;

    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      appBar: AppBar(
        backgroundColor: ShrineV3Colors.paper,
        foregroundColor: ShrineV3Colors.ink,
        elevation: 0,
        title: const Text('신당 부적함'),
      ),
      body: SafeArea(
        child: provider.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => context.read<ShrineV3Provider>().loadBox(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text('기간이 끝나도 부적은 지워지지 않아요.', style: ShrineV3TextStyles.ui.copyWith(fontSize: 12)),
                    const SizedBox(height: 12),
                    if (summary != null)
                      Row(
                        children: [
                          _sumCell('소지 중', summary.active),
                          _sumCell('기간 만료', summary.expired),
                          _sumCell('보관 중', summary.archived),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text('아직 지어 드린 부적이 없어요.', style: ShrineV3TextStyles.ui.copyWith(fontSize: 13)),
                        ),
                      ),
                    ...items.map((o) => _BoxItemTile(order: o)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sumCell(String label, int n) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: ShrineV3Colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShrineV3Colors.line),
      ),
      child: Column(
        children: [
          Text('$n', style: ShrineV3TextStyles.title.copyWith(fontSize: 18)),
          Text(label, style: ShrineV3TextStyles.ui.copyWith(fontSize: 11)),
        ],
      ),
    ),
  );
}

class _BoxItemTile extends StatelessWidget {
  const _BoxItemTile({required this.order});
  final ShrineOrder order;

  @override
  Widget build(BuildContext context) {
    final t = order.talisman;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShrineV3OwnedScreen(orderId: order.orderId)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ShrineV3Colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ShrineV3Colors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/shrine_v3/${t.thumbPath ?? t.imagePath}',
                width: 44,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 44, height: 70, color: ShrineV3Colors.paperDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: ShrineV3TextStyles.body.copyWith(fontSize: 14)),
                  Text(
                    order.isActive
                        ? '${order.daysRemaining}일 남음 · ${order.issuedDateKey} 제작'
                        : order.isExpired
                        ? '기간 만료 · ${order.issuedDateKey} 제작'
                        : '보관 중 · ${order.issuedDateKey} 제작',
                    style: ShrineV3TextStyles.ui.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (order.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: order.incenseLitToday ? ShrineV3Colors.paperDark : const Color(0xFF2A1A10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.incenseLitToday ? '오늘 올림' : '香 향 올리기',
                  style: TextStyle(
                    fontSize: 11,
                    color: order.incenseLitToday ? ShrineV3Colors.ink3 : const Color(0xFFFFD98A),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ShrineV3Colors.paperDark,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.isExpired ? '기간 만료' : '보관 중',
                  style: ShrineV3TextStyles.ui.copyWith(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
