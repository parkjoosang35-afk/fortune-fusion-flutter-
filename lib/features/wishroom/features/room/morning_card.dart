// [A13 신규 — 46개 안내 팝업 전수 대조 공백 보완] app3/guide3.jsx MorningCard3 1:1 포팅.
// "감동 포인트" — 2일째부터 하루 1번, 아직 오늘 기도를 안 올린 채 소원방
// 화면에 들어오면(screen-load 훅, A12 TomorrowCard의 기도 "직후" 트리거와는
// 반대로 기도 "전" 트리거) 밤사이 수호자가 촛불을 지켰다는 안내를 보여준다.
// app3 원본 `n = v.public ? 3 + ((v.day*7 + v.prayedN*3) % 9) : 0`의 `v.day`는
// "방 생성일부터 누적 일련번호"(0-base)인데, 이 프로젝트 서버 WishRoom 모델엔
// 그 값이 없으므로(서버 스키마 부재 — CHECKLIST.md 공백 기록) 대신
// room.dayN(1-base, 의미상 거의 동일한 "경과일")으로 치환한다 — 숫자 하나가
// 끼어드는 장식용 의사난수라 정확히 같은 값일 필요는 없다.
import 'package:flutter/material.dart' hide Visibility;
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';

class MorningCard extends StatelessWidget {
  const MorningCard({super.key, required this.room, required this.guardianName, required this.onClose});
  final WishRoom room;
  final String guardianName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // app3 `n = v.public ? 3 + ((v.day*7 + v.prayedN*3) % 9) : 0` 1:1(치환: day→dayN).
    final n = room.visibility == Visibility.PUBLIC
        ? 3 + ((room.dayN * 7 + room.prayedN * 3) % 9)
        : 0;
    final hour = DateTime.now().hour;
    final hi = hour < 11 ? '좋은 아침이에요' : hour < 18 ? '오늘도 와 주셨네요' : '편안한 저녁이에요';
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: onClose,
          child: Container(color: const Color(0x73080308)), // .dim rgba(8,3,8,.45)
        ),
      ),
      Positioned(
        left: 26, right: 26, top: 170,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF7FFF6EC), Color(0xF7FAE2EC)]),
            boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 50, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('DAY ${room.dayN} · $hi', style: WrF.mono(color: const Color(0xFFB0607A))),
            const SizedBox(height: 10),
            Text('밤사이 $guardianName이(가)\n촛불을 지켰어요',
                textAlign: TextAlign.center,
                style: WrF.display(19, color: const Color(0xFF4A2436), height: 1.45)),
            const SizedBox(height: 10),
            Text(
              n > 0 ? '어젯밤 $n명이 당신의 소원을 함께 빌었어요' : '오늘도 소원이 당신을 기다리고 있었어요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, height: 1.7, color: Color(0xFF4A2436)),
            ),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 14, children: [
              Text('🕯 ${room.dayN}일째', style: WrF.body(12.5, w: FontWeight.w700, color: const Color(0xFF8A4A5E))),
              Text('🙏 ${room.prayedN}번', style: WrF.body(12.5, w: FontWeight.w700, color: const Color(0xFF8A4A5E))),
              if (room.goal != null)
                Text('목표까지 ${(room.goal! - room.prayedN).clamp(0, 1 << 30)}번',
                    style: WrF.body(12.5, w: FontWeight.w700, color: const Color(0xFF8A4A5E))),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 48,
              child: Semantics(
                identifier: 'morning_card_close',
                button: true,
                child: DecoratedBox(
                  decoration: WrDeco.btnPink,
                  child: Material(color: Colors.transparent,
                    child: InkWell(borderRadius: BorderRadius.circular(16),
                      onTap: onClose,
                      child: const Center(
                        child: Text('오늘의 기도 올리러 가기',
                            style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
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
