import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/data/my_fortune_record_store.dart';
import '../../../../core/util/safe_share.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/tarot_audio_controller.dart';
import '../application/tarot_provider.dart';
import '../application/tarot_session_controller.dart';
import '../domain/tarot_model.dart';
import '../domain/tarot_reading_extras.dart';
import '../domain/tarot_result_view_model.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'tarot_deep_dive_screen.dart';
import 'theme/tarot_perf_config.dart';
import 'widgets/tarot_particle_burst.dart';
import 'widgets/tarot_share_card.dart';

/// [타로 오즈 리스킨 · 화면07 RESULT] 결과 화면.
///
/// 순수 리스킨: [_handleAction]/[_onSave]/[_onShare]/[_captureAndShare]
/// 전체 로직, [_TarotResultCinematic]의 애니메이션 타이밍 구조(모든
/// `_lerpRange` start/end 값은 절대 변경하지 않음), [TarotResultView
/// .fromResult], [TarotResultAction] 5개 액션은 100% 그대로 유지하고,
/// 오직 각 하위 위젯의 시각적 스타일(색상/타이포/배경)만 오즈 톤으로
/// 교체한다.
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

  Future<void> _onSave(TarotResultView view) async {
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

  Future<void> _onShare(TarotResultView view) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: OzColors.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OzTokens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '타로 결과 공유하기',
                style: OzTypography.sectionTitle(fontSize: 18),
              ),
              const SizedBox(height: OzTokens.spaceLg),
              ClipRRect(
                borderRadius: BorderRadius.circular(OzTokens.radiusLg),
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
              const SizedBox(height: OzTokens.spaceLg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OzColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OzTokens.radiusPill),
                    ),
                  ),
                  onPressed: () async {
                    // [8가지 버그 리포트 §1 수정] 기존에는 바텀시트를 먼저
                    // pop()한 뒤 캡처를 시도했는데, pop() 즉시 이 바텀시트
                    // 안에 있던 RepaintBoundary(_shareCardKey)가 위젯 트리에서
                    // 제거되어(dispose) currentContext가 null이 되어버렸다.
                    // 이 때문에 _captureAndShare()가 조용히 return하며 아무
                    // 공유도 일어나지 않는 것이 실제 "공유하기 안 됨" 버그의
                    // 원인이었다. 바텀시트가 아직 열려있는 이 시점에 먼저
                    // 캡처를 완료한 뒤, 그 다음에 시트를 닫고 공유 시트를
                    // 띄운다.
                    await _captureAndShare(ctx);
                  },
                  child: Text('이미지로 공유하기', style: OzTypography.ctaLabel()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndShare(BuildContext sheetContext) async {
    // [타로 공유 안 되는 버그 수정] 기존에는 path_provider(getTemporaryDirectory)로
    // 캡처한 이미지를 디스크에 저장한 뒤 그 경로로 XFile을 만들어 공유했다.
    // path_provider는 Web 플랫폼을 지원하지 않는 패키지라(pub.dev platforms에
    // web이 없음) 웹 프리뷰/웹 배포에서 getTemporaryDirectory() 호출 자체가
    // 예외를 던져 항상 catch로 빠지고, 텍스트만 공유하는 폴백조차 브라우저의
    // Web Share API 제약으로 실패하는 경우가 있었다. 디스크 파일 저장 없이
    // 캡처한 PNG 바이트를 곧바로 XFile.fromData()(메모리 기반, 모든 플랫폼
    // 지원)로 감싸 공유하도록 바꿔 Web/Android 양쪽에서 동작하게 한다.
    //
    // [8가지 버그 리포트 §1 추가 수정] 캡처는 호출부가 바텀시트를 pop()하기
    // *전에* 이 함수를 호출하도록 순서를 바꿨으므로, 여기서는 캡처를 끝낸
    // 뒤에 바텀시트를 닫는다(sheetContext로 명시적으로 pop) — 이전에는
    // pop()이 먼저 실행되어 RepaintBoundary가 이미 dispose된 뒤라
    // currentContext가 null이 되어 캡처 자체가 조용히 실패했었다.
    bool popped = false;
    try {
      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        popped = true;
        if (!mounted) return;
        AppToast.show(context, '공유 이미지를 준비하지 못했어요. 다시 시도해주세요.');
        return;
      }
      final image = await boundary.toImage(
        pixelRatio: TarotShareCard.capturePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // 캡처가 끝났으니 이제 바텀시트를 닫는다.
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      popped = true;

      final file = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'tarot_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await Share.shareXFiles(
        [file],
        text: '타로 카드 풀이 결과를 확인해보세요! · Fortune Fusion',
      );
    } catch (e) {
      if (!popped && sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      // [근본 수정 — 2026-12] 이미지 첨부 공유(shareXFiles)가 실패했을 때의
      // 텍스트 전용 폴백에서 예전에는 `Share.share()`를 직접 호출했다.
      // `share_plus_web.dart`가 웹에서 canShare() 미지원 시 `mailto:`
      // 스킴을 자체적으로 새 탭에 열려고 시도해 net::ERR_UNKNOWN_URL_SCHEME
      // 에러 화면을 유발하는 것을 확인했다(core/util/safe_share.dart 문서
      // 참고). 공통 헬퍼로 교체해 웹에서는 곧바로 클립보드 복사로 폴백한다.
      if (!mounted) return;
      await safeShareText(context, '타로 카드 풀이 결과를 확인해보세요! · Fortune Fusion');
    }
  }

  /// [8가지 버그 리포트 §6 — 탈출구 없음 수정] 이 화면은 question →
  /// (pushReplacementNamed)loading → (pushReplacementNamed)result 순서로
  /// 진입하므로, 뒤로가기(pop)는 이전 질문 입력 화면으로 돌아간다(자연스러운
  /// "다시 물어보기" 동작). 다만 스택 맨 밑(예: 히스토리에서 곧바로 진입한
  /// 경우 등)이라 canPop이 false일 수도 있으므로, 그 경우에는 앱 전역
  /// [MainBottomNavBar]와 동일한 패턴(`pushNamedAndRemoveUntil('/home', ...,
  /// arguments: 1)`)으로 "운세" 탭으로 안전하게 복귀시킨다.
  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (route) => false, arguments: 1);
    }
  }

  /// [8가지 버그 리포트 §6] "홈으로 가기" — 언제나 앱 첫 탭(홈)으로 복귀.
  void _handleHome(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/home', (route) => false, arguments: 0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TarotProvider>();
    final state = provider.state;

    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      extendBody: true,
      body: Stack(
        children: [
          const OzBackground(),
          SafeArea(
            bottom: false,
            child: switch (state.status) {
              LoadStatus.loading => const Center(
                child: CircularProgressIndicator(color: OzColors.gold),
              ),
              LoadStatus.error => AppErrorState(
                message: state.errorMessage ?? '타로 리딩에 실패했습니다.',
                onRetry: () => provider.retry(),
              ),
              LoadStatus.success => _TarotResultCinematic(
                key: ValueKey(state.data!.id),
                result: state.data!,
              ),
              LoadStatus.initial => const AppErrorState(
                message: '입력 정보가 없습니다.',
              ),
            },
          ),
          // [8가지 버그 리포트 §6 — 뒤로가기/홈 없음 수정] 사용자 지적("뒤로가기나
          // 홈으로 가기가 없어") 대응. 기존 5액션 하단 바(다시 뽑기/저장/공유/
          // 심화해석/히스토리)는 기획상 100% 그대로 유지하고, 대신 상단에
          // 작은 원형 뒤로가기/홈 버튼을 얹어 이 화면에서 항상 벗어날 수 있게
          // 한다. 카드 리빌 연출(OzBackground/_TarotResultCinematic) 위에
          // 얹히므로 기존 애니메이션 타이밍에는 전혀 영향을 주지 않는다.
          if (state.isSuccess || state.isError)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OzTokens.spaceMd,
                  OzTokens.spaceSm,
                  OzTokens.spaceMd,
                  0,
                ),
                child: Row(
                  children: [
                    _TopCircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: '뒤로가기',
                      onTap: () => _handleBack(context),
                    ),
                    const SizedBox(width: OzTokens.spaceSm),
                    _TopCircleIconButton(
                      icon: Icons.home_rounded,
                      tooltip: '홈으로 가기',
                      onTap: () => _handleHome(context),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: state.isSuccess
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: OzTokens.spaceSm,
                  vertical: OzTokens.spaceSm,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      OzColors.bgDeep.withValues(alpha: 0.7),
                      OzColors.bgDeep.withValues(alpha: 0.97),
                    ],
                  ),
                  border: Border(top: BorderSide(color: OzColors.borderSoft)),
                ),
                child: Row(
                  children: TarotResultAction.values
                      .map(
                        (action) => Expanded(
                          child: _ResultActionButton(
                            action: action,
                            saved:
                                action == TarotResultAction.save && _justSaved,
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
    );
  }
}

/// [8가지 버그 리포트 §6] 상단 뒤로가기/홈 버튼 — 반투명 원형 배경 위에
/// 아이콘만 얹은 작은 버튼. [oz_topbar.dart]의 `_CircleIconButton`과 톤을
/// 맞추되, 카드 리빌 연출 위에 겹쳐도 눈에 띄도록 살짝 배경을 준다.
class _TopCircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TopCircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(OzTokens.radiusPill),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: OzColors.bgDeep.withValues(alpha: 0.55),
            border: Border.all(color: OzColors.borderSoft),
          ),
          child: Icon(icon, size: 16, color: OzColors.fg),
        ),
      ),
    );
  }
}

