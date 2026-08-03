import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/tarot_provider.dart';
import '../domain/tarot_model.dart';
import '../domain/tarot_reading_extras.dart';
import 'widgets/tarot_mystic_background.dart';
import 'widgets/tarot_particle_burst.dart';

/// [AI 타로 리딩 UX/UI 개선 §4~7,§9] TarotResultScreen 전면 재구성.
///
/// 기존(단순 ListView + Fade In)을 대체해 "결과가 등장하는 순간"을 한 편의
/// 짧은 영화처럼 연출한다. 두 개의 독립된 타임라인으로 구성한다:
///
/// 1) [_HeroRevealOverlay] - §4의 암전→빛수렴→카드확대→플립→강한빛→
///    별가루폭발→카드이름 시퀀스를 화면 전체를 덮는 오버레이로 한 번만 재생한다.
/// 2) [_ResultContent] - 오버레이가 끝나는 순간 시작되는 §6(①~⑦) 순차 등장
///    콘텐츠 목록. 두 타임라인은 오버레이의 `overlayFade`(0.93~1.0 구간)와
///    콘텐츠의 첫 항목 등장(0.0~ 구간)이 겹치도록 설계해 부드럽게 크로스페이드된다.
///
/// [재생 1회 보장] `_TarotResultCinematic`을 `ValueKey(result.id)`로 감싸,
/// 같은 결과 화면 내에서 Provider가 notifyListeners()로 리빌드되어도(공유
/// 버튼 클릭 등) State가 재사용되어 애니메이션이 처음부터 다시 재생되지
/// 않는다 - 오직 "새로운" 결과(id 변경)일 때만 새로 재생된다.
class TarotResultScreen extends StatefulWidget {
  final String? resultId;
  const TarotResultScreen({super.key, this.resultId});

  @override
  State<TarotResultScreen> createState() => _TarotResultScreenState();
}

class _TarotResultScreenState extends State<TarotResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TarotProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TarotProvider>();
    final state = provider.state;

    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      appBar: AppBar(
        backgroundColor: AppColors.deepSpace,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('타로 결과'),
        actions: [
          if (state.isSuccess)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => AppToast.show(context, '공유 링크가 복사되었습니다.'),
            ),
        ],
      ),
      body: switch (state.status) {
        LoadStatus.loading => const Center(child: CircularProgressIndicator()),
        LoadStatus.error => SafeArea(
          child: AppErrorState(
            message: state.errorMessage ?? '타로 리딩에 실패했습니다.',
            onRetry: () => provider.retry(),
          ),
        ),
        LoadStatus.success => _TarotResultCinematic(
          key: ValueKey(state.data!.id),
          result: state.data!,
        ),
        LoadStatus.initial => const SafeArea(
          child: AppErrorState(message: '입력 정보가 없습니다.'),
        ),
      },
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
                        ).pushNamed('/ai-fortune/tarot/history'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('히스토리'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/tarot/question'),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('다시 뽑기'),
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

/// [t]가 [start]~[end] 구간을 지나는 동안 [from]~[to]로 보간하는 헬퍼.
/// 구간 이전이면 [from], 이후면 [to]를 반환한다(값 유출 방지를 위한 클램프 포함).
double _lerpRange(
  double t,
  double start,
  double end,
  double from,
  double to, [
  Curve curve = Curves.linear,
]) {
  if (end <= start) return t < start ? from : to;
  if (t <= start) return from;
  if (t >= end) return to;
  final p = curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
  return from + (to - from) * p;
}

/// 결과 화면의 시네마틱 두 타임라인(리빌 오버레이 + 콘텐츠 순차 등장)을 관리한다.
class _TarotResultCinematic extends StatefulWidget {
  final TarotResultModel result;
  const _TarotResultCinematic({super.key, required this.result});

  @override
  State<_TarotResultCinematic> createState() => _TarotResultCinematicState();
}

class _TarotResultCinematicState extends State<_TarotResultCinematic>
    with TickerProviderStateMixin {
  static const _revealDuration = Duration(milliseconds: 3600);
  static const _contentDuration = Duration(milliseconds: 2600);

  late final AnimationController _revealController;
  late final AnimationController _contentController;

  bool _contentStarted = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: _revealDuration,
    );
    _contentController = AnimationController(
      vsync: this,
      duration: _contentDuration,
    );
    _revealController.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _contentStarted = true);
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroCard = widget.result.positions.first.card;
    return Stack(
      children: [
        // §7 "배경 애니메이션(결과화면)" - 살아있지만 "너무 화려하지 않게".
        const TarotMysticBackground(intensity: 0.55),
        SafeArea(
          child: AnimatedBuilder(
            animation: _contentController,
            builder: (context, _) {
              return _ResultContent(
                result: widget.result,
                progress: _contentController.value,
                started: _contentStarted,
              );
            },
          ),
        ),
        // §4 "결과 등장 연출" - 화면 전체를 덮는 1회성 시네마틱 오버레이.
        AnimatedBuilder(
          animation: _revealController,
          builder: (context, _) {
            final t = _revealController.value;
            if (t >= 1.0) return const SizedBox.shrink();
            return _HeroRevealOverlay(card: heroCard, t: t);
          },
        ),
      ],
    );
  }
}

