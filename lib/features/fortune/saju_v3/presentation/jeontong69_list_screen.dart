// 신통방통 정통사주 v3 — 69종 목록 화면
// 4단계 UX: ①목록(이 화면) → ②정보창(바텀시트) → ③로딩 → ④결과(상세)
//
// [Option 2 이식] 원본 ConsumerWidget(riverpod)을 StatefulWidget +
// provider 패키지로 재작성. go_router 대신 Navigator.push(MaterialPageRoute) 사용.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/saju_v3_provider.dart';
import '../domain/birth_input.dart';
import '../domain/category_item.dart';
import 'jeontong69_loading_screen.dart';
import 'jeontong_v3_theme.dart';

class Jeontong69ListScreen extends StatefulWidget {
  final BirthInput birth;
  const Jeontong69ListScreen({super.key, required this.birth});

  @override
  State<Jeontong69ListScreen> createState() => _Jeontong69ListScreenState();
}

class _Jeontong69ListScreenState extends State<Jeontong69ListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SajuV3Provider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Jt3Colors.inkBlack,
      appBar: AppBar(
        backgroundColor: Jt3Colors.inkBlack,
        foregroundColor: Jt3Colors.royalGold,
        title: const Text(
          '정통사주 69종',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Consumer<SajuV3Provider>(
        builder: (context, provider, _) {
          final state = provider.categoriesState;
          if (state.isLoading || state.isInitial) {
            return const Center(
              child: CircularProgressIndicator(color: Jt3Colors.royalGold),
            );
          }
          if (state.isError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '목록을 불러올 수 없습니다\n${state.errorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Jt3Colors.moonSilver),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => provider.loadCategories(),
                      child: const Text(
                        '다시 시도',
                        style: TextStyle(color: Jt3Colors.royalGold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return _GroupedList(
            categories: state.data ?? const [],
            birth: widget.birth,
          );
        },
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  final List<CategoryItem> categories;
  final BirthInput birth;
  const _GroupedList({required this.categories, required this.birth});

  @override
  Widget build(BuildContext context) {
    final byCode = {for (final c in categories) c.code: c};
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kJt3Groups.length,
      itemBuilder: (context, i) {
        final g = kJt3Groups.entries.elementAt(i);
        final items = g.value.$2
            .map((c) => byCode[c])
            .whereType<CategoryItem>()
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                '${g.key} · ${g.value.$1}',
                style: const TextStyle(
                  color: Jt3Colors.royalGold,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: items.map((c) => _Tile(item: c, birth: birth)).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final CategoryItem item;
  final BirthInput birth;
  const _Tile({required this.item, required this.birth});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Jt3Radii.card),
      onTap: () => _showInfoSheet(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Jt3Colors.deepNight,
          borderRadius: BorderRadius.circular(Jt3Radii.card),
          border: Border.all(color: Jt3Colors.royalGold.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.code,
              style: const TextStyle(
                color: Jt3Colors.antiqueGold,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Jt3Colors.starWhite,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ② 정보창
  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Jt3Colors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${item.code} · ${item.name}',
              style: const TextStyle(
                color: Jt3Colors.royalGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '일간·십신·오행·용신 등 정통사주 계산값으로 산출됩니다.',
              style: TextStyle(color: Jt3Colors.moonSilver, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // ③ 로딩 → ④ 결과
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Jt3Colors.royalGold,
                foregroundColor: Jt3Colors.inkBlack,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Jt3Radii.button),
                ),
              ),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Jeontong69LoadingScreen(
                      birth: birth,
                      targetCode: item.code,
                    ),
                  ),
                );
              },
              child: const Text(
                '사주보기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