/// §8 "5액션" 바의 버튼 1개. redraw는 골드로 강조, 나머지는 fg 계열로 통일.
/// 저장 직후([saved])에는 저장 아이콘만 골드로 강조.
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
        ? OzColors.gold
        : isPrimary
        ? OzColors.gold
        : OzColors.fg.withValues(alpha: 0.7);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OzTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OzTokens.spaceSm),
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
              style: OzTypography.monoLabel(
                fontSize: 9.5,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [t]가 [start]~[end] 구간을 지나는 동안 [from]~[to]로 보간하는 헬퍼.
/// (기존과 완전히 동일, 절대 변경하지 않음)
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
/// (타이밍/컨트롤러 구조는 기존과 완전히 동일)
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
  bool _revealImpactPlayed = false;
  bool _stardustChimePlayed = false;

  @override
  void initState() {
    super.initState();
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
        AnimatedBuilder(
          animation: _contentController,
          builder: (context, _) {
            return _ResultContent(
              view: _view,
              progress: _contentController.value,
              started: _contentStarted,
            );
          },
        ),
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
/// 모든 _lerpRange 구간 값은 기존과 완전히 동일하게 유지된다 - 오직 색상
/// 팔레트(수렴 원형/플래시/텍스트 스타일)만 오즈 톤으로 교체.
class _HeroRevealOverlay extends StatelessWidget {
  final TarotCard card;
  final double t;
  const _HeroRevealOverlay({required this.card, required this.t});

  @override
  Widget build(BuildContext context) {
    final darkOpacity = t < 0.16
        ? _lerpRange(t, 0.0, 0.08, 0.0, 0.85)
        : _lerpRange(t, 0.16, 0.32, 0.85, 0.0);
    final convergeScale = _lerpRange(
      t,
      0.06,
      0.30,
      1.7,
      0.55,
      Curves.easeInOut,
    );
    final convergeOpacity = _lerpRange(t, 0.06, 0.30, 0.0, 0.9, Curves.easeIn);
    final cardOpacity = _lerpRange(t, 0.28, 0.36, 0.0, 1.0);
    final cardScale = _lerpRange(t, 0.28, 0.54, 0.3, 1.0, Curves.elasticOut);
    final flipAngle = _lerpRange(t, 0.50, 0.70, 0.0, pi, Curves.easeInOut);
    final flashOpacity = t < 0.72
        ? _lerpRange(t, 0.66, 0.72, 0.0, 1.0)
        : _lerpRange(t, 0.72, 0.80, 1.0, 0.0);
    final burstProgress = _lerpRange(t, 0.68, 0.95, 0.0, 1.0);
    final nameOpacity = _lerpRange(t, 0.80, 0.94, 0.0, 1.0);
    final nameSlide = _lerpRange(t, 0.80, 0.94, 14, 0);
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
                        Color(0xE6F5D97A),
                        Color(0x668B6EC8),
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
                  style: OzTypography.hero(fontSize: 22, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 리빌 전(뒤집히기 전) 카드 뒷면.
class _HeroCardBackFace extends StatelessWidget {
  const _HeroCardBackFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 240,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D2A6B), Color(0xFF1A0F3D)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OzColors.gold.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: OzColors.goldGlow(alpha: 0.4, blur: 36),
      ),
      child: Center(
        child: Text('✨', style: TextStyle(fontSize: 44, color: OzColors.gold)),
      ),
    );
  }
}

/// 뒤집힌 후 공개되는 카드 앞면.
class _HeroCardFront extends StatelessWidget {
  final TarotCard card;
  const _HeroCardFront({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 240,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3378), Color(0xFF2A1A5C)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OzColors.gold, width: 2),
        boxShadow: OzColors.goldGlow(alpha: 0.55, blur: 40),
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

/// §8 "결과보기" 7섹션을 [_contentController]의 진행값에 따라 순차적으로
/// 등장시키는 콘텐츠 목록. start/fadeSpan 등 모든 등장 타이밍 값은 기존과
/// 완전히 동일하게 유지된다.
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
        OzTokens.spaceLg,
        OzTokens.spaceMd,
        OzTokens.spaceLg,
        110,
      ),
      children: [
        _Reveal(
          t: t,
          start: 0.0,
          child: _QuestionBanner(question: result.question),
        ),
        // [65종 타로 리딩엔진 §계획2 - 자유질문 자동매칭] 사용자가 주제를
        // 직접 고르지 않은 자유질문이 서버에서 65개 주제 중 하나로 자동
        // 매칭되었을 때만 노출되는 안내 배너. 매칭이 없었던 기존 흐름에는
        // 영향이 없다(autoMatchedTopicName이 항상 null).
        if (result.autoMatchedTopicName != null) ...[
          const SizedBox(height: OzTokens.spaceSm),
          _Reveal(
            t: t,
            start: 0.02,
            child: _AutoMatchedTopicBanner(
              topicName: result.autoMatchedTopicName!,
            ),
          ),
        ],
        if (result.answer != null) ...[
          const SizedBox(height: OzTokens.spaceMd),
          _Reveal(
            t: t,
            start: 0.04,
            child: _YesNoBadge(answer: result.answer!),
          ),
        ],
        // [65종 타로 리딩엔진 §계획1 - choice_ab] A/B 양자택일 스프레드는
        // 사용자가 입력한 두 선택지를 카드 결과 위에 다시 보여줘, 5장의
        // 포지션(선택A 현재/결과흐름/선택B 현재/결과흐름/최종조언)이 각각
        // 어느 선택지에 대한 것인지 헷갈리지 않게 한다.
        if (result.spreadType == 'choice_ab' &&
            result.optionA != null &&
            result.optionB != null) ...[
          const SizedBox(height: OzTokens.spaceMd),
          _Reveal(
            t: t,
            start: 0.04,
            child: _ChoiceAbOptionsBanner(
              optionA: result.optionA!,
              optionB: result.optionB!,
            ),
          ),
        ],
        const SizedBox(height: OzTokens.spaceXl),
        // ① 카드 이름
        _Reveal(
          t: t,
          start: 0.08,
          child: _SectionHeaderCard(
            heroCard: view.heroCard,
            multi: result.positions.length > 1,
          ),
        ),
        const SizedBox(height: OzTokens.spaceLg),
        // ② 한 줄 운세
        _Reveal(
          t: t,
          start: 0.20,
          child: _OneLinerCard(text: view.oneLiner),
        ),
        const SizedBox(height: OzTokens.spaceLg),
        // AI 리딩 텍스트(총평)
        _Reveal(
          t: t,
          start: 0.27,
          child: _AiReadingCard(text: result.summary, label: view.aiReadingLabel),
        ),
        const SizedBox(height: OzTokens.spaceLg),
        // ③ 상세 리딩
        Column(
          children: [
            for (var i = 0; i < result.positions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: OzTokens.spaceMd),
                child: _Reveal(
                  t: t,
                  start: 0.34 + i * 0.04,
                  fadeSpan: 0.14,
                  child: _PositionCard(
                  position: result.positions[i],
                  index: i,
                  topic: result.topic,
                  resultId: result.id,
                ),
                ),
              ),
          ],
        ),
        const SizedBox(height: OzTokens.spaceMd),
        // ④ 오늘의 조언
        _Reveal(
          t: t,
          start: 0.58,
          child: _InfoTile(icon: '🧭', label: view.adviceLabel, content: view.advice),
        ),
        const SizedBox(height: OzTokens.spaceMd),
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
              const SizedBox(width: OzTokens.spaceMd),
              Expanded(child: _LuckyNumberTile(number: view.luckyNumber)),
            ],
          ),
        ),
        const SizedBox(height: OzTokens.spaceXl),
        // ⑦ AI 한마디
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

