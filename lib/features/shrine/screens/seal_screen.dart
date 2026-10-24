// 신당(THE SHRINE) U13 — 부적을 소원방으로 가져가 함께 봉인
// 원본: /tmp/shrine_v3/merged/prototype/shrine-seal.jsx (유일한 소스 오브 트루스)
// ─────────────────────────────────────────────────────────────
// [아키텍처 차이에 따른 재설계 — 사용자 승인된 설계 결정]
// 원본 SealScreen은 "여러 소원 중 하나를 고르는"(pick 단계, SEAL_WISHES_SAMPLE
// 4개) UI를 두지만, 이 프로젝트의 WishRoomProvider는 사용자당 활성 소원방이
// 최대 1개(WishRoom? room)인 구조다(fortune/shared/presentation/
// seal_reading_flow.dart가 이미 확립한 선례와 동일한 제약). 따라서:
//   - 활성 소원방이 있으면 → "고르기" 화면 없이 그 방에 바로 확인 후 봉인
//     (고를 대상이 하나뿐이므로 고르기 UI 자체가 불필요하다).
//   - 활성 소원방이 없으면 → ComposeScreen(pendingShrineBoxNo: item.no)으로
//     보내 "방을 새로 만들면서 함께 봉인"한다(seal_reading_flow.dart의
//     v7.1 예외 경로와 동일 패턴).
// road/place/lay/press/done 5단계 연출은 원본을 그대로 포팅하되, "소원
// 고르기"가 사라진 대신 road 단계 진입 전에 "이 소원에 봉인하시겠습니까"
// 확인 바텀시트를 먼저 띄운다(seal_reading_flow.dart의 확인 시트 패턴 재사용).
//
// [사용자 확정 원칙] 서버 WishRoom/Wish 스키마는 전혀 변경하지 않는다 — 봉인
// 결과(BoxItem.sealedTo)는 로컬(SharedPreferences 'shrine.v2')에만 저장한다.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../wishroom/application/wishroom_provider.dart';
import '../../wishroom/features/compose/compose_screen.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import '../widgets/bujeok.dart';

/// [SEAL_GLYPH 포팅] TalismanSpec.type(fate/love/money/flow/guard/will) →
/// 소원 봉인 인장에 쓰이는 한자. 원본 shrine-seal.jsx와 값이 1:1 동일하며,
/// 신당 talismans.types의 실제 type 키와도 정확히 일치함을 확인했다
/// (assets/shrine/data/shrine.json: fate=命/love=緣/money=財/flow=流/guard=守/will=決).
const Map<String, String> kSealGlyph = {
  'love': '緣',
  'fate': '命',
  'money': '財',
  'flow': '流',
  'guard': '守',
  'will': '決',
};

/// [WR 포팅] 소원방 Midnight Temple 팔레트 — 원본 shrine-seal.jsx의 WR 상수.
class _WR {
  static const bg1 = Color(0xFF1A0D2E);
  static const bg2 = Color(0xFF0A0716);
  static const glow = Color(0xFFF5CF6A);
  static const accent = Color(0xFFC94A3B);
  static const fg = Color(0xFFF8F2E6);
}

