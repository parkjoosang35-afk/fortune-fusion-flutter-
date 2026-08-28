import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../domain/luckybag_product_model.dart';

/// [복주머니 디자인 정합성 수정] 복주머니 상점 카드.
///
/// [배경] 기존에는 다크 "우주(Cosmic)" 팔레트([AppCard]+[AppColors])를 쓰는
/// 레거시 카드였다. 복주머니 허브([LuckyBagScreen], luckybag_hub_screen.dart)는
/// 이미 화이트+라벤더 [UnifiedColors] 톤으로 리뉴얼됐는데, 허브에서 "복주머니
/// 열기"를 눌러 들어오는 이 카드만 옛 다크 톤 그대로 남아 있어 화면 전환 시
/// 마치 다른 앱으로 넘어간 듯한 이질감을 줬다("복주머니도 어이없다"는 지적의
/// 실체). 허브와 동일한 팔레트/타이포로 전면 재작성한다.
class LuckyBagCard extends StatelessWidget {
  final LuckyBagProductModel product;
  final VoidCallback? onTap;
  final Widget? trailing; // 가격/개봉버튼 등 화면별 가변 영역

  const LuckyBagCard({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UnifiedColors.cardSection,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: UnifiedColors.cardMain,
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusSm,
                      ),
                    ),
                    child: Text(
                      product.iconEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const Spacer(),
                  if (product.seasonName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: UnifiedColors.black,
                        borderRadius: BorderRadius.circular(
                          UnifiedTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        product.seasonName!,
                        style: UnifiedText.chipLabel(color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: UnifiedTokens.spaceSm),
              Text(
                product.name,
                style: UnifiedText.bodyStrong(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${product.pricePoint}개',
                style: UnifiedText.caption(color: UnifiedColors.textPrimary),
              ),
              if (trailing != null) ...[
                const SizedBox(height: UnifiedTokens.spaceSm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
