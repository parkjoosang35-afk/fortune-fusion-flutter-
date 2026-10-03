// 성취 후기 — app2/review2.jsx › ReviewWrite()/ReviewReward() 1:1 이식.
// docs/REVIEW.md · docs/CHANGELOG.md "소원 성취 & 후기(v2.4)" 참고.
// SCR-10(Complete) 하단 "💌 후기" 버튼에서 진입 → 작성 → 제출 → 보상 연출 → pop(결과).
// edit 모드는 이번 범위 밖(보관함 내 "고치기"는 추후). 여기서는 신규 작성만 구현.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/fx/wr_fx.dart';

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

/// ReviewWrite + ReviewReward 를 하나의 화면 흐름으로 관리.
/// pop 결과: null = 스킵("나중에 남길게요"/닫기, 제출 안 함) · 'next' = 제출 완료 후 계속하기 ·
/// 'stories' = 제출 완료(공개) 후 "이야기 보기" 선택. 호출부(complete_screen)는 null 이 아니면
/// reviewed=true 로 간주해 💌 후기/되돌리기 버튼을 숨긴다 — 원본 `reviewed` state 1:1.
class ReviewWriteScreen extends StatefulWidget {
  const ReviewWriteScreen({super.key, required this.room});
  final WishRoom room;
  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  final _ctrl = TextEditingController();
  String? _photoBase64;
  bool _public = false; // 기본 '나만 보기' (PRIVATE) — docs/REVIEW.md
  bool _busy = false;
  String? _err;
  Map<String, dynamic>? _result; // postReview 응답 → 보상 단계로 전환

