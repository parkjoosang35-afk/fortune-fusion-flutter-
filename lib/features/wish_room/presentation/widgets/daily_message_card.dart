import 'package:flutter/material.dart';

import '../../data/models/daily_message_model.dart';
import '../theme/wish_room_theme.dart';
import 'wish_room_animations.dart';

/// [소원방 Riverpod 실험판] 오늘의 한 줄 메시지 카드.
///
/// [UI 전면 개선] 완전 정적이던 텍스트를 메시지가 바뀔 때마다 은은하게
/// 페이드+슬라이드로 전환되도록 보강했다(같은 메시지가 유지되는 동안은
/// 재생되지 않음 — AnimatedSwitcher의 key가 message.text이므로 값이 실제로
/// 바뀔 때만 전환된다). 좌우에 작게 반짝이는 별 장식을 추가해 "오늘의
/// 메시지"라는 특별함을 시각적으로 강조한다.
class DailyMessageCard extends StatelessWidget {
  final DailyMessage message;

  const DailyMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WishRoomSpacing.lg),
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 120),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const GentleWiggle(
              child: Text('✨', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: WishRoomSpacing.sm),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  message.text,
                  key: ValueKey<String>(message.text),
                  style: WishRoomTextStyles.dailyMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: WishRoomSpacing.sm),
            GentleWiggle(
              period: const Duration(seconds: 2, milliseconds: 800),
              child: const Text('✨', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
