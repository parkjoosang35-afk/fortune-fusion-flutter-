import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/web_ads/web_ad_config.dart';
import '../../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../../../mypage/presentation/theme/mypage_archive_widgets.dart';
import '../application/face_provider.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S06/S08] design_handoff_mypage_
/// minimal.zip README "S06 운세 보관함 목록(공용)"/"S08 빈 상태" 스펙에
/// 따라 Minimal 테마 공용 위젯으로 리스킨한다. [FaceProvider.loadHistory]
/// 데이터 조회 로직 및 하단 광고([WebAdInPage]) 배치는 그대로 유지한다 —
/// "로직은 그대로, 스킨만 교체" 원칙.
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

    return MyPageArchiveScaffold(
      title: '관상 히스토리',
      itemCount: history.length,
      isLoading: false,
      body: history.isEmpty
          ? MyPageArchiveEmptyState(
              glyph: '觀\n相',
              title: '아직 분석 기록이 없어요',
              subtitle: '관상을 분석하면 이곳에 차곡차곡 쌓여요',
              ctaLabel: '관상 보러 가기 ›',
              onCta: () =>
                  Navigator.of(context).pushNamed('/ai-fortune/face/capture'),
            )
          : Column(
              children: [
                for (final item in history)
                  MyPageArchiveRow(
                    glyph: '觀',
                    tileIndex: 2,
                    dateLabel:
                        '${item.createdAt.year} · ${item.createdAt.month.toString().padLeft(2, '0')} · ${item.createdAt.day.toString().padLeft(2, '0')}',
                    title: '관상 분석',
                    summary: item.summary,
                    onTap: () => Navigator.of(context).pushNamed(
                      '/ai-fortune/face/result',
                      arguments: item.id,
                    ),
                  ),
                // [웹 일반 AdSense 전체 확장 — 관상] 기록이 있을 때만
                // 광고 1개를 그대로 유지한다.
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: WebAdInPage(surface: WebAdSurface.face, adSlot: ''),
                ),
              ],
            ),
    );
  }
}
