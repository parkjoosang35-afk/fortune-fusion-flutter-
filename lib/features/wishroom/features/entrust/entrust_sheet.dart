// [S3 신규] 수호자에게 맡기기(代願) 시트 — app3/entrust.jsx Entrust3 1:1 포팅.
// 내가 바쁜 날, 내 대표 수호자가 내 방에서 대신 기도한다(연속·촛불만 유지,
// 방 성장·기도 횟수·오늘의 복은 직접 빈 날만 쌓임). room.entrustNow/entrustNext가
// 있으면 "맡겨 둔 기간" 뷰로, 없으면 "맡길까요" 선택 뷰로 분기한다(flow.js view()와
// 동일한 분기 — Flutter 쪽은 room 필드로 이미 서버가 계산해 내려준다).
// [S5 — 공용 결제창 통일] "맡기기" 버튼은 더 이상 직접 entrustGuardian()을 호출하지
// 않고, app3 원본(entrust.jsx go() → app.checkout({kind:'entrust',...}))과 동일하게
// 공용 PayScreen(openPayScreen)을 거친다 — pay_screen.dart 상단 주석 "구매 로직은
// 1벌만" 지시를 수호자/옷/꾸미기 탭뿐 아니라 맡기기에도 적용한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_toast.dart';
import '../shop/pay_screen.dart';
import '../guide/guide3_sheet.dart';

/// 어디서든(소원방 돌보기 메뉴 "수호자에게 맡기기") 호출 가능한 오프너.
void openEntrustSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const EntrustSheet(),
  );
}

class EntrustSheet extends StatefulWidget {
  const EntrustSheet({super.key});
  @override
  State<EntrustSheet> createState() => _EntrustSheetState();
}

/// 조사(을/를, 이/가) 선택 — 받침 유무 판정. JOSA(name, '이', '가') 1:1 포팅.
String _josa(String name, String withBatchim, String noBatchim) {
  if (name.isEmpty) return noBatchim;
  final code = name.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return noBatchim; // 한글 음절 범위 밖이면 받침 없음 취급
  return ((code - 0xAC00) % 28 == 0) ? noBatchim : withBatchim;
}

/// 복주머니 N개 → 원화 환산 표시(1복주머니 = 10원 기준, 천 단위 콤마).
String _won(int n) {
  final s = (n * 10).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '$s원';
}

