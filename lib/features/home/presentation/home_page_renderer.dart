import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../wallet/application/wallet_provider.dart';
import '../domain/page_config_model.dart';

/// [메인화면 관리자 편집기] §14/§16 HomePageRenderer
///
/// admin_web에서 발행하고 SectionVisibilityEvaluator로 걸러진
/// `List<PageSectionModel>`을 13개 화이트리스트 blockType에 맞춰 실제 위젯으로
/// 그린다. 프리셋(stylePreset/backgroundPreset/alignmentPreset/densityPreset)만
/// 참조하고 자유 CSS/폰트/패딩 값은 받지 않는다(§9 "프리셋 기반 스타일" 원칙).
///
/// [그룹 렌더링] double_card_grid/horizontal_card_scroll/category_shortcut_row는
/// 관리자가 "여러 섹션을 연달아 등록"하는 방식으로 하나의 그리드/가로스크롤/
/// 숏컷행을 구성한다고 가정하고, 같은 blockType이 연속된 구간을 하나의
/// 그룹 레이아웃으로 묶어서 그린다(섹션 하나 = 그리드/스크롤의 한 아이템).
class HomePageRenderer extends StatelessWidget {
  final List<PageSectionModel> sections;

  const HomePageRenderer({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    final groups = _groupSections(sections);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          _buildGroup(context, group),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  Widget _buildGroup(BuildContext context, _SectionGroup group) {
    switch (group.blockType) {
      case PageBlockType.doubleCardGrid:
        return _DoubleCardGrid(sections: group.sections);
      case PageBlockType.horizontalCardScroll:
        return _HorizontalCardScroll(sections: group.sections);
      case PageBlockType.categoryShortcutRow:
        return _CategoryShortcutRow(section: group.sections.first);
      default:
        // 그 외 블록타입은 그룹핑 없이 섹션 각각을 개별 위젯으로 렌더링.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in group.sections)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildSingle(context, section),
              ),
          ],
        );
    }
  }

  Widget _buildSingle(BuildContext context, PageSectionModel section) {
    switch (section.blockType) {
      case PageBlockType.passPromoBar:
        return _PassPromoBar(section: section);
      case PageBlockType.pointStatusBar:
        return _PointStatusBar(section: section);
      case PageBlockType.wishPreviewBlock:
        return _WishPreviewBlock(section: section);
      case PageBlockType.heroBanner:
      case PageBlockType.textBanner:
      case PageBlockType.ctaBanner:
      case PageBlockType.singleCard:
      case PageBlockType.aiConsultBanner:
      case PageBlockType.eventBanner:
      case PageBlockType.featuredContentBlock:
      case PageBlockType.unknown:
        return _SectionCard(section: section);
      case PageBlockType.doubleCardGrid:
      case PageBlockType.horizontalCardScroll:
      case PageBlockType.categoryShortcutRow:
        // 그룹 렌더링 경로에서만 처리되어야 하지만, 방어적으로 단일 카드로 폴백.
        return _SectionCard(section: section);
    }
  }

  List<_SectionGroup> _groupSections(List<PageSectionModel> input) {
    final groups = <_SectionGroup>[];
    for (final section in input) {
      if (groups.isNotEmpty &&
          groups.last.blockType == section.blockType &&
          _isGroupable(section.blockType)) {
        groups.last.sections.add(section);
      } else {
        groups.add(_SectionGroup(section.blockType, [section]));
      }
    }
    return groups;
  }

  bool _isGroupable(PageBlockType type) =>
      type == PageBlockType.doubleCardGrid ||
      type == PageBlockType.horizontalCardScroll ||
      type == PageBlockType.categoryShortcutRow;
}

class _SectionGroup {
  final PageBlockType blockType;
  final List<PageSectionModel> sections;
  _SectionGroup(this.blockType, this.sections);
}

/// stylePreset/backgroundPreset/alignmentPreset/densityPreset -> 실제 Flutter
/// 스타일 값 매핑(관리자에게는 프리셋 이름만 노출되고, 값 자체는 여기서만 정의).
class _ResolvedStyle {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color secondaryTextColor;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAlign;
  final TextAlign textAlign;
  final Color buttonColor;
  final Color buttonForegroundColor;

