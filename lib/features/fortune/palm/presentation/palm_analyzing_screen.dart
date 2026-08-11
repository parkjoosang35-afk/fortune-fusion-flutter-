import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../application/palm_provider.dart';

/// [STEP10 - 손금 AI 스캔 연출] PalmAnalyzingScreen 고급화.
///
/// "신통방통 기존 시스템 유지 + 프리패스 + 관상·손금 AI 스캔 연출 통합 개발
/// 프롬프트" §손금 스캔 요구사항: 사진 업로드 후 즉시 결과가 아니라 중간에
/// AI 스캔 연출 화면을 추가하고, 손금의 4대 주요선(감정선→두뇌선→운명선→
/// 생명선)을 사진 상단→하단 순서로 순차 하이라이트한다.
///
/// [핵심 원칙 - 실제 분석 중 표시] FaceAnalyzingScreen(STEP9)과 동일하게,
/// 스캔 애니메이션은 실제 [PalmProvider.analyze] API 호출이 진행되는 동안
/// 표시되어야 하며, "가짜 애니메이션을 먼저 재생한 뒤 결과를 붙이는" 방식은
/// 금지된다. [_navigateOnResult]가 `provider.state.isSuccess ||
/// provider.state.isError`가 될 때까지 라인별 하이라이트 사이클
/// (_lineCycleDuration마다 순환)을 계속 반복하고, API가 실제로 끝난 시점에만
/// 결과 화면으로 이동한다.
///
/// [기존 시스템 유지 원칙] PalmProvider/analyze()/결과화면 라우팅
/// (`/ai-fortune/palm/result`)은 전혀 변경하지 않는다. 이 화면은 Presentation
/// 레이어의 로딩 연출만 사진 기반 스캔으로 교체한다.
class PalmAnalyzingScreen extends StatefulWidget {
  const PalmAnalyzingScreen({super.key});

  @override
  State<PalmAnalyzingScreen> createState() => _PalmAnalyzingScreenState();
}

/// 감정선 → 두뇌선 → 운명선 → 생명선 순서. 각 항목의 [rangeStart]/[rangeEnd]는
/// 사진 높이 대비 비율(0.0=상단, 즉 손가락 쪽 / 1.0=하단, 즉 손목 쪽)로,
/// 스캔라인이 이 구간에 머무를 때 해당 손금선이 하이라이트된다.
class _PalmLine {
  const _PalmLine(this.label, this.rangeStart, this.rangeEnd);
  final String label;
  final double rangeStart;
  final double rangeEnd;
}

