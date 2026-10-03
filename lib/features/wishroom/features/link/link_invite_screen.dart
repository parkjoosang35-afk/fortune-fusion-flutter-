// 링크로 들어온 사람 — 초대장 연출 후 방 입장. app2/capsule2.jsx › LinkInvite() 1:1 이식.
// API_CONTRACT.md S2 `GET /share/{token}` → Room(무효/PRIVATE 404 LINK_INVALID).
// `/w/{token}` 딥링크(앱 라우터 + OS 레벨 딥링크 핸들러)의 최종 목적지.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../room/room_scene.dart';
import '../explore/other_room_screen.dart';

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

class LinkInviteScreen extends StatefulWidget {
  const LinkInviteScreen({super.key, required this.token});
  final String token;
  @override
  State<LinkInviteScreen> createState() => _LinkInviteScreenState();
}

class _LinkInviteScreenState extends State<LinkInviteScreen> {
  WishRoom? _room;
  ApiError? _err;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = context.read<WishRoomProvider>().repo;
      try {
        final r = await repo.roomByToken(widget.token);
        if (mounted) setState(() => _room = r);
      } on ApiError catch (e) {
        if (mounted) setState(() => _err = e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    return Theme(data: wrThemeData(), child: Scaffold(backgroundColor: const Color(0xFF0C0408), body: Stack(children: [
      Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [Color(0xFF4A2040), Color(0xFF0C0408)], stops: [0, .78]))),
      const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 10, dur: (8, 12), spread: 8))),
      if (_err != null) Positioned(left: 24, right: 24, top: 300, child: Column(children: [
        const Text('🔒', style: TextStyle(fontSize: 34)),
        const SizedBox(height: 10),
        Text(_err!.message, style: WrF.display(19), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        _backButton(context),
      ])),
      if (_room != null) _buildInvite(context, _room!, cat),
    ])));
  }

  Widget _backButton(BuildContext context) {
    return SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(
      decoration: WrDeco.btnDark,
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).maybePop(),
        child: const Center(child: Text('돌아가기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white))),
      )),
    ));
  }

  Widget _enterButton(BuildContext context, WishRoom room) {
    return SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(
      decoration: WrDeco.btnPink,
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OtherRoomScreen(roomId: room.id))),
        child: const Center(child: Text('🕯 소원방에 들어가기',
          style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white))),
      )),
    ));
  }

  Widget _buildInvite(BuildContext context, WishRoom room, WrCatalog cat) {
    final w = cat.wishColors.firstWhere((e) => e['id'] == room.wishColor, orElse: () => cat.wishColors.first);
    final color = _hex(w['color'] as String), deep = _hex(w['deep'] as String), hanja = w['hanja'] as String;
    return Stack(children: [
      Positioned(left: 0, right: 0, top: 110, child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1000), curve: Curves.easeOut,
        builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child)),
        child: Column(children: [
          Text('INVITATION · 초대장', style: WrF.mono(size: 10, color: const Color(0xFFFFE08A))),
          const SizedBox(height: 10),
          Text('${room.owner}님이\n소원방에 초대했어요', style: WrF.display(23, height: 1.35), textAlign: TextAlign.center),
        ]),
      )),
      Positioned(left: 30, right: 30, top: 230, child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 800), curve: const Cubic(.34, 1.56, .64, 1),
        builder: (_, t, child) => Transform.scale(scale: t, child: child),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x59FFDC96)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: .27), blurRadius: 40), const BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 20))]),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // G-4 RoomThumb — [버그수정 — 전수감사] items:const[] 고정으로 장식이 전혀 반영되지 않던 버그.
            SizedBox(height: 200, child: LayoutBuilder(builder: (context, c) =>
              RoomThumb(room: room, items: context.read<WishRoomProvider>().items, w: c.maxWidth, h: 200, focus: .22, zoom: 1.5))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF1DC), Color(0xFFF1E0BD)])),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 30, height: 30, alignment: Alignment.center,
                  decoration: BoxDecoration(color: deep, borderRadius: BorderRadius.circular(6)),
                  child: Text(hanja, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${room.daysLit}일째 밝히는 중 · Lv.${room.level}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11, color: Color(0x995A321E))),
                  const SizedBox(height: 2),
                  Text('"${room.text}"', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15, height: 1.45, color: Color(0xFF4A2A1C))),
                ])),
              ]),
            ),
          ]),
        ),
      )),
      Positioned(left: 20, right: 20, bottom: 44, child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1000),
        builder: (_, t, child) => Opacity(opacity: t, child: child),
        child: _enterButton(context, room),
      )),
    ]);
  }
}
