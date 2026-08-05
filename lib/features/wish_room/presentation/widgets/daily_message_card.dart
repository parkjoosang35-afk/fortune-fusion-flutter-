import 'package:flutter/material.dart';

import '../../data/models/daily_message_model.dart';
import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 오늘의 한 줄 메시지 카드.
class DailyMessageCard extends StatelessWidget {
  final DailyMessage message;

  const DailyMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WishRoomSpacing.lg),
      child: Text(
        message.text,
        style: WishRoomTextStyles.dailyMessage,
        textAlign: TextAlign.center,
      ),
    );
  }
}
