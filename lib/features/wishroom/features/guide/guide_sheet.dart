// app2/guide2.jsx › GuideBook + Tour + FirstVisitChip 1:1 이식.
// main_room_screen.dart의 최소구현 _GuideSheet(4항목)를 교체한다.
// CHECKLIST.md "안내서 10항목 · 한 바퀴 둘러보기 6단계 · 첫 방문 칩" 대응.
import 'package:flutter/material.dart';
import '../../core/theme/wr_theme.dart';
import 'guide_data.dart';
import 'guide_prefs.dart';

/// app2/guide2.jsx › GuideBook — 소원방 안내서(펼침 목록). focus 항목을 펼친 채로 연다.
/// onStartTour가 주어지면(= room이 있을 때) 상단에 "한 바퀴 둘러보기" 버튼을 보여준다.
class GuideBook extends StatefulWidget {
  const GuideBook({super.key, this.focus, this.onStartTour});
  final String? focus;
  final VoidCallback? onStartTour;
  @override
  State<GuideBook> createState() => _GuideBookState();
}

class _GuideBookState extends State<GuideBook> {
  late String? _open = widget.focus ?? 'candle';
  late bool _on = GuidePrefs.I.hintsOn;

  Future<void> _toggleHints() async {
    final v = !_on;
    setState(() => _on = v);
    await GuidePrefs.I.setHintsOn(v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .86),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: WrDeco.sheet,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Image.asset('assets/wishroom/items/chest.png', width: 52, height: 52, errorBuilder: (_, __, ___) => const SizedBox(width: 52, height: 52)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GUIDE · 소원방 안내서', style: WrF.mono(size: 10, color: WrC.blossom2)),
            const SizedBox(height: 4),
            Text('처음 오셨나요', style: WrF.display(20, color: Colors.white)),
            const SizedBox(height: 2),
            Text('궁금한 것을 눌러 펼쳐보세요', style: WrF.body(12, color: WrC.muted)),
          ])),
          GestureDetector(onTap: () => Navigator.of(context).maybePop(), child: Container(
            width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(color: WrC.glass, shape: BoxShape.circle, border: Border.all(color: WrC.line)),
            child: const Text('✕', style: TextStyle(color: Colors.white, fontSize: 13)),
          )),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: GestureDetector(onTap: _toggleHints, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x14FFFFFF)),
            child: Row(children: [
              Icon(_on ? Icons.toggle_on : Icons.toggle_off, color: _on ? WrC.blossom2 : WrC.muted, size: 22),
              const SizedBox(width: 6),
              Expanded(child: Text(_on ? '화면 속 ? 힌트 보이기 켜짐' : '화면 속 ? 힌트 보이기 꺼짐', style: WrF.body(11.5, color: WrC.muted))),
            ]),
          ))),
        ]),
        if (widget.onStartTour != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(width: double.infinity, height: WrSize.btnSmH, child: DecoratedBox(decoration: WrDeco.btnPink,
            child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16),
              onTap: () { Navigator.of(context).maybePop(); widget.onStartTour!(); },
              child: const Center(child: Text('✦ 소원방 한 바퀴 둘러보기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white))))))),
        ),
        const SizedBox(height: 12),
        Flexible(child: SingleChildScrollView(child: Column(children: [
          for (final id in kGuideOrder) _guideCard(id),
        ]))),
      ]),
    );
  }

  Widget _guideCard(String id) {
    final g = kGuide[id]!;
    final o = _open == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
          color: o ? const Color(0x14F2628F) : WrC.card,
          border: Border.all(color: o ? const Color(0x80FF8FB1) : WrC.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          GestureDetector(
            onTap: () => setState(() => _open = o ? null : id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Image.asset('assets/wishroom/items/${g.icon}.png', width: 36, height: 36, errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 36)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.title, style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
                  Text(g.sub, style: WrF.body(11.5, color: WrC.muted)),
                ])),
                AnimatedRotation(turns: o ? .5 : 0, duration: const Duration(milliseconds: 350),
                  child: const Text('▾', style: TextStyle(color: WrC.blossom2, fontSize: 12))),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 350),
            crossFadeState: o ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(60, 0, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final t in g.body) Padding(padding: const EdgeInsets.only(bottom: 4),
                  child: Text(t, style: WrF.body(12.5, color: const Color(0xE6FFF0E6), height: 1.65))),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0x1AF5CF6A),
                    border: Border.all(color: const Color(0x66F5CF6A), style: BorderStyle.solid)),
                  child: Text('✦ ${g.tip}', style: WrF.body(11.5, color: const Color(0xFFFFE7A0))),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// app2/guide2.jsx › Tour — 메인 화면 위 6단계 코치마크(라디얼 스포트라이트 + 점선 원 + 말풍선).
