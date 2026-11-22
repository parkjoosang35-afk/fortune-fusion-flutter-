// [G5 신규 — 46개 안내 팝업 전수 대조 공백 보완] app3/home.jsx DispatchBack 1:1 포팅.
// me.dispatchDone(서버가 계산한 "내가 보낸 수호자가 기간을 마쳤지만 아직 확인
// 안 한 것" — wishroom-engine.ts getDispatchDone()/meView() 참고)이 null이 아니고
// 내 소원방 화면에서 다른 시트·연출이 하나도 없을 때 이 카드 1장을 보여준다.
// EntrustBack(G3)과 달리 "내 방"이 아니라 "내가 보낸 수호자"가 주인공이라
// WishRoom이 아닌 Me 레벨 데이터를 쓴다(entrust_back_card.dart와 동일 패턴,
// 데이터 출처만 다름). [축소 반영] 원본은 받는 방의 소원 문구·방문자 수까지
// 보여주지만(FEED 캐시 조회), 이 프로젝트 서버는 공개 API로 "그 방" 상세를
// 발신자에게 내려주지 않는다 — CHECKLIST.md 공백 기록대로 이미 있는
// DispatchAway 필드(guardian/days)만으로 요약 문구를 구성한다.
// [마음에 담기]를 누르면 WishRoomProvider.ackDispatch('wrd_{id}')를 호출해
// 서버에 ack를 기록한다(금전 효과 없음 — _shared.ts formatWishRoomDispatchId와
// 동일하게 'wrd_' 접두어를 붙여야 parseWishRoomDispatchId가 인식한다).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';

class DispatchBackCard extends StatefulWidget {
  const DispatchBackCard({super.key, required this.dispatch});
  final DispatchAway dispatch;

  @override
  State<DispatchBackCard> createState() => _DispatchBackCardState();
}

class _DispatchBackCardState extends State<DispatchBackCard> {
  bool _busy = false;

  Future<void> _ack(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<WishRoomProvider>().ackDispatch('wrd_${widget.dispatch.id}');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispatch;
    final guardian = context.watch<WishRoomProvider>().characters.where((c) => c.id == d.guardian).firstOrNull;
    final name = guardian?.name ?? '수호자';
    final dayLabel = const {1: '하루', 3: '사흘', 7: '이레'}[d.days] ?? '${d.days}일';
    return Stack(children: [
      Positioned.fill(child: Container(color: const Color(0x80080308))), // .dim
      Positioned(
        left: 26, right: 26, top: 200,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x61FFDC96)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF7461E38), Color(0xFA1A0812)]),
            boxShadow: [BoxShadow(color: const Color(0x38FFBE78), blurRadius: 60), const BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 24))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('代願 · 기도 일지', style: WrF.mono(color: WrC.glow)),
            const SizedBox(height: 8),
            Text('$name이(가) 돌아왔어요', textAlign: TextAlign.center, style: WrF.display(20)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: WrDeco.hanji,
              child: Text(
                '“다른 분 소원방에서 $dayLabel 동안 빌고 왔어요. 촛불이 아주 환해졌어요.”',
                textAlign: TextAlign.left,
                style: const TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, height: 1.7, color: WrC.hanjiInk),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 14, children: [
              Text('🙏 $dayLabel 대신 기도', style: WrF.body(12.5, w: FontWeight.w700, color: WrC.glow)),
              Text('🕯 그 방 촛불 +5%', style: WrF.body(12.5, w: FontWeight.w700, color: WrC.glow)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: Semantics(
                identifier: 'dispatch_back_ack',
                button: true,
                child: DecoratedBox(
                  decoration: WrDeco.btnGold,
                  child: Material(color: Colors.transparent,
                    child: InkWell(borderRadius: BorderRadius.circular(16),
                      onTap: _busy ? null : () => _ack(context),
                      child: Center(
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A2A10)))
                            : const Text('마음에 담기',
                                style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF4A2A10))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
