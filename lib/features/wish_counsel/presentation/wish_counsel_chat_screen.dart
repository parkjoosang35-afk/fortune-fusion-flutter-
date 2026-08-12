import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_counsel_provider.dart';
import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';
import '../widgets/wish_counsel_avatar.dart';
import '../widgets/wish_counsel_crisis_banner.dart';
import '../widgets/wish_counsel_message_bubble.dart';
import 'wish_counsel_summary_screen.dart';

/// CHAT — `mc-screen-chat.jsx` 이식 (핵심 화면).
/// sticky 헤더(아바타+이름+AI뱃지+LISTENING), 모드 strip 3버튼, 감정칩 row,
/// 메시지 리스트(ListView reverse), 위기 배너, QuickChips, InputBar.
class WishCounselChatScreen extends StatefulWidget {
  const WishCounselChatScreen({super.key, required this.character});

  final CounselCharacter character;

  @override
  State<WishCounselChatScreen> createState() => _WishCounselChatScreenState();
}

class _WishCounselChatScreenState extends State<WishCounselChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureStarted());
  }

  Future<void> _ensureStarted() async {
    if (_started) return;
    _started = true;
    final provider = context.read<WishCounselProvider>();
    if (provider.session?.character.id != widget.character.id) {
      await provider.startSession(widget.character);
    }
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    context.read<WishCounselProvider>().sendMessage(text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.character.theme;
    final provider = context.watch<WishCounselProvider>();
    final session = provider.session;
    final messages = session?.messages ?? const [];

    return Scaffold(
      backgroundColor: WishCounselColors.bg1,
      appBar: AppBar(
        backgroundColor: WishCounselColors.bg1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WishCounselColors.fg),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            WishCounselAvatar(character: widget.character, size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(widget.character.name, style: WishCounselText.uiLabel(size: 14)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: WishCounselColors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: WishCounselColors.line),
                      ),
                      child: Text('AI', style: WishCounselText.monoLabel()),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF6FE3A0)),
                    const SizedBox(width: 4),
                    Text(
                      'LISTENING',
                      style: WishCounselText.monoLabel(),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.check_circle_outline, color: t.glow),
              tooltip: '상담 마무리',
              onPressed: session == null
                  ? null
                  : () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              WishCounselSummaryScreen(session: session),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ModeStrip(theme: t),
            if (provider.crisisActive) const WishCounselCrisisBanner(),
            const _EmotionRow(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[messages.length - 1 - i];
                  return WishCounselMessageBubble(
                    message: msg,
                    glow: t.glow,
                    accent: t.accent,
                  );
                },
              ),
            ),
            _QuickChips(character: widget.character, onPick: (q) {
              _controller.text = q;
            }),
            _InputBar(controller: _controller, onSend: _send, glow: t.glow),
          ],
        ),
      ),
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.theme});

  final dynamic theme;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishCounselProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: CounselMode.all.map((m) {
          final active = provider.mode == m.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => provider.selectMode(m.key),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? theme.soft : WishCounselColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? theme.glow : WishCounselColors.line,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            m.glyph,
                            style: TextStyle(
                              fontSize: 12,
                              color: active ? theme.glow : WishCounselColors.fg2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.label,
                            style: WishCounselText.caption(
                              color: active ? theme.glow : WishCounselColors.fg2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (m.pro)
                      Positioned(
                        top: 3,
                        right: 5,
                        child: Text(
                          'PRO',
                          style: WishCounselText.monoLabel(color: theme.accent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmotionRow extends StatelessWidget {
  const _EmotionRow();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishCounselProvider>();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: CounselEmotion.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final e = CounselEmotion.all[i];
          final color = WishCounselColors.emotionColors[e.key]!;
          final active = provider.selectedEmotion == e.key;
          return GestureDetector(
            onTap: () => provider.selectEmotion(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.16) : WishCounselColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? color : WishCounselColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.glyph, style: TextStyle(fontSize: 13, color: color)),
                  const SizedBox(width: 5),
                  Text(
                    e.label,
                    style: WishCounselText.caption(
                      color: active ? color : WishCounselColors.fg2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  const _QuickChips({required this.character, required this.onPick});

  final CounselCharacter character;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: character.sampleQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final q = character.sampleQuestions[i];
          return GestureDetector(
            onTap: () => onPick(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: WishCounselColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: WishCounselColors.line),
              ),
              alignment: Alignment.center,
              child: Text(q, style: WishCounselText.caption()),
            ),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.glow,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WishCounselColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: WishCounselColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WishCounselColors.line2),
              ),
              child: TextField(
                controller: controller,
                style: WishCounselText.bodyText(size: 14),
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '마음속에 있는 이야기를...',
                  hintStyle: WishCounselText.bodyText(
                    color: WishCounselColors.muted,
                    size: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: glow),
              child: const Icon(Icons.arrow_upward, color: Color(0xFF0A0A12)),
            ),
          ),
        ],
      ),
    );
  }
}
