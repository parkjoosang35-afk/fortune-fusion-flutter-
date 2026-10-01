// SCR-08 알림 `/noti` (탭3) — docs/SCREENS.md §SCR-08
// 필터 칩(전체·응원·복주머니·댓글·시스템) + 알림 행(안읽음 dot) + 모두읽음 + 빈 상태.
// 탭하면 읽음 처리 후 해당 방(OtherRoomScreen)으로 이동한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import '../explore/other_room_screen.dart';

enum _NotiFilter { all, support, pouch, comment, system }

class WrNotificationsScreen extends StatefulWidget {
  const WrNotificationsScreen({super.key});
  @override
  State<WrNotificationsScreen> createState() => _WrNotificationsScreenState();
}

class _WrNotificationsScreenState extends State<WrNotificationsScreen> {
  _NotiFilter _filter = _NotiFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WishRoomProvider>().loadNotifications());
  }

  bool _matches(NotiType t, _NotiFilter f) {
    switch (f) {
      case _NotiFilter.all: return true;
      case _NotiFilter.support: return t == NotiType.SUPPORT;
      case _NotiFilter.pouch: return t == NotiType.POUCH;
      case _NotiFilter.comment: return t == NotiType.COMMENT;
      case _NotiFilter.system: return t == NotiType.STATUS || t == NotiType.GROWTH || t == NotiType.COMPLETE || t == NotiType.UNSEAL || t == NotiType.REVIEW;
    }
  }

  Future<void> _onTapNoti(WrNotification n) async {
    final p = context.read<WishRoomProvider>();
    if (!n.read) await p.readNotifications(id: n.id);
    if (!mounted) return;
    if (n.roomId != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtherRoomScreen(roomId: n.roomId!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // [버그수정] Theme(...) 적용 전 context에는 WrColors extension이 없어
    // context.wr(null-check)가 터진다. midnight 고정이므로 상수를 직접 참조.
    const c = WrColors.midnight;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final list = p.notifications.where((n) => _matches(n.type, _filter)).toList()
          ..sort((a, b) => b.at.compareTo(a.at));
        return SafeArea(bottom: false, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: Row(children: [
            Text('알림', style: WrType.h1(c.fg)),
            const Spacer(),
            GestureDetector(
              onTap: () => p.readNotifications(),
              child: Text('모두 읽음', style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _chip('전체', _NotiFilter.all, c),
              _chip('응원', _NotiFilter.support, c),
              _chip('복주머니', _NotiFilter.pouch, c),
              _chip('댓글', _NotiFilter.comment, c),
              _chip('시스템', _NotiFilter.system, c),
            ]),
          )),
          const SizedBox(height: 8),
          Expanded(child: list.isEmpty
              ? _EmptyState(c: c)
              : RefreshIndicator(
                  onRefresh: () => p.loadNotifications(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _NotiRow(n: list[i], c: c, onTap: () => _onTapNoti(list[i])),
                  ),
                )),
        ]));
      }),
    ));
  }

  Widget _chip(String label, _NotiFilter f, WrColors c) {
    final sel = _filter == f;
    return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: sel ? c.accent : c.card, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : c.fg, fontSize: 12)),
      ),
    ));
  }
}

class _NotiRow extends StatelessWidget {
  const _NotiRow({required this.n, required this.c, required this.onTap});
  final WrNotification n; final WrColors c; final VoidCallback onTap;

  String get _icon => switch (n.type) {
        NotiType.SUPPORT => '❤', NotiType.POUCH => '💰', NotiType.COMMENT => '💬',
        NotiType.STATUS => '🕯', NotiType.GROWTH => '✨', NotiType.COMPLETE => '成',
        NotiType.UNSEAL => '🔓', NotiType.REVIEW => '✍',
      };

  String _relTime() {
    final diff = DateTime.now().difference(n.at);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 2) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${n.at.year}.${n.at.month}.${n.at.day}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: n.read ? c.card : const Color(0x1AF2628F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(children: [
        Container(width: 44, height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(color: c.bg1, borderRadius: BorderRadius.circular(12)),
          child: Text(_icon, style: const TextStyle(fontSize: 20))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.text, style: TextStyle(color: c.fg, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(_relTime(), style: TextStyle(color: c.muted, fontSize: 11)),
        ])),
        if (!n.read) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF2628F))),
      ]),
    ));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c});
  final WrColors c;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('☾', style: TextStyle(fontSize: 40, color: c.muted)),
        const SizedBox(height: 12),
        Text('아직 조용한 밤이에요', style: TextStyle(color: c.fg, fontSize: 14)),
        const SizedBox(height: 4),
        Text('소식이 오면 이곳에 머뭅니다', style: TextStyle(color: c.muted, fontSize: 12)),
      ]));
}
