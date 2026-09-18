// ═══════════════════════════════════════════════════════════════
// FILE: sintong_dynamic_section_card.dart
// [Stage2 결함수정 — 결함-E05-01] 관리자(admin_web) CMS가 발행한 홈 섹션
// (`PageSectionModel`) 중, 기존 전용 위젯(SintongFreePassBar, 서비스
// 그리드 등)으로 매핑되지 않는 나머지 섹션(pass_promo, hero_fortune_summary,
// lucky_number, wish_community_preview, happy_money_earn/use,
// subscription_promo)을 관리자가 입력한 title/subtitle/buttonText/badgeText
// 값 그대로 렌더링하는 범용 카드.
//
// [배경] 이전에는 `HomePageConfigProvider.load()` 결과를 `debugPrint`로만
// 출력하고 실제 화면에는 전혀 반영하지 않아, 관리자가 섹션 순서를 바꾸거나
// 숨겨도 앱 화면이 전혀 바뀌지 않는 결함(E-05, 미구현 판정)이 있었다. 이
// 위젯 + home_screen.dart의 동적 배선으로 admin_web이 내려주는 sortOrder/
// isVisible/status/displayRules가 실제 렌더링 순서·노출 여부를 결정하도록
// 수정한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../../domain/page_config_model.dart';
import '../sintong_home_tokens.dart';

class SintongDynamicSectionCard extends StatelessWidget {
  final PageSectionModel section;

  const SintongDynamicSectionCard({super.key, required this.section});

  Color _backgroundColor() {
    switch (section.backgroundPreset) {
      case 'lavender':
        return const Color(0xFFF1EEFB);
      case 'soft_gray':
        return const Color(0xFFF4F4F5);
      case 'black_emphasis':
        return SintongHomeColors.inkBlack;
      default:
        return Colors.white;
    }
  }

  bool get _isDark => section.backgroundPreset == 'black_emphasis';

  @override
  Widget build(BuildContext context) {
    final titleColor = _isDark ? Colors.white : SintongHomeColors.ink;
    final subtitleColor = _isDark
        ? Colors.white.withValues(alpha: 0.75)
        : SintongHomeColors.inkSoft;

    return GestureDetector(
      onTap: section.buttonLink == null
          ? null
          : () => Navigator.of(context).pushNamed(section.buttonLink!),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _backgroundColor(),
          borderRadius: BorderRadius.circular(16),
          border: _isDark
              ? null
              : Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (section.title != null)
                        Flexible(
                          child: Text(
                            section.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                      if (section.badgeText != null &&
                          section.badgeText!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SintongHomeColors.ctaGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            section.badgeText!,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A5A1A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (section.subtitle != null &&
                      section.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (section.buttonText != null &&
                section.buttonText!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isDark ? Colors.white : SintongHomeColors.inkBlack,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  section.buttonText!,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isDark ? SintongHomeColors.inkBlack : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
