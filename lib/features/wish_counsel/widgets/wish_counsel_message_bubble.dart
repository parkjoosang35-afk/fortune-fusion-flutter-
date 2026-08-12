import 'package:flutter/material.dart';

import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';

/// 채팅 말풍선 — `04_DESIGN_TOKENS.md` §5-6 (Message Bubble).
class WishCounselMessageBubble extends StatelessWidget {
  const WishCounselMessageBubble({
    super.key,
    required this.message,
    required this.glow,
    required this.accent,
  });

  final CounselMessage message;
  final Color glow;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == CounselRole.user;
    final radius = mine
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: mine
              ? LinearGradient(
                  colors: [glow, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: mine ? null : WishCounselColors.card2,
          borderRadius: radius,
          border: mine
              ? null
              : Border.all(color: WishCounselColors.line2, width: 1),
        ),
        child: message.text.isEmpty
            ? const _TypingDots()
            : Text(
                message.text,
                style: WishCounselText.bodyText(
                  color: mine ? const Color(0xFF0A0A12) : WishCounselColors.fg,
                  size: 14,
                ),
              ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 12,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_ctrl.value + i * 0.2) % 1.0;
              final dy = -3 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: WishCounselColors.fg2,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