/// showTalisManual의 「願 소원방에 봉인」 버튼에서 호출하는 진입점.
/// 1) 보낸(灰)/이미 봉인된 부적이면 호출 전에 버튼 자체가 막혀 있어야 한다.
/// 2) 활성 소원방 유무에 따라 분기한다(원본 SEAL_WISHES_SAMPLE "고르기" 대신).
Future<void> showSealToWishRoomSheet(
  BuildContext context, {
  required BoxItem item,
}) async {
  final wr = context.read<WishRoomProvider>();
  if (!wr.loaded) {
    await wr.loadMyRoom();
    if (!context.mounted) return;
  }
  final room = wr.room;
  final hasActiveWish = room != null && !room.readOnly;

  if (!hasActiveWish) {
    // 소원방이 없거나(또는 봉인/보관 상태라 다시 쓸 수 없는 경우) — ComposeScreen으로
    // 보내 "방을 새로 만들면서 함께 봉인"한다(v7.1 예외 경로와 동일 패턴).
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NoWishRoomSheet(item: item),
    );
    if (go != true || !context.mounted) return;
    Navigator.of(context).pop(); // showTalisManual 바텀시트 닫기
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComposeScreen(pendingShrineBoxNo: item.no),
      ),
    );
    return;
  }

  // 활성 소원방이 있으면 — 확인 후 바로 봉인 연출(road→place→lay→press→done)로 진입.
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ConfirmSealSheet(item: item, wishText: room.text),
  );
  if (confirmed != true || !context.mounted) return;
  Navigator.of(context).pop(); // showTalisManual 바텀시트 닫기
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SealScreen(itemNo: item.no, wishRoomId: room.id, wishText: room.text),
    ),
  );
}

