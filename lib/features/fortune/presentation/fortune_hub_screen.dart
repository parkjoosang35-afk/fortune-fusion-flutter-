import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_badge.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/presentation/pass_gate_helper.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 운세 허브 화면 (v2)
///
/// 기준 시안(홈 화면)의 "전체운세/사주/궁합/손금" 칩 구조 + 큰 라운드 카드를
/// 운세 탭 전체로 확장한다. 상단에 대표 히어로 카드(오늘의 운세 안내) +
/// 칩형 카테고리 필터 + 카테고리별 카드 리스트로 구성해 메인 화면과 같은
/// 세계관으로 보이게 만든다.
///
/// [주의] 진입 게이트체크 로직(navigateWithPassGate)과 PassProvider는 기존
/// 그대로 재사용한다 — 이번 작업은 디자인/레이아웃 정리이며 기능은 무변경.
class FortuneHubScreen extends StatefulWidget {
  const FortuneHubScreen({super.key});

  @override
  State<FortuneHubScreen> createState() => _FortuneHubScreenState();
}

class _FortuneHubScreenState extends State<FortuneHubScreen> {
  bool _checking = false;
  String _filter = '전체';

  static const _filters = ['전체', '무료', '사주', '타로', '궁합', '손금'];

  static const _items = [
    (
      '오늘의 운세',
      '매일 새로운 종합운을 확인해보세요',
      '☀️',
      '무료',
      '/home/daily-fortune-detail',
      false,
      '전체',
    ),
    (
      '사주',
      'AI가 분석하는 나의 사주 명식',
      '📜',
      '열림패스',
      '/ai-fortune/saju/input',
      true,
      '사주',
    ),
    (
      '타로',
      '78장의 카드가 전하는 오늘의 메시지',
      '🔮',
      '열림패스',
      '/ai-fortune/tarot/question',
      true,
      '타로',
    ),
    (
      '관상',
      '사진으로 보는 AI 관상 분석',
      '🙂',
      '열림패스',
      '/ai-fortune/face/capture',
      true,
      '전체',
    ),
    (
      '손금',
      '손바닥 속에 숨겨진 나의 운명',
      '✋',
      '열림패스',
      '/ai-fortune/palm/capture',
      true,
      '손금',
    ),
    (
      '궁합',
      '두 사람의 인연과 케미를 확인해요',
      '💞',
      '열림패스',
      '/ai-fortune/compatibility/input',
      true,
      '궁합',
    ),
    (
      'AI 상담',
      '실시간 AI 운세 상담사와 대화하기',
      '💬',
      '열림패스',
      '/ai-fortune/consultation/type',
      true,
      '전체',
    ),
  ];

  Future<void> _handleTap({
    required String title,
    required String route,
    required bool requiresPass,
  }) async {
    if (requiresPass) setState(() => _checking = true);
    await navigateWithPassGate(
      context,
      title: title,
      route: route,
      requiresPass: requiresPass,
    );
    if (mounted && requiresPass) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final filtered = _filter == '전체'
        ? _items
        : _filter == '무료'
            ? _items.where((e) => !e.$6).toList()
            : _items.where((e) => e.$7 == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.premiumBgMain,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text('운세', style: AppTypography.heroTitle),
            const SizedBox(height: 4),
            Text('오늘 당신의 운명은 어떤 이야기를 담고 있을까요?', style: AppTypography.bodyMain),
            const SizedBox(height: AppSpacing.lg),

            // 열림패스 상태 히어로 카드 - 기준 시안의 "오늘의 운세 이야기" 카드 톤 재사용.
            FadeSlideIn(
              child: _PassHeroCard(
                isActive: pass.isActive,
                remainingSec: pass.status.remainingSec,
                isBusy: _checking,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 카테고리 칩 필터
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  return PremiumChip(
                    label: f,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            ...List.generate(filtered.length, (index) {
              final (title, desc, emoji, cost, route, requiresPass, _) =
                  filtered[index];
              final isFree = !requiresPass;
              final badgeLabel = isFree ? '무료' : (pass.isActive ? '이용가능' : cost);
              final badgeType = isFree || pass.isActive
                  ? PremiumBadgeType.done
                  : PremiumBadgeType.pass;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 40 * index),
                  child: _FortuneCategoryCard(
                    title: title,
                    desc: desc,
                    emoji: emoji,
                    badgeLabel: badgeLabel,
                    badgeType: badgeType,
                    onTap: _checking
                        ? null
                        : () => _handleTap(
                              title: title,
                              route: route,
                              requiresPass: requiresPass,
                            ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 열림패스 상태를 알리는 히어로 카드 - 연라벤더 그라디언트 + 은은한 그래픽.
class _PassHeroCard extends StatelessWidget {
  const _PassHeroCard({
    required this.isActive,
    required this.remainingSec,
    required this.isBusy,
  });

  final bool isActive;
  final int remainingSec;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final h = remainingSec ~/ 3600;
    final m = (remainingSec % 3600) ~/ 60;
    final timeLabel = h > 0 ? '$h시간 $m분 남음' : '$m분 남음';

    return PremiumCard(
      gradient: AppColors.premiumHeroGradient,
      borderColor: AppColors.premiumCardBorder,
      child: Stack(
        children: [
          const Positioned(top: -6, right: 4, child: FloatingMoon(size: 26)),
          const Positioned(top: 30, right: 34, child: SparkleDot(size: 10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🔓', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    isBusy
                        ? '열림패스 확인 중...'
                        : isActive
                            ? '열림패스 활성중 · $timeLabel'
                            : '열림패스가 없어요',
                    style: AppTypography.cardTitle.copyWith(fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isActive
                    ? '지금 모든 운세 카테고리를 자유롭게 열람할 수 있어요'
                    : '카테고리 진입 시 발급 방법을 안내해드려요',
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 운세 카테고리 카드 - 큰 라운드 카드 + 좌측 정렬 텍스트 + 우측 배지.
class _FortuneCategoryCard extends StatelessWidget {
  const _FortuneCategoryCard({
    required this.title,
    required this.desc,
    required this.emoji,
    required this.badgeLabel,
    required this.badgeType,
    required this.onTap,
  });

  final String title;
  final String desc;
  final String emoji;
  final String badgeLabel;
  final PremiumBadgeType badgeType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.premiumBgSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.cardTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PremiumBadge(label: badgeLabel, type: badgeType),
        ],
      ),
    );
  }
}
