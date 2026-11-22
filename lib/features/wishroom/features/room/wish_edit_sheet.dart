// [S6 신규 — CHECKLIST.md "소원 수정 제한"] app3/extras.js WishEdit3 1:1 포팅.
// 문구 다듬기(하루 3번)/다른 소원으로(처음 3일·평생 1번) 토글 + 기도 목표
// (21/49/100일·목표 없음) 칩 + "이 소원 마무리하기 ›" 링크(Fulfill3→CompleteScreen).
//
// [서버 선계산] canRewish/wishEditsRemaining/goal은 서버(roomView())가 dayN·
// rewished·wishEditsToday를 이미 반영해 내려주므로, 여기서는 클라이언트 쪽
// dayN 재계산 없이 room 필드를 그대로 쓴다(wish-edit/route.ts·models.dart 참고).
//
// [에러 표시] WishRoomProvider.editWish()는 다른 메서드들과 달리 ApiError를
// lastError에 담고 삼키는 대신 rethrow한다 — 원본 WishEdit3의
// `catch(e){ setErr(e.message) }`처럼 이 시트 로컬 상태(_err)에 바로 보여주기
// 위함이다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_toast.dart';
import '../complete/complete_screen.dart';

/// 소원방 돌보기 메뉴 "소원 · 목표 고쳐 쓰기"에서 호출하는 오프너.
void openWishEditSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const WishEditSheet(),
  );
}

class WishEditSheet extends StatefulWidget {
  const WishEditSheet({super.key});
  @override
  State<WishEditSheet> createState() => _WishEditSheetState();
}

class _WishEditSheetState extends State<WishEditSheet> {
  String _mode = 'edit'; // 'edit' | 'rewish' — extras.js WishEdit3 mode state 1:1
  late final TextEditingController _textCtrl;
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final room = context.read<WishRoomProvider>().room;
    _textCtrl = TextEditingController(text: room?.text ?? '');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _switchMode(String k, WishRoom room) {
    setState(() {
      _mode = k;
      _err = null;
      _textCtrl.text = k == 'edit' ? room.text : '';
    });
  }

  Future<void> _save(WishRoom room) async {
    if (_busy) return;
    final t = _textCtrl.text.trim();
    if (_mode == 'rewish' && (!room.canRewish || t.length < 2)) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final p = context.read<WishRoomProvider>();
    try {
      if (t != room.text) {
        await p.editWish(room.id, mode: _mode, text: t);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      WrToast.show(context, _mode == 'edit' ? '소원을 다시 새겼어요' : '새 마음으로 다시 담았어요');
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = e.message;
      });
    }
  }

  Future<void> _setGoal(WishRoom room, int g) async {
    if (_busy) return;
    final p = context.read<WishRoomProvider>();
    try {
      await p.editWish(room.id, mode: 'goal', goalDays: g == 0 ? null : g);
    } on ApiError catch (e) {
      if (!mounted) return;
      WrToast.show(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WishRoomProvider>();
    final room = p.room;
    if (room == null) return const SizedBox.shrink();
    final canRe = room.canRewish;
    final editsToday = (3 - room.wishEditsRemaining).clamp(0, 3);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _modeChip(label: '✎ 문구 다듬기', selected: _mode == 'edit', disabled: false, onTap: () => _switchMode('edit', room))),
                const SizedBox(width: 6),
                Expanded(child: _modeChip(label: '↺ 다른 소원으로', selected: _mode == 'rewish', disabled: !canRe, onTap: () => _switchMode('rewish', room))),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _mode == 'edit'
                  ? '오타 · 표현만 다듬어요 · 날짜와 기도 횟수는 그대로 · 오늘 $editsToday/3번'
                  : (canRe ? '처음 3일 안에 한 번만 다른 소원으로 바꿀 수 있어요 · 기도 기록은 이어져요' : '처음 3일이 지났거나 이미 한 번 바꿨어요 · 다른 소원은 「마무리」 후 새로 담아요'),
              style: WrF.body(12, color: WrC.muted, height: 1.6),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: WrDeco.hanji,
              child: TextField(
                controller: _textCtrl,
                maxLength: 60,
                maxLines: 3,
                minLines: 3,
                onChanged: (_) => setState(() => _err = null),
                style: const TextStyle(fontFamily: 'Pretendard', fontSize: 17, height: 1.7, color: WrC.hanjiInk),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: _mode == 'rewish' ? '새로 담을 소원을 적어 주세요' : '',
                  hintStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 15, color: WrC.hanjiInk.withValues(alpha: .4)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${_textCtrl.text.length} / 60', style: WrF.mono(size: 11)),
            ),
            if (_err != null) ...[
              const SizedBox(height: 4),
              Text(_err!, style: WrF.body(12.5, color: WrC.blossom2)),
            ],
            const SizedBox(height: 16),
            Text('기도 목표', style: WrF.body(13, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in const [21, 49, 100, 0])
                  Semantics(
                    identifier: 'wish_edit_goal_$g',
                    button: true,
                    child: _goalChip(label: g == 0 ? '목표 없음' : '$g일', selected: (room.goal ?? 0) == g, onTap: () => _setGoal(room, g)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: WrSize.btnH,
              child: Semantics(
                identifier: 'wish_edit_save',
                button: true,
                child: ElevatedButton(
                  onPressed: (_busy || (_mode == 'rewish' && (!canRe || _textCtrl.text.trim().length < 2))) ? null : () => _save(room),
                  style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_mode == 'edit' ? '저장하기' : '이 소원으로 다시 담기', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompleteScreen(roomId: room.id)));
                },
                child: Text('이 소원 마무리하기 ›', style: WrF.body(13, color: WrC.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MY WISH', style: WrF.mono(color: WrC.blossom2)),
            const SizedBox(height: 6),
            Text('내 소원', style: WrF.display(20)),
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

  Widget _modeChip({required String label, required bool selected, required bool disabled, required VoidCallback onTap}) {
    return Semantics(
      identifier: 'wish_edit_mode_${label.contains('다듬') ? 'edit' : 'rewish'}',
      button: true,
      child: Opacity(
        opacity: disabled ? .4 : 1,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: selected ? WrDeco.chipOn : WrDeco.chip,
            child: Text(label, style: WrF.body(12.5, w: FontWeight.w700, color: selected ? Colors.white : WrC.fg)),
          ),
        ),
      ),
    );
  }

  Widget _goalChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: WrSize.chipPad,
        decoration: selected ? WrDeco.chipOn : WrDeco.chip,
        child: Text(label, style: WrF.body(12, w: FontWeight.w700, color: selected ? Colors.white : WrC.fg)),
      ),
    );
  }
}
