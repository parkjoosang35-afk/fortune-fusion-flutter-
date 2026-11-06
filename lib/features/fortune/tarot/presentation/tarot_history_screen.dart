import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/web_ads/web_ad_config.dart';
import '../../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../../../mypage/presentation/theme/mypage_archive_widgets.dart';
import '../application/tarot_provider.dart';

/// 03단계 §3.3 - TarotHistoryScreen (히스토리형 패턴)
///
/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S06/S08] design_handoff_mypage_
/// minimal.zip README "S06 운세 보관함 목록(공용)"/"S08 빈 상태" 스펙에
/// 따라 Minimal 테마 공용 위젯으로 리스킨한다. [TarotProvider.loadHistory]
/// 데이터 조회 로직 및 하단 광고([WebAdInPage]) 배치는 그대로 유지한다 —
/// "로직은 그대로, 스킨만 교체" 원칙.
class TarotHistoryScreen extends StatefulWidget {
  const TarotHistoryScreen({super.key});

  @override
  State<TarotHistoryScreen> createState() => _TarotHistoryScreenState();
}

class _TarotHistoryScreenState extends State<TarotHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TarotProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<TarotProvider>().history;

    return MyPageArchiveScaffold(
      title: '타로 히스토리',
      itemCount: history.length,
      isLoading: false,
      body: history.isEmpty
          ? MyPageArchiveEmptyState(
              glyph: '塔\n羅',
              title: '아직 타로 기록이 없어요',
              subtitle: '타로를 뽑아보면 이곳에 차곡차곡 쌓여요',
              ctaLabel: '타로 보러 가기 ›',
              onCta: () => Navigator.of(context).pushNamed('/tarot/home'),
            )
          : Column(
              children: [
                for (final item in history)
                  MyPageArchiveRow(
                    glyph: '塔',
                    tileIndex: 1,
                    dateLabel:
                        '${item.createdAt.year} · ${item.createdAt.month.toString().padLeft(2, '0')} · ${item.createdAt.day.toString().padLeft(2, '0')}',
                    title: item.question,
                    summary: item.summary,
                    onTap: () => Navigator.of(context).pushNamed(
                      '/ai-fortune/tarot/result',
                      arguments: item.id,
                    ),
                  ),
                // [웹 광고 STEP G] 히스토리 리스트 끝에 광고 1개를
                // 그대로 유지한다(기록 탭 CTA와 분리된 별도 아이템).
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: WebAdInPage(surface: WebAdSurface.tarot, adSlot: ''),
                ),
              ],
            ),
    );
  }
}