/// 소원방이 없을 때 — "먼저 소원을 써야 봉인할 수 있다"는 안내 + 이동 확인.
class _NoWishRoomSheet extends StatelessWidget {
  final BoxItem item;
  const _NoWishRoomSheet({required this.item});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final glyph = kSealGlyph[item.spec.type] ?? '願';
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _WR.bg1,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x1FFFEBC8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(color: _WR.accent, borderRadius: BorderRadius.circular(9)),
                child: Text(glyph, style: const TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 18, color: _WR.fg)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('아직 빌어 둔 소원이 없습니다', style: t.display(16, w: FontWeight.w900, c: _WR.fg))),
            ]),
            const SizedBox(height: 14),
            Text(
              '${item.spec.name}를 소원방에 봉인하려면 먼저 소원을 써야 합니다. 지금 소원을 쓰시겠습니까? 쓰는 소원에 이 부적이 함께 봉인됩니다.',
              style: TextStyle(fontSize: 13, height: 1.6, color: _WR.fg.withValues(alpha: .82)),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(foregroundColor: _WR.fg, side: const BorderSide(color: Color(0x33FFEBC8)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('그만두기'),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: _WR.glow, foregroundColor: const Color(0xFF3A2515), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('소원 쓰러 가기', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 활성 소원방이 있을 때 — "이 소원에 봉인하시겠습니까" 확인.
class _ConfirmSealSheet extends StatelessWidget {
  final BoxItem item;
  final String wishText;
  const _ConfirmSealSheet({required this.item, required this.wishText});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final glyph = kSealGlyph[item.spec.type] ?? '願';
    final fit = kSealGlyph.containsKey(item.spec.type);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _WR.bg1, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0x1FFFEBC8))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(color: _WR.accent, borderRadius: BorderRadius.circular(9)),
                child: Text(glyph, style: const TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 18, color: _WR.fg)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('${item.spec.name}를\n어느 소원과 함께 봉인하시겠습니까', style: t.display(15, w: FontWeight.w900, c: _WR.fg, h: 1.3))),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0x0DFFEBC8), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x1FFFEBC8))),
              child: Text(wishText, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'GowunBatang', fontSize: 14, height: 1.6, color: _WR.fg)),
            ),
            const SizedBox(height: 10),
            Text(
              fit
                  ? '${item.spec.name}와 맞닿은 소원입니다. 부적 한 장은 소원 하나에만 봉인되며, 봉인하면 되돌릴 수 없습니다.'
                  : '부적 한 장은 소원 하나에만 봉인되며, 봉인하면 되돌릴 수 없습니다.',
              style: TextStyle(fontSize: 12, height: 1.6, color: _WR.fg.withValues(alpha: .62)),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(foregroundColor: _WR.fg, side: const BorderSide(color: Color(0x33FFEBC8)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('그만두기'),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: _WR.glow, foregroundColor: const Color(0xFF3A2515), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('봉인하러 가기', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

enum _SealPhase { road, place, lay, press, done }

/// 봉인 연출 본 화면 — road(초롱 길) → place(마법진) → lay(겹치기) →
/// press(인장 길게 누르기) → done(완료 카드). 원본 ph state machine 1:1 포팅.
class SealScreen extends StatefulWidget {
  final String itemNo;
  final String wishRoomId;
  final String wishText;
  const SealScreen({
    super.key,
    required this.itemNo,
    required this.wishRoomId,
    required this.wishText,
  });
  @override
  State<SealScreen> createState() => _SealScreenState();
}

class _SealScreenState extends State<SealScreen> {
  _SealPhase ph = _SealPhase.road;
  double laid = 0; // 0..1 부적이 소원 위로 겹친 정도(탭으로만 조작 — 드래그는 생략)
  double press = 0; // 0..1 인장 길게 누르기
  bool _holding = false;
  Timer? _advanceTimer;
  Timer? _pressTimer;
  bool _finished = false;

  BoxItem? get _item {
    final box = context.read<ShrineSessionProvider>().state.box;
    for (final b in box) {
      if (b.no == widget.itemNo) return b;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final reduce = context.read<ShrineSessionProvider>().state.reduce;
    _advanceTimer = Timer(Duration(milliseconds: reduce ? 500 : 4200), () {
      if (!mounted) return;
      setState(() => ph = _SealPhase.place);
      _toLay();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _pressTimer?.cancel();
    super.dispose();
  }

  void _skipToPlace() {
    _advanceTimer?.cancel();
    setState(() => ph = _SealPhase.place);
    _toLay();
  }

  void _toLay() {
    final reduce = context.read<ShrineSessionProvider>().state.reduce;
    Timer(Duration(milliseconds: reduce ? 200 : 1800), () {
      if (mounted) setState(() => ph = _SealPhase.lay);
    });
  }

  /// 탭(또는 Enter 역할)으로 부적을 소원 위에 겹친다 — 원본 onKeyDown Enter/Space와 동일 효과.
  void _layTap() {
    if (ph != _SealPhase.lay) return;
    setState(() => laid = 1);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => ph = _SealPhase.press);
    });
  }

  void _startPress() {
    if (ph != _SealPhase.press || _finished) return;
    _holding = true;
    _pressTimer?.cancel();
    const tick = Duration(milliseconds: 16);
    _pressTimer = Timer.periodic(tick, (_) {
      if (!mounted) return;
      setState(() {
        final delta = tick.inMilliseconds / 1000;
        press = (_holding ? press + delta / 1.8 : press - delta / 1.2).clamp(0.0, 1.0);
        if (press >= 1 && !_finished) {
          _finished = true;
          _finish();
        }
      });
      if (press <= 0 && !_holding) {
        _pressTimer?.cancel();
      }
    });
  }

  void _stopPress() {
    _holding = false;
  }

  void _finish() {
    final provider = context.read<ShrineSessionProvider>();
    provider.updateBox(
      widget.itemNo,
      (b) => b.copy(
        sealedTo: SealedTo(
          wishRoomId: widget.wishRoomId,
          wishText: widget.wishText,
          at: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => ph = _SealPhase.done);
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final item = _item;
    if (item == null) {
      // 부적이 사라진(예: 보냄) 경우 안전하게 부적함으로.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: _WR.bg2, body: SizedBox.shrink());
    }
    final glyph = kSealGlyph[item.spec.type] ?? '願';
    final shownName = nameShown(st.name, item.mode);
    final room = ph != _SealPhase.road;

    return Scaffold(
      backgroundColor: _WR.bg2,
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_WR.bg1, _WR.bg2],
              ),
            ),
          ),
          // 마법진 — press 단계에서 빠르게 회전 + 밝아짐.
          if (room)
            Center(
              child: Opacity(
                opacity: ph == _SealPhase.press ? .45 + press * .5 : .45,
                child: _SpinningSigil(
                  speedUp: ph == _SealPhase.press ? press : 0,
                ),
              ),
            ),
          if (ph == _SealPhase.road) _RoadStage(glyph: glyph, shownName: shownName, itemName: item.spec.name),
          if (room)
            _AltarStage(
              item: item,
              shownName: shownName,
              wishText: widget.wishText,
              ph: ph,
              laid: laid,
              onLayTap: _layTap,
            ),
          if (ph == _SealPhase.lay)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Text('↑ 부적을 소원 위로 올려 겹치십시오', style: t.mono.copyWith(color: _WR.glow)),
              ),
            ),
          if (ph == _SealPhase.press)
            _PressStage(glyph: glyph, press: press, onDown: _startPress, onUp: _stopPress),
          if (ph == _SealPhase.done)
            _DoneStage(item: item, glyph: glyph, shownName: shownName, wishText: widget.wishText),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () {
                      if (ph == _SealPhase.road || ph == _SealPhase.done) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => ph = _SealPhase.road);
                      }
                    },
                    child: Container(
                      width: 36, height: 36, alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x590A0605), border: Border.all(color: C.goldLine)),
                      child: const Icon(Icons.chevron_left, color: C.fg, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text(room ? 'WISH ROOM · 願' : 'SEAL · 封', style: t.mono),
                  const Spacer(),
                  if (ph == _SealPhase.road)
                    GestureDetector(
                      onTap: _skipToPlace,
                      child: Container(
                        height: 32, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0x80080404), borderRadius: BorderRadius.circular(999), border: Border.all(color: C.goldLine)),
                        child: Text('SKIP ›', style: t.mono.copyWith(letterSpacing: 2.5, color: C.muted)),
                      ),
                    )
                  else
                    const SizedBox(width: 36),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// road 단계 — 초롱에 담긴 부적이 신당에서 소원방으로 향한다.
