import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/compatibility_provider.dart';
import '../domain/compatibility_model.dart';

/// 06§4.5 `GET /compatibility/history` + `GET /compatibility/compare?ids=` 대응 화면
/// 03§9.2 "내 보관함" 재사용 패턴(MyAmuletsScreen/LuckyBagHistoryScreen)과 동일한 구조:
/// 전체 히스토리 리스트 + 저장(isSaved)된 항목 다중선택 비교 기능
class CompatibilityHistoryScreen extends StatefulWidget {
  const CompatibilityHistoryScreen({super.key});

  @override
  State<CompatibilityHistoryScreen> createState() =>
      _CompatibilityHistoryScreenState();
}

class _CompatibilityHistoryScreenState
    extends State<CompatibilityHistoryScreen> {
  final Set<String> _selectedIds = {};
  bool _isComparing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CompatibilityProvider>().loadHistory(),
    );
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _openCompare() async {
    if (_selectedIds.length < 2) {
      AppToast.show(context, '비교하려면 2개 이상 선택해 주세요.', isError: true);
      return;
    }
    setState(() => _isComparing = true);
    final ok = await context.read<CompatibilityProvider>().compare(
      _selectedIds.toList(),
    );
    if (!mounted) return;
    setState(() => _isComparing = false);
    if (!ok) {
      AppToast.show(context, '비교표를 불러오지 못했습니다.', isError: true);
      return;
    }
    final provider = context.read<CompatibilityProvider>();
    final targets = provider.history
        .where((r) => _selectedIds.contains(r.id))
        .toList();
    if (!mounted) return;
    showAppBottomSheet(
      context,
      title: '궁합 비교',
      child: _CompareTable(rows: provider.compareRows, targets: targets),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompatibilityProvider>();
    final history = provider.history;
    final savedCount = history.where((r) => r.isSaved).length;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('궁합 보관함', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(
                icon: Icons.favorite_border_rounded,
                title: '아직 궁합 분석 이력이 없어요',
                description: 'AI 궁합을 분석하고 결과를 저장해 보세요',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    context.read<CompatibilityProvider>().loadHistory(),
                child: ListView.builder(
                  padding: EdgeInsets.all(UnifiedTokens.screenPadding),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return _HistoryTile(
                      result: item,
                      selected: _selectedIds.contains(item.id),
                      onToggle: item.isSaved
                          ? () => _toggleSelect(item.id)
                          : null,
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: savedCount >= 2
          ? FloatingActionButton.extended(
              onPressed: _isComparing ? null : _openCompare,
              backgroundColor: UnifiedColors.black,
              icon: _isComparing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.compare_arrows_rounded,
                      color: Colors.white,
                    ),
              label: Text(
                '비교하기 (${_selectedIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final CompatibilityResultModel result;
  final bool selected;
  final VoidCallback? onToggle;

  const _HistoryTile({
    required this.result,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      child: Container(
        padding: EdgeInsets.all(UnifiedTokens.spaceXl),
        decoration: BoxDecoration(
          color: UnifiedColors.cardSection,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
          border: selected
              ? Border.all(color: UnifiedColors.black, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            if (onToggle != null)
              Checkbox(value: selected, onChanged: (_) => onToggle!())
            else
              SizedBox(
                width: 40,
                child: Icon(
                  Icons.bookmark_border_rounded,
                  size: 18,
                  color: UnifiedColors.textCaption,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.nameA} ❤ ${result.nameB}',
                    style: UnifiedText.bodyStrong(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.type.label} · ${result.createdAt.month}.${result.createdAt.day}',
                    style: UnifiedText.bodySmall(
                      color: UnifiedColors.textCaption,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: UnifiedColors.cardAllMenu,
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
              ),
              child: Text(
                '${result.score}점',
                style: UnifiedText.chipLabel(color: UnifiedColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  final List<CompatibilityCompareRow> rows;
  final List<CompatibilityResultModel> targets;

  const _CompareTable({required this.rows, required this.targets});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('항목', style: UnifiedText.bodyStrong())),
          ...targets.map(
            (t) => DataColumn(
              label: Text(
                '${t.nameA}❤${t.nameB}',
                style: UnifiedText.bodyStrong(),
              ),
            ),
          ),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.topic, style: UnifiedText.bodyStrong())),
                  ...targets.map(
                    (t) => DataCell(
                      SizedBox(
                        width: 160,
                        child: Text(
                          row.valueByResultId[t.id] ?? '-',
                          style: UnifiedText.caption(
                            color: UnifiedColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