/// 좌표는 390×844 캔버스 기준(WrCanvasScaler 안에서 그려야 함).
class WrTour extends StatefulWidget {
  const WrTour({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<WrTour> createState() => _WrTourState();
}

class _WrTourState extends State<WrTour> {
  int _i = 0;

  void _next() { if (_i < kTour.length - 1) { setState(() => _i++); } else { widget.onDone(); } }

  @override
  Widget build(BuildContext context) {
    final s = kTour[_i];
    final g = kGuide[s.id]!;
    final up = s.y > 430;
    return GestureDetector(
      onTap: _next,
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _SpotlightPainter(cx: s.x, cy: s.y, r: s.r)))),
        Positioned(left: s.x - s.r, top: s.y - s.r, child: IgnorePointer(child: Container(
          width: s.r * 2, height: s.r * 2,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xD9FFBED2), width: 2)),
        ))),
        Positioned(
          left: 18, right: 18,
          top: up ? null : s.y + s.r + 16,
          bottom: up ? 844 - (s.y - s.r) + 16 : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF7421A30), Color(0xFA220C1A)]),
              border: Border.all(color: const Color(0x59FFBED2)),
              boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 34, offset: Offset(0, 12))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Image.asset('assets/wishroom/items/${g.icon}.png', width: 38, height: 38, errorBuilder: (_, __, ___) => const SizedBox(width: 38, height: 38)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TOUR · ${_i + 1} / ${kTour.length}', style: WrF.mono(size: 10, color: WrC.blossom2)),
                  const SizedBox(height: 2),
                  Text(s.line, style: WrF.display(16, color: Colors.white)),
                ])),
              ]),
              const SizedBox(height: 8),
              Text('${g.body.isNotEmpty ? g.body[0] : ''} ${g.body.length > 1 ? g.body[1] : ''}',
                style: WrF.body(12.5, color: const Color(0xD9FFF0E6), height: 1.6)),
              const SizedBox(height: 10),
              Row(children: [
                GestureDetector(onTap: widget.onDone, child: Text('건너뛰기', style: WrF.body(12, color: WrC.muted))),
                const Spacer(),
                Row(children: [for (var k = 0; k < kTour.length; k++) Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: k == _i ? 14 : 5, height: 5,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: k == _i ? WrC.blossom2 : Colors.white24),
                )]),
                const Spacer(),
                SizedBox(height: 34, child: DecoratedBox(decoration: WrDeco.btnPink, child: Material(color: Colors.transparent,
                  child: InkWell(borderRadius: BorderRadius.circular(16), onTap: _next,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Center(child: Text(_i < kTour.length - 1 ? '다음' : '시작하기',
                      style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)))))))),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.cx, required this.cy, required this.r});
  final double cx, cy, r;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r + 26));
    final combined = Path.combine(PathOperation.difference, path, hole);
    canvas.drawPath(combined, Paint()..color = const Color(0xD1080308));
    // 안쪽 경계는 부드럽게 — 반투명 테두리 원으로 radial-gradient 느낌 근사.
    canvas.drawCircle(Offset(cx, cy), r + 4, Paint()
      ..color = const Color(0x59080308)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44);
  }
  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.cx != cx || oldDelegate.cy != cy || oldDelegate.r != r;
}

/// app2/guide2.jsx › FirstVisitChip — 메인 화면 상단의 "처음 오셨나요" 배너.
class WrFirstVisitChip extends StatefulWidget {
  const WrFirstVisitChip({super.key, required this.onStartTour});
  final VoidCallback onStartTour;
  @override
  State<WrFirstVisitChip> createState() => _WrFirstVisitChipState();
}

class _WrFirstVisitChipState extends State<WrFirstVisitChip> {
  bool _hide = GuidePrefs.I.tourDone;

  Future<void> _dismiss({bool startTour = false}) async {
    setState(() => _hide = true);
    await GuidePrefs.I.setTourDone();
    if (startTour) widget.onStartTour();
  }

  @override
  Widget build(BuildContext context) {
    if (_hide || !GuidePrefs.I.hintsOn) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 800), curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child)),
      child: Center(child: Container(
        padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0xF2FFFAF4),
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 18), BoxShadow(color: Color(0x66FFA0C8), blurRadius: 16)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(onTap: () => _dismiss(startTour: true), child: Text('처음 오셨나요 · 소원방 한 바퀴 둘러보기 ›',
            style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF5A2A36)))),
          const SizedBox(width: 6),
          GestureDetector(onTap: () => _dismiss(), child: Container(
            width: 20, height: 20, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x1F5A2A36)),
            child: const Text('✕', style: TextStyle(fontSize: 10, color: Color(0xFF5A2A36))),
          )),
        ]),
      )),
    );
  }
}
