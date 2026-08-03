import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/fortune/primary_cta.dart';
import '../application/wish_room_provider.dart';

/// [소원방 MVP §6 첫 진입 안내] 첫 진입 시 1회만 보여주는 짧은 안내.
/// 확인(시작하기) 후에는 [WishRoomProvider.markIntroSeen]으로 다시 뜨지
/// 않게 한다. "설명은 짧고 아름답게, 절대 길게 나열하지 않는다"를 지키기
/// 위해 4줄 안내 + CTA 1개로만 구성한다.
Future<void> showWishRoomIntroModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WishRoomIntroDialog(),
  );
}

class _WishRoomIntroDialog extends StatelessWidget {
  const _WishRoomIntroDialog();

  static const _steps = [
    '매일 소원방에 들어옵니다',
    '오늘의 치성을 드립니다',
    '치성 보상을 받습니다',
    '정성이 쌓일수록 소원의 빛이 자랍니다',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: UnifiedColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('소원방 이용 안내', style: UnifiedText.titleLarge()),
            const SizedBox(height: UnifiedTokens.spaceLg),
            for (int i = 0; i < _steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ['①', '②', '③', '④'][i],
                    style: UnifiedText.bodyStrong(),
                  ),
                  const SizedBox(width: UnifiedTokens.spaceSm),
                  Expanded(
                    child: Text(_steps[i], style: UnifiedText.body()),
                  ),
                ],
              ),
              if (i != _steps.length - 1)
                const SizedBox(height: UnifiedTokens.spaceSm),
            ],
            const SizedBox(height: UnifiedTokens.spaceXxl),
            PrimaryCTA(
              label: '시작하기',
              onPressed: () {
                context.read<WishRoomProvider>().markIntroSeen();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