/// §4의 전체 시퀀스(암전→빛수렴→카드확대→플립→강한빛→별가루폭발→카드이름)를
/// 단일 진행값 [t](0.0~1.0)에서 구간별로 파생시켜 그리는 오버레이.
/// §5 "카드 등장 방식"(확대→회전→빛→튕김→멈춤)도 이 안에서 함께 구현된다
/// (카드 확대에 [Curves.elasticOut]을 사용해 "살짝 튕김" 효과를 낸다).
class _HeroRevealOverlay extends StatelessWidget {
  final TarotCard card;
  final double t;
  const _HeroRevealOverlay({required this.card, required this.t});

  @override
  Widget build(BuildContext context) {
    // 1) 화면이 잠시 어두워짐
    final darkOpacity = t < 0.16
        ? _lerpRange(t, 0.0, 0.08, 0.0, 0.85)
        : _lerpRange(t, 0.16, 0.32, 0.85, 0.0);
    // 2) 빛이 화면 중앙으로 모임
    final convergeScale = _lerpRange(
      t,
      0.06,
      0.30,
      1.7,
      0.55,
      Curves.easeInOut,
    );
    final convergeOpacity = _lerpRange(t, 0.06, 0.30, 0.0, 0.9, Curves.easeIn);
    // 3) 카드가 크게 등장(확대 + 살짝 튕김) + 4) 카드가 뒤집힘
    final cardOpacity = _lerpRange(t, 0.28, 0.36, 0.0, 1.0);
    final cardScale = _lerpRange(t, 0.28, 0.54, 0.3, 1.0, Curves.elasticOut);
    final flipAngle = _lerpRange(t, 0.50, 0.70, 0.0, pi, Curves.easeInOut);
    // 5) 강한 빛
    final flashOpacity = t < 0.72
        ? _lerpRange(t, 0.66, 0.72, 0.0, 1.0)
        : _lerpRange(t, 0.72, 0.80, 1.0, 0.0);
    // 6) 별가루 폭발
    final burstProgress = _lerpRange(t, 0.68, 0.95, 0.0, 1.0);
    // 7) 카드 이름 등장
    final nameOpacity = _lerpRange(t, 0.80, 0.94, 0.0, 1.0);
    final nameSlide = _lerpRange(t, 0.80, 0.94, 14, 0);
    // 오버레이 전체 페이드아웃(콘텐츠 타임라인과 크로스페이드되도록)
    final overlayFade = _lerpRange(t, 0.93, 1.0, 1.0, 0.0);

    final isFront = flipAngle > pi / 2;

    return Opacity(
      opacity: overlayFade,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: darkOpacity),
            ),
          ),
          if (convergeOpacity > 0)
            Opacity(
              opacity: convergeOpacity,
              child: Transform.scale(
                scale: convergeScale,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xE6F5D992),
                        Color(0x66A97CF0),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (cardOpacity > 0)
            Opacity(
              opacity: cardOpacity,
              child: Transform.scale(
                scale: cardScale,
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(flipAngle),
                  alignment: Alignment.center,
                  child: isFront
                      ? Transform(
                          transform: Matrix4.identity()..rotateY(pi),
                          alignment: Alignment.center,
                          child: _HeroCardFront(card: card),
                        )
                      : const _HeroCardBackFace(),
                ),
              ),
            ),
          if (burstProgress > 0)
            TarotParticleBurst(progress: burstProgress, maxDistance: 180),
          if (flashOpacity > 0)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: flashOpacity * 0.85),
              ),
            ),
          Positioned(
            bottom: 90,
            child: Opacity(
              opacity: nameOpacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, nameSlide),
                child: Text(
                  '${card.nameKr}${card.isReversed ? " (역방향)" : ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 리빌 전(뒤집히기 전) 카드 뒷면 - 로딩 화면의 신비로운 카드 뒷면과 톤을 맞춘다.
class _HeroCardBackFace extends StatelessWidget {
  const _HeroCardBackFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 240,
      decoration: BoxDecoration(
        gradient: AppColors.mysticGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.45),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Center(child: Text('✨', style: TextStyle(fontSize: 44))),
    );
  }
}

