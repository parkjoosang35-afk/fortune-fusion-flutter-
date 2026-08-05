import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 사용 방법 안내 팝업(5단계 온보딩).
/// 초회 1회 자동 노출되고, 이후 헤더의 도움말 버튼으로 재노출된다.
class WishGuideDialog extends StatelessWidget {
  const WishGuideDialog({super.key});

  static const _steps = [
    ('1. 입장하기', '조용히 문을 열고 당신만의 소원방에 들어와요'),
    ('2. 소원 정하기', '직접 적거나, 추천 카테고리 중 하나를 골라보세요'),
    ('3. 정성 담기', '복주머니로 소원에 마음을 담아보세요'),
    ('4. 매일 기도하기', '하루 한 번, 오늘의 정성을 이어가요'),
    ('5. 소원 확인하기', '쌓여가는 기도의 기록을 언제든 돌아볼 수 있어요'),
  ];

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const WishGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: WishRoomColors.backgroundMid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WishRoomRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WishRoomSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('당신만의 소원방에 오신 걸 환영해요', style: WishRoomTextStyles.titleLg),
            const SizedBox(height: WishRoomSpacing.md),
            for (final step in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: WishRoomSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.$1,
                      style: WishRoomTextStyles.bodyMd.copyWith(
                        color: WishRoomColors.goldSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(step.$2, style: WishRoomTextStyles.caption),
                  ],
                ),
              ),
            const SizedBox(height: WishRoomSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WishRoomColors.gold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text('시작하기', style: WishRoomTextStyles.ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
