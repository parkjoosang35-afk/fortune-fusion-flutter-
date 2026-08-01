import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/intro_shell.dart';
import '../../../../core/widgets/result_card_stack.dart';
import '../../presentation/fortune_hub_screen.dart';
import '../application/daily_fortune_provider.dart';

/// 03단계 §3.3 홈 탭 - DailyFortuneDetailScreen
///
/// [서브 디자인 통일 확산 프롬프트] "한 화면의 완성"이 아니라 앱 전체 운세
/// 카테고리가 재사용할 표준 플로우를 만드는 작업의 기준 화면. 이 화면이
/// 완성되면 사주/궁합/타로/관상/손금 결과 화면은 UI를 다시 만들지 않고
/// `ResultCardStack`에 데이터(히어로 문구/섹션 목록/CTA 목록)만 채워
/// 넣으면 동일한 톤을 그대로 얻는다.
///
/// [Phase22-2] 로딩 상태에는 SkeletonCard 대신 IntroShell(호명→소환→참여→개안)을
/// 노출하여 "오늘의 운세"를 받아오는 과정에 의례감을 부여한다(라이트 톤).
class DailyFortuneDetailScreen extends StatefulWidget {
  const DailyFortuneDetailScreen({super.key});

  @override
  State<DailyFortuneDetailScreen> createState() =>
      _DailyFortuneDetailScreenState();
}

class _DailyFortuneDetailScreenState extends State<DailyFortuneDetailScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyFortuneProvider>();
    final today = provider.today;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('오늘의 운세', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: _error != null
            ? _buildError(context)
            : provider.isLoading || today == null
            ? IntroShell<void>(
                task: () => context.read<DailyFortuneProvider>().loadToday(),
                centerIcon: Icons.auto_awesome_rounded,
                onComplete: (_) {
                  if (!mounted) return;
                  if (context.read<DailyFortuneProvider>().today == null) {
                    setState(() => _error = '운세를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
                  }
                },
                onError: (_) {
                  if (!mounted) return;
                  setState(() => _error = '운세를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
                },
              )
            : ResultCardStack(
                heroCaption: '${today.date.month}월 ${today.date.day}일의 운세',
                heroSummary: today.summaryText,
                heroChips: [
                  _luckyChip(Icons.palette_outlined, '행운의 색', today.luckyColor),
                  _luckyChip(
                    Icons.pin_outlined,
                    '행운의 숫자',
                    '${today.luckyNumber}',
                  ),
                ],
                sectionTitle: '세부 운세',
                sections: today.categoryScores.entries
                    .map(
                      (e) => ResultSection(
                        title: e.key,
                        body: '${e.value}점 · ${_scoreComment(e.value)}',
                      ),
                    )
                    .toList(),
                ctas: [
                  ResultCta(
                    label: '다른 운세 보러가기',
                    icon: Icons.explore_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FortuneHubScreen(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _scoreComment(int score) {
    if (score >= 80) return '아주 좋아요';
    if (score >= 60) return '좋은 흐름이에요';
    if (score >= 40) return '무난해요';
    return '조심이 필요해요';
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: UnifiedColors.textCaption,
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            Text(
              _error ?? '알 수 없는 오류가 발생했어요.',
              textAlign: TextAlign.center,
              style: UnifiedText.body(),
            ),
            const SizedBox(height: UnifiedTokens.spaceLg),
            TextButton(
              onPressed: () => setState(() => _error = null),
              child: Text('다시 시도', style: UnifiedText.bodyStrong()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _luckyChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: UnifiedTokens.spaceSm,
        horizontal: UnifiedTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: UnifiedColors.textSecondary,
            size: UnifiedTokens.iconMd,
          ),
          const SizedBox(width: UnifiedTokens.spaceXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: UnifiedText.caption()),
                Text(value, style: UnifiedText.bodyStrong()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
