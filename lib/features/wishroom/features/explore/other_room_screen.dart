// SCR-07 타인의 소원방 `/explore/:id` — docs/SCREENS.md §SCR-07
// 방 장면(카메라 인) + TopBar + 한지 카드 + CTA 3종(응원/복주머니/메시지) + 신고·차단 시트.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';

class OtherRoomScreen extends StatefulWidget {
  const OtherRoomScreen({super.key, required this.roomId});
  final String roomId;
  @override
  State<OtherRoomScreen> createState() => _OtherRoomScreenState();
}

class _OtherRoomScreenState extends State<OtherRoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WishRoomProvider>().loadViewedRoom(widget.roomId));
  }

  Future<void> _support() async {
    final p = context.read<WishRoomProvider>();
    final reward = await p.support(widget.roomId);
    await p.loadViewedRoom(widget.roomId);
    if (!mounted) return;
    if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
      return;
    }
    if (reward != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('응원을 보냈어요')));
    }
  }

  void _openGiftSheet() {
    final p = context.read<WishRoomProvider>();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => _GiftSheet(
      onPick: (amount) async {
        Navigator.of(context).pop();
        final ok = await p.gift(widget.roomId, amount);
        if (!mounted) return;
        if (ok) {
          await p.loadViewedRoom(widget.roomId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('복주머니를 보냈어요')));
        } else if (p.lastError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
        }
      },
    ));
  }

  void _openMessageSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF73E182C), Color(0xFA1E0A16)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, maxLength: 60, maxLines: 3, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: '응원 메시지를 남겨주세요', hintStyle: TextStyle(color: Colors.white38), border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                final ok = await context.read<WishRoomProvider>().postComment(widget.roomId, ctrl.text.trim());
                if (mounted) Navigator.of(context).pop();
                if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('전송에 실패했어요')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2628F)),
              child: const Text('보내기', style: TextStyle(color: Colors.white)),
            )),
          ]),
        ),
      ));
  }

  void _openReportBlockSheet(String ownerId) {
    final p = context.read<WishRoomProvider>();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF73E182C), Color(0xFA1E0A16)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.flag, color: Colors.white70), title: const Text('신고하기', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.of(context).pop();
            final ok = await p.report(roomId: widget.roomId);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '신고했어요' : '신고에 실패했어요')));
          }),
        ListTile(leading: const Icon(Icons.block, color: Colors.white70), title: const Text('차단하기', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.of(context).pop();
            final ok = await p.block(ownerId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '차단했어요' : '차단에 실패했어요')));
              if (ok) Navigator.of(context).maybePop();
            }
          }),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.viewedRoom;
        if (room == null || room.id != widget.roomId) return const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A)));
        return Stack(children: [
          Positioned.fill(child: WrCanvasScaler(child: RoomScene(room: room, items: p.items))),
          SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 0), child: Row(children: [
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back, color: Colors.white)),
              Expanded(child: Text('${room.owner}님의 소원방 / Lv.${room.level} ${room.levelName}',
                style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => _openReportBlockSheet(room.ownerId), icon: const Icon(Icons.more_horiz, color: Colors.white)),
            ])),
            const Spacer(),
          ])),
          Positioned(left: 16, right: 16, bottom: 24, child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xF7FFF4E2), Color(0xF2F7E2C8)]), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${room.region} · ${room.daysLit}일째', style: const TextStyle(fontSize: 11, color: Color(0x993C2D1E))),
                const SizedBox(height: 6),
                Text(room.text, style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 15, color: Color(0xFF4A2A1C))),
                const SizedBox(height: 10),
                Text('❤ ${room.supportCount} · 💬 ${room.commentCount} · 福 ${room.pouchReceived}', style: const TextStyle(fontSize: 12, color: Color(0x993C2D1E))),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: room.supportedToday ? null : _support,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2628F), disabledBackgroundColor: const Color(0x55F2628F)),
                child: Text(room.supportedToday ? '✓ 응원함' : '❤ 응원하기', style: const TextStyle(color: Colors.white, fontSize: 13)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _openGiftSheet,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5CF6A)),
                child: const Text('복주머니 보내기', style: TextStyle(color: Color(0xFF4A2A10), fontSize: 13)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _openMessageSheet,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A1F3E)),
                child: const Text('💬 메시지', style: TextStyle(color: Colors.white, fontSize: 13)))),
            ]),
          ])),
        ]);
      }),
    ));
  }
}

class _GiftSheet extends StatelessWidget {
  const _GiftSheet({required this.onPick});
  final void Function(int amount) onPick;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF73E182C), Color(0xFA1E0A16)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('복주머니 보내기', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [5, 10, 30, 50].map((v) => GestureDetector(
          onTap: () => onPick(v),
          child: Container(width: 72, height: 56, alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(12)),
            child: Text('$v', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        )).toList()),
      ]),
    );
  }
}
