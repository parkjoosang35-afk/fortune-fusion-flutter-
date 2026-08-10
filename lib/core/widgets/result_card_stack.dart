import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';
import 'premium_button.dart';
import 'premium_card.dart';
import 'simple_markdown_text.dart';

/// [서브 디자인 통일 확산 프롬프트] §6 결과 페이지 표준 스켈레톤.
///
/// "한 화면의 완성"이 아니라, 오늘의 운세/사주/타로/궁합/관상/손금 등
/// 모든 운세 결과 화면이 재사용할 표준 플로우를 만드는 것이 목표다.
/// 각 카테고리는 이 위젯에 데이터(히어로 문구/섹션 목록/CTA 목록)만 넘기면
/// UI를 다시 구현하지 않고 동일한 "카드 스택형 리포트" 톤을 그대로 얻는다.
///
/// 스펙(§6): 배경 화이트, 히어로카드 #F0EEFB, 섹션카드 #F6F5FA, radius16,
/// padding14, 카드간 세로간격 12, 섹션제목 Title15/SemiBold, 섹션본문
/// Body14/Medium 행간1.4, 강조는 컬러가 아니라 SemiBold로만, 하단 CTA는
/// 블랙 pill(홈 CTA 스타일 재사용=PremiumButton.black), 열림패스 필요 영역은
/// 카드 상단 "잠금" 표시 + 담백한 유도 문구(활성 시 잠금 제거 + 남은 시간 표시).
class ResultSection {
  const ResultSection({required this.title, required this.body, this.trailing});

  final String title;
  final String body;
  final Widget? trailing;
}

class ResultCta {
  const ResultCta({required this.label, this.icon, required this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
}

class ResultCardStack extends StatelessWidget {
  const ResultCardStack({
    super.key,
    required this.heroCaption,
    required this.heroSummary,
    this.heroChips = const [],
    this.heroExtra,
    this.sections = const <ResultSection>[],
    this.ctas = const <ResultCta>[],
    this.isLocked = false,
    this.lockMessage,
    this.remainingLabel,
    this.sectionTitle = '세부 리포트',
  });

  /// 히어로 카드 상단 캡션(예: "11월 3일의 운세")
  final String heroCaption;

  /// 히어로 카드 메인 요약 문구
  final String heroSummary;

  /// 히어로 카드 내부에 표시할 작은 정보 칩(예: 행운의 색/숫자) 목록
  final List<Widget> heroChips;

  /// 히어로 카드 하단에 추가로 붙일 위젯(예: 점수 바, 카드 이미지 등)
  final Widget? heroExtra;

  /// 섹션 카드 리스트(세부 리포트)
  final List<ResultSection> sections;

  /// 하단 CTA 목록(저장/공유/다른 운세 보기 등)
  final List<ResultCta> ctas;

  /// 열림패스 필요 영역 잠금 여부
  final bool isLocked;

  /// 잠금 상태일 때 표시할 유도 문구
  final String? lockMessage;

  /// 잠금 해제(활성) 상태일 때 표시할 남은 시간 라벨
  final String? remainingLabel;

  /// 세부 리포트 섹션 상단 제목
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UnifiedColors.bg,
      child: ListView(
        padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
        children: [
          // 열림패스 상태 바
          if (isLocked || remainingLabel != null) ...[
            _PassStatusBar(
              isLocked: isLocked,
              message: lockMessage,
              remainingLabel: remainingLabel,
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
          ],

          // 히어로 카드
          PremiumCard(
            backgroundColor: UnifiedColors.cardMain,
            borderColor: Colors.transparent,
            showShadow: false,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
            padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heroCaption, style: UnifiedText.caption()),
                const SizedBox(height: UnifiedTokens.spaceSm),
                SimpleMarkdownText(
                  data: heroSummary,
                  baseStyle: UnifiedText.body(
                    color: UnifiedColors.textPrimary,
                  ).copyWith(fontSize: 15),
                ),
                if (heroChips.isNotEmpty) ...[
                  const SizedBox(height: UnifiedTokens.spaceLg),
                  Row(
                    children: [
                      for (int i = 0; i < heroChips.length; i++) ...[
                        Expanded(child: heroChips[i]),
                        if (i != heroChips.length - 1)
                          const SizedBox(width: UnifiedTokens.spaceMd),
                      ],
                    ],
                  ),
                ],
                if (heroExtra != null) ...[
                  const SizedBox(height: UnifiedTokens.spaceLg),
                  heroExtra!,
                ],
              ],
            ),
          ),

          if (sections.isNotEmpty) ...[
            const SizedBox(height: UnifiedTokens.spaceXxl),
            Text(sectionTitle, style: UnifiedText.titleLarge()),
            const SizedBox(height: UnifiedTokens.spaceMd),
            for (int i = 0; i < sections.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == sections.length - 1 ? 0 : UnifiedTokens.spaceMd,
                ),
                child: _SectionCard(section: sections[i]),
              ),
          ],

          if (ctas.isNotEmpty) ...[
            const SizedBox(height: UnifiedTokens.spaceXxl),
            for (int i = 0; i < ctas.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == ctas.length - 1 ? 0 : UnifiedTokens.spaceSm,
                ),
                child: i == 0
                    ? PremiumButton.black(
                        label: ctas[i].label,
                        icon: ctas[i].icon,
                        onPressed: ctas[i].onTap,
                      )
                    : PremiumButton.secondary(
                        label: ctas[i].label,
                        icon: ctas[i].icon,
                        onPressed: ctas[i].onTap,
                      ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final ResultSection section;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(section.title, style: UnifiedText.title())),
              if (section.trailing != null) section.trailing!,
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          SimpleMarkdownText(data: section.body, baseStyle: UnifiedText.body()),
        ],
      ),
    );
  }
}

class _PassStatusBar extends StatelessWidget {
  const _PassStatusBar({
    required this.isLocked,
    this.message,
    this.remainingLabel,
  });

  final bool isLocked;
  final String? message;
  final String? remainingLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceLg,
        vertical: UnifiedTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: isLocked ? UnifiedColors.cardAllMenu : UnifiedColors.cardMain,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textPrimary,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              isLocked
                  ? (message ?? '상세 리포트는 프리패스로 열람할 수 있어요.')
                  : '프리패스 사용 중${remainingLabel != null ? ' · $remainingLabel' : ''}',
              style: UnifiedText.bodySmall(),
            ),
          ),
        ],
      ),
    );
  }
}
