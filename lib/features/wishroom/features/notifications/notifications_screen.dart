// SCR-08 알림 `/noti` (탭3) — docs/SCREENS.md §SCR-08 · app2/screens-c2.jsx › Noti() 1:1 이식
// 필터 칩(전체·응원·복주머니·댓글·시스템) + 알림 행(44px 아이콘 타일 + 안읽음 dot + ago() 상대시간)
// + "모두 읽음" + 빈 상태("아직 조용한 밤이에요"). 탭하면 읽음 처리 후 메인 탭으로 이동한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_nav_pill.dart';

enum _NotiFilter { all, support, pouch, comment, system }

// NOTI_IMG — 원본 screens-c2.jsx:5 매핑 1:1. 유형별 44px 아이콘 타일에 쓰는 아이템 PNG.
const Map<NotiType, String> _notiImg = {
  NotiType.SUPPORT: 'lotus', NotiType.POUCH: 'pouch', NotiType.COMMENT: 'petal',
  NotiType.STATUS: 'c_basic', NotiType.GROWTH: 'spark', NotiType.COMPLETE: 'chest',
  NotiType.UNSEAL: 'c_basic', NotiType.REVIEW: 'petal',
};

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

  // ago(t, n) — 원본 screens-c2.jsx:4 1:1. 지금 · N분 전 · N시간 전 · N일 전.
  String _ago(DateTime at) {
    final m = DateTime.now().difference(at).inMinutes;
    if (m < 1) return '지금';
    if (m < 60) return '$m분 전';
    final h = m ~/ 60;
    return h < 24 ? '$h시간 전' : '${h ~/ 24}일 전';
  }

  // app2/screens-c2.jsx › Noti() open(n) 1:1 — 읽음 처리 후 항상 메인 탭(app.go('home'))으로
  // 이동한다. [버그수정 — 전수감사] 기존엔 roomId가 있으면 OtherRoomScreen으로 push했으나
  // 원본은 그런 분기가 전혀 없다.
  Future<void> _open(WrNotification n) async {
    final p = context.read<WishRoomProvider>();
    if (!n.read) await p.readNotifications(id: n.id);
    if (!mounted) return;
    p.requestTab(0);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final list = p.notifications.where((n) => _matches(n.type, _filter)).toList()
          ..sort((a, b) => b.at.compareTo(a.at));
        final hasUnread = list.any((n) => !n.read);
        return SafeArea(bottom: false, child: Column(children: [
          // TopBar — 원본은 상단 고정(absolute top:52) + 중앙 타이틀 + 우측 "모두 읽음" 칩.
          // app2/screens-c2.jsx › Noti() TopBar(title="알림함") nav 기본값 true로
          // NavPill이 좌측에 온다. [버그수정 — 전수감사] 기존엔 전혀 없었다.
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [
            WrNavPill(onBack: () => wrBackOrAskExit(context), onExitHome: () => wrExitHome(context)),
            Expanded(child: Center(child: Text('알림함', style: WrF.display(18)))),
            const SizedBox(width: 60), // NavPill과 시각적 균형
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Row(children: [
            Expanded(child: SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _chip('전체', _NotiFilter.all),
                _chip('응원', _NotiFilter.support),
                _chip('복주머니', _NotiFilter.pouch),
                _chip('댓글', _NotiFilter.comment),
                _chip('시스템', _NotiFilter.system),
              ]),
            )),
            if (hasUnread) Padding(padding: const EdgeInsets.only(left: 8), child: GestureDetector(
              onTap: () => p.readNotifications(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: WrDeco.chip,
                child: Text('모두 읽음', style: WrF.body(12, color: WrC.fg)),
              ),
            )),
          ])),
          const SizedBox(height: 14),
          Expanded(child: list.isEmpty
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: () => p.loadNotifications(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _NotiRow(n: list[i], ago: _ago(list[i].at), onTap: () => _open(list[i])),
                  ),
                )),
        ]));
      }),
    ));
  }

  Widget _chip(String label, _NotiFilter f) {
    final sel = _filter == f;
    return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: sel ? WrDeco.chipOn : WrDeco.chip,
        child: Text(label, style: WrF.body(12, w: FontWeight.w700, color: sel ? Colors.white : WrC.fg)),
      ),
    ));
  }
}

/// 알림 행 — 원본 screens-c2.jsx:23-28 1:1. 44px 아이콘 타일(radial 핑크 글로우) + 안읽음 핑크 dot +
/// 13px 세리프 문구 + 10.5px 상대시간. 안읽음은 배경 rgba(242,98,143,.1) + 테두리 rgba(255,143,177,.35).
class _NotiRow extends StatelessWidget {
  const _NotiRow({required this.n, required this.ago, required this.onTap});
  final WrNotification n; final String ago; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = _notiImg[n.type] ?? 'c_basic';
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: n.read ? WrC.card : const Color(0x1AF2628F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: n.read ? WrC.cardBorder : const Color(0x59FF8FB1)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (!n.read) Padding(padding: const EdgeInsets.only(right: 8), child: Container(width: 6, height: 6,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: WrC.blossom, boxShadow: [BoxShadow(color: WrC.blossom, blurRadius: 8)]))),
        Container(width: 44, height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0x40FFA0BE), Color(0x33000000)]),
            border: Border.all(color: WrC.line)),
          child: Image.asset('assets/wishroom/items/$img.png', width: 36, height: 36,
            errorBuilder: (_, __, ___) => const Text('✦', style: TextStyle(fontSize: 18, color: WrC.glow)))),
        const SizedBox(width: 12),
        Expanded(child: Text(n.text, style: WrF.body(13, color: n.read ? WrC.muted : WrC.fg, height: 1.45), maxLines: 3, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(ago, style: TextStyle(fontFamily: 'Pretendard', fontSize: 10.5, color: WrC.muted)),
      ]),
    ));
  }
}

/// 빈 상태 — 원본 "moon" 이미지 80px opacity .6 + 세리프 안내문구.
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.only(bottom: 100), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Opacity(opacity: .6, child: Image.asset('assets/wishroom/items/moon.png', width: 80,
          errorBuilder: (_, __, ___) => Text('☾', style: TextStyle(fontSize: 56, color: WrC.muted)))),
        const SizedBox(height: 12),
        Text('아직 조용한 밤이에요', textAlign: TextAlign.center, style: WrF.body(14, color: WrC.muted, height: 1.7)),
        Text('소식이 오면 이곳에 머뭅니다', textAlign: TextAlign.center, style: WrF.body(14, color: WrC.muted, height: 1.7)),
      ])));
}
