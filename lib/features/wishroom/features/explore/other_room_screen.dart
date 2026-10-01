// SCR-07 타인의 소원방 `/explore/:id` — docs/SCREENS.md §SCR-07 · app2/screens-b2.jsx › OtherRoom() 1:1 이식
// 방 장면(RoomScene, entering 카메라인) + TopBar(제목/⋯) + 상단 칩(❤·💬·福 + ◉방만보기)
// + 응원 메시지 한 줄 티커(4.5s 순환) + 하단 도크(한 줄 소원 + 둥근 ❤응원버튼66px + 복주머니/메시지 알약)
// + 소원 탭 → 전문 펼침 카드 + 시트 3종(메시지/복주머니/더보기 신고·차단)
import 'dart:async';
import 'package:flutter/material.dart' hide Visibility;
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_canvas.dart';
import '../../core/fx/wr_fx.dart';
import '../room/room_scene.dart';

class OtherRoomScreen extends StatefulWidget {
  const OtherRoomScreen({super.key, required this.roomId});
  final String roomId;
  @override
  State<OtherRoomScreen> createState() => _OtherRoomScreenState();
}

class _OtherRoomScreenState extends State<OtherRoomScreen> {
  bool _peek = false; // ◉ 방만 보기
  bool _wishOpen = false; // 소원 전문 펼침
  int _tick = 0; // 응원 메시지 티커
  Timer? _tickTimer;
  final List<_FxEntry> _fx = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WishRoomProvider>().loadViewedRoom(widget.roomId));
    _tickTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _addFx(Widget w, {int life = 2800}) {
    final key = UniqueKey();
    setState(() => _fx.add(_FxEntry(key, w)));
    Timer(Duration(milliseconds: life), () {
      if (mounted) setState(() => _fx.removeWhere((e) => e.key == key));
    });
  }

  Future<void> _cheer() async {
    final p = context.read<WishRoomProvider>();
    final reward = await p.support(widget.roomId);
    if (!mounted) return;
    if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
      return;
    }
    await p.loadViewedRoom(widget.roomId);
    if (!mounted) return;
    _addFx(Stack(children: [
      const WrHearts(x: 330, y: 500, n: 14),
      const WrBurst(x: 204, y: 260, n: 14, color: Color(0xFFFF9AB8), spread: 110),
    ]));
    if (reward != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('응원 ${reward['at']}회 · ${reward['reward']}')));
    }
  }

  Future<void> _sendMessage(String text) async {
    final p = context.read<WishRoomProvider>();
    final ok = await p.postComment(widget.roomId, text);
    if (!mounted) return;
    if (ok) {
      _addFx(const WrBurst(x: 204, y: 230, n: 14, glyph: '🌸', spread: 130, color: Color(0xFFF7A9C4)));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('응원 메시지가 전해졌어요')));
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  Future<void> _gift(int amount) async {
    final p = context.read<WishRoomProvider>();
    final ok = await p.gift(widget.roomId, amount);
    if (!mounted) return;
    if (ok) {
      await p.loadViewedRoom(widget.roomId);
      if (!mounted) return;
      _addFx(const WrBurst(x: 204, y: 260, n: 22, glyph: '🧧', spread: 150, dur: 1600), life: 2600);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('복주머니 $amount개가 닿았어요')));
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  Future<void> _report({String? commentId}) async {
    final p = context.read<WishRoomProvider>();
    final ok = await p.report(roomId: commentId == null ? widget.roomId : null, commentId: commentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '신고가 접수되어 숨겨졌어요 · 24시간 안에 살펴볼게요' : '신고에 실패했어요')));
    if (ok && commentId == null) Navigator.of(context).maybePop();
  }

  Future<void> _block(String ownerId) async {
    final p = context.read<WishRoomProvider>();
    final ok = await p.block(ownerId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '이 분과는 서로 보이지 않아요' : '차단에 실패했어요')));
    if (ok) Navigator.of(context).maybePop();
  }

  void _openSheet(Widget Function(BuildContext) builder) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: builder);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.viewedRoom;
        if (room == null || room.id != widget.roomId) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A)));
        }
        final comments = p.viewedComments;
        final cat = WrCatalog.I;
        final wc = cat.wishColors.where((c) => c['id'] == room.wishColor).toList();
        final W = wc.isNotEmpty ? wc.first : null;
        final pp = cat.papers.where((x) => x['id'] == room.paper).toList();
        final paper = pp.isNotEmpty ? pp.first : cat.papers.first;

        return GestureDetector(
          onTap: _peek ? () => setState(() => _peek = false) : null,
          child: Stack(children: [
            Positioned.fill(child: WrCanvasScaler(child: RoomScene(
              room: room, items: p.items,
              fx: _fx.map((e) => e.widget).toList(),
            ))),
            if (!_peek) SafeArea(child: WrCanvasScaler(child: Stack(children: [
              // TopBar
              Positioned(top: 52, left: 14, child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white))),
              Positioned(top: 58, left: 60, right: 60, child: Column(children: [
                Text('${room.owner}님의 소원방', style: WrF.display(16), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                Text('Lv.${room.level} ${room.levelName}', style: WrF.body(10.5, color: WrC.muted)),
              ])),
              Positioned(top: 52, right: 14, child: GestureDetector(
                onTap: () => _openMoreSheet(room),
                child: Container(width: 38, height: 38, decoration: BoxDecoration(color: WrC.glass, shape: BoxShape.circle),
                  child: const Icon(Icons.more_horiz, color: Colors.white)))),
              // 상단 칩: 응원·메시지·복 + 방만 보기
              Positioned(left: 14, right: 14, top: 104, child: Row(children: [
                if (room.visibility == Visibility.LINK) Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999)),
                  child: Text('🔗 초대받은 방', style: WrF.body(11, w: FontWeight.w700, color: const Color(0xFFFFE08A)))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('❤ ${room.supportCount}', style: WrF.body(11.5, w: FontWeight.w700, color: WrC.blossom2)),
                    const SizedBox(width: 10),
                    Text('💬 ${comments.length}', style: WrF.body(11.5, w: FontWeight.w700, color: WrC.fg)),
                    const SizedBox(width: 10),
                    Text('福 ${room.pouchReceived}', style: WrF.body(11.5, w: FontWeight.w700, color: WrC.glow)),
                  ])),
                const Spacer(),
                GestureDetector(onTap: () => setState(() => _peek = true), child: Container(
                  padding: const EdgeInsets.fromLTRB(11, 5, 7, 5),
                  decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
                  child: Text('◉ 방만 보기', style: WrF.body(11.5, w: FontWeight.w700, color: WrC.fg)))),
              ])),
              // 응원 메시지 한 줄 티커
              if (comments.isNotEmpty) Positioned(right: 14, top: 140, width: 210, child: GestureDetector(
                onTap: () => _openMessageSheet(room, comments),
                child: Container(key: ValueKey('${comments[_tick % comments.length].id}_$_tick'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0x991E0C18), borderRadius: BorderRadius.circular(14), border: Border.all(color: WrC.line)),
                  child: RichText(maxLines: 1, overflow: TextOverflow.ellipsis, text: TextSpan(children: [
                    TextSpan(text: '${comments[_tick % comments.length].author} ', style: WrF.body(10.5, w: FontWeight.w700, color: WrC.blossom2)),
                    TextSpan(text: '· ${comments[_tick % comments.length].text}', style: WrF.body(11.5, color: WrC.fg)),
                  ])),
                ),
              )),
              // 하단 도크
              Positioned(left: 12, right: 12, bottom: 30, child: Column(children: [
                Row(children: [
                  GestureDetector(onTap: () => _openGiftSheet(room), child: Container(
                    padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
                    decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x80F5CF6A))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/wishroom/items/pouch.png', width: 18, height: 18),
                      const SizedBox(width: 5),
                      Text('복주머니', style: WrF.body(12, w: FontWeight.w700, color: WrC.fg)),
                    ]))),
                  const SizedBox(width: 6),
                  GestureDetector(onTap: () => _openMessageSheet(room, comments), child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
                    child: Text('💬 응원 메시지', style: WrF.body(12, w: FontWeight.w700, color: WrC.fg)))),
                ]),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _wishOpen = true),
                    child: Container(
                      height: 58, padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [_paperColor(paper, 0).withValues(alpha: .93), _paperColor(paper, 1).withValues(alpha: .93)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: (W != null ? _hex(W['color'] as String) : const Color(0xFFFFDCB4)).withValues(alpha: .53), blurRadius: 16),
                          const BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Row(children: [
                        Container(width: 30, height: 30, alignment: Alignment.center,
                          decoration: BoxDecoration(color: W != null ? _hex(W['deep'] as String) : const Color(0xFFC94A3B),
                            borderRadius: BorderRadius.circular(6)),
                          child: Text(W != null ? W['hanja'] as String : '願', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFFF9E8)))),
                        const SizedBox(width: 9),
                        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${room.region} · ${room.daysLit}일째 밝히는 중${W != null ? ' · ${W['label']}' : ''}',
                            style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 10, color: _paperInk(paper).withValues(alpha: .6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(room.text, style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 13.5, color: _paperInk(paper), height: 1.35), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        Text('▲', style: TextStyle(fontSize: 10, color: _paperInk(paper).withValues(alpha: .5))),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  GestureDetector(onTap: room.supportedToday ? null : _cheer, child: Container(
                    width: 66, height: 66,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      gradient: SweepGradient(colors: room.supportedToday
                        ? const [Color(0xFFFF8FB1), Color(0xFFFF8FB1)]
                        : const [Color(0x33FFFFFF), Color(0x33FFFFFF)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFF2628F).withValues(alpha: room.supportedToday ? .4 : .6), blurRadius: room.supportedToday ? 14 : 22)]),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: room.supportedToday ? const [Color(0xFF4A2238), Color(0xFF2A1020)] : const [Color(0xFFFF9CBC), Color(0xFFF2628F)])),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('❤', style: TextStyle(fontSize: 20, height: 1, color: room.supportedToday ? const Color(0xFFFF8FB1) : Colors.white)),
                        const SizedBox(height: 3),
                        Text(room.supportedToday ? '응원함' : '응원하기', style: WrF.body(9.5, w: FontWeight.w800, color: Colors.white)),
                      ]),
                    ),
                  )),
                ]),
              ])),
            ]))),
            if (_peek) Positioned(left: 0, right: 0, bottom: 60, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999)),
              child: Text('화면을 누르면 돌아와요', style: WrF.body(12, w: FontWeight.w700, color: WrC.fg)),
            ))),
            if (_wishOpen) _wishOpenCard(room, W, paper),
          ]),
        );
      }),
    ));
  }

  Color _paperColor(Map<String, dynamic> paper, int i) => _hex((paper['bg'] as List)[i] as String);
  Color _paperInk(Map<String, dynamic> paper) => _hex(paper['ink'] as String);

  Widget _wishOpenCard(WishRoom room, Map<String, dynamic>? W, Map<String, dynamic> paper) {
    return Stack(children: [
      GestureDetector(onTap: () => setState(() => _wishOpen = false), child: Container(color: Colors.black54)),
      Positioned(left: 14, right: 14, bottom: 40, child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_paperColor(paper, 0), _paperColor(paper, 1)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: (W != null ? _hex(W['color'] as String) : Colors.transparent).withValues(alpha: .33), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 34, height: 34, alignment: Alignment.center,
              decoration: BoxDecoration(color: W != null ? _hex(W['deep'] as String) : const Color(0xFFC94A3B), borderRadius: BorderRadius.circular(6)),
              child: Text(W != null ? W['hanja'] as String : '願', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFFFF9E8)))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${room.owner}님 · ${room.region} · ${room.daysLit}일째', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 11, color: _paperInk(paper).withValues(alpha: .6))),
              Text(W != null ? '${W['label']}의 소원' : '', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 12, color: W != null ? _hex(W['deep'] as String) : _paperInk(paper))),
            ])),
            GestureDetector(onTap: () => setState(() => _wishOpen = false), child: Container(
              width: 30, height: 30, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .08), shape: BoxShape.circle),
              child: Icon(Icons.close, size: 16, color: _paperInk(paper)))),
          ]),
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxHeight: 150), child: SingleChildScrollView(
            child: Text(room.text, style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, height: 1.7, color: _paperInk(paper))))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: SizedBox(height: 44, child: ElevatedButton(
              onPressed: () { setState(() => _wishOpen = false); _openMessageSheet(room, context.read<WishRoomProvider>().viewedComments); },
              style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
              child: const Text('💬 한 마디', style: TextStyle(color: Colors.white, fontSize: 13))))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 44, child: ElevatedButton(
              onPressed: room.supportedToday ? null : () { setState(() => _wishOpen = false); _cheer(); },
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, disabledBackgroundColor: WrC.blossom.withValues(alpha: .3)),
              child: Text(room.supportedToday ? '❤ 응원했어요' : '❤ 응원하기', style: const TextStyle(color: Colors.white, fontSize: 13))))),
          ]),
        ]),
      )),
    ]);
  }

  void _openMessageSheet(WishRoom room, List<WrComment> comments) {
    final ctrl = TextEditingController();
    _openSheet((sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheetState) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * .8),
        decoration: WrDeco.sheet,
        padding: WrSize.sheetHeaderPad,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SUPPORT MESSAGE', style: WrF.mono(color: WrC.blossom2)),
              const SizedBox(height: 6),
              Text('응원 한 마디', style: WrF.display(20)),
            ]),
            Positioned(right: 0, top: 0, child: IconButton(onPressed: () => Navigator.of(sheetCtx).pop(),
              icon: const Icon(Icons.close, color: WrC.fg, size: 18))),
          ]),
          const SizedBox(height: 12),
          Flexible(child: SingleChildScrollView(child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(children: [
              Container(decoration: WrDeco.card, padding: const EdgeInsets.all(12), child: Column(children: [
                TextField(controller: ctrl, maxLength: 60, maxLines: 3, style: WrF.body(15, color: WrC.fg),
                  decoration: const InputDecoration(hintText: '따뜻한 한 마디를 적어주세요', hintStyle: TextStyle(color: WrC.muted), border: InputBorder.none, counterText: '')),
              ])),
              Align(alignment: Alignment.centerRight, child: Text('${ctrl.text.length}/60', style: WrF.mono())),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: WrSize.btnH, child: ElevatedButton(
                onPressed: () {
                  if (ctrl.text.trim().isEmpty) return;
                  Navigator.of(sheetCtx).pop();
                  _sendMessage(ctrl.text.trim());
                },
                style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('전하기', style: TextStyle(color: Colors.white)),
              )),
              const SizedBox(height: 18),
              Align(alignment: Alignment.centerLeft, child: Text('도착한 마음 ${comments.length}', style: WrF.display(14))),
              for (final c in comments) Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.author, style: WrF.body(11, w: FontWeight.w700, color: WrC.blossom2)),
                    const SizedBox(height: 2),
                    Text(c.text, style: WrF.body(13.5, color: WrC.fg)),
                  ])),
                  TextButton(onPressed: () => _report(commentId: c.id), child: Text('신고', style: WrF.body(11, color: WrC.muted))),
                ]),
              ),
            ]),
          ))),
        ]),
      ),
    )));
  }

  void _openGiftSheet(WishRoom room) {
    final me = context.read<WishRoomProvider>().me;
    int amt = 10;
    _openSheet((sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheetState) => Container(
      decoration: WrDeco.sheet,
      padding: WrSize.sheetHeaderPad,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SEND POUCH', style: WrF.mono(color: WrC.blossom2)),
            const SizedBox(height: 6),
            Text('복주머니 보내기', style: WrF.display(20)),
          ]),
          Positioned(right: 0, top: 0, child: IconButton(onPressed: () => Navigator.of(sheetCtx).pop(), icon: const Icon(Icons.close, color: WrC.fg, size: 18))),
        ]),
        const SizedBox(height: 14),
        Image.asset('assets/wishroom/items/pouch.png', width: 110),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final v in [5, 10, 30, 50]) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(onTap: () => setSheetState(() => amt = v), child: Container(
              padding: WrSize.chipPad,
              decoration: amt == v ? WrDeco.chipOn : WrDeco.chip,
              child: Text('$v개', style: WrF.body(12, w: FontWeight.w700, color: amt == v ? Colors.white : WrC.fg)),
            )),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          '지금 ${me?.pouch ?? 0}개 가지고 있어요'
          '${(me?.accountAgeDays ?? 999) < 7 ? '\n가입 7일 전까지는 하루 100개까지 · 오늘 ${me?.giftToday ?? 0}개 보냄' : ''}',
          style: WrF.body(12.5, color: WrC.muted, height: 1.7), textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: WrSize.btnH, child: ElevatedButton(
          onPressed: () { Navigator.of(sheetCtx).pop(); _gift(amt); },
          style: ElevatedButton.styleFrom(backgroundColor: WrC.glow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Text('복주머니 $amt개 보내기', style: const TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)),
        )),
      ]),
    )));
  }

  void _openMoreSheet(WishRoom room) {
    _openSheet((sheetCtx) => Container(
      decoration: WrDeco.sheet,
      padding: WrSize.sheetHeaderPad,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SAFETY', style: WrF.mono(color: WrC.blossom2)),
            const SizedBox(height: 6),
            Text('이 소원방', style: WrF.display(20)),
          ]),
          Positioned(right: 0, top: 0, child: IconButton(onPressed: () => Navigator.of(sheetCtx).pop(), icon: const Icon(Icons.close, color: WrC.fg, size: 18))),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: WrSize.btnH, child: ElevatedButton(
          onPressed: () { Navigator.of(sheetCtx).pop(); _report(); },
          style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('소원방 신고하기', style: TextStyle(color: Colors.white)),
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: WrSize.btnH, child: ElevatedButton(
          onPressed: () { Navigator.of(sheetCtx).pop(); _block(room.ownerId); },
          style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('이 분 차단하기', style: TextStyle(color: Colors.white)),
        )),
        const SizedBox(height: 12),
        Text('신고된 소원방은 즉시 숨겨지고, 24시간 안에 살펴봅니다.', style: WrF.body(12, color: WrC.muted, height: 1.6)),
      ]),
    ));
  }
}

class _FxEntry { final Key key; final Widget widget; _FxEntry(this.key, this.widget); }

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
