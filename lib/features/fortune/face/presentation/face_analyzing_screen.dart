import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sintong/theme/sintong_colors.dart';
import '../../sintong/theme/sintong_typography.dart';
import '../../sintong/widgets/bangtong_fairy_avatar.dart';
import '../../sintong/widgets/sintong_screen_bg.dart';
import '../application/face_provider.dart';

/// [관상·손금 신통방통 "새벽 한지" 리스킨] AI 관상 분석중(로딩) 화면.
///
/// [핵심 원칙 - 실제 분석 중 표시] 스캔 애니메이션은 실제 [FaceProvider.analyze]
/// API 호출이 진행되는 동안 표시되어야 하며, "가짜 애니메이션을 먼저 재생한 뒤
/// 결과를 붙이는" 방식은 금지된다. 이 화면은 [_navigateOnResult]가
/// `provider.state.isSuccess || provider.state.isError`가 될 때까지 부위별
/// 하이라이트 사이클(_regionCycleDuration마다 순환)을 계속 반복하고, API가
/// 실제로 끝난 시점에만 결과 화면으로 이동한다 — 이 로직은 리스킨 전과
/// 전혀 변경하지 않았다.
///
/// [기존 시스템 유지 원칙] FaceProvider/analyze()/결과화면 라우팅
/// (`/ai-fortune/face/result`)은 전혀 변경하지 않는다. 위젯 트리와
/// 색상/타이포/모티프만 핸드오프의 AnalyzingScreen 디자인(Dawn Hanji 배경 +
/// 방통선녀 + 觀相 하자 라벨)으로 교체한다.
class FaceAnalyzingScreen extends StatefulWidget {
  const FaceAnalyzingScreen({super.key});

  @override
  State<FaceAnalyzingScreen> createState() => _FaceAnalyzingScreenState();
}

/// 이마 → 눈 → 코 → 입 → 턱 순서. 각 항목의 [rangeStart]/[rangeEnd]는 사진
/// 높이 대비 비율(0.0=상단, 1.0=하단)로, 스캔라인이 이 구간에 머무를 때
/// 해당 부위가 하이라이트된다.
class _FaceRegion {
  const _FaceRegion(this.label, this.hanja, this.rangeStart, this.rangeEnd);
  final String label;
  final String hanja;
  final double rangeStart;
  final double rangeEnd;
}

