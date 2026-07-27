import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/face_provider.dart';
import '../domain/face_model.dart';

/// 07단계 결과형 패턴 - FaceResultScreen
/// 07단계(추가) §3.3 - 손금(PalmResultScreen)과 동일한 시각적 업그레이드 적용
class FaceResultScreen extends StatefulWidget {
  final String? resultId;
  const FaceResultScreen({super.key, this.resultId});

  @override
  State<FaceResultScreen> createState() => _FaceResultScreenState();
}

class _FaceResultScreenState extends State<FaceResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<FaceProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaceProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('관상 결과'),
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
          LoadStatus.success => _FaceResultBody(
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
                        ).pushNamed('/ai-fortune/face/history'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('히스토리'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/face/capture'),
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

/// 07단계(추가) §3.3 - 관상 부위별 색상 매핑
/// 이마=골드, 눈=블루, 코=그린, 입=핑크(레드 계열), 턱=퍼플
const Map<String, Color> _featureColors = {
  '이마': AppColors.secondary,
  '눈': AppColors.info,
  '코': AppColors.success,
  '입': AppColors.error,
  '턱': AppColors.primary,
};

/// 07단계(추가) §3.3 - 주제별 아이콘/이모지 매핑 (손금과 동일)
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
/// 종합 요약 카드 → 부위별 특징 카드 → 주제별 카드 순으로 위→아래 순차 등장
class _FaceResultBody extends StatefulWidget {
  final FaceResultModel result;
  const _FaceResultBody({super.key, required this.result});

  @override
  State<_FaceResultBody> createState() => _FaceResultBodyState();
}

class _FaceResultBodyState extends State<_FaceResultBody>
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
    final totalCards = 1 + result.features.length + topicEntries.length;

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
        Text('부위별 특징', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...result.features.entries.map(
          (e) => staggeredCard(
            child: _FeatureTile(part: e.key, text: e.value),
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
            '종합 관상 해석',
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

/// 부위별 특징 카드 - 부위별 색상 구분 + elevation/호버 효과
class _FeatureTile extends StatefulWidget {
  final String part;
  final String text;
  const _FeatureTile({required this.part, required this.text});

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<_FeatureTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _featureColors[widget.part] ?? AppColors.primary;

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
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  widget.part,
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
