// [G3 신규 — 46개 안내 팝업 전수 대조 공백 보완] app3/entrust.jsx EntrustBack 1:1 포팅.
// room.entrustDone(서버가 계산한 "맡기기 끝났지만 아직 확인 안 한 것")이 null이 아니고
// 내 소원방 화면에서 다른 시트·연출이 하나도 없을 때(main_room_screen.dart 호출부
// 조건 참고, unlock_card.dart와 동일 패턴) 이 카드 1장을 보여준다.
// [축소 반영] 원본은 e.startDay~endDay 구간을 날짜별로 "내가 빈 날/수호자가 빈 날"
// 달력 칸으로 그리지만(v.prayed/v.guarded 배열), 이 프로젝트 서버는 아직 그 일자별
// 기도 로그(WishRoomPrayerLog 모델은 있으나 API 미연결)를 공개 API로 내려주지 않는다
// — CHECKLIST.md "확인된 공백" 기록대로 데이터·API가 없는 부분은 새로 만들지 않고,
// 이미 있는 Entrust 필드(guardian/days/startDay/endDay)만으로 "○○이 N일 동안
// 대신 빌어 주었어요" 요약 문구로 대체한다. [마음에 담기]를 누르면
// WishRoomProvider.ackEntrust(room.id)를 호출해 서버에 ack를 기록한다(금전 효과 없음).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';

class EntrustBackCard extends StatefulWidget {
  const EntrustBackCard({super.key, required this.roomId, required this.entrust});
  final String roomId;
  final Entrust entrust;

  @override
  State<EntrustBackCard> createState() => _EntrustBackCardState();
}

class _EntrustBackCardState extends State<EntrustBackCard> {
  bool _busy = false;

  Future<void> _ack(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<WishRoomProvider>().ackEntrust(widget.roomId);
    // ack 실패해도(네트워크 등) 카드를 계속 띄워 둘 이유가 없다 — app3 원본도
    // window.WRF.ackEntrust(e.id)의 성공 여부를 따지지 않고 바로 닫는다(flow.js 1:1).
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entrust;
    final guardian = context.watch<WishRoomProvider>().characters.where((c) => c.id == e.guardian).firstOrNull;
    final name = guardian?.name ?? '수호자';
    final dayLabel = const {1: '하루', 3: '사흘', 7: '이레'}[e.days] ?? '${e.days}일';
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
            Text('$dayLabel 동안 지켜 드렸어요', textAlign: TextAlign.center, style: WrF.display(20)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: WrDeco.hanji,
              child: Text(
                '“촛불은 내내 환했어요. 이제 다시 함께 빌어요.”',
                textAlign: TextAlign.left,
                style: const TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, height: 1.7, color: WrC.hanjiInk),
              ),
            ),
            const SizedBox(height: 10),
            Text('■ $name이(가) 빈 날', style: WrF.body(11, color: WrC.glow)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: Semantics(
                identifier: 'entrust_back_ack',
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