class _RoadStage extends StatelessWidget {
  final String glyph, shownName, itemName;
  const _RoadStage({required this.glyph, required this.shownName, required this.itemName});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 78, alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_WR.accent, Color(0xFF7A2A20)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: _WR.glow.withValues(alpha: .45), blurRadius: 30, spreadRadius: 4)],
            ),
            child: Text(glyph, style: const TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 28, color: _WR.fg)),
          ),
          const SizedBox(height: 28),
          Text('神堂 → 願', style: T(1).mono),
          const SizedBox(height: 10),
          Text(
            '"${shownName.isNotEmpty ? shownName : '당신'}님의 $itemName를\n소원방으로 모셔 갑니다."',
            textAlign: TextAlign.center,
            style: T(1).body(14, c: _WR.fg, h: 1.6),
          ),
        ],
      ),
    );
  }
}

/// place/lay/press/done 공통 배경 — 소원 두루마리 + 부적.
class _AltarStage extends StatelessWidget {
  final BoxItem item;
  final String shownName, wishText;
  final _SealPhase ph;
  final double laid;
  final VoidCallback onLayTap;
  const _AltarStage({
    required this.item,
    required this.shownName,
    required this.wishText,
    required this.ph,
    required this.laid,
    required this.onLayTap,
  });
  @override
  Widget build(BuildContext context) {
    if (ph == _SealPhase.done) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0x14FFEBC8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x33FFEBC8)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('願 · 소원방', style: T(1).mono.copyWith(color: _WR.glow)),
                const SizedBox(height: 6),
                Text(wishText, style: const TextStyle(fontFamily: 'GowunBatang', fontSize: 14, height: 1.6, color: _WR.fg)),
              ]),
            ),
          ),
          if (ph == _SealPhase.lay || ph == _SealPhase.press)
            GestureDetector(
              onTap: onLayTap,
              child: Transform.translate(
                offset: Offset(0, -laid * 40),
                child: Opacity(
                  opacity: 1,
                  child: BujeokSheet(w: 96, name: shownName, spec: item.spec, serial: '神堂 · ${item.no}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// press 단계 — 인장을 길게 눌러 봉인한다(1.8초).
class _PressStage extends StatelessWidget {
  final String glyph;
  final double press;
  final VoidCallback onDown, onUp;
  const _PressStage({required this.glyph, required this.press, required this.onDown, required this.onUp});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80, left: 0, right: 0,
      child: Column(
        children: [
          GestureDetector(
            onTapDown: (_) => onDown(),
            onTapUp: (_) => onUp(),
            onTapCancel: onUp,
            child: SizedBox(
              width: 100, height: 100,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 100, height: 100,
                  child: CircularProgressIndicator(
                    value: press,
                    strokeWidth: 5,
                    backgroundColor: const Color(0x33FFEBC8),
                    valueColor: AlwaysStoppedAnimation(_WR.glow),
                  ),
                ),
                Container(
                  width: 72, height: 72, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _WR.accent, boxShadow: [BoxShadow(color: _WR.glow.withValues(alpha: .4), blurRadius: 20)]),
                  child: Text(glyph, style: const TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 28, color: _WR.fg)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Text(press > 0 ? '손을 떼지 마십시오' : '인장을 길게 누르십시오', style: T(1).mono.copyWith(color: _WR.glow)),
        ],
      ),
    );
  }
}

/// done 단계 — 봉인 완료 카드.
class _DoneStage extends StatelessWidget {
  final BoxItem item;
  final String glyph, shownName, wishText;
  const _DoneStage({required this.item, required this.glyph, required this.shownName, required this.wishText});
  @override
  Widget build(BuildContext context) {
    final t = T(1);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0x14FFEBC8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x33FFEBC8)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                BujeokSheet(w: 72, name: shownName, spec: item.spec),
                const SizedBox(height: 12),
                Container(
                  width: 44, height: 44, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _WR.accent),
                  child: Text(glyph, style: const TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 20, color: _WR.fg)),
                ),
                const SizedBox(height: 10),
                Text('願 · 封 · 봉인된 소원', style: t.mono.copyWith(color: _WR.glow)),
                const SizedBox(height: 8),
                Text(wishText, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'GowunBatang', fontSize: 15, height: 1.6, color: _WR.fg)),
                const SizedBox(height: 8),
                Text('${item.spec.name} · ${item.spec.phrase} · ${item.no}', style: t.mono.copyWith(fontSize: 9.5)),
              ]),
            ),
            const SizedBox(height: 20),
            Text(
              '"이제 이 소원은 혼자 밝히지 않습니다.\n${item.spec.name}가 곁에서 함께 지킵니다."',
              textAlign: TextAlign.center,
              style: t.body(13.5, c: _WR.fg, h: 1.7),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 50, alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: redButtonGradient, borderRadius: BorderRadius.circular(12)),
                  child: Text('부적함으로 돌아가기 ›', style: t.ui(14.5, w: FontWeight.w700, c: C.btnText)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '소원방에서 이 소원을 열면 붙어 있는 부적을 볼 수 있습니다. 소원이 이루어지면 부적은 함께 태워 보냅니다.',
              textAlign: TextAlign.center,
              style: t.ui(11, c: C.faint),
            ),
          ],
        ),
      ),
    );
  }
}

/// 회전하는 마법진 장식 — Sigil(원본)을 대체하는 간단한 동심원+별 장식.
class _SpinningSigil extends StatefulWidget {
  final double speedUp; // 0..1, press 진행도에 따라 회전 가속
  const _SpinningSigil({required this.speedUp});
  @override
  State<_SpinningSigil> createState() => _SpinningSigilState();
}

class _SpinningSigilState extends State<_SpinningSigil> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final speed = 1 + widget.speedUp * 14; // press 진행 시 최대 15배 가속
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi * speed,
        child: child,
      ),
      child: SizedBox(
        width: 280, height: 280,
        child: CustomPaint(painter: _SigilPainter(color: _WR.glow)),
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  final Color color;
  _SigilPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, r * .72, paint);
    canvas.drawCircle(center, r * .4, paint);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = center + Offset(r * .4 * math.cos(a), r * .4 * math.sin(a));
      final p2 = center + Offset(r * math.cos(a), r * math.sin(a));
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) => oldDelegate.color != color;
}