class _EntrustSheetState extends State<EntrustSheet> {
  int _days = 3;
  late bool _startsToday = true; // initState에서 room.devotionsToday로 확정
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final room = context.read<WishRoomProvider>().room;
    _startsToday = !(room != null && room.devotionsToday > 0);
    // [C8 신규] app3/shell.jsx `want` — sh==='entrust' 시트를 처음 열 때
    // "수호자에게 맡겨요" 안내(평생 1번).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowGuide3(context, 'entrust');
    });
  }

  // [S5 — 공용 결제창 통일] app3/entrust.jsx `go()`가 app.checkout({kind:'entrust',...})을
  // 호출하는 것과 1:1 — 더 이상 이 시트가 직접 entrustGuardian()을 호출하지 않는다.
  // 시트를 먼저 닫고(app.sheet(null)) PayScreen을 연다 — guardian_detail_sheet.dart의
  // Navigator.pop() → openPayScreen() 패턴과 동일하다.
  void _checkout(BuildContext context, WishRoom room, String name, WrCatalog cat) {
    final p = context.read<WishRoomProvider>();
    final price = cat.entrustPrice[_days.toString()] ?? 0;
    final pose = const {WrTheme.buddha: Pose.bow, WrTheme.shaman: Pose.rub}[room.theme] ?? Pose.pray;
    final img = cat.poseImage(room.char, room.theme, pose) ?? cat.charImage(room.char, room.outfitNow, outfitId: room.outfitId);
    final days = _days;
    final startsToday = _startsToday;
    final order = PayOrder(
      kind: 'entrust',
      name: '$name에게 ${const {1: '하루', 3: '사흘', 7: '이레'}[days]} 맡기기',
      sub: '${startsToday ? '오늘' : '내일'}부터 · "${room.text}"',
      img: img,
      price: price,
      doneTitle: '$name${_josa(name, '이', '가')} 당신의 소원을 지켜요',
      afterLabel: '🙏 소원방으로',
      after: () {}, // app3 `after: () => app.go('home')` — 이미 소원방 화면 위에서 열렸으므로 pop만으로 충분.
      onConfirmPay: (idempotencyKey) => p.entrustGuardian(room.id, days: days, startsToday: startsToday, idempotencyKey: idempotencyKey),
    );
    Navigator.of(context).pop(); // 시트 닫기
    openPayScreen(context, order);
  }

  Future<void> _cancel(WishRoom room) async {
    if (_busy) return;
    setState(() => _busy = true);
    final p = context.read<WishRoomProvider>();
    final refund = await p.cancelEntrust(room.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (refund != null) {
      Navigator.of(context).pop();
      WrToast.show(context, refund > 0 ? '맡기기를 그만두었어요 · 🧧 $refund 돌려받았어요' : '맡기기를 그만두었어요');
    } else if (p.lastError != null) {
      WrToast.show(context, p.lastError!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WishRoomProvider>();
    final room = p.room;
    if (room == null) return const SizedBox.shrink();
    final cat = WrCatalog.I;
    final guardian = p.characters.where((c) => c.id == room.char).firstOrNull;
    final name = guardian?.name ?? '수호자';
    final existing = room.entrustNow ?? room.entrustNext;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(
              context,
              sub: existing != null ? '代願 · 맡겨 둔 기간' : '代願 · 내가 못 오는 날',
              title: existing != null ? '$name에게 맡겨 두었어요' : '$name에게 맡길까요',
            ),
            const SizedBox(height: 14),
            if (existing != null)
              _existingView(context, room, existing, name)
            else
              _formView(context, room, name, cat),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, {required String sub, required String title}) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sub, style: WrF.mono(color: WrC.blossom2)),
            const SizedBox(height: 6),
            Text(title, style: WrF.display(20)),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: WrC.fg, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _existingView(BuildContext context, WishRoom room, Entrust e, String name) {
    final remain = e.startDay > room.dayN ? '내일부터 ${e.days}일 동안' : '${e.endDay - room.dayN}일 남았어요';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: WrDeco.hanji,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$remain · 그동안 연속 기도와 촛불은 $name${_josa(name, '이', '가')} 지켜요\n',
                  style: const TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, height: 1.7, color: WrC.hanjiInk),
                ),
                TextSpan(
                  text: '직접 오시면 함께 빌어요 · 그날은 내 기도로 기록돼요',
                  style: TextStyle(fontFamily: 'Pretendard', fontSize: 12, color: WrC.hanjiInk.withValues(alpha: .6)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: WrSize.btnH,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _cancel(room),
            style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('맡기기 그만두기 · 남은 날 돌려받기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _formView(BuildContext context, WishRoom room, String name, WrCatalog cat) {
    final devotedToday = room.devotionsToday > 0;
    final price = cat.entrustPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '바쁘거나 멀리 떠나는 날, $name${_josa(name, '이', '가')} 내 방에서 내 소원을 대신 빌어요. 연속 기도가 끊기지 않고 촛불도 약해지지 않아요.',
          style: WrF.body(13, color: WrC.muted, height: 1.6),
        ),
        const SizedBox(height: 12),
        Text('언제부터', style: WrF.body(13, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _startChip(label: '오늘부터', selected: _startsToday, disabled: devotedToday, disabledLabel: '오늘은 이미 빌었어요', onTap: () => setState(() => _startsToday = true))),
            const SizedBox(width: 7),
            Expanded(child: _startChip(label: '내일부터', selected: !_startsToday, disabled: false, disabledLabel: null, onTap: () => setState(() => _startsToday = false))),
          ],
        ),
        const SizedBox(height: 14),
        Text('며칠 동안', style: WrF.body(13, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in const [1, 3, 7]) ...[
              if (d != 1) const SizedBox(width: 7),
              Expanded(
                child: _daysChip(
                  label: const {1: '하루', 3: '사흘', 7: '이레'}[d]!,
                  pouch: price[d.toString()] ?? 0,
                  won: _won(price[d.toString()] ?? 0),
                  selected: _days == d,
                  onTap: () => setState(() => _days = d),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: WrDeco.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✓ 연속 기도 · 촛불 밝기를 지켜요', style: WrF.body(12, height: 1.7)),
              Text('✕ 방 성장 · 기도 횟수 · 오늘의 복주머니는 직접 빈 날만 쌓여요', style: WrF.body(12, color: WrC.muted, height: 1.7)),
              Text('· 끝나면 다음 날부터 다시 맡길 수 있어요 · 그만두면 내일부터 남은 날을 돌려받아요', style: WrF.body(12, color: WrC.muted, height: 1.7)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: WrSize.btnH,
          child: Semantics(
            identifier: 'entrust_checkout',
            button: true,
            child: ElevatedButton(
              onPressed: (_startsToday && devotedToday) ? null : () => _checkout(context, room, name, cat),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.glow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text('🧧 ${price[_days.toString()] ?? 0} · $name에게 맡기기', style: const TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _startChip({required String label, required bool selected, required bool disabled, String? disabledLabel, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? .4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? const Color(0x24F5CF6A) : WrC.card,
            border: Border.all(color: selected ? WrC.glow : WrC.cardBorder),
          ),
          child: Column(
            children: [
              Text(label, style: WrF.body(13.5, w: FontWeight.w700), textAlign: TextAlign.center),
              if (disabled && disabledLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(disabledLabel, style: WrF.body(10, color: WrC.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _daysChip({required String label, required int pouch, required String won, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? const Color(0x24F5CF6A) : WrC.card,
          border: Border.all(color: selected ? WrC.glow : WrC.cardBorder),
        ),
        child: Column(
          children: [
            Text(label, style: WrF.body(14, w: FontWeight.w700), textAlign: TextAlign.center),
            Text('🧧 $pouch', style: WrF.display(13, color: WrC.glow)),
            Text(won, style: WrF.body(10, color: WrC.muted)),
          ],
        ),
      ),
    );
  }
}
