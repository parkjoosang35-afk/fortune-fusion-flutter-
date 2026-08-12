import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_counsel_provider.dart';
import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';
import '../widgets/wish_counsel_avatar.dart';
import 'wish_counsel_chat_screen.dart';

/// SUMMARY — `mc-screen-summary.jsx` 이식.
/// 세션마크(원형글로우), WITH카드, 감정 arc, Insights, 다시 대화하기.
class WishCounselSummaryScreen extends StatelessWidget {
  const WishCounselSummaryScreen({super.key, required this.session});

  final CounselSession session;

  static const List<String> _insights = [
    '오늘 대화에서 반복된 키워드를 함께 짚어봤어요.',
    '마음이 무거웠던 지점을 스스로 말로 꺼내보셨어요.',
    '다음에 시도해볼 작은 실천 하나를 찾았어요.',
  ];

  @override
  Widget build(BuildContext context) {
    final t = session.character.theme;
    final minutes = session.elapsed.inMinutes.clamp(1, 999);
    final startEmotion = session.startEmotion != null
        ? CounselEmotion.byKey(session.startEmotion!)
        : null;
    final endEmotion = session.endEmotion != null
        ? CounselEmotion.byKey(session.endEmotion!)
        : null;

    return Scaffold(
      backgroundColor: WishCounselColors.bg1,
      appBar: AppBar(
        backgroundColor: WishCounselColors.bg1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WishCounselColors.fg),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: Text('SUMMARY · 오늘의 마음', style: WishCounselText.monoLabel()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [t.soft, Colors.transparent],
                  ),
                  border: Border.all(color: t.glow, width: 1.4),
                ),
                child: Text(
                  '◈',
                  style: TextStyle(fontSize: 24, color: t.glow),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'SESSION · $minutes MIN',
                style: WishCounselText.monoLabel(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '오늘 마음이\n조금은 가벼워졌기를',
              textAlign: TextAlign.center,
              style: WishCounselText.display2(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WishCounselColors.card2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WishCounselColors.line2),
              ),
              child: Row(
                children: [
                  WishCounselAvatar(character: session.character, size: 44),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WITH', style: WishCounselText.monoLabel()),
                      Text(
                        '${session.character.name} ${session.character.nameSub}',
                        style: WishCounselText.uiLabel(size: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('MOOD · 감정 변화', style: WishCounselText.monoLabel()),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: CustomPaint(
                painter: _EmotionArcPainter(
                  startColor: startEmotion != null
                      ? WishCounselColors.emotionColors[startEmotion.key]!
                      : const Color(0xFFA89CFF),
                  endColor: t.glow,
                ),
                child: Row(
                  children: [
                    if (startEmotion != null)
                      _EmotionTag(emotion: startEmotion),
                    const Spacer(),
                    if (endEmotion != null) _EmotionTag(emotion: endEmotion),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('INSIGHTS · 오늘 나눈 이야기', style: WishCounselText.heading()),
            const SizedBox(height: 12),
            ..._insights.asMap().entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: WishCounselColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: WishCounselColors.line2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.soft,
                      ),
                      child: Text(
                        '${entry.key + 1}',
                        style: WishCounselText.caption(color: t.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: WishCounselText.bodySmall(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: WishCounselColors.line2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {},
                    child: Text('보관', style: WishCounselText.uiLabel(size: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: WishCounselColors.line2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {},
                    child: Text('공유', style: WishCounselText.uiLabel(size: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                context.read<WishCounselProvider>().closeSession();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        WishCounselChatScreen(character: session.character),
                  ),
                );
              },
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [t.glow, t.accent]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '다시 대화하기',
                  style: WishCounselText.uiLabel(
                    color: const Color(0xFF0A0A12),
                    size: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '"오늘의 마음도, 지나가는 계절 중 하나예요."',
                textAlign: TextAlign.center,
                style: WishCounselText.bodySmall(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmotionTag extends StatelessWidget {
  const _EmotionTag({required this.emotion});

  final CounselEmotion emotion;

  @override
  Widget build(BuildContext context) {
    final color = WishCounselColors.emotionColors[emotion.key]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emotion.glyph, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text(emotion.label, style: WishCounselText.caption(color: color)),
        ],
      ),
    );
  }
}

/// `04_DESIGN_TOKENS.md` §5-11 Summary Emotion Arc — SVG 대신 CustomPaint로
/// quadratic bezier 곡선을 재현.
class _EmotionArcPainter extends CustomPainter {
  _EmotionArcPainter({required this.startColor, required this.endColor});

  final Color startColor;
  final Color endColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.02, h * 0.7);
    path.quadraticBezierTo(w * 0.35, h * 0.78, w * 0.5, h * 0.5);
    path.quadraticBezierTo(w * 0.7, h * 0.3, w * 0.98, h * 0.2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [startColor, endColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);

    canvas.drawCircle(Offset(w * 0.02, h * 0.7), 5, Paint()..color = startColor);
    canvas.drawCircle(Offset(w * 0.98, h * 0.2), 5, Paint()..color = endColor);
  }

  @override
  bool shouldRepaint(covariant _EmotionArcPainter oldDelegate) =>
      oldDelegate.startColor != startColor || oldDelegate.endColor != endColor;
}