  int get _len => _ctrl.text.replaceAll(RegExp(r'\s'), '').length;
  bool get _ok => _len >= 20;

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1200).timeout(const Duration(seconds: 30));
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 8 * 1000 * 1000) {
        if (mounted) setState(() => _err = '사진은 8MB 이하로 골라주세요');
        return;
      }
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (mounted) setState(() { _photoBase64 = b64; _err = null; });
    } catch (e) {
      if (mounted) setState(() => _err = '사진을 불러오지 못했어요');
    }
  }

  Future<void> _submit() async {
    if (_busy || !_ok) return;
    setState(() { _busy = true; _err = null; });
    final p = context.read<WishRoomProvider>();
    final res = await p.postReview(widget.room.id, text: _ctrl.text, photo: _photoBase64, public: _public);
    if (!mounted) return;
    if (res == null) {
      setState(() { _busy = false; _err = p.lastError?.message ?? '후기를 저장하지 못했어요'; });
      return;
    }
    setState(() { _busy = false; _result = res; });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final w = cat.wishColors.firstWhere((c) => c['id'] == widget.room.wishColor, orElse: () => cat.wishColors.first);
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: const Color(0xFF12060E),
      body: _result != null ? _RewardBody(res: _result!, onDone: (go) => Navigator.of(context).pop(go))
        : Container(
          decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1), radius: 1.3, colors: [Color(0xFF4A2040), Color(0xFF12060E)], stops: [0, .7])),
          child: Stack(children: [
            const WrPetalRain(n: 6, dur: (9, 13), spread: 8),
            SafeArea(child: Column(children: [
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 150), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white54)),
                ]),
                Text('FULFILLED · STORY', style: WrF.mono(size: 10, color: const Color(0xFFFFE08A))),
                const SizedBox(height: 10),
                Text('💌 소원이 이루어진 이야기를\n남겨주세요', style: WrF.display(23, color: Colors.white)),
                const SizedBox(height: 8),
                Text('어떻게 소원이 이루어졌는지\n다른 사람들과 나누어 주세요.', style: WrF.body(13, color: WrC.muted, height: 1.65)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x4DFFDC96))),
                  child: Row(children: [
                    Container(width: 30, height: 30, alignment: Alignment.center,
                      decoration: BoxDecoration(color: _hex(w['deep'] as String), borderRadius: BorderRadius.circular(6)),
                      child: Text(w['hanja'] as String, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('💛 이루어진 소원', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 10.5, color: Color(0xFFFFE08A))),
                      Text('"${widget.room.text}"', style: WrF.body(13, w: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: WrDeco.hanji,
                  child: Column(children: [
                    TextField(controller: _ctrl, maxLength: 500, maxLines: 6, minLines: 6, onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(border: InputBorder.none, counterText: '', hintText: '소원이 이루어진 이야기를 자유롭게 적어주세요.', hintStyle: TextStyle(color: Color(0x994A2A1C))),
                      style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 15, height: 1.7, color: Color(0xFF4A2A1C))),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_ok ? '✓ 좋아요' : '${20 - _len}자 더 적어주세요', style: WrF.mono(size: 10.5, color: _ok ? const Color(0xD92F7A52) : const Color(0x8C5A321E))),
                      Text('${_ctrl.text.length} / 500', style: WrF.mono(size: 10.5, color: const Color(0x8C5A321E))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [Text('사진 ', style: WrF.display(14, color: Colors.white)), Text('선택 · 첨부하면 복주머니 +20', style: WrF.body(11, color: WrC.muted))]),
                const SizedBox(height: 8),
                _photoBase64 != null
                  ? Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_decodePhoto(_photoBase64!), width: 120, height: 120, fit: BoxFit.cover)),
                      Positioned(right: 6, top: 6, child: GestureDetector(onTap: () => setState(() => _photoBase64 = null),
                        child: Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 13, color: Colors.white)))),
                    ])
                  : GestureDetector(onTap: _pick, child: Container(width: 120, height: 120, alignment: Alignment.center,
                      decoration: WrDeco.card.copyWith(border: Border.all(color: WrC.line, style: BorderStyle.solid)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('📷', style: TextStyle(fontSize: 22)),
                        const SizedBox(height: 6),
                        Text('사진 추가', style: WrF.body(11.5, color: WrC.muted)),
                      ]))),
                const SizedBox(height: 16),
                Text('💛 이 이야기를 다른 사람들과 나눌까요?', style: WrF.display(14, color: Colors.white)),
                const SizedBox(height: 8),
                for (final v in [(false, '나만 보기', '나의 기록관에만 남아요'), (true, '공개하기', '「소원이 이루어진 이야기」에 함께 보여요')])
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(onTap: () => setState(() => _public = v.$1),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: _public == v.$1 ? const Color(0x1AF2628F) : WrC.card, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _public == v.$1 ? WrC.blossom2 : WrC.cardBorder)),
                      child: Row(children: [
                        Container(width: 20, height: 20, alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _public == v.$1 ? WrC.blossom2 : WrC.line, width: 2)),
                          child: _public == v.$1 ? Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: WrC.blossom2)) : null),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v.$2, style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
                          Text(v.$3, style: WrF.body(11.5, color: WrC.muted)),
                        ])),
                      ])))),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: WrC.line, style: BorderStyle.solid)),
                  child: RichText(text: TextSpan(style: WrF.body(11.5, color: WrC.muted, height: 1.65), children: [
                    const TextSpan(text: '· 후기를 남기면 복주머니 '),
                    const TextSpan(text: '+30', style: TextStyle(color: WrC.glow, fontWeight: FontWeight.w700)),
                    const TextSpan(text: ', 사진까지 첨부하면 '),
                    const TextSpan(text: '+20', style: TextStyle(color: WrC.glow, fontWeight: FontWeight.w700)),
                    const TextSpan(text: '을 더 드려요. 소원 하나에 한 번만 받을 수 있어요.\n· 같은 글자 반복, 의미 없는 글은 확인 후 보상이 드려질 수 있어요.'),
                  ]))),
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 12.5))),
              ]))),
            ])),
            Positioned(left: 0, right: 0, bottom: 0, child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF12060E)], stops: [0, .35])),
              child: Column(children: [
                SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(decoration: !_ok || _busy ? WrDeco.btnDark : WrDeco.btnPink,
                  child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: !_ok || _busy ? null : _submit,
                    child: Center(child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('💌 이야기 남기기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: WrSize.btnFont, color: _ok ? Colors.white : WrC.muted))))))),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('나중에 남길게요', style: WrF.body(12.5, color: WrC.muted))),
              ]),
            )),
          ]),
        ),
    ));
  }
}

Uint8List _decodePhoto(String dataUrl) {
  final i = dataUrl.indexOf(',');
  return base64Decode(i >= 0 ? dataUrl.substring(i + 1) : dataUrl);
}

