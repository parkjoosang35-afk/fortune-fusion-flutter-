import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';

/// [Phase22 - "Fortune Fusion 마스터 개발 프롬프트" 3부 IntroShell 철학 이식]
/// 운세/AI서비스 결과를 받아오기 전 보여주는 "의례감 있는" 4단계 인트로 연출.
/// 새 마스터 프롬프트가 제안한 "호명 → 소환 → 참여 → 개안" 4단 구조를 그대로
/// 이식하되, Riverpod/Supabase 신규스택이 아니라 기존 StatefulWidget 패턴으로
/// 구현한다(옵션B - 기존 스택 유지, 철학만 이식).
///
/// [설계] 화면 전체를 대체하는 Scaffold가 아니라 "끼워넣는" 위젯으로 만들어,
/// 호출하는 화면이 AppBar/Scaffold 구조를 유지한 채 body 영역에만 배치할 수
/// 있게 한다(예: DailyFortuneDetailScreen에서 today==null일 때만 노출).
///
/// [동작] [task]는 initState에서 정확히 1회만 실행되며(rebuild되어도 재실행되지
/// 않음, LuckyBagOpenAnimationScreen의 `_started` 플래그 패턴과 동일), 최소
/// [totalDuration] 동안은 애니메이션이 유지된다(작업이 더 빨리 끝나도 의례감을
/// 위해 애니메이션 완료까지 대기). 완료되면 [onComplete]를 호출하고, 실패하면
/// [onError]를 호출한다(둘 다 정확히 1회).
class IntroShellStage {
  final String label;
  final String description;
  final IconData icon;

  const IntroShellStage({
    required this.label,
    required this.description,
    required this.icon,
  });
}

/// 새 마스터 프롬프트 3부가 제안한 기본 4단계 - "호명 → 소환 → 참여 → 개안"
const List<IntroShellStage> kDefaultIntroShellStages = [
  IntroShellStage(
    label: '호명',
    description: '당신의 이름을 우주에 새기고 있어요...',
    icon: Icons.record_voice_over_rounded,
  ),
  IntroShellStage(
    label: '소환',
    description: '흩어진 기운을 하나로 모으고 있어요...',
    icon: Icons.auto_awesome_rounded,
  ),
  IntroShellStage(
    label: '참여',
    description: '당신의 하루가 운명과 이어지고 있어요...',
    icon: Icons.diversity_3_rounded,
  ),
  IntroShellStage(
    label: '개안',
    description: '드디어 눈이 열리며 답이 보여요...',
    icon: Icons.remove_red_eye_rounded,
  ),
];

class IntroShell<T> extends StatefulWidget {
  /// 실행할 비동기 작업(예: `() => provider.loadToday()`). initState에서 1회만 호출된다.
  final Future<T> Function() task;

  /// 작업 성공 + 최소 애니메이션 시간 경과 후 정확히 1회 호출된다.
  final void Function(T result) onComplete;

  /// 작업 실패 시 정확히 1회 호출된다(미지정 시 onComplete만 로그로 남기고 무시).
  final void Function(Object error)? onError;

  /// 표시할 4단계(기본값: kDefaultIntroShellStages - 호명/소환/참여/개안).
  final List<IntroShellStage> stages;

  /// 애니메이션 최소 지속시간(작업이 더 빨리 끝나도 의례감을 위해 이 시간만큼 대기).
  final Duration totalDuration;

  /// 중앙에 표시할 심볼(이모지). [centerIcon]이 지정되면 이모지 대신 사용된다.
  final String centerEmoji;

  /// [서브 디자인 통일 확산 프롬프트] 이모지 남용 금지 원칙에 맞춰 중앙 심볼을
  /// 라인 아이콘으로 대체할 수 있는 선택적 오버라이드(지정 시 [centerEmoji]보다 우선).
  final IconData? centerIcon;

  const IntroShell({
    super.key,
    required this.task,
    required this.onComplete,
    this.onError,
    this.stages = kDefaultIntroShellStages,
    this.totalDuration = const Duration(milliseconds: 2800),
    this.centerEmoji = '🔮',
    this.centerIcon,
  });

  @override
  State<IntroShell<T>> createState() => _IntroShellState<T>();
}

class _IntroShellState<T> extends State<IntroShell<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;

    final animationFuture = _controller.forward();

    try {
      final result = await widget.task();
      await animationFuture; // 최소 애니메이션 지속시간 보장(의례감)
      if (!mounted) return;
      widget.onComplete(result);
    } catch (e) {
      await animationFuture;
      if (!mounted) return;
      if (widget.onError != null) {
        widget.onError!(e);
      }
    }
  }

  int _stageIndexOf(double t) {
    final stageCount = widget.stages.length;
    final idx = (t * stageCount).floor();
    return idx.clamp(0, stageCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: UnifiedColors.cardMain,
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final stageIndex = _stageIndexOf(t);
              final stage = widget.stages[stageIndex];

              // 각 단계 내에서의 진행률(0~1) - 반짝임/스케일 연출에 사용
              final stageCount = widget.stages.length;
              final stageLocalT = ((t * stageCount) - stageIndex).clamp(
                0.0,
                1.0,
              );
              final pulse =
                  0.9 + (sin(stageLocalT * pi) * 0.12).clamp(-0.12, 0.12);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.spaceXl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ..._buildSparkles(stageLocalT, stageIndex),
                          Transform.scale(
                            scale: pulse,
                            child: widget.centerIcon != null
                                ? Container(
                                    width: 72,
                                    height: 72,
                                    decoration: const BoxDecoration(
                                      color: UnifiedColors.bg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      widget.centerIcon,
                                      size: 32,
                                      color: UnifiedColors.textPrimary,
                                    ),
                                  )
                                : Text(
                                    widget.centerEmoji,
                                    style: const TextStyle(fontSize: 56),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceXxl),
                    // 4단계 진행 인디케이터(점)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(stageCount, (i) {
                        final active = i <= stageIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? UnifiedColors.black
                                : UnifiedColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceLg),
                    Icon(
                      stage.icon,
                      color: UnifiedColors.textSecondary,
                      size: UnifiedTokens.iconLg,
                    ),
                    const SizedBox(height: UnifiedTokens.spaceSm),
                    Text(stage.label, style: UnifiedText.title()),
                    const SizedBox(height: UnifiedTokens.spaceXs),
                    Text(
                      stage.description,
                      style: UnifiedText.body(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSparkles(double stageLocalT, int stageIndex) {
    // 마지막 단계("개안")에서는 반짝임을 더 풍성하게 표현
    final isLastStage = stageIndex == widget.stages.length - 1;
    final count = isLastStage ? 10 : 6;
    final opacity = (sin(stageLocalT * pi)).clamp(0.0, 1.0);

    return List.generate(count, (i) {
      final angle = (2 * pi / count) * i;
      final distance = 55 + stageLocalT * 30;
      final dx = cos(angle) * distance;
      final dy = sin(angle) * distance;
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: opacity * 0.7,
          child: Icon(
            Icons.star_rounded,
            size: 10 + (i % 3) * 3,
            color: UnifiedColors.textCaption,
          ),
        ),
      );
    });
  }
}
