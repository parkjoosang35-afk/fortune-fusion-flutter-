import 'package:flutter/material.dart';

import '../../domain/talisman_item.dart';
import '../theme/shrine_v3_theme.dart';
import 'shrine_asset_path.dart';

/// 03/04/05/06/09/10 화면이 공용으로 쓰는 부적 썸네일(README/HTML
/// 프로토타입 `PH`/`GenImg` 역할). [thumb]가 true면 목록/카드용 썸네일
/// 경로(thumbPath, 없으면 imagePath)를 쓰고, false면 05/10/확대보기용
/// 원본(imagePath)을 쓴다.
class TalismanThumb extends StatelessWidget {
  const TalismanThumb({
    super.key,
    required this.talisman,
    required this.width,
    this.height,
    this.useThumb = true,
    this.borderRadius = 10,
  });

  final TalismanItem talisman;
  final double width;
  final double? height;
  final bool useThumb;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = useThumb && talisman.thumbPath != null
        ? shrineAssetPath(talisman.thumbPath!)
        : shrineAssetPath(talisman.imagePath);
    final h = height ?? width * 2.3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        path,
        width: width,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: h,
          color: ShrineV3Colors.paperDark,
          alignment: Alignment.center,
          child: Text(
            talisman.hanja,
            style: ShrineV3TextStyles.title.copyWith(
              fontSize: width * 0.4,
              color: ShrineV3Colors.seal,
            ),
          ),
        ),
      ),
    );
  }
}
