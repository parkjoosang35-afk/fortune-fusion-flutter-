import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/consultation_provider.dart';
import '../domain/consultation_model.dart';

/// 07단계 - ConsultationChatScreen (채팅형 패턴)
/// 09단계 §1.2 스트리밍 응답을 말풍선에 실시간으로 이어붙여 표시한다.
class ConsultationChatScreen extends StatefulWidget {
  const ConsultationChatScreen({super.key});

  @override
  State<ConsultationChatScreen> createState() => _ConsultationChatScreenState();
}

class _ConsultationChatScreenState extends State<ConsultationChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  static const _typeLabels = {
    'saju': '사주상담',
    'tarot': '타로상담',
    'general': '일반상담',
  };

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(ConsultationProvider provider) {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    provider.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConsultationProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(_typeLabels[provider.type] ?? 'AI 상담')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: provider.isStarting
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: provider.messages.length,
                      itemBuilder: (context, index) {
                        final msg = provider.messages[index];
                        final isLast = index == provider.messages.length - 1;
                        return _MessageBubble(
                          message: msg,
                          showTypingCursor:
                              isLast &&
                              msg.role == ConsultationRole.ai &&
                              provider.isStreaming,
                        );
                      },
                    ),
            ),
            _InputBar(
              controller: _inputController,
              enabled: !provider.isStreaming && !provider.isStarting,
              onSend: () => _send(provider),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ConsultationMessage message;
  final bool showTypingCursor;
  const _MessageBubble({required this.message, this.showTypingCursor = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ConsultationRole.user;
    final bubbleColor = isUser ? AppColors.primary : Colors.white;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
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
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: message.text.isEmpty
            ? const SizedBox(
                width: 28,
                height: 16,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Text(
                showTypingCursor ? '${message.text}▏' : message.text,
                style: TextStyle(color: textColor, fontSize: 14, height: 1.5),
              ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: enabled ? '메시지를 입력하세요' : 'AI가 답변하고 있어요...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