class _FaceAnalyzingScreenState extends State<FaceAnalyzingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _pulseController;

  bool _navigated = false;

  static const _regions = [
    _FaceRegion('이마', '額', 0.05, 0.28),
    _FaceRegion('눈', '眼', 0.28, 0.48),
    _FaceRegion('코', '鼻', 0.46, 0.66),
    _FaceRegion('입', '口', 0.64, 0.82),
    _FaceRegion('턱', '頷', 0.80, 0.98),
  ];

  static const _regionCycleDuration = Duration(milliseconds: 4200);

  @override
  void initState() {
    super.initState();
    // 스캔라인이 사진 위를 한 사이클(이마→턱) 동안 이동하며, API가 아직
    // 끝나지 않았으면 [_navigateOnResult]가 재이동을 트리거하지 않으므로
    // repeat()로 자연스럽게 계속 순환한다.
    _scanController = AnimationController(
      vsync: this,
      duration: _regionCycleDuration,
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

  void _navigateOnResult(FaceProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/face/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  /// 현재 스캔 진행률(0.0~1.0)에 대응하는 현재 부위 인덱스.
  int _currentRegionIndex(double t) {
    final index = (t * _regions.length).floor();
    return index.clamp(0, _regions.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaceProvider>();
    _navigateOnResult(provider);
    final imageBytes = provider.selectedImageBytes;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SintongScreenBg()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, _) {
                      final t = _scanController.value;
                      final regionIndex = _currentRegionIndex(t);
                      return _FaceScanCard(
                        imageBytes: imageBytes,
                        scanProgress: t,
                        regions: _regions,
                        activeRegionIndex: regionIndex,
                        pulseValue: _pulseController.value,
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // 방통선녀 (읽는 중)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const BangtongFairyAvatar(
                        size: 60,
                        borderWidth: 2,
                        glowIntensity: 0.8,
                      ),
                      Positioned(
                        top: -4,
                        left: -6,
                        child: Transform.rotate(
                          angle: -0.14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SintongColors.accent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '方通',
                              style: SintongType.monoSm.copyWith(
                                color: const Color(0xFFFAF3E0),
                                fontSize: 8,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    '觀相 · READING',
                    style: SintongType.monoSm.copyWith(
                      color: SintongColors.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '얼굴을 / 읽고 있어요',
                    style: SintongType.displayLg.copyWith(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, _) {
                      final regionIndex = _currentRegionIndex(
                        _scanController.value,
                      );
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeInOutCubic,
                        switchOutCurve: Curves.easeInOutCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
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
                          '${_regions[regionIndex].label} 부위를 분석하고 있어요...',
                          key: ValueKey(regionIndex),
                          style: SintongType.bodySmall.copyWith(
                            color: SintongColors.muted,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),

                  _RegionStepIndicator(
                    regions: _regions,
                    controller: _scanController,
                    currentIndexBuilder: _currentRegionIndex,
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

/// 실제 업로드 사진 위에 스캔라인 + 부위별 하이라이트 박스를 그리는 카드.
/// 사진이 없는 경우(이론상 발생하지 않음 — capture 화면에서 이미 필수로 강제)
/// 안전망으로 아이콘 placeholder를 대신 보여준다(회귀 방지).
class _FaceScanCard extends StatelessWidget {
  const _FaceScanCard({
    required this.imageBytes,
    required this.scanProgress,
    required this.regions,
    required this.activeRegionIndex,
    required this.pulseValue,
  });

  final dynamic imageBytes;
  final double scanProgress;
  final List<_FaceRegion> regions;
  final int activeRegionIndex;
  final double pulseValue;

  static const double _cardWidth = 240;
  static const double _cardHeight = 300;

  @override
  Widget build(BuildContext context) {
    final activeRegion = regions[activeRegionIndex];
    final glowOpacity = 0.35 + (0.35 * pulseValue);

    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SintongColors.line),
        boxShadow: [
          BoxShadow(
            color: SintongColors.glowShadow,
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
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
              color: SintongColors.card,
              alignment: Alignment.center,
              child: Icon(
                Icons.face_retouching_natural_rounded,
                size: 72,
                color: SintongColors.muted,
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

          // ③ 현재 활성 부위 하이라이트 박스(글로우 테두리).
          Positioned(
            left: 0,
            right: 0,
            top: _cardHeight * activeRegion.rangeStart,
            height:
                _cardHeight * (activeRegion.rangeEnd - activeRegion.rangeStart),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: SintongColors.glow.withValues(
                    alpha: glowOpacity + 0.4,
                  ),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SintongColors.glow.withValues(
                      alpha: glowOpacity * 0.5,
                    ),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // ④ 좌우로 가로지르는 스캔라인.
          Positioned(
            left: 0,
            right: 0,
            top: (_cardHeight * scanProgress).clamp(0.0, _cardHeight - 2),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: SintongColors.glow.withValues(alpha: 0.9),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    SintongColors.glow.withValues(alpha: 0.0),
                    SintongColors.glow,
                    SintongColors.glow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ⑤ 좌측 상단 라벨 뱃지(현재 분석 중인 부위, 하자 표기).
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(SintongColors.glow),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${activeRegion.hanja} · ${activeRegion.label}',
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

/// 하단 5단계 부위 스텝 인디케이터(이마-눈-코-입-턱). 현재 부위는 채워진
/// 하자 배지 + 라벨 강조, 이미 지나간 부위는 진하게, 아직 안 온 부위는 옅게.
class _RegionStepIndicator extends StatelessWidget {
  const _RegionStepIndicator({
    required this.regions,
    required this.controller,
    required this.currentIndexBuilder,
  });

  final List<_FaceRegion> regions;
  final AnimationController controller;
  final int Function(double) currentIndexBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentIndex = currentIndexBuilder(controller.value);
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(regions.length, (index) {
            final isDone = index < currentIndex;
            final isActive = index == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: (isDone || isActive)
                    ? SintongColors.accent
                    : Colors.black.withValues(alpha: 0.06),
                border: (isDone || isActive)
                    ? null
                    : Border.all(color: SintongColors.line),
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: isActive ? 1 : (isDone ? 1 : 0.45),
                child: Text(
                  regions[index].hanja,
                  style: TextStyle(
                    fontFamily: SintongType.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: (isDone || isActive)
                        ? const Color(0xFFFAF3E0)
                        : SintongColors.fg,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