  const _ResolvedStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.secondaryTextColor,
    required this.padding,
    required this.crossAlign,
    required this.textAlign,
    required this.buttonColor,
    required this.buttonForegroundColor,
    this.gradient,
    this.border,
    this.shadow,
  });

  factory _ResolvedStyle.resolve(PageSectionModel section) {
    final isCompact = section.densityPreset == 'compact';
    final padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: isCompact ? AppSpacing.sm : AppSpacing.lg,
    );
    final crossAlign = section.alignmentPreset == 'center'
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = section.alignmentPreset == 'center'
        ? TextAlign.center
        : TextAlign.left;

    Color bg = AppColors.premiumBgSection;
    Color fg = AppColors.premiumTextPrimary;
    Color secondary = AppColors.premiumTextSecondary;
    Gradient? gradient;
    Border? border = Border.all(color: AppColors.premiumCardBorder);
    List<BoxShadow>? shadow = const [
      BoxShadow(
        color: AppColors.premiumCardShadow,
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ];
    Color buttonColor = AppColors.premiumBlackCta;
    Color buttonFg = Colors.white;

    switch (section.backgroundPreset) {
      case 'lavender':
        bg = AppColors.premiumSoftLavender;
        break;
      case 'soft_gray':
        bg = AppColors.premiumBgSecondary;
        break;
      case 'black_emphasis':
        bg = AppColors.premiumDeepNavy;
        fg = Colors.white;
        secondary = AppColors.cosmicTextSecondary;
        break;
      default:
        bg = AppColors.premiumBgSection;
    }

    switch (section.stylePreset) {
      case 'soft':
        border = null;
        shadow = const [
          BoxShadow(
            color: AppColors.premiumCardShadow,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ];
        break;
      case 'highlighted':
        border = Border.all(color: AppColors.goldGlowBorder, width: 1.4);
        shadow = const [
          BoxShadow(
            color: Color(0x3AFFD700),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ];
        break;
      case 'compact':
        // 밀도는 densityPreset이 담당하므로 별도 배경 변화 없음.
        break;
      case 'premium':
        gradient = AppColors.premiumIndigoHeroGradient;
        fg = Colors.white;
        secondary = Colors.white.withValues(alpha: 0.82);
        border = null;
        buttonColor = Colors.white;
        buttonFg = AppColors.premiumIndigoStart;
        break;
      case 'black_cta':
        buttonColor = AppColors.premiumBlackCta;
        buttonFg = Colors.white;
        break;
      case 'minimal':
        border = null;
        shadow = null;
        bg = Colors.transparent;
        break;
      default:
        break;
    }

    return _ResolvedStyle(
      backgroundColor: bg,
      foregroundColor: fg,
      secondaryTextColor: secondary,
      gradient: gradient,
      border: border,
      shadow: shadow,
      padding: padding,
      crossAlign: crossAlign,
      textAlign: textAlign,
      buttonColor: buttonColor,
      buttonForegroundColor: buttonFg,
    );
  }
}

Future<void> _handleLink(BuildContext context, String? link) async {
  if (link == null || link.trim().isEmpty) return;
  final value = link.trim();
  if (value.startsWith('/')) {
    Navigator.of(context).pushNamed(value);
    return;
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// hero_banner/text_banner/CTA_banner/single_card/ai_consult_banner/
/// event_banner/featured_content_block 공용 카드.
class _SectionCard extends StatelessWidget {
  final PageSectionModel section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final style = _ResolvedStyle.resolve(section);
    final banner = section.primaryBannerAttachment;
    final isHero =
        section.blockType == PageBlockType.heroBanner ||
        section.blockType == PageBlockType.eventBanner;

    return Container(
      decoration: BoxDecoration(
        color: style.gradient == null ? style.backgroundColor : null,
        gradient: style.gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: style.border,
        boxShadow: style.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: section.buttonLink != null
            ? () => _handleLink(context, section.buttonLink)
            : null,
        child: Padding(
          padding: style.padding,
          child: Column(
            crossAxisAlignment: style.crossAlign,
            children: [
              if (banner != null && isHero)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Image.network(
                      banner.attachmentUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (section.badgeText != null && section.badgeText!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: style.foregroundColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(_kRadiusFull),
                  ),
                  child: Text(
                    section.badgeText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: style.foregroundColor,
                    ),
                  ),
                ),
              if (section.title != null && section.title!.isNotEmpty)
                Text(
                  section.title!,
                  textAlign: style.textAlign,
                  style: TextStyle(
                    fontSize: isHero ? 20 : 17,
                    fontWeight: FontWeight.w800,
                    color: style.foregroundColor,
                  ),
                ),
              if (section.subtitle != null && section.subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    section.subtitle!,
                    textAlign: style.textAlign,
                    style: TextStyle(
                      fontSize: 14,
                      color: style.secondaryTextColor,
                    ),
                  ),
                ),
              if (section.description != null &&
                  section.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    section.description!,
                    textAlign: style.textAlign,
                    style: TextStyle(
                      fontSize: 13,
                      color: style.secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
                ),
              if (section.buttonText != null && section.buttonText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: ElevatedButton(
                    onPressed: () => _handleLink(context, section.buttonLink),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: style.buttonColor,
                      foregroundColor: style.buttonForegroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kRadiusFull),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: Text(section.buttonText!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const double _kRadiusFull = 999;

/// pass_promo_bar - 열림패스 홍보 슬림 바. 실제 PassProvider.isActive를
/// 반영해 이미 활성화된 사용자에게는 문구를 자동으로 바꿔준다.
class _PassPromoBar extends StatelessWidget {
  final PageSectionModel section;
  const _PassPromoBar({required this.section});

  @override
  Widget build(BuildContext context) {
    // [재잠금 정확도] PassProvider.isActive(서버 스냅샷) 대신 AccessChecker의
    // 실시간 계산값을 사용해 만료 시점 이후 즉시 문구가 원래대로 돌아가게 한다.
    final isActive = context.watch<AccessChecker>().openPassState.isActive;
    final style = _ResolvedStyle.resolve(section);
    final title = isActive
        ? '프리패스 이용 중입니다 ✨'
        : (section.title ?? '프리패스로 더 많은 운세를 만나보세요');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: style.gradient == null ? style.backgroundColor : null,
        gradient: style.gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: style.border,
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: style.foregroundColor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: style.foregroundColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isActive && section.buttonText != null)
            TextButton(
              onPressed: () => _handleLink(context, section.buttonLink),
              child: Text(section.buttonText!),
            ),
        ],
      ),
    );
  }
}

/// point_status_bar - 복주머니 적립/보유 현황 슬림 바. WalletProvider.balance를 실반영.
class _PointStatusBar extends StatelessWidget {
  final PageSectionModel section;
  const _PointStatusBar({required this.section});

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<WalletProvider>().balance;
    final style = _ResolvedStyle.resolve(section);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: style.border,
      ),
      child: InkWell(
        onTap: () => _handleLink(context, section.buttonLink),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.accentGold,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                section.title ?? '복주머니 적립하기',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: style.foregroundColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${balance.toString()}개',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.premiumMainPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// wish_preview_block - 소원방 인기글 미리보기. WishPostProvider에 이미 로드된
/// hotWishes가 있으면 실제 데이터 1건을 함께 노출하고, 없으면 관리자 정적
/// 문구만으로 카드를 구성한다(§ Phase-1 범위: 별도 API 재조회는 하지 않음).
class _WishPreviewBlock extends StatelessWidget {
  final PageSectionModel section;
  const _WishPreviewBlock({required this.section});

  @override
  Widget build(BuildContext context) {
    final style = _ResolvedStyle.resolve(section);

    return Container(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: style.border,
        boxShadow: style.shadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => _handleLink(context, section.buttonLink ?? '/wish-room'),
        child: Padding(
          padding: style.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title ?? '신통방통 소원방',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: style.foregroundColor,
                ),
              ),
              if (section.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    section.subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: style.secondaryTextColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// double_card_grid 그룹 - 연속된 섹션 2개씩 한 행에 배치.
class _DoubleCardGrid extends StatelessWidget {
  final List<PageSectionModel> sections;
  const _DoubleCardGrid({required this.sections});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sections.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) => _SectionCard(section: sections[index]),
    );
  }
}

/// horizontal_card_scroll 그룹 - 연속된 섹션을 가로 스크롤 리스트로 배치.
class _HorizontalCardScroll extends StatelessWidget {
  final List<PageSectionModel> sections;
  const _HorizontalCardScroll({required this.sections});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) =>
            SizedBox(width: 220, child: _SectionCard(section: sections[index])),
      ),
    );
  }
}

/// category_shortcut_row - usageType='icon' 첨부들을 가로 숏컷 버튼 행으로 렌더링.
class _CategoryShortcutRow extends StatelessWidget {
  final PageSectionModel section;
  const _CategoryShortcutRow({required this.section});

  @override
  Widget build(BuildContext context) {
    final icons = section.attachmentsOf('icon');
    final style = _ResolvedStyle.resolve(section);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null && section.title!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              section.title!,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: style.foregroundColor,
              ),
            ),
          ),
        if (icons.isEmpty)
          _SectionCard(section: section)
        else
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: icons.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final icon = icons[index];
                return GestureDetector(
                  onTap: () => _handleLink(context, section.buttonLink),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        child: Image.network(
                          icon.attachmentUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: AppColors.premiumInactiveGrey,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
