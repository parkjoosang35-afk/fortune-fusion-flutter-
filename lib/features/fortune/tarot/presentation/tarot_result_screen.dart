import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/data/my_fortune_record_store.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/tarot_audio_controller.dart';
import '../application/tarot_provider.dart';
import '../application/tarot_session_controller.dart';
import '../domain/tarot_model.dart';
import '../domain/tarot_result_view_model.dart';
import 'tarot_deep_dive_screen.dart';
import 'theme/tarot_colors.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_text_styles.dart';
import 'theme/tarot_theme_scope.dart';
import 'theme/tarot_tokens.dart';
import 'widgets/tarot_mystic_background.dart';
import 'widgets/tarot_particle_burst.dart';
import 'widgets/tarot_share_card.dart';

/// [타로 섹션 전면 개편 §8/§10 P3] TarotResultScreen 전면 재구성.
///
/// 기존(단순 ListView + Fade In)을 대체해 "결과가 등장하는 순간"을 한 편의
/// 짧은 영화처럼 연출한다. 두 개의 독립된 타임라인으로 구성한다:
///
/// 1) [_HeroRevealOverlay] - §4의 암전→빛수렴→카드확대→플립→강한빛→
///    별가루폭발→카드이름 시퀀스를 화면 전체를 덮는 오버레이로 한 번만 재생한다.
/// 2) [_ResultContent] - 오버레이가 끝나는 순간 시작되는 §8(①~⑦) 순차 등장
///    콘텐츠 목록. 두 타임라인은 오버레이의 `overlayFade`(0.93~1.0 구간)와
///    콘텐츠의 첫 항목 등장(0.0~ 구간)이 겹치도록 설계해 부드럽게 크로스페이드된다.
///
/// [P3 변경점] 화면 전체가 [TarotThemeScope]+[TarotColors]로 전환되어 §7
/// 신규 화면들(질문/카드선택/로딩)과 다크 미스틱 톤이 일관된다. 콘텐츠 값
/// (한줄운세/조언/행운색/행운숫자/AI한마디)은 더 이상 이 화면에서 직접
/// [TarotReadingExtras]를 호출하지 않고, [TarotResultView.fromResult]로
/// 한 번에 캡슐화된 뷰모델을 사용한다(§11 P4 공유카드/심화해석 화면과의
/// 재사용을 위한 선행 작업). 하단 액션 바도 §8 "5액션"(히스토리/다시뽑기/
/// 저장하기/공유하기/심화해석) 전부를 [TarotResultAction]으로 데이터 기반
/// 렌더링한다(기존 2액션에서 확장).
///
/// [재생 1회 보장] `_TarotResultCinematic`을 `ValueKey(result.id)`로 감싸,
/// 같은 결과 화면 내에서 Provider가 notifyListeners()로 리빌드되어도(저장/
/// 공유 버튼 클릭 등) State가 재사용되어 애니메이션이 처음부터 다시 재생되지
/// 않는다 - 오직 "새로운" 결과(id 변경)일 때만 새로 재생된다.
class TarotResultScreen extends StatefulWidget {
  final String? resultId;
  const TarotResultScreen({super.key, this.resultId});

  @override
  State<TarotResultScreen> createState() => _TarotResultScreenState();
}

