// app2/capsule2.jsx › SealedDone() 1:1 이식 — 소원 작성 제출 성공 직후의 "봉인 완료" 연출.
// 두루마리가 말리고(scroll-roll) 인장이 쾅 찍힌 뒤(stamp) 자물쇠 문구가 뜬다.
// CHANGELOG '소원 봉인(타임캡슐)' 4단계. compose_screen._submit() 성공 시 이 화면을 거쳐
// WishRoomIntroScreen(full)으로 넘어간다 — 원본 onGo={() => app.reload('intro')} 1:1.
import 'package:flutter/material.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

class SealedDoneScreen extends StatefulWidget {
  const SealedDoneScreen({super.key, required this.date, required this.text, required this.wishColor, required this.onGo});
  final DateTime date;
  final String text;
  final String wishColor;
  final VoidCallback onGo;
  @override
  State<SealedDoneScreen> createState() => _SealedDoneScreenState();
}

class _SealedDoneScreenState extends State<SealedDoneScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..forward();
  bool _burst1 = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2100), () { if (mounted) setState(() => _burst1 = true); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  String get _dateK => '${widget.date.year}년 ${widget.date.month}월 ${widget.date.day}일';

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final w = cat.wishColors.firstWhere((e) => e['id'] == widget.wishColor, orElse: () => cat.wishColors.first);
    final color = _hex(w['color'] as String);
    final deep = _hex(w['deep'] as String);
    final hanja = w['hanja'] as String;
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: const Color(0xFF0C0408),
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.42), radius: 1.1, colors: [Color(0xFF3A1A34), Color(0xFF0C0408)], stops: [0, .75])),
        child: Stack(children: [
          const WrPetalRain(n: 8, dur: (8, 12), spread: 8),
          // 18개 방사형 광선 — halo-rays 40s
          Positioned(left: 0, right: 0, top: 245, child: Center(child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final angle = _c.value * 2 * 3.14159 / 10; // 40s 1주기 근사(화면 체류시간 짧아 큰 영향 없음)
              return Opacity(opacity: .4, child: Transform.rotate(angle: angle, child: SizedBox(
                width: 380, height: 380,
                child: Stack(children: [
                  for (var i = 0; i < 16; i++)
                    Positioned(left: 189, top: 190, child: Transform.rotate(
                      angle: i * 22.5 * 3.14159 / 180,
                      alignment: Alignment.topCenter,
                      child: Container(width: 2, height: 190, decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .7), Colors.transparent]))),
                    )),
                ]),
              )));
            },
          ))),
          // 두루마리 → 말림 (scroll-roll)
          Positioned(left: 60, right: 60, top: 170, child: AnimatedBuilder(
            animation: _c, builder: (_, __) {
              final t = _c.value;
              final rollT = ((t * 3600 - 300) / 1400).clamp(0.0, 1.0);
              final scaleY = rollT < .7 ? 1.0 - rollT / .7 * .88 : .12 - (rollT - .7) / .3 * .02;
              final opacity = rollT < .7 ? 1.0 : (1.0 - (rollT - .7) / .3).clamp(0.0, 1.0);
              return Opacity(opacity: opacity, child: Transform.scale(scaleY: scaleY.clamp(0.1, 1.0), alignment: Alignment.center,
                child: Container(height: 150, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF1DC), Color(0xFFF1E0BD)]),
                    boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 10))]),
                  child: Text(widget.text, maxLines: 5, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 14, height: 1.6, color: Color(0xFF4A2A1C))),
                )));
            },
          )),
          // 말린 두루마리 + 끈 (1.5s 지연 등장)
          Positioned(left: 70, right: 70, top: 232, child: AnimatedBuilder(
            animation: _c, builder: (_, __) {
              final raw = ((_c.value * 3600 - 1500) / 600).clamp(0.0, 1.0);
              final op = Curves.easeOut.transform(raw);
              return Opacity(opacity: op, child: Transform.translate(offset: Offset(0, (1 - op) * 20), child: Container(
                height: 26, decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF5E6C6), Color(0xFFD8BF8E), Color(0xFFB8986A)], stops: [0, .6, 1]),
                  boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 8))]),
                child: Center(child: Container(width: 18, margin: const EdgeInsets.symmetric(vertical: -4),
                  decoration: BoxDecoration(color: deep, boxShadow: [BoxShadow(color: color, blurRadius: 10)]))),
              )));
            },
          )),
          // 인장 쾅 (stamp, 1.9s 지연)
          Positioned(left: 0, right: 0, top: 216, child: Center(child: AnimatedBuilder(
            animation: _c, builder: (_, __) {
              final raw = ((_c.value * 3600 - 1900) / 800).clamp(0.0, 1.0);
              if (raw <= 0) return const SizedBox(width: 58, height: 58);
              final scale = raw < .55 ? 3.0 - raw / .55 * 2.08 : raw < .7 ? .92 + (raw - .55) / .15 * .12 : 1.04 - (raw - .7) / .3 * .04;
              final op = raw < .3 ? raw / .3 : 1.0;
              return Opacity(opacity: op.clamp(0.0, 1.0), child: Transform.scale(scale: scale.clamp(0.1, 3.0), child: Container(
                width: 58, height: 58, alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, deep]),
                  boxShadow: [BoxShadow(color: color, blurRadius: 30)]),
                child: Text(hanja, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 30, color: Color(0xFFFFF4E0))),
              )));
            },
          ))),
          if (_burst1) const WrBurst(x: 195, y: 245, n: 24, spread: 150, color: Color(0xFFFFE0A0)),
          // 문구
          Positioned(left: 24, right: 24, top: 360, child: AnimatedBuilder(
            animation: _c, builder: (_, __) {
              final raw = ((_c.value * 3600 - 2600) / 1000).clamp(0.0, 1.0);
              final op = Curves.easeOut.transform(raw);
              return Opacity(opacity: op, child: Transform.translate(offset: Offset(0, (1 - op) * 16), child: Column(children: [
                const Text('🔐', style: TextStyle(fontSize: 30)),
                const SizedBox(height: 8),
                Text('소원이 봉인되었습니다.', textAlign: TextAlign.center, style: WrF.display(24)),
                const SizedBox(height: 16),
                Text(_dateK, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFFFFE08A))),
                const SizedBox(height: 12),
                Text('그날까지 소원을 소중히 간직하세요. ✨', textAlign: TextAlign.center, style: WrF.body(14, color: WrC.muted, height: 1.7)),
                const SizedBox(height: 14),
                Text('봉인이 풀리는 날 알림을 보내드릴게요.\n그동안 소원방에서 촛불을 밝혀주세요.', textAlign: TextAlign.center,
                  style: WrF.body(12, color: const Color(0x99FFE6C8), height: 1.7)),
              ])));
            },
          )),
          // CTA
          Positioned(left: 20, right: 20, bottom: 44, child: AnimatedBuilder(
            animation: _c, builder: (_, __) {
              final raw = ((_c.value * 3600 - 3200) / 1000).clamp(0.0, 1.0);
              final op = Curves.easeOut.transform(raw);
              return Opacity(opacity: op, child: SizedBox(width: double.infinity, height: WrSize.btnH,
                child: DecoratedBox(decoration: WrDeco.btnPink, child: Material(color: Colors.transparent,
                  child: InkWell(borderRadius: BorderRadius.circular(16), onTap: widget.onGo,
                    child: Center(child: Text('소원방 들어가기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: WrSize.btnFont, color: Colors.white))))))));
            },
          )),
        ]),
      ),
    ));
  }
}
