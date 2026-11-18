// [S3 신규] 찾아온 수호자(받은 마음) 시트 — app3/entrust.jsx Received3 1:1 포팅.
// 내 소원방에 다녀간(praying/asked, 최근 7일) 다른 분의 수호자 목록을 보여준다.
// "고마워요"(한마디 고르기, 복주머니 적립), "답례로 보내기"(내 수호자를 그 방으로),
// "돌려보내기"(목록에서 제외) 3가지 액션을 지원한다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_toast.dart';

/// 어디서든(소원방 돌보기 메뉴 "찾아온 수호자") 호출 가능한 오프너.
void openReceivedSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const ReceivedSheet(),
  );
}

/// "고마워요" 고른 한마디 4종 — app3/entrust.jsx Received3 words.
const _kThanksWords = ['고마워요, 덕분에 힘이 나요', '저도 당신 소원을 빌게요', '마음이 따뜻해졌어요', '꼭 이루어지길 바라요'];

class ReceivedSheet extends StatefulWidget {
  const ReceivedSheet({super.key});
  @override
  State<ReceivedSheet> createState() => _ReceivedSheetState();
}

class _ReceivedSheetState extends State<ReceivedSheet> {
  String? _pickId; // "고마워요" 한마디 고르는 중인 visitor id
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WishRoomProvider>().loadVisitors());
  }

  Future<void> _thanks(String id) async {
    if (_busy) return;
    setState(() { _busy = true; _pickId = null; });
    final p = context.read<WishRoomProvider>();
    final rewarded = await p.thanksVisitor(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (rewarded != null) {
      WrToast.show(context, rewarded > 0 ? '고마운 마음을 전했어요 · 🧧 $rewarded 받았어요' : '고마운 마음을 전했어요');
    } else if (p.lastError != null) {
      WrToast.show(context, p.lastError!.message);
    }
  }

  Future<void> _recall(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    final p = context.read<WishRoomProvider>();
    final ok = await p.recallVisitor(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      WrToast.show(context, '정중히 돌려보냈어요');
    } else if (p.lastError != null) {
      WrToast.show(context, p.lastError!.message);
    }
  }

  Future<void> _reply(VisitorIn x) async {
    if (_busy) return;
    final p = context.read<WishRoomProvider>();
    final me = p.me;
    if (me == null) return;
    // 지금 다른 곳에 가 있지 않은 내 수호자(= busy 아닌 것)를 하나 고른다.
    final candidate = me.ownedChars.firstWhere(
      (c) => p.room?.guardianAway?.guardian != c && p.room?.entrustNow?.guardian != c,
      orElse: () => me.ownedChars.isNotEmpty ? me.ownedChars.first : '',
    );
    if (candidate.isEmpty) {
      WrToast.show(context, '보낼 수 있는 수호자가 없어요');
      return;
    }
    setState(() => _busy = true);
    final result = await p.dispatchGuardian(x.room, guardian: candidate, isReply: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      WrToast.show(context, '답례로 수호자를 보냈어요 · ${x.who ?? ''}님 방으로');
    } else if (p.lastError != null) {
      WrToast.show(context, p.lastError!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WishRoomProvider>();
    final room = p.room;
    final cat = WrCatalog.I;
    final list = p.visitors;
    const policyLabel = {'off': '받지 않기', 'ask': '물어보고 받기', 'open': '누구든 받기'};

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECEIVED · 최근 7일', style: WrF.mono(color: WrC.blossom2)),
                      const SizedBox(height: 6),
                      Text('찾아온 수호자', style: WrF.display(20)),
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
              ),
              const SizedBox(height: 10),
              Text('방문 받기 · ${policyLabel[room?.visitPolicy] ?? '물어보고 받기'}', style: WrF.body(12, color: WrC.muted)),
              const SizedBox(height: 14),
              if (p.visitorsLoading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(color: WrC.glow)))
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    (room?.visibility == Visibility.PUBLIC)
                        ? '아직 찾아온 수호자가 없어요'
                        : '소원을 공개하면 다른 분의 수호자가 찾아올 수 있어요',
                    style: WrF.body(13, color: WrC.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final x in list) _visitorCard(context, x, cat),
              if (_pickId != null) ...[
                const SizedBox(height: 10),
                for (final w in _kThanksWords)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _thanks(_pickId!),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: WrDeco.card,
                        child: Text(w, style: WrF.body(13, w: FontWeight.w700)),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Text(
                '먼저 보내 준 분께는 7일 동안 답례를 보낼 수 있어요 · 답례는 한 번만 · 익명으로 온 수호자에겐 고마워요만 전할 수 있어요',
                style: WrF.body(11, color: WrC.muted, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visitorCard(BuildContext context, VisitorIn x, WrCatalog cat) {
    final name = x.anon ? '익명의 수호자' : '${x.who ?? '익명'}님의 ${cat.charName(x.guardian)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: WrDeco.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            cat.charImage(x.guardian, WrTheme.free),
            width: 54, height: 66, fit: BoxFit.contain, alignment: Alignment.bottomCenter,
            errorBuilder: (_, __, ___) => const SizedBox(width: 54, height: 66),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: WrF.body(13.5, w: FontWeight.w700)),
                if (x.word != null && x.word!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('"${x.word}"', style: WrF.body(12, color: WrC.muted)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (!x.anon)
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => _reply(x),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WrC.glow,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          child: const Text('☾ 답례로 보내기', style: TextStyle(fontSize: 11.5, color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (!x.thanked)
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => setState(() => _pickId = x.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WrC.darkBtn,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          child: const Text('고마워요', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('✓ 마음 전함', style: WrF.body(11, color: WrC.glow)),
                      ),
                    TextButton(
                      onPressed: _busy ? null : () => _recall(x.id),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                      child: Text('돌려보내기', style: WrF.body(11, color: WrC.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