class _PalmAnalyzingScreenState extends State<PalmAnalyzingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _pulseController;

  bool _navigated = false;

  static const _lines = [
    _PalmLine('감정선', 0.05, 0.30),
    _PalmLine('두뇌선', 0.28, 0.54),
    _PalmLine('운명선', 0.52, 0.76),
    _PalmLine('생명선', 0.74, 0.98),
  ];

  static const _lineCycleDuration = Duration(milliseconds: 4200);

  @override
  void initState() {
    super.initState();
    // 스캔라인이 사진 위를 한 사이클(감정선→생명선) 동안 이동하며, API가
    // 아직 끝나지 않았으면 [_navigateOnResult]가 재이동을 트리거하지
    // 않으므로 repeat()로 자연스럽게 계속 순환한다.
    _scanController = AnimationController(
      vsync: this,
      duration: _lineCycleDuration,
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateOnResult(PalmProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/palm/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  /// 현재 스캔 진행률(0.0~1.0)에 대응하는 현재 손금선 인덱스.
  int _currentLineIndex(double t) {
    final index = (t * _lines.length).floor();
    return index.clamp(0, _lines.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PalmProvider>();
    _navigateOnResult(provider);
    final imageBytes = provider.selectedImageBytes;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceXxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, _) {
                  final t = _scanController.value;
                  final lineIndex = _currentLineIndex(t);
                  return _PalmScanCard(
                    imageBytes: imageBytes,
                    scanProgress: t,
                    lines: _lines,
                    activeLineIndex: lineIndex,
                    pulseValue: _pulseController.value,
                  );
                },
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, _) {
                  final lineIndex = _currentLineIndex(_scanController.value);
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      '${_lines[lineIndex].label}을 분석하고 있어요...',
                      key: ValueKey(lineIndex),
                      style: UnifiedText.body(color: UnifiedColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
              SizedBox(height: UnifiedTokens.spaceLg),
              _LineStepIndicator(
                lines: _lines,
                controller: _scanController,
                currentIndexBuilder: _currentLineIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 실제 업로드 손금 사진 위에 스캔라인 + 손금선별 하이라이트 박스를 그리는
/// 카드. 사진이 없는 경우(이론상 발생하지 않음 — capture 화면에서 이미 필수로
/// 강제) 안전망으로 아이콘 placeholder를 대신 보여준다(회귀 방지).
class _PalmScanCard extends StatelessWidget {
  const _PalmScanCard({
    required this.imageBytes,
    required this.scanProgress,
    required this.lines,
    required this.activeLineIndex,
    required this.pulseValue,
  });

  final dynamic imageBytes;
  final double scanProgress;
  final List<_PalmLine> lines;
  final int activeLineIndex;
  final double pulseValue;

  static const double _cardWidth = 240;
  static const double _cardHeight = 300;

  @override
  Widget build(BuildContext context) {
    final activeLine = lines[activeLineIndex];
    final glowOpacity = 0.35 + (0.35 * pulseValue);

    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        border: Border.all(color: UnifiedColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ① 실제 업로드 사진(없으면 안전망 placeholder).
          if (imageBytes != null)
            Image.memory(imageBytes, fit: BoxFit.cover)
          else
            Container(
              color: UnifiedColors.cardAllMenu,
              alignment: Alignment.center,
              child: const Icon(
                Icons.back_hand_rounded,
                size: 72,
                color: UnifiedColors.textCaption,
              ),
            ),

          // ② 아직 스캔되지 않은 하단부를 살짝 어둡게(스캔 진행 시각화).
          Positioned(
            left: 0,
            right: 0,
            top: _cardHeight * scanProgress,
            bottom: 0,
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),

          // ③ 현재 활성 손금선 하이라이트 박스(네온 테두리 + 은은한 glow).
          Positioned(
            left: 0,
            right: 0,
            top: _cardHeight * activeLine.rangeStart,
            height: _cardHeight * (activeLine.rangeEnd - activeLine.rangeStart),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: UnifiedColors.neon.withValues(alpha: glowOpacity + 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: UnifiedColors.neon.withValues(alpha: glowOpacity * 0.5),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // ④ 좌우로 가로지르는 스캔라인(레이저 느낌).
          Positioned(
            left: 0,
            right: 0,
            top: (_cardHeight * scanProgress).clamp(0.0, _cardHeight - 2),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: UnifiedColors.neon.withValues(alpha: 0.9),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    UnifiedColors.neon.withValues(alpha: 0.0),
                    UnifiedColors.neon,
                    UnifiedColors.neon.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ⑤ 좌측 상단 라벨 뱃지(현재 분석 중인 손금선).
          Positioned(
            left: UnifiedTokens.spaceSm,
            top: UnifiedTokens.spaceSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: UnifiedColors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        UnifiedColors.neon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI 스캔 · ${activeLine.label}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 4단계 손금선 스텝 인디케이터(감정선-두뇌선-운명선-생명선). 현재
/// 손금선은 채워진 원 + 라벨 강조, 이미 지나간 손금선은 진한 색, 아직 안 온
/// 손금선은 옅게.
class _LineStepIndicator extends StatelessWidget {
  const _LineStepIndicator({
    required this.lines,
    required this.controller,
    required this.currentIndexBuilder,
  });

  final List<_PalmLine> lines;
  final AnimationController controller;
  final int Function(double) currentIndexBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentIndex = currentIndexBuilder(controller.value);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(lines.length, (index) {
            final isDone = index < currentIndex;
            final isActive = index == currentIndex;
            final color = isActive
                ? UnifiedColors.black
                : (isDone
                      ? UnifiedColors.textSecondary
                      : UnifiedColors.textCaption.withValues(alpha: 0.4));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isActive ? 10 : 7,
                    height: isActive ? 10 : 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone || isActive
                          ? color
                          : Colors.transparent,
                      border: Border.all(color: color, width: 1.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lines[index].label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