/// [t]가 [start]~[start]+[fadeSpan] 구간을 지나는 동안 페이드인 + 슬라이드
/// 등장시키는 공용 헬퍼(기존과 완전히 동일).
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
      padding: const EdgeInsets.all(OzTokens.spaceLg),
      decoration: BoxDecoration(
        color: OzColors.cardSoft,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '질문',
            style: OzTypography.monoLabel(fontSize: 10, letterSpacing: 2.4),
          ),
          const SizedBox(height: 6),
          Text(question, style: OzTypography.cardName(fontSize: 14)),
        ],
      ),
    );
  }
}

/// [65종 타로 리딩엔진 §계획2 - 자유질문 자동매칭] 사용자가 주제를 직접
/// 고르지 않은 자유질문이 서버에서 65개 주제 중 하나로 자동 매칭되었을
/// 때, 그 사실과 매칭된 주제명을 알려주는 작은 안내 배너.
class _AutoMatchedTopicBanner extends StatelessWidget {
  final String topicName;
  const _AutoMatchedTopicBanner({required this.topicName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OzTokens.spaceMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: OzColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: OzColors.teal),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '이 질문은 \'$topicName\' 주제로 자동 매칭되었어요',
              style: OzTypography.monoLabel(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// [65종 타로 리딩엔진 §계획1 - choice_ab] A/B 두 선택지를 나란히 보여주는
/// 배너. `_PositionCard` 5개(선택A 현재/결과흐름/선택B 현재/결과흐름/
/// 최종조언)를 읽기 전에 어떤 두 선택지를 비교하는지 다시 상기시켜준다.
class _ChoiceAbOptionsBanner extends StatelessWidget {
  final String optionA;
  final String optionB;
  const _ChoiceAbOptionsBanner({required this.optionA, required this.optionB});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceAbOptionTile(
            label: 'A',
            text: optionA,
            accent: OzColors.teal,
          ),
        ),
        const SizedBox(width: OzTokens.spaceSm),
        Expanded(
          child: _ChoiceAbOptionTile(
            label: 'B',
            text: optionB,
            accent: OzColors.rose,
          ),
        ),
      ],
    );
  }
}

