import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/web_ads/web_ad_config.dart';
import '../../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../../../mypage/presentation/theme/mypage_archive_widgets.dart';
import '../application/palm_provider.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S06/S08] design_handoff_mypage_
/// minimal.zip README "S06 운세 보관함 목록(공용)"/"S08 빈 상태" 스펙에
/// 따라 Minimal 테마 공용 위젯으로 리스킨한다. [PalmProvider.loadHistory]
/// 데이터 조회 로직 및 하단 광고([WebAdInPage]) 배치는 그대로 유지한다 —
/// "로직은 그대로, 스킨만 교체" 원칙.
class PalmHistoryScreen extends StatefulWidget {
  const PalmHistoryScreen({super.key});

  @override
  State<PalmHistoryScreen> createState() => _PalmHistoryScreenState();
}

class _PalmHistoryScreenState extends State<PalmHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PalmProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<PalmProvider>().history;

    return MyPageArchiveScaffold(
      title: '손금 히스토리',
      itemCount: history.length,
      isLoading: false,
      body: history.isEmpty
          ? MyPageArchiveEmptyState(
              glyph: '掌\n相',
              title: '아직 분석 기록이 없어요',
              subtitle: '손금을 분석하면 이곳에 차곡차곡 쌓여요',
              ctaLabel: '손금 보러 가기 ›',
              onCta: () =>
                  Navigator.of(context).pushNamed('/ai-fortune/palm/capture'),
            )
          : Column(
              children: [
                for (final item in history)
                  MyPageArchiveRow(
                    glyph: '掌',
                    tileIndex: 3,
                    dateLabel:
                        '${item.createdAt.year} · ${item.createdAt.month.toString().padLeft(2, '0')} · ${item.createdAt.day.toString().padLeft(2, '0')}',
                    title: '손금 분석',
                    summary: item.summary,
                    onTap: () => Navigator.of(context).pushNamed(
                      '/ai-fortune/palm/result',
                      arguments: item.id,
                    ),
                  ),
                // [웹 일반 AdSense 전체 확장 — 손금] 기록이 있을 때만
                // 광고 1개를 그대로 유지한다.
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: WebAdInPage(surface: WebAdSurface.palm, adSlot: ''),
                ),
              ],
            ),
    );
  }
}
