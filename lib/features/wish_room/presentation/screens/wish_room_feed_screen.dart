import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';

/// [디자인 핸드오프 — "모두의 소원" 피드] `wish-screens.jsx`의
/// `ScreenFeed` 스펙에 대응하는 화면.
///
/// [진행 상태] 현재는 아직 community `WishPostRepository`/
/// `WishPostProvider`와의 연동 방식이 확정되지 않아 placeholder로 남겨둔다
/// (TodoWrite 항목13, 별도 작업에서 구현). 하단 탭 구조(Shell) 자체는 먼저
/// 완성해 사용자 지시("페이지 한칸을 더 만들어서 구현")의 탭 뼈대를 확보한다.
class WishRoomFeedScreen extends StatelessWidget {
  const WishRoomFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: WishRoomBackground(mainSigilOpacity: 0.12, showDust: true),
            ),
            Center(
              child: DramaticEntrance(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: WishRoomSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('☾', style: TextStyle(fontSize: 40, color: WishRoomColors.glow)),
                      const SizedBox(height: WishRoomSpacing.md),
                      Text('모두의 소원', style: WishRoomTextStyles.screenTitle),
                      const SizedBox(height: WishRoomSpacing.sm),
                      Text(
                        '다른 이들의 소원이 이곳에 모입니다.\n곧 만나볼 수 있어요.',
                        textAlign: TextAlign.center,
                        style: WishRoomTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
