import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/palm_provider.dart';
import '../domain/palm_model.dart';

class PalmResultScreen extends StatefulWidget {
  final String? resultId;
  const PalmResultScreen({super.key, this.resultId});

  @override
  State<PalmResultScreen> createState() => _PalmResultScreenState();
}

class _PalmResultScreenState extends State<PalmResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PalmProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PalmProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('손금 결과'),
        actions: [
          if (state.isSuccess)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => AppToast.show(context, '공유 링크가 복사되었습니다.'),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          LoadStatus.error => AppErrorState(
            message: state.errorMessage ?? '분석에 실패했습니다.',
            onRetry: () => provider.retry(),
          ),
          // 07단계(추가) §3.3 - 결과 데이터가 바뀔 때마다(id 기준) 새 위젯 인스턴스를 생성하여
          // FadeInUp + Staggered 진입 애니메이션이 매번 재생되도록 한다.
          LoadStatus.success => _PalmResultBody(
            key: ValueKey(state.data!.id),
            result: state.data!,
          ),
          LoadStatus.initial => const AppErrorState(message: '입력 정보가 없습니다.'),
        },
      ),
      bottomNavigationBar: state.isSuccess
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/palm/history'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('히스토리'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/palm/capture'),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('다시 분석'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// 07단계(추가) §3.3 - 손금선별 색상 매핑
/// 생명선=초록, 두뇌선=파랑, 감정선=빨강, 운명선=보라
const Map<String, Color> _lineColors = {
  '생명선': AppColors.success,
  '두뇌선': AppColors.info,
  '감정선': AppColors.error,
  '운명선': AppColors.primary,
};

/// 07단계(추가) §3.3 - 주제별 아이콘/이모지 매핑
/// 재물=💰, 애정=💕, 직업=💼, 건강=❤️
const Map<String, String> _topicEmojis = {
  '재물': '💰',
  '애정': '💕',
  '직업': '💼',
  '건강': '❤️',
};

const Map<String, IconData> _topicIcons = {
  '재물': Icons.payments_rounded,
  '애정': Icons.favorite_rounded,
  '직업': Icons.work_rounded,
  '건강': Icons.health_and_safety_rounded,
};

/// 결과 화면 본문 - FadeInUp + Staggered Animation 적용
/// 종합 요약 카드 → 손금선 카드(4) → 주제별 카드(4) 순으로 위→아래 순차 등장
class _PalmResultBody extends StatefulWidget {
  final PalmResultModel result;
  const _PalmResultBody({super.key, required this.result});

  @override
  State<_PalmResultBody> createState() => _PalmResultBodyState();
}

class _PalmResultBodyState extends State<_PalmResultBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// index번째 카드의 등장 구간(Interval)을 계산하여 Staggered 효과를 만든다.
  /// 07단계(추가) §3.3 - Curves.easeInOutCubic로 부드러운 트랜지션 적용
  Animation<double> _staggerFor(int index, int totalCount) {
    final start = (index / totalCount) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeInOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final topicEntries = result.topicResults.entries
        .where((e) => e.key != '종합')
        .toList();
    // 카드 총 개수 = 요약(1) + 손금선(N) + 주제(M)
    final totalCards = 1 + result.lines.length + topicEntries.length;

    int cardIndex = 0;

    Widget staggeredCard({required Widget child}) {
      final animation = _staggerFor(cardIndex, totalCards);
      cardIndex++;
      return _FadeInUpTransition(animation: animation, child: child);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        staggeredCard(child: _SummaryCard(summary: result.summary)),
        const SizedBox(height: AppSpacing.xl),
        Text('주요 손금선', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...result.lines.entries.map(
          (e) => staggeredCard(
            child: _LineTile(name: e.key, text: e.value),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('주제별 해석', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...topicEntries.map(
          (e) => staggeredCard(
            child: _TopicCard(name: e.key, text: e.value),
          ),
        ),
      ],
    );
  }
}

/// 공용 FadeInUp 진입 트랜지션 - 07단계(추가) §3.3
class _FadeInUpTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeInUpTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// 종합 요약 카드 - 상단→하단 그래디언트 배경
class _SummaryCard extends StatelessWidget {
  final String summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.deepSpace,
            AppColors.primaryDark,
            AppColors.deepSpaceLight,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '종합 손금 해석',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.onDeepSpace,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4대 손금선 카드 - 손금선별 색상 구분 + elevation/그림자
class _LineTile extends StatefulWidget {
  final String name;
  final String text;
  const _LineTile({required this.name, required this.text});

  @override
  State<_LineTile> createState() => _LineTileState();
}

class _LineTileState extends State<_LineTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _lineColors[widget.name] ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _hovered ? 0.28 : 0.14),
                blurRadius: _hovered ? 14 : 8,
                offset: Offset(0, _hovered ? 6 : 3),
              ),
            ],
          ),
          transform: _hovered
              ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  widget.name,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.text,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 주제별 해석 카드 - 아이콘 + 제목 + 텍스트, elevation/호버 효과
class _TopicCard extends StatefulWidget {
  final String name;
  final String text;
  const _TopicCard({required this.name, required this.text});

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final emoji = _topicEmojis[widget.name] ?? '✨';
    final icon = _topicIcons[widget.name] ?? Icons.auto_awesome_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: _hovered ? 0.20 : 0.10,
                ),
                blurRadius: _hovered ? 16 : 8,
                offset: Offset(0, _hovered ? 8 : 4),
              ),
            ],
          ),
          transform: _hovered
              ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer,
                    ),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$emoji ${widget.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.text,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