/// 뒤집힌 후 실제로 공개되는 카드 앞면.
class _HeroCardFront extends StatelessWidget {
  final TarotCard card;
  const _HeroCardFront({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 240,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.secondaryLight, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: card.isReversed ? pi : 0,
        child: Text(card.icon, style: const TextStyle(fontSize: 56)),
      ),
    );
  }
}

/// §6 "리딩 결과" 7단계(①카드이름 ②한줄운세 ③상세리딩 ④오늘의조언 ⑤행운의색
/// ⑥행운의숫자 ⑦AI한마디)를 [_contentController]의 진행값에 따라 순차적으로
/// 등장시키는 콘텐츠 목록. §9 "마지막 감동"은 ⑦AI한마디 카드로 구현된다.
class _ResultContent extends StatelessWidget {
  final TarotResultModel result;
  final double progress;
  final bool started;
  const _ResultContent({
    required this.result,
    required this.progress,
    required this.started,
  });

  @override
  Widget build(BuildContext context) {
    if (!started) return const SizedBox.shrink();
    final t = progress;
    final heroCard = result.positions.first.card;
    final oneLiner = TarotReadingExtras.oneLiner(result.summary);
    final advice = TarotReadingExtras.advice(result.id, result.topic);
    final closing = TarotReadingExtras.aiClosing(result.id);
    final lucky = TarotReadingExtras.luckyColor(result.id);
    final luckyNumber = TarotReadingExtras.luckyNumber(result.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        _Reveal(
          t: t,
          start: 0.0,
          child: _QuestionBanner(question: result.question),
        ),
        // [운세 카테고리 확장] 타로 YES/NO 스프레드 전용 배지(추가 전용,
        // 기존 카드 등장 애니메이션/레이아웃에는 영향 없음). answer가 없는
        // 기존 one_card/three_card 결과에서는 아무것도 렌더링하지 않는다.
        if (result.answer != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Reveal(t: t, start: 0.04, child: _YesNoBadge(answer: result.answer!)),
        ],
        const SizedBox(height: AppSpacing.xl),
        // ① 카드 이름
        _Reveal(
          t: t,
          start: 0.08,
          child: _SectionHeaderCard(
            heroCard: heroCard,
            multi: result.positions.length > 1,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // ② 한 줄 운세
        _Reveal(
          t: t,
          start: 0.20,
          child: _OneLinerCard(text: oneLiner),
        ),
        const SizedBox(height: AppSpacing.lg),
        // AI 리딩 텍스트(§4 "AI 리딩 텍스트 등장") - 서버가 생성한 총평 전문.
        _Reveal(
          t: t,
          start: 0.27,
          child: _AiReadingCard(text: result.summary),
        ),
        const SizedBox(height: AppSpacing.lg),
        // ③ 상세 리딩
        Column(
          children: [
            for (var i = 0; i < result.positions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _Reveal(
                  t: t,
                  start: 0.34 + i * 0.04,
                  fadeSpan: 0.14,
                  child: _PositionCard(position: result.positions[i]),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // ④ 오늘의 조언
        _Reveal(
          t: t,
          start: 0.58,
          child: _InfoTile(icon: '🧭', label: '오늘의 조언', content: advice),
        ),
        const SizedBox(height: AppSpacing.md),
        // ⑤ 행운의 색 / ⑥ 행운의 숫자
        _Reveal(
          t: t,
          start: 0.70,
          child: Row(
            children: [
              Expanded(
                child: _LuckyColorTile(name: lucky.name, color: lucky.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _LuckyNumberTile(number: luckyNumber)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // ⑦ AI 한마디(§9 "마지막 감동")
        _Reveal(
          t: t,
          start: 0.84,
          fadeSpan: 0.18,
          child: _AiClosingCard(text: closing),
        ),
      ],
    );
  }
}

/// [t]가 [start]~[start]+[fadeSpan] 구간을 지나는 동안 [child]를 페이드인 +
/// 위로 슬라이드 등장시키는 공용 헬퍼(§6 "순차적으로 등장"을 위한 최소 단위).
class _Reveal extends StatelessWidget {
  final double t;
  final double start;
  final double fadeSpan;
  final Widget child;
  const _Reveal({
    required this.t,
    required this.start,
    this.fadeSpan = 0.14,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = _lerpRange(
      t,
      start,
      start + fadeSpan,
      0.0,
      1.0,
      Curves.easeOut,
    );
    final slide = _lerpRange(
      t,
      start,
      start + fadeSpan,
      18.0,
      0.0,
      Curves.easeOut,
    );
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      child: Transform.translate(offset: Offset(0, slide), child: child),
    );
  }
}

class _QuestionBanner extends StatelessWidget {
  final String question;
  const _QuestionBanner({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.mysticGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '질문',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: const TextStyle(
              color: AppColors.onDeepSpace,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// [운세 카테고리 확장] 타로 YES/NO 스프레드의 답변 방향(YES/NO)을 강조해
/// 보여주는 배지. 신규 위젯이며 기존 위젯을 대체하지 않는다(추가 전용).
class _YesNoBadge extends StatelessWidget {
  final String answer;
  const _YesNoBadge({required this.answer});

  @override
  Widget build(BuildContext context) {
    final isYes = answer.toUpperCase() == 'YES';
    final color = isYes ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            isYes ? '🔮 YES' : '🔮 NO',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '카드가 가리키는 방향입니다',
            style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderCard extends StatelessWidget {
  final TarotCard heroCard;
  final bool multi;
  const _SectionHeaderCard({required this.heroCard, required this.multi});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.mysticGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(heroCard.icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${heroCard.nameKr}${heroCard.isReversed ? " (역방향)" : ""}',
            style: const TextStyle(
              color: AppColors.onDeepSpace,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (multi) ...[
            const SizedBox(height: 4),
            const Text(
              '카드들이 이야기를 전하고 있어요',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _OneLinerCard extends StatelessWidget {
  final String text;
  const _OneLinerCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.secondaryLight.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        '"$text"',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.secondaryLight,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _AiReadingCard extends StatelessWidget {
  final String text;
  const _AiReadingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            AppColors.deepSpaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🔮', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'AI 리딩',
                style: TextStyle(
                  color: AppColors.secondaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String icon;
  final String label;
  final String content;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.secondaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LuckyColorTile extends StatelessWidget {
  final String name;
  final Color color;
  const _LuckyColorTile({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '행운의 색',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LuckyNumberTile extends StatelessWidget {
  final int number;
  const _LuckyNumberTile({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            '$number',
            style: const TextStyle(
              color: AppColors.secondaryLight,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '행운의 숫자',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AiClosingCard extends StatelessWidget {
  final String text;
  const _AiClosingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 22)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepSpace,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final TarotSpreadPosition position;
  const _PositionCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final card = position.card;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 84,
            decoration: BoxDecoration(
              gradient: AppColors.mysticGradient,
              borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            ),
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: card.isReversed ? pi : 0,
              child: Text(card.icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    position.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${card.nameKr}${card.isReversed ? ' (역방향)' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  position.interpretation,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
