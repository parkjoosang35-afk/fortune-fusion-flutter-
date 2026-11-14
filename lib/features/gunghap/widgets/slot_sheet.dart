// ═══════════════════════════════════════════════════════════════
// FILE: slot_sheet.dart
// [궁합지도 「인연지도」 디자인 핸드오프 2차 반영] design_handoff_gunghap_map
// (1).zip `MAP_HOME_SPEC.md` §9 "빈 자리 탭 → 채우기 안내창(SlotSheet)"
// 구현(원본 참고 Dart 파일 없음 — 명세 텍스트 기준으로 직접 작성).
//
// 구성 (위→아래)
//  1. EMPTY SEAT · {분야 한자} · ✕
//  2. 일러스트: 나 ★ — 흐르는 점선 — ⊕ {슬롯 라벨}
//  3. 제목 "이 자리에 {슬롯}의 별을 / 띄워 볼까요" · 설명
//  4. "{슬롯}와 보기 좋은 궁합" 칩 → 해당 분야 세부 선택으로 바로 시작
//  5. 진행 점 8개(●=채워짐 ○=빈자리) · "인연지도 n / 8"
//  6. "생년월일을 몰라도 초대장으로 채울 수 있어요"
//  Footer: [✉ {슬롯}에게 초대장 보내기](primary) · [직접 입력하기](secondary)
import 'package:flutter/material.dart';

import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import 'destiny_map.dart' show GhSlot;
import 'gh_button.dart';

/// 빈 자리(인연 슬롯) 탭 시 열리는 안내창.
///
/// [onInvite] "✉ {슬롯}에게 초대장 보내기" — `GunghapInviteScreen`으로
/// 이동시킨다(호출부가 네비게이션을 수행 — 이 위젯은 콜백만 노출).
/// [onDirect] "직접 입력하기" — `GunghapMajorScreen`(method: 'direct')로
/// 이동시킨다.
Future<void> showSlotSheet(
  BuildContext context,
  GhSlot slot, {
  required int filledCount,
  required VoidCallback onInvite,
  required VoidCallback onDirect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: GHColors.scrim,
    builder: (ctx) => _SlotSheet(
      slot: slot,
      filledCount: filledCount,
      onInvite: onInvite,
      onDirect: onDirect,
    ),
  );
}

class _SlotSheet extends StatelessWidget {
  const _SlotSheet({
    required this.slot,
    required this.filledCount,
    required this.onInvite,
    required this.onDirect,
  });

  final GhSlot slot;
  final int filledCount;
  final VoidCallback onInvite, onDirect;

  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(slot.majorId);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF222D4A), GHColors.bg1],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: GHColors.gray.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'EMPTY SEAT · ${major.hanja}',
                            style: GHText.mono(color: GHColors.gold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Text('✕', style: TextStyle(color: GHColors.ivory)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 2. 일러스트: 나 ★ — 점선 — ⊕ 슬롯
                    Center(
                      child: SizedBox(
                        height: 72,
                        child: CustomPaint(
                          size: const Size(220, 72),
                          painter: _SeatLinkPainter(slotLabel: slot.label),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 3. 제목/설명
                    Text(
                      '이 자리에 ${slot.label}의 별을\n띄워 볼까요',
                      style: GHText.display(size: 23),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '가장 가까운 사람과 궁합을 보면 이 자리에 별이 떠요. 점수가 높을수록 나와 가까운 곳에 자리 잡아요.',
                      style: GHText.ui(size: 14, color: GHColors.gray, height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    // 4. 추천 칩
                    GestureDetector(
                      onTap: onDirect,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GHColors.gold.withValues(alpha: .5)),
                          color: GHColors.gold.withValues(alpha: .08),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${slot.label}와 보기 좋은 궁합',
                                    style: GHText.cardTitle(size: 14.5, color: GHColors.gold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(slot.recommend, style: GHText.caption()),
                                ],
                              ),
                            ),
                            const Text('›', style: TextStyle(color: GHColors.gold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 5. 진행 점
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 8; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < filledCount
                                    ? GHColors.gold
                                    : GHColors.gray.withValues(alpha: .25),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('인연지도 $filledCount / 8', style: GHText.mono(size: 10)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '생년월일을 몰라도 초대장으로 채울 수 있어요',
                      textAlign: TextAlign.center,
                      style: GHText.caption(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  GHButton(
                    label: '✉ ${slot.label}에게 초대장 보내기',
                    size: GHButtonSizeT.lg,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onInvite();
                    },
                  ),
                  const SizedBox(height: 8),
                  GHButton(
                    label: '생년월일을 알아요 · 직접 입력하기',
                    variant: GHButtonVariant.secondary,
                    size: GHButtonSizeT.md,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDirect();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatLinkPainter extends CustomPainter {
  _SeatLinkPainter({required this.slotLabel});
  final String slotLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final left = Offset(28, size.height / 2);
    final right = Offset(size.width - 28, size.height / 2);

    // 점선.
    const dashW = 5.0, gapW = 4.0;
    final total = (right.dx - left.dx);
    var x = left.dx;
    final dashPaint = Paint()
      ..strokeWidth = 1.2
      ..color = GHColors.gold.withValues(alpha: .45);
    while (x < left.dx + total) {
      final x2 = (x + dashW).clamp(left.dx, right.dx);
      canvas.drawLine(Offset(x, left.dy), Offset(x2, left.dy), dashPaint);
      x += dashW + gapW;
    }

    // 나(★).
    canvas.drawCircle(
      left,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = GHColors.gold.withValues(alpha: .7),
    );
    _star(canvas, left, 6, GHColors.gold);
    _text(canvas, '나', left + const Offset(0, 24), 10, GHColors.ivory);

    // 빈 자리(⊕).
    _dashedCircle(canvas, right, 16, GHColors.gray.withValues(alpha: .55));
    _text(canvas, '+', right, 14, GHColors.gray.withValues(alpha: .8), w900: true);
    _text(canvas, slotLabel, right + const Offset(0, 24), 10, GHColors.gray);
  }

  void _dashedCircle(Canvas cv, Offset o, double r, Color color) {
    const dashCount = 14;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (var i = 0; i < dashCount; i++) {
      final a0 = i / dashCount * 2 * 3.14159265;
      final a1 = a0 + (3.14159265 / dashCount) * .7;
      final p1 = o + Offset.fromDirection(a0, r);
      final p2 = o + Offset.fromDirection(a1, r);
      cv.drawLine(p1, p2, paint);
    }
  }

  void _star(Canvas cv, Offset o, double r, Color color) {
    final l = r * 2.5, w = r * .4;
    final path = Path()
      ..moveTo(o.dx, o.dy - l)
      ..lineTo(o.dx + w, o.dy - w)
      ..lineTo(o.dx + l, o.dy)
      ..lineTo(o.dx + w, o.dy + w)
      ..lineTo(o.dx, o.dy + l)
      ..lineTo(o.dx - w, o.dy + w)
      ..lineTo(o.dx - l, o.dy)
      ..lineTo(o.dx - w, o.dy - w)
      ..close();
    cv.drawPath(path, Paint()..color = color);
  }

  void _text(Canvas cv, String s, Offset at, double fs, Color color, {bool w900 = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: w900 ? 'NotoSerifKR' : 'Pretendard',
          fontSize: fs,
          fontWeight: w900 ? FontWeight.w900 : FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(cv, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SeatLinkPainter old) => old.slotLabel != slotLabel;
}
