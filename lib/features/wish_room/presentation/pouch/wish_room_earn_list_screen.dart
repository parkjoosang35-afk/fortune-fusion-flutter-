import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import 'wish_room_earn_moment_screen.dart';

/// 07. 오늘의 적립 · 조용한 미션 — 출처: PouchScreens.jsx `ScreenEarnList`
class WishRoomEarnListScreen extends StatelessWidget {
  const WishRoomEarnListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final missions = provider.todayMissions;
    final doneCount = missions.where((m) => m.done).length;
    final total = missions.length;

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(size: 280, color: palette.sigil, opacity: 0.16),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(text: 'EARN · 오늘', palette: palette),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '달빛 조각을\n모아요',
                            style: WishRoomText.h1(palette.fg).copyWith(
                              fontSize: 24,
                              shadows: [Shadow(color: palette.glowShadow, blurRadius: 24)],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '매일 밤 소원방에 방문할 때마다\n조용히 쌓이는 정성입니다.',
                            style: WishRoomText.body(palette.muted).copyWith(height: 1.7, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: palette.card,
                        border: Border.all(color: palette.line),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(56, 56),
                                  painter: _RingPainter(
                                    progress: total == 0 ? 0 : doneCount / total,
                                    trackColor: palette.line,
                                    progressColor: palette.glow,
                                  ),
                                ),
                                Text(
                                  '$doneCount/$total',
                                  style: TextStyle(
                                    fontFamily: WishRoomText.fontDisplay,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: palette.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('오늘의 조각', style: WishRoomText.h3(palette.fg)),
                                const SizedBox(height: 2),
                                Text(
                                  doneCount >= total ? '오늘 몫을 모두 담았어요' : '${total - doneCount}개만 더 담으면 됩니다',
                                  style: WishRoomText.monoSm(palette.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: missions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final m = missions[i];
                          return WishRoomMissionRow(
                            label: m.label,
                            sub: m.sub,
                            reward: m.reward,
                            done: m.done,
                            palette: palette,
                            onTap: m.done || m.onClaim == null
                                ? null
                                : () async {
                                    final result = await m.onClaim!();
                                    if (result != null && context.mounted) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => WishRoomEarnMomentScreen(result: result),
                                        ),
                                      );
                                    }
                                  },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: WishRoomText.body(palette.muted).copyWith(fontSize: 11, height: 1.6),
                          children: [
                            const TextSpan(text: '다음 만월 · 8일 후 · '),
                            TextSpan(text: '모든 조각 ×2', style: TextStyle(color: palette.glow)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.trackColor, required this.progressColor});
  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