class _TarotResultScreenState extends State<TarotResultScreen> {
  final _shareCardKey = GlobalKey();
  bool _justSaved = false;

  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TarotProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  Future<void> _handleAction(
    TarotResultAction action,
    TarotResultView view,
  ) async {
    final session = context.read<TarotSessionController>();
    switch (action) {
      case TarotResultAction.history:
        Navigator.of(context).pushNamed('/ai-fortune/tarot/history');
      case TarotResultAction.redraw:
        // 새 세션으로 다시 시작 - 이전 카드선택/셔플 상태가 남아있지 않도록
        // 질문화면 재진입 전에 세션을 초기화한다.
        session.reset();
        Navigator.of(context).pushNamed('/ai-fortune/tarot/question');
      case TarotResultAction.save:
        await _onSave(view);
      case TarotResultAction.share:
        await _onShare(view);
      case TarotResultAction.deepDive:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TarotDeepDiveScreen(result: view.result),
          ),
        );
    }
  }

  /// [§11 P4] "저장하기" - 세션 상태 피드백(markSaved)에 더해 앱 전역
  /// 공용 저장소([MyFortuneRecordStore])에 실제로 영속화한다. 오늘의
  /// 운세 화면과 동일한 저장소를 재사용하므로, 마이페이지 "내 운세 기록"
  /// 에서 타로 결과도 함께 조회된다(§1-3 신규 자산 최소화).
  Future<void> _onSave(TarotResultView view) async {
    // 히스토리에서 바로 진입한 경우(세션이 이 결과를 모름) 등에도
    // markSaved()는 상태 가드로 조용히 no-op되므로 안전하다.
    context.read<TarotSessionController>().markSaved();
    context.read<TarotAudioController>().playSaveConfirm();
    await MyFortuneRecordStore.save(
      SavedFortuneRecord(
        id: 'tarot_${view.result.id}',
        categoryLabel: '타로',
        title: view.saveTitle,
        summary: view.oneLiner,
        score: view.score,
        date: view.result.createdAt,
        savedAt: DateTime.now(),
        cardImageAssetPath: view.heroCard.thumbAssetPath,
      ),
    );
    if (!mounted) return;
    setState(() => _justSaved = true);
    AppToast.show(context, '마이 > 내 운세 기록에 저장되었어요');
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  /// [§11 P4] "공유하기" - 앱 전역 공유카드 캡처 패턴([FortuneShareCard]/
  /// [DailyFortuneResultScreen._captureAndShare]와 동일한 구조)을 그대로
  /// 재사용해 [TarotShareCard]를 이미지로 캡처 후 공유한다.
  Future<void> _onShare(TarotResultView view) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TarotColors.bgIndigo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TarotThemeScope(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(TarotTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('타로 결과 공유하기', style: TarotTextStyles.screenTitle),
                const SizedBox(height: TarotTokens.spaceLg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(TarotTokens.radiusLg),
                  child: RepaintBoundary(
                    key: _shareCardKey,
                    child: TarotShareCard(
                      cardIcon: view.heroCard.icon,
                      cardImagePath: view.heroCard.imageAssetPath,
                      cardName: view.heroCard.nameKr,
                      isReversed: view.heroCard.isReversed,
                      oneLiner: view.oneLiner,
                      luckyColorName: view.luckyColorName,
                      luckyColor: view.luckyColor,
                      luckyNumber: view.luckyNumber,
                    ),
                  ),
                ),
                const SizedBox(height: TarotTokens.spaceLg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: TarotColors.pinkGlow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          TarotTokens.radiusPill,
                        ),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _captureAndShare();
                    },
                    child: Text(
                      '이미지로 공유하기',
                      style: TarotTextStyles.ctaLabel.copyWith(
                        color: TarotColors.bgVoid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndShare() async {
    try {
      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(
        pixelRatio: TarotShareCard.capturePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = await File(
        '${dir.path}/tarot_share_${DateTime.now().millisecondsSinceEpoch}.png',
      ).writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'AI 타로 리딩 결과를 확인해보세요! · Fortune Fusion');
    } catch (_) {
      if (!mounted) return;
      await Share.share('AI 타로 리딩 결과를 확인해보세요! · Fortune Fusion');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TarotProvider>();
    final state = provider.state;

    return TarotThemeScope(
      child: Scaffold(
        backgroundColor: TarotColors.bgVoid,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('타로 결과', style: TarotTextStyles.screenTitle),
        ),
        body: switch (state.status) {
          LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
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
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TarotTokens.spaceSm,
                    vertical: TarotTokens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: TarotColors.bgIndigo.withValues(alpha: 0.92),
                    border: const Border(
                      top: BorderSide(color: TarotColors.borderSoft),
                    ),
                  ),
                  child: Row(
                    children: TarotResultAction.values
                        .map(
                          (action) => Expanded(
                            child: _ResultActionButton(
                              action: action,
                              saved:
                                  action == TarotResultAction.save &&
                                  _justSaved,
                              onTap: () => _handleAction(
                                action,
                                TarotResultView.fromResult(state.data!),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// §8 "5액션" 바의 버튼 1개. [TarotResultAction.redraw]는 이 세션의
/// 다음 행동을 유도하는 주 액션이라 핑크글로우로 강조하고, 나머지는
/// 문라이트실버 계열로 통일한다(§5-1 금색 절제 규칙 - 이 바에는 금색을
/// 전혀 사용하지 않는다). [saved]가 true인 동안(저장 직후) "저장하기"
/// 아이콘만 잠깐 별빛 골드로 강조해 "완료됐다"는 확실한 피드백을 준다.
class _ResultActionButton extends StatelessWidget {
  final TarotResultAction action;
  final bool saved;
  final VoidCallback onTap;
  const _ResultActionButton({
    required this.action,
    required this.saved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = action == TarotResultAction.redraw;
    final color = saved
        ? TarotColors.starlightGold
        : isPrimary
        ? TarotColors.pinkGlow
        : TarotColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TarotTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TarotTokens.spaceSm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? Icons.bookmark_rounded : action.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              saved ? '저장됨' : action.label,
              style: TarotTextStyles.caption.copyWith(
                color: color,
                fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
  late final TarotResultView _view;

  bool _contentStarted = false;
  // [§11 P5] _HeroRevealOverlay의 "강한 빛"(flashOpacity, t≈0.66~)과
  // "별가루 폭발"(burstProgress, t≈0.68~) 구간에 맞춰 SFX를 정확히 한 번씩만
  // 재생하기 위한 가드 플래그. AnimatedBuilder는 매 프레임 리빌드되므로
  // 이 플래그 없이는 같은 사운드가 수십 번 재생된다.
  bool _revealImpactPlayed = false;
  bool _stardustChimePlayed = false;

  @override
  void initState() {
    super.initState();
    // §11 P4에서 공유카드/심화해석 화면이 동일한 뷰모델을 재사용할 수
    // 있도록, 결과 콘텐츠 계산을 이 지점에서 한 번만 수행한다.
    _view = TarotResultView.fromResult(widget.result);
    _revealController = AnimationController(
      vsync: this,
      duration: _revealDuration,
    );
    _contentController = AnimationController(
      vsync: this,
      duration: _contentDuration,
    );
    _revealController.addListener(_onRevealTick);
    _revealController.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _contentStarted = true);
      _contentController.forward();
    });
  }

  void _onRevealTick() {
    final t = _revealController.value;
    if (!_revealImpactPlayed && t >= 0.66) {
      _revealImpactPlayed = true;
      context.read<TarotAudioController>().playRevealImpact();
    }
    if (!_stardustChimePlayed && t >= 0.70) {
      _stardustChimePlayed = true;
      context.read<TarotAudioController>().playStardustChime();
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // §7 "배경 애니메이션(결과화면)" - 살아있지만 "너무 화려하지 않게".
        TarotMysticBackground(
          intensity: TarotPerfConfig.backgroundIntensity(0.55),
        ),
        SafeArea(
          child: AnimatedBuilder(
            animation: _contentController,
            builder: (context, _) {
              return _ResultContent(
                view: _view,
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
            return _HeroRevealOverlay(card: _view.heroCard, t: t);
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
                        Color(0xE6FF9EC4),
                        Color(0x66C9D3EC),
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
          // [§11 P6] low 티어에서는 별가루 폭발을 완전히 생략한다
          // (TarotPerfConfig.particleCount가 low에서 0을 반환하므로
          // TarotParticleBurst 내부에서도 아무것도 그리지 않지만,
          // 위젯 생성/애니메이션 리스닝 자체를 건너뛰어 한 단계 더
          // 절약한다).
          if (burstProgress > 0 && TarotPerfConfig.showSymbolLayer)
            TarotParticleBurst(
              progress: burstProgress,
              count: TarotPerfConfig.particleCount(36),
              maxDistance: 180,
            ),
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
                  style: TarotTextStyles.categoryTitle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 리빌 전(뒤집히기 전) 카드 뒷면 - 카드선택/로딩 화면의 카드 뒷면과 톤을 맞춘다.
class _HeroCardBackFace extends StatelessWidget {
  const _HeroCardBackFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 240,
      decoration: BoxDecoration(
        gradient: TarotColors.cardBackGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TarotColors.moonSilver.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: TarotColors.pinkGlow.withValues(alpha: 0.4),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Center(child: Text('✨', style: TextStyle(fontSize: 44))),
    );
  }
}

/// 뒤집힌 후 실제로 공개되는 카드 앞면. §5-1 금색 절제 규칙 - "히어로 전체
/// 배경에는 금색을 사용하지 않는다"에 따라 배경은 핑크글로우 그라디언트를
/// 쓰고, 금색은 테두리/글로우 악센트로만 국소 사용한다.
class _HeroCardFront extends StatelessWidget {
  final TarotCard card;
  const _HeroCardFront({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 240,
      decoration: BoxDecoration(
        gradient: TarotColors.pinkGlowGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TarotColors.starlightGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: TarotColors.starlightGold.withValues(alpha: 0.55),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Transform.rotate(
          angle: card.isReversed ? pi : 0,
          child: Image.asset(
            card.imageAssetPath,
            width: 148,
            height: 228,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Text(card.icon, style: const TextStyle(fontSize: 56)),
          ),
        ),
      ),
    );
  }
}

/// §8 "결과보기" 7섹션(①카드이름 ②한줄운세 [총평] ③상세리딩 ④오늘의조언
/// ⑤행운의색 ⑥행운의숫자 ⑦AI한마디)을 [_contentController]의 진행값에
/// 따라 순차적으로 등장시키는 콘텐츠 목록. §9 "마지막 감동"은 ⑦AI한마디
/// 카드로 구현된다. 콘텐츠 값은 모두 [TarotResultView]에서 가져온다.
class _ResultContent extends StatelessWidget {
  final TarotResultView view;
  final double progress;
  final bool started;
  const _ResultContent({
    required this.view,
    required this.progress,
    required this.started,
  });

  @override
  Widget build(BuildContext context) {
    if (!started) return const SizedBox.shrink();
    final t = progress;
    final result = view.result;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TarotTokens.spaceLg,
        TarotTokens.spaceMd,
        TarotTokens.spaceLg,
        TarotTokens.spaceXxl,
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
          const SizedBox(height: TarotTokens.spaceMd),
          _Reveal(
            t: t,
            start: 0.04,
            child: _YesNoBadge(answer: result.answer!),
          ),
        ],
        const SizedBox(height: TarotTokens.spaceXl),
        // ① 카드 이름
        _Reveal(
          t: t,
          start: 0.08,
          child: _SectionHeaderCard(
            heroCard: view.heroCard,
            multi: result.positions.length > 1,
          ),
        ),
        const SizedBox(height: TarotTokens.spaceLg),
        // ② 한 줄 운세
        _Reveal(
          t: t,
          start: 0.20,
          child: _OneLinerCard(text: view.oneLiner),
        ),
        const SizedBox(height: TarotTokens.spaceLg),
        // AI 리딩 텍스트(§4 "AI 리딩 텍스트 등장") - 서버가 생성한 총평 전문.
        _Reveal(
          t: t,
          start: 0.27,
          child: _AiReadingCard(text: result.summary),
        ),
        const SizedBox(height: TarotTokens.spaceLg),
        // ③ 상세 리딩
        Column(
          children: [
            for (var i = 0; i < result.positions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: TarotTokens.spaceMd),
                child: _Reveal(
                  t: t,
                  start: 0.34 + i * 0.04,
                  fadeSpan: 0.14,
                  child: _PositionCard(position: result.positions[i]),
                ),
              ),
          ],
        ),
        const SizedBox(height: TarotTokens.spaceMd),
        // ④ 오늘의 조언
        _Reveal(
          t: t,
          start: 0.58,
          child: _InfoTile(icon: '🧭', label: '오늘의 조언', content: view.advice),
        ),
        const SizedBox(height: TarotTokens.spaceMd),
        // ⑤ 행운의 색 / ⑥ 행운의 숫자
        _Reveal(
          t: t,
          start: 0.70,
          child: Row(
            children: [
              Expanded(
                child: _LuckyColorTile(
                  name: view.luckyColorName,
                  color: view.luckyColor,
                ),
              ),
              const SizedBox(width: TarotTokens.spaceMd),
              Expanded(child: _LuckyNumberTile(number: view.luckyNumber)),
            ],
          ),
        ),
        const SizedBox(height: TarotTokens.spaceXl),
        // ⑦ AI 한마디(§9 "마지막 감동")
        _Reveal(
          t: t,
          start: 0.84,
          fadeSpan: 0.18,
          child: _AiClosingCard(text: view.aiClosing),
        ),
      ],
    );
  }
}

/// [t]가 [start]~[start]+[fadeSpan] 구간을 지나는 동안 [child]를 페이드인 +
/// 위로 슬라이드 등장시키는 공용 헬퍼(§8 "순차적으로 등장"을 위한 최소 단위).
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
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        gradient: TarotColors.nightGradient,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: TarotColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('질문', style: TarotTextStyles.caption),
          const SizedBox(height: 6),
          Text(question, style: TarotTextStyles.bodyStrong),
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
        vertical: TarotTokens.spaceLg,
        horizontal: TarotTokens.spaceLg,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            isYes ? '🔮 YES' : '🔮 NO',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '카드가 가리키는 방향입니다',
            style: TarotTextStyles.caption.copyWith(
              color: color.withValues(alpha: 0.85),
            ),
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
        vertical: TarotTokens.spaceXl,
        horizontal: TarotTokens.spaceLg,
      ),
      decoration: BoxDecoration(
        gradient: TarotColors.nightGradient,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: TarotColors.borderGlow),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              heroCard.thumbAssetPath,
              width: 56,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Text(heroCard.icon, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: TarotTokens.spaceSm),
          Text(
            '${heroCard.nameKr}${heroCard.isReversed ? " (역방향)" : ""}',
            style: TarotTextStyles.categoryTitle,
          ),
          if (multi) ...[
            const SizedBox(height: 4),
            Text('카드들이 이야기를 전하고 있어요', style: TarotTextStyles.caption),
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
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCard,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: TarotColors.borderGlow),
      ),
      child: Text(
        '"$text"',
        textAlign: TextAlign.center,
        style: TarotTextStyles.bodyStrong.copyWith(
          color: TarotColors.pinkGlow,
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
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCard,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: TarotColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔮', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'AI 리딩',
                style: TarotTextStyles.caption.copyWith(
                  color: TarotColors.moonSilver,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: TarotTokens.spaceSm),
          Text(text, style: TarotTextStyles.body),
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
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCard,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: TarotTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TarotTextStyles.caption.copyWith(
                    color: TarotColors.moonSilver,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(content, style: TarotTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// §5-1 금색 절제 규칙의 명시적 예외 지점(3) - "행운의 색/숫자 타일" 등
/// 국소 강조. 이 타일들에서만 별빛 골드를 자유롭게 사용한다.
class _LuckyColorTile extends StatelessWidget {
  final String name;
  final Color color;
  const _LuckyColorTile({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCard,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
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
          const SizedBox(height: TarotTokens.spaceSm),
          Text('행운의 색', style: TarotTextStyles.caption),
          const SizedBox(height: 2),
          Text(name, style: TarotTextStyles.bodyStrong),
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
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCard,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
      ),
      child: Column(
        children: [
          Text(
            '$number',
            style: const TextStyle(
              color: TarotColors.starlightGold,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text('행운의 숫자', style: TarotTextStyles.caption),
        ],
      ),
    );
  }
}

/// §9 "마지막 감동" - AI 한마디 카드. §5-1 규칙(카드 전체 배경에 금색 금지)에
/// 따라 배경은 나이트 그라디언트를 쓰고, 금색은 테두리 글로우로만 국소 사용.
class _AiClosingCard extends StatelessWidget {
  final String text;
  const _AiClosingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TarotTokens.spaceXl),
      decoration: BoxDecoration(
        gradient: TarotColors.nightGradient,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(
          color: TarotColors.starlightGold.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: TarotColors.starlightGold.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 22)),
          const SizedBox(height: TarotTokens.spaceSm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TarotTextStyles.bodyStrong,
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
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCard,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: TarotColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 84,
            decoration: BoxDecoration(
              gradient: TarotColors.cardBackGradient,
              borderRadius: BorderRadius.circular(TarotTokens.radiusSm),
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TarotTokens.radiusSm),
              child: Transform.rotate(
                angle: card.isReversed ? pi : 0,
                child: Image.asset(
                  card.thumbAssetPath,
                  width: 56,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Text(card.icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
          const SizedBox(width: TarotTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TarotTokens.spaceSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: TarotColors.pinkGlow.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
                  ),
                  child: Text(
                    position.label,
                    style: TarotTextStyles.chipLabel.copyWith(
                      color: TarotColors.pinkGlow,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${card.nameKr}${card.isReversed ? ' (역방향)' : ''}',
                  style: TarotTextStyles.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(position.interpretation, style: TarotTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
