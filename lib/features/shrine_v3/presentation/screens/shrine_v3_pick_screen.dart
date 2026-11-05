import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/shrine_v3_provider.dart';
import '../../domain/shrine_categories.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/talisman_thumb.dart';
import 'shrine_v3_detail_screen.dart';

/// 신당(THE SHRINE) v3 — 04 직접 고르기. 카테고리 필터 + 2열 그리드.
class ShrineV3PickScreen extends StatefulWidget {
  const ShrineV3PickScreen({super.key});

  @override
  State<ShrineV3PickScreen> createState() => _ShrineV3PickScreenState();
}

class _ShrineV3PickScreenState extends State<ShrineV3PickScreen> {
  int _filter = -1; // -1 = 전체

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineV3Provider>();
    final catalog = provider.catalog;
    final list = _filter < 0
        ? catalog
        : catalog
              .where((k) => k.category == kShrineCategoryOrder[_filter])
              .toList();

    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      appBar: AppBar(
        backgroundColor: ShrineV3Colors.paper,
        foregroundColor: ShrineV3Colors.ink,
        elevation: 0,
        title: const Text('직접 고르기'),
      ),
      body: provider.isLoading && catalog.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '어떤 부적을\n써 드릴까요',
                        style: ShrineV3TextStyles.title.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${catalog.length}가지 부적 · 누르면 뜻과 쓰임을 먼저 보여 드려요.',
                        style: ShrineV3TextStyles.ui.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: kShrineCategoryOrder.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final isAll = i == 0;
                      final idx = i - 1;
                      final cat = isAll ? null : kShrineCategoryOrder[idx];
                      final count = isAll
                          ? catalog.length
                          : catalog.where((k) => k.category == cat).length;
                      final on = isAll ? _filter < 0 : _filter == idx;
                      return ChoiceChip(
                        label: Text(
                          isAll ? '전체 $count' : '${kShrineCategoryLabels[cat]} $count',
                        ),
                        selected: on,
                        onSelected: (_) => setState(() => _filter = isAll ? -1 : idx),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: on ? ShrineV3Colors.paper : ShrineV3Colors.ink2,
                        ),
                        selectedColor: ShrineV3Colors.ink,
                        backgroundColor: ShrineV3Colors.card,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final k = list[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ShrineV3DetailScreen(talismanId: k.id),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ShrineV3Colors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ShrineV3Colors.line),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: TalismanThumb(
                                  talisman: k,
                                  width: 100,
                                  height: double.infinity,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                k.name,
                                style: ShrineV3TextStyles.body.copyWith(fontSize: 13),
                              ),
                              Text(
                                k.aim,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ShrineV3TextStyles.ui.copyWith(
                                  fontSize: 10,
                                  color: ShrineV3Colors.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
