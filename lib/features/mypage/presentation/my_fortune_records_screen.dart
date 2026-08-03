import 'package:flutter/material.dart';
import '../../../core/data/my_fortune_record_store.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_empty_state.dart';

/// [오늘의 운세 표준 플로우] §6 후속연결 "저장 → 마이 → 내 운세 기록에 카드 저장"의
/// 실제 조회 화면. 카테고리 무관 공용 저장소([MyFortuneRecordStore])를 그대로
/// 읽어오므로, 사주/궁합/타로 등 다른 카테고리에서 저장한 기록도 함께 노출된다.
class MyFortuneRecordsScreen extends StatefulWidget {
  const MyFortuneRecordsScreen({super.key});

  @override
  State<MyFortuneRecordsScreen> createState() => _MyFortuneRecordsScreenState();
}

class _MyFortuneRecordsScreenState extends State<MyFortuneRecordsScreen> {
  List<SavedFortuneRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await MyFortuneRecordStore.list();
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('내 운세 기록', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
            ? const AppEmptyState(
                icon: Icons.bookmark_border_rounded,
                title: '저장된 운세 기록이 없어요',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
                itemCount: _records.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: UnifiedTokens.spaceMd),
                itemBuilder: (context, i) {
                  final r = _records[i];
                  return PremiumCard(
                    backgroundColor: UnifiedColors.cardSection,
                    borderColor: Colors.transparent,
                    showShadow: false,
                    borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
                    padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    r.categoryLabel,
                                    style: UnifiedText.caption(),
                                  ),
                                  const SizedBox(width: UnifiedTokens.spaceSm),
                                  Text(
                                    '${r.date.month}월 ${r.date.day}일',
                                    style: UnifiedText.caption(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: UnifiedTokens.spaceXs),
                              Text(r.title, style: UnifiedText.title()),
                              const SizedBox(height: UnifiedTokens.spaceXs),
                              Text(
                                r.summary,
                                style: UnifiedText.body(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: UnifiedTokens.spaceSm),
                        Text('${r.score}', style: UnifiedText.titleLarge()),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
