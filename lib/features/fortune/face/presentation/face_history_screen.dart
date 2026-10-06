import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/web_ads/web_ad_config.dart';
import '../../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/face_provider.dart';

class FaceHistoryScreen extends StatefulWidget {
  const FaceHistoryScreen({super.key});

  @override
  State<FaceHistoryScreen> createState() => _FaceHistoryScreenState();
}

class _FaceHistoryScreenState extends State<FaceHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<FaceProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<FaceProvider>().history;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('관상 히스토리', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(
                icon: Icons.face_retouching_natural_outlined,
                title: '아직 분석 기록이 없어요',
              )
            : ListView.separated(
                padding: EdgeInsets.all(UnifiedTokens.screenPadding),
                // [웹 일반 AdSense 전체 확장 — 관상] 히스토리 리스트 끝에
                // 광고 아이템 1개 추가(기록이 있을 때만 — 비어있으면 위의
                // AppEmptyState 분기가 먼저 적용되어 광고도 노출되지 않음).
                itemCount: history.length + 1,
                separatorBuilder: (_, __) =>
                    SizedBox(height: UnifiedTokens.spaceMd),
                itemBuilder: (context, index) {
                  if (index == history.length) {
                    return const WebAdInPage(
                      surface: WebAdSurface.face,
                      adSlot: '',
                    );
                  }
                  final item = history[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/ai-fortune/face/result', arguments: item.id),
                    child: Container(
                      padding: EdgeInsets.all(UnifiedTokens.screenPadding),
                      decoration: BoxDecoration(
                        color: UnifiedColors.cardSection,
                        borderRadius: BorderRadius.circular(
                          UnifiedTokens.radiusMd,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.face_retouching_natural_rounded,
                            size: UnifiedTokens.iconLg,
                            color: UnifiedColors.textPrimary,
                          ),
                          SizedBox(width: UnifiedTokens.spaceMd),
                          Expanded(
                            child: Text(
                              '${item.createdAt.year}.${item.createdAt.month}.${item.createdAt.day} 관상 분석',
                              style: UnifiedText.bodyStrong(),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: UnifiedColors.textCaption,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
