import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/consultation_model.dart';
import 'consultation_type_style.dart';

/// 07단계(추가) §3.4 - 재사용 가능한 채팅 말풍선 컴포넌트.
/// ConsultationChatScreen에서 분리되어 독립적으로 애니메이션(FadeInUp + Scale)을
/// 관리한다. SingleTickerProviderStateMixin으로 위젯 생성 시점에 0.3초짜리
/// 등장 애니메이션을 1회 재생한다.
///
/// ▸ FadeInUp: opacity 0→1 + 아래에서 위로 살짝 슬라이드
/// ▸ ScaleTransition: 사용자 메시지는 우측에서, AI 메시지는 좌측에서 중앙으로 확장
/// ▸ 스트리밍 중(showTypingCursor)이고 텍스트가 비어있으면 점(●●●) 순차 애니메이션 표시
class MessageBubble extends StatefulWidget {
  final ConsultationMessage message;
  final bool showTypingCursor;
  final ConsultationTypeStyle typeStyle;

  const MessageBubble({
    super.key,
    required this.message,
    required this.typeStyle,
    this.showTypingCursor = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  bool get _isUser => widget.message.role == ConsultationRole.user;

  @override
  void initState() {
    super.initState();
    // 07단계(추가) §3.4 - 메시지 나타남 FadeInUp(0.3초)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // 07단계(추가) §3.4 - 말풍선 확장: 사용자는 우측에서, AI는 좌측에서 중앙으로
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = _isUser ? widget.typeStyle.primaryColor : Colors.white;
    final textColor = _isUser ? Colors.white : AppColors.textPrimary;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Align(
          alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ScaleTransition(
            alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
            scale: _scaleAnim,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.card),
                  topRight: const Radius.circular(AppRadius.card),
                  bottomLeft: Radius.circular(_isUser ? AppRadius.card : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : AppRadius.card),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.message.text.isEmpty
                  ? const _TypingDots()
                  : Text(
                      widget.showTypingCursor
                          ? '${widget.message.text}▏'
                          : widget.message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 07단계(추가) §3.4 - 스트리밍 시작 전(AI 응답 대기) 표시되는 점(●●●) 순차 애니메이션.
/// 위상차(phase offset)를 이용해 3개의 점이 순서대로 커졌다 작아지는 효과를 낸다.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              // 각 점마다 1/3 주기씩 위상차를 두어 순차적으로 튀어오르게 함
              final t = (_controller.value + (i * 0.2)) % 1.0;
              final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
              return Transform.scale(
                scale: 0.6 + scale * 0.6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.textHint,
                    shape: BoxShape.circle,
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