class _RewardBody extends StatefulWidget {
  const _RewardBody({required this.res, required this.onDone});
  final Map<String, dynamic> res; final void Function(String go) onDone;
  @override
  State<_RewardBody> createState() => _RewardBodyState();
}

class _RewardBodyState extends State<_RewardBody> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rw = widget.res['reward'] as Map<String, dynamic>?;
    final held = widget.res['held'] == true;
    final review = widget.res['review'] as Map<String, dynamic>?;
    final total = rw == null ? 0 : ((rw['base'] as num?)?.toInt() ?? 0) + ((rw['photo'] as num?)?.toInt() ?? 0);
    final isPublic = review != null && review['visibility'] == 'PUBLIC';
    return Container(
      decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.2, colors: [Color(0xFF4A2040), Color(0xFF0C0408)], stops: [0, .78])),
      child: Stack(children: [
        const WrPetalRain(n: 10, dur: (7, 11), spread: 6),
        Positioned(left: 24, right: 24, top: 150, child: Column(children: [
          SizedBox(height: 140, child: Stack(alignment: Alignment.center, children: [
            Positioned(top: 10, child: AnimatedBuilder(animation: _c, builder: (_, __) => Opacity(opacity: .45,
              child: Transform.rotate(angle: _c.value * 6.28, child: SizedBox(width: 260, height: 260, child: CustomPaint(painter: _RaysPainter())))))),
            ScaleTransition(scale: CurvedAnimation(parent: _c, curve: WrCurves.overshoot),
              child: Image.asset('assets/wishroom/items/pouch.png', width: 110, errorBuilder: (_, __, ___) => const Text('🧧', style: TextStyle(fontSize: 64)))),
            if (rw != null) const WrBurst(x: 0, y: -40, n: 22, spread: 150, color: WrC.glow),
          ])),
          if (held) ...[
            Text('이야기가 잘 담겼어요', style: WrF.display(20, color: Colors.white)),
            const SizedBox(height: 10),
            Text('남겨주신 이야기를 한 번 더 살펴본 뒤\n복주머니를 보내드릴게요.', textAlign: TextAlign.center, style: WrF.body(13, color: WrC.muted, height: 1.7)),
          ] else if (rw != null) ...[
            Text('🧧 복주머니 +$total', style: WrF.display(26, color: WrC.glow)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _chip('후기 +${rw['base']}'),
              if ((rw['photo'] as num?)?.toInt() != null && (rw['photo'] as num).toInt() > 0) ...[const SizedBox(width: 6), _chip('사진 +${rw['photo']}', gold: true)],
            ]),
            const SizedBox(height: 12),
            Text('소중한 이야기를 나눠주셔서 고마워요.', style: WrF.body(13, color: WrC.muted, height: 1.7)),
          ] else ...[
            Text('이야기를 고쳤어요', style: WrF.display(20, color: Colors.white)),
          ],
          if (review != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(
            isPublic ? '「소원이 이루어진 이야기」에 함께 보여요' : '나만 볼 수 있어요',
            style: WrF.body(12, color: const Color(0x99FFE6D2)))),
        ])),
        Positioned(left: 20, right: 20, bottom: 40, child: Column(children: [
          if (isPublic) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: _bigBtn('✨ 소원이 이루어진 이야기 보기', WrDeco.btnDark, Colors.white, () => widget.onDone('stories'))),
          _bigBtn('계속하기', WrDeco.btnPink, Colors.white, () => widget.onDone('next')),
        ])),
      ]),
    );
  }

  Widget _bigBtn(String label, BoxDecoration deco, Color color, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: WrSize.btnH,
    child: DecoratedBox(decoration: deco, child: Material(color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: Center(child: Text(label, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: WrSize.btnFont, color: color))))),
    ));

  Widget _chip(String t, {bool gold = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: gold ? const Color(0x80F5CF6A) : WrC.line)),
    child: Text(t, style: WrF.body(11.5, color: gold ? const Color(0xFFFFE08A) : Colors.white)));
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..strokeWidth = 2;
    for (var i = 0; i < 14; i++) {
      final a = i * 25.7 * 3.14159 / 180;
      final p1 = center;
      final p2 = center + Offset.fromDirection(a, 130);
      paint.shader = ui.Gradient.linear(p1, p2, [const Color(0xB3FFDC96), Colors.transparent]);
      canvas.drawLine(p1, p2, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) => false;
}
