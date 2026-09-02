import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// C · Calculating — `/guinji-map/calc` (호스트) / 게스트 참여 계산 화면.
///
/// [2026-09 새 디자인 리스킨] 새 디자인 zip `lib/guiindo/screens/calculating_screen.dart`
/// 의 UI(6초 회전 정/역방향 이중 원 + 중앙 56px 로즈 그라디언트 오브)를 그대로
/// 이식했다. 데이터 흐름(계산 완료 후 다음 화면 이동)은 라우팅 계층이 담당하도록
/// [onComplete] 콜백 + [autoAdvanceAfter] 타이머 시그니처를 그대로 유지한다.
///
/// [2026-09 컨텍스트별 문구 분기] 이 화면은 두 개의 서로 다른 흐름에서
/// 재사용된다 — (1) 호스트가 자기 정보만 입력한 시점(I→C→M, 아직 2인
/// 관계가 존재하지 않는 "내 사주 계산"), (2) 지인이 참여해 호스트와의
/// 관계를 계산하는 시점(게스트 참여→C→Y, "두 분의 관계 계산"). 기존에는
/// 두 경우 모두 "두 분의 관계를 정성껏 살펴보고 있어요"로 고정되어 있어
/// 호스트의 1인 계산 시점에는 논리적으로 맞지 않았다. [title]/[subtitle]을
/// 선택적으로 오버라이드할 수 있게 해, 기본값(게스트 2인 관계 계산 문구)은
/// 그대로 유지하면서 호스트 라우트(`/guinji-map/calc`, app_router.dart)에서만
/// "내 사주" 문구로 교체한다.
class GuinjiCalculatingScreen extends StatefulWidget {
  const GuinjiCalculatingScreen({
    super.key,
    this.autoAdvanceAfter = const Duration(milliseconds: 1600),
    this.onComplete,
    this.title = '두 분의 관계를\n정성껏 살펴보고 있어요',
    this.subtitle = '만세력을 계산하고\n오행·십성·합충을 분석 중입니다',
  });

  static const routeName = '/guinji-map/calc';

  final Duration autoAdvanceAfter;
  final VoidCallback? onComplete;

  /// 로딩 화면 헤드라인. 기본값은 게스트 2인 관계 계산 문구(하위 호환).
  final String title;

  /// 로딩 화면 서브텍스트. 기본값은 게스트 2인 관계 계산 문구(하위 호환).
  final String subtitle;

  @override
  State<GuinjiCalculatingScreen> createState() =>
      _GuinjiCalculatingScreenState();
}

class _GuinjiCalculatingScreenState extends State<GuinjiCalculatingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _advanceTimer;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _advanceTimer = Timer(widget.autoAdvanceAfter, () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: const GmTopBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RotationTransition(
                      turns: _ringController,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GmColors.rose300.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RotationTransition(
                      turns: ReverseAnimation(_ringController),
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GmColors.rose600.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [GmColors.rose300, GmColors.rose600],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: GmColors.blush.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '신',
                        style: TextStyle(
                          fontFamily: GmFonts.serif,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GmFonts.serif,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: GmColors.ink,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: GmColors.inkSoft,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              '✦ Powered by 신통방통 자체 만세력 엔진 ✦',
              style: TextStyle(
                fontSize: 10,
                color: GmColors.inkFaint,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
