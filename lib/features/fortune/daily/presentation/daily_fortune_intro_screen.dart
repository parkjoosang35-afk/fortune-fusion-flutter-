import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../../core/widgets/fortune/primary_cta.dart';

/// [오늘의 운세 표준 플로우] §1 진입 화면 — /fortune/today/intro
/// (기존 진입점 `/home/daily-fortune-detail`도 이 화면으로 라우팅된다.)
///
/// 헤더 + 히어로카드 + 안내카드 + 하단 고정 CTA. 이 화면은 다른 운세
/// 카테고리(사주/궁합/타로/관상/손금)의 진입 화면으로도 그대로 복제해
/// 문구만 바꿔 재사용할 수 있는 표준 레이아웃이다.
class DailyFortuneIntroScreen extends StatelessWidget {
  const DailyFortuneIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UnifiedTokens.spaceXl,
                vertical: UnifiedTokens.spaceSm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: UnifiedTokens.iconLg,
                      color: UnifiedColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('오늘의 운세', style: UnifiedText.titleLarge()),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.spaceXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: UnifiedTokens.spaceLg),
                    // 히어로 카드
                    PremiumCard(
                      backgroundColor: UnifiedColors.cardMain,
                      borderColor: Colors.transparent,
                      showShadow: false,
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusLg,
                      ),
                      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('오늘 하루의 흐름을 확인해보세요', style: UnifiedText.title()),
                          const SizedBox(height: UnifiedTokens.spaceXs),
                          Text(
                            '지금 이 순간의 기운을 담백하게 정리해드려요',
                            style: UnifiedText.body(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceMd),
                    // 안내 카드
                    PremiumCard(
                      backgroundColor: UnifiedColors.cardSection,
                      borderColor: Colors.transparent,
                      showShadow: false,
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusMd,
                      ),
                      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                      child: Text(
                        '연애 · 금전 · 인간관계 · 건강 · 일 · 학업의 흐름을 정리해드려요',
                        style: UnifiedText.body(),
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceXxl),
                  ],
                ),
              ),
            ),
            // 하단 고정 CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UnifiedTokens.spaceXl,
                0,
                UnifiedTokens.spaceXl,
                UnifiedTokens.spaceXl,
              ),
              child: PrimaryCTA(
                label: '오늘의 운세 보기',
                onPressed: () =>
                    Navigator.of(context).pushNamed('/fortune/today/input'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
