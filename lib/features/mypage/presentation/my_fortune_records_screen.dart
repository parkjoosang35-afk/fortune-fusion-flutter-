import 'package:flutter/material.dart';
import '../../../core/data/my_fortune_record_store.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../saju_renewal/navigation/saju_dimension_transition.dart';

/// [오늘의 운세 표준 플로우] §6 후속연결 "저장 → 마이 → 내 운세 기록에 카드 저장"의
/// 실제 조회 화면. 카테고리 무관 공용 저장소([MyFortuneRecordStore])를 그대로
/// 읽어오므로, 사주/궁합/타로 등 다른 카테고리에서 저장한 기록도 함께 노출된다.
///
/// [마이페이지 리뉴얼 · DEV 2026-10-11] 마이페이지 "사주 히스토리" 카드가
/// 기존에는 정통사주 실행 화면(`/saju-renewal`)으로 바로 이동해 기록 목록이
/// 아예 보이지 않는 버그가 있었다. 전용 사주 기록 목록 화면을 새로 만드는
/// 대신(§B안), 이미 있는 이 공용 기록 화면을 [categoryFilter]로 재사용해
/// "사주" 카테고리만 걸러 보여준다 — 신규 화면/저장소를 만들지 않고 기존
/// 인프라를 그대로 확장하는 방식(B안 범위 최소화 원칙).
class MyFortuneRecordsScreen extends StatefulWidget {
  const MyFortuneRecordsScreen({super.key, this.categoryFilter});

  /// null이면 전체 기록, 값이 있으면 해당 카테고리만 필터링해 보여준다.
  /// 예: '사주'.
  final String? categoryFilter;

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
    final filter = widget.categoryFilter;
    final list = filter != null
        ? await MyFortuneRecordStore.listByCategory(filter)
        : await MyFortuneRecordStore.list();
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  /// [마이페이지 리뉴얼 시안 "빈 화면 시안"] 사주 히스토리가 비어있을 때는
  /// 공용 문구 대신 "정통사주 보러가기" CTA가 있는 사주 전용 빈 상태를
  /// 보여준다 — 시안이 "정통사주로 가는 길은 빈 화면의 버튼으로만"이라고
  /// 명시했으므로, 이 버튼이 saju_renewal로의 유일한 경로가 된다.
  Widget _buildEmptyState(BuildContext context) {
    final isSaju = widget.categoryFilter == '사주';
    if (!isSaju) {
      return const AppEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: '저장된 운세 기록이 없어요',
      );
    }
    return AppEmptyState(
      icon: Icons.auto_stories_outlined,
      title: '아직 저장된 사주 기록이 없어요',
      description: '정통사주를 보면 결과가 이곳에 쌓여요',
      action: Builder(
        builder: (btnContext) => ElevatedButton(
          onPressed: () => Navigator.of(btnContext).pushNamed(
            '/saju-renewal',
            arguments: sajuCardCenterOf(btnContext),
          ),
          child: const Text('정통사주 보러가기'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.categoryFilter == '사주' ? '사주 히스토리' : '내 운세 기록';
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text(title, style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
            ? _buildEmptyState(context)
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
                        if (r.cardImageAssetPath != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              UnifiedTokens.radiusMd,
                            ),
                            child: Image.asset(
                              r.cardImageAssetPath!,
                              width: 48,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox(width: 48, height: 72),
                            ),
                          ),
                          const SizedBox(width: UnifiedTokens.spaceMd),
                        ],
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
                        if (r.score != null) ...[
                          const SizedBox(width: UnifiedTokens.spaceSm),
                          Text('${r.score}', style: UnifiedText.titleLarge()),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