class _ChoiceAbOptionTile extends StatelessWidget {
  final String label;
  final String text;
  final Color accent;
  const _ChoiceAbOptionTile({
    required this.label,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OzTokens.spaceMd),
      decoration: BoxDecoration(
        color: OzColors.cardSoft,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(OzTokens.radiusPill),
            ),
            child: Text(
              '선택 $label',
              style: OzTypography.monoLabel(fontSize: 9.5, color: accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: OzTypography.body(fontSize: 12.5, color: OzColors.fg),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 타로 YES/NO 스프레드의 답변 방향(YES/NO) 배지.
class _YesNoBadge extends StatelessWidget {
  final String answer;
  const _YesNoBadge({required this.answer});

  @override
  Widget build(BuildContext context) {
    final isYes = answer.toUpperCase() == 'YES';
    final color = isYes ? OzColors.gold : OzColors.rose;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: OzTokens.spaceLg,
        horizontal: OzTokens.spaceLg,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            isYes ? '🔮 YES' : '🔮 NO',
            style: OzTypography.hero(fontSize: 22, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '카드가 가리키는 방향입니다',
            style: OzTypography.body(
              fontSize: 11.5,
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
        vertical: OzTokens.spaceXl,
        horizontal: OzTokens.spaceLg,
      ),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            const Color(0xFF3D2A6B).withValues(alpha: 0.5),
            OzColors.bgMid.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(OzTokens.radiusXl),
        border: Border.all(color: OzColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              heroCard.thumbAssetPath,
              width: 64,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Text(heroCard.icon, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: OzTokens.spaceMd),
          Text(
            '${heroCard.nameKr}${heroCard.isReversed ? " (역방향)" : ""}',
            style: OzTypography.hero(fontSize: 20),
          ),
          if (multi) ...[
            const SizedBox(height: 4),
            Text('카드들이 이야기를 전하고 있어요', style: OzTypography.body(fontSize: 12)),
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
      padding: const EdgeInsets.all(OzTokens.spaceLg),
      decoration: BoxDecoration(
        color: OzColors.card,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.borderStrong),
      ),
      child: Text(
        '"$text"',
        textAlign: TextAlign.center,
        style: OzTypography.italicBody(fontSize: 14.5, color: OzColors.gold),
      ),
    );
  }
}

class _AiReadingCard extends StatelessWidget {
  final String text;
  // [65종 타로 리딩엔진 §계획3 - 결과화면 7섹션 제목 동적화] 65개 주제
  // 중 하나로 매칭되면 'OO AI 리딩'처럼 주제명이 붙은 제목을 받는다.
  // 매칭 실패 시 [TarotResultView.aiReadingLabel]이 기존 고정 문구
  // 'AI 리딩'을 그대로 내려주므로 이 위젯은 항상 label만 그리면 된다.
  final String label;
  const _AiReadingCard({required this.text, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OzTokens.spaceLg),
      decoration: BoxDecoration(
        color: OzColors.cardSoft,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: '🔮', label: label),
          const SizedBox(height: OzTokens.spaceSm),
          Text(
            text,
            style: OzTypography.body(
              fontSize: 13.5,
              color: OzColors.fg.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// 중앙정렬 구분선 포함 라벨. CSS 대응: .oz-reading-section-label.
class _SectionLabel extends StatelessWidget {
  final String icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 6),
        Text(
          label,
          style: OzTypography.monoLabel(fontSize: 10.5, letterSpacing: 1.6),
        ),
      ],
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
      padding: const EdgeInsets.all(OzTokens.spaceLg),
      decoration: BoxDecoration(
        color: OzColors.cardSoft,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border(left: BorderSide(color: OzColors.gold, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: OzTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: OzTypography.monoLabel(
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: OzTypography.body(
                    fontSize: 13,
                    color: OzColors.fg.withValues(alpha: 0.85),
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

/// 행운의 색/숫자 타일 - 골드 국소 강조.
class _LuckyColorTile extends StatelessWidget {
  final String name;
  final Color color;
  const _LuckyColorTile({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OzTokens.spaceLg),
      decoration: BoxDecoration(
        color: OzColors.cardSoft,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.borderSoft),
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
          const SizedBox(height: OzTokens.spaceSm),
          Text(
            '행운의 색',
            style: OzTypography.monoLabel(fontSize: 9.5, letterSpacing: 1.4),
          ),
          const SizedBox(height: 2),
          Text(name, style: OzTypography.cardName(fontSize: 13)),
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
      padding: const EdgeInsets.all(OzTokens.spaceLg),
      decoration: BoxDecoration(
        color: OzColors.cardSoft,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.borderSoft),
      ),
      child: Column(
        children: [
          Text(
            '$number',
            style: OzTypography.hero(fontSize: 22, color: OzColors.gold),
          ),
          const SizedBox(height: 4),
          Text(
            '행운의 숫자',
            style: OzTypography.monoLabel(fontSize: 9.5, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}

/// §9 "마지막 감동" - AI 한마디 카드. 골드 테두리+글로우로 국소 강조.
class _AiClosingCard extends StatelessWidget {
  final String text;
  const _AiClosingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OzTokens.spaceXl),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.3,
          colors: [
            OzColors.gold.withValues(alpha: 0.10),
            OzColors.bgMid.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(OzTokens.radiusLg),
        border: Border.all(color: OzColors.gold.withValues(alpha: 0.4)),
        boxShadow: OzColors.goldGlow(alpha: 0.18, blur: 24),
      ),
      child: Column(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 22)),
          const SizedBox(height: OzTokens.spaceSm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: OzTypography.italicBody(fontSize: 14, color: OzColors.fg),
          ),
        ],
      ),
    );
  }
}

/// 카드별 리딩(상세 리딩). CSS 대응: .oz-card-reading(.past/.present/.future
/// 색상 차등 → past:teal, present:gold, future:rose로 재현).
///
/// [타로 카드 탭 확대] 카드를 탭하면 [_PositionDetailSheet]가 카드 이미지를
/// 확대해서 보여주고, 기존 [position.interpretation](요약 1줄)에 더해
/// [TarotReadingExtras.deepDivePerspectives]가 만들어주는 "마음/현실/흐름"
/// 3관점 심화 텍스트를 추가로 노출한다(§11 P4 심화해석에서 이미 검증된
/// 문장 풀을 그대로 재사용 - 신규 서버 API 없이 §1-3 신규 자산 최소화
/// 원칙을 유지). 카드에 살짝 확대되는 느낌을 주기 위해 InkWell + Hero를
/// 함께 사용한다.
class _PositionCard extends StatelessWidget {
  final TarotSpreadPosition position;
  final int index;
  final String topic;
  final String resultId;
  const _PositionCard({
    required this.position,
    required this.index,
    required this.topic,
    required this.resultId,
  });

  Color get _glow {
    switch (index) {
      case 0:
        return OzColors.teal;
      case 2:
        return OzColors.rose;
      default:
        return OzColors.gold;
    }
  }

  String get _heroTag => 'tarot_position_card_${resultId}_$index';

  @override
  Widget build(BuildContext context) {
    final card = position.card;
    final glow = _glow;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(OzTokens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(OzTokens.radiusLg),
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.all(OzTokens.spaceLg),
          decoration: BoxDecoration(
            color: OzColors.cardSoft,
            borderRadius: BorderRadius.circular(OzTokens.radiusLg),
            border: Border.all(color: OzColors.borderSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: _heroTag,
                child: Container(
                  width: 56,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A3378), Color(0xFF2A1A5C)],
                    ),
                    borderRadius: BorderRadius.circular(OzTokens.radiusSm),
                    border: Border.all(color: glow.withValues(alpha: 0.5)),
                  ),
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(OzTokens.radiusSm),
                    child: Transform.rotate(
                      angle: card.isReversed ? pi : 0,
                      child: Image.asset(
                        card.thumbAssetPath,
                        width: 56,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          card.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: OzTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: OzTokens.spaceSm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: glow.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(
                              OzTokens.radiusPill,
                            ),
                          ),
                          child: Text(
                            position.label,
                            style: OzTypography.monoLabel(
                              fontSize: 9.5,
                              color: glow,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.zoom_in_rounded,
                          size: 16,
                          color: OzColors.faint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${card.nameKr}${card.isReversed ? ' (역방향)' : ''}',
                      style: OzTypography.cardName(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      position.interpretation,
                      style: OzTypography.body(
                        fontSize: 12.5,
                        color: OzColors.fg.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _PositionDetailSheet(
          position: position,
          glow: _glow,
          heroTag: _heroTag,
          topic: topic,
          resultId: resultId,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }
}

/// [타로 카드 탭 확대] 과거/현재/미래(등) 포지션 카드를 탭했을 때 뜨는
/// 확대 상세 화면. 카드 이미지를 크게 보여주고, 기존 요약 해석
/// ([position.interpretation])에 더해 [TarotReadingExtras
/// .deepDivePerspectives](§11 P4 심화해석에서 이미 검증된 "마음/현실/흐름"
/// 3관점 문장 풀)를 이 포지션의 카드에 적용해 추가 콘텐츠로 보여준다.
/// 신규 서버 API/문장 풀 없이 기존 자산만 재사용한다(§1-3 원칙).
class _PositionDetailSheet extends StatelessWidget {
  final TarotSpreadPosition position;
  final Color glow;
  final String heroTag;
  final String topic;
  final String resultId;
  const _PositionDetailSheet({
    required this.position,
    required this.glow,
    required this.heroTag,
    required this.topic,
    required this.resultId,
  });

  @override
  Widget build(BuildContext context) {
    final card = position.card;
    // 포지션별로 다른 관점 문장이 나오도록 index 정보 없이도 카드명 자체가
    // 이미 시드에 포함되므로(perspectives 내부에서 card.name도 섞임)
    // 과거/현재/미래가 서로 다른 카드라면 자연히 문장도 달라진다.
    final perspectives = TarotReadingExtras.deepDivePerspectives(
      card,
      topic,
      '${resultId}_${position.label}',
    );

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            // 바깥 여백을 탭하면 닫히도록 하되, 카드 내부 탭은 전파되지
            // 않게 한다.
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OzTokens.spaceLg,
              ),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: OzTokens.spaceMd,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: glow.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(
                                  OzTokens.radiusPill,
                                ),
                              ),
                              child: Text(
                                position.label,
                                style: OzTypography.monoLabel(
                                  fontSize: 11,
                                  color: glow,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: OzColors.fg.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: OzTokens.spaceSm),
                        Hero(
                          tag: heroTag,
                          child: Container(
                            width: 170,
                            height: 255,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4A3378),
                                  Color(0xFF2A1A5C),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                OzTokens.radiusLg,
                              ),
                              border: Border.all(
                                color: glow.withValues(alpha: 0.7),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: glow.withValues(alpha: 0.35),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                OzTokens.radiusLg,
                              ),
                              child: Transform.rotate(
                                angle: card.isReversed ? pi : 0,
                                child: Image.asset(
                                  card.imageAssetPath,
                                  width: 170,
                                  height: 255,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    card.icon,
                                    style: const TextStyle(fontSize: 64),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: OzTokens.spaceLg),
                        Text(
                          '${card.nameKr}${card.isReversed ? ' (역방향)' : ''}',
                          textAlign: TextAlign.center,
                          style: OzTypography.hero(
                            fontSize: 20,
                            color: OzColors.fg,
                          ),
                        ),
                        const SizedBox(height: OzTokens.spaceMd),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(OzTokens.spaceLg),
                          decoration: BoxDecoration(
                            color: OzColors.cardSoft,
                            borderRadius: BorderRadius.circular(
                              OzTokens.radiusMd,
                            ),
                            border: Border.all(color: OzColors.borderSoft),
                          ),
                          child: Text(
                            position.interpretation,
                            style: OzTypography.body(
                              fontSize: 13.5,
                              color: OzColors.fg.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: OzTokens.spaceLg),
                        Text(
                          '이 카드를 더 깊이 들여다보면',
                          style: OzTypography.monoLabel(
                            fontSize: 10.5,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: OzTokens.spaceSm),
                        for (final p in perspectives) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: OzTokens.spaceSm,
                            ),
                            padding: const EdgeInsets.all(OzTokens.spaceMd),
                            decoration: BoxDecoration(
                              color: OzColors.card,
                              borderRadius: BorderRadius.circular(
                                OzTokens.radiusMd,
                              ),
                              border: Border.all(color: OzColors.borderSoft),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '✨',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      p.label,
                                      style: OzTypography.monoLabel(
                                        fontSize: 9.5,
                                        color: OzColors.gold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  p.text,
                                  style: OzTypography.body(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: OzTokens.spaceLg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
