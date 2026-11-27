// [v5 S2] 매핑표 00-C "열림 카드" — app3/flows.jsx UNLOCK_TXT + UnlockCard3 1:1 이식.
// room.pendingUnlock(서버가 계산한 "열렸지만 아직 ack 안 한 것 중 순서상 첫 번째")가
// null이 아니고, 내 소원 화면에서 다른 시트·연출이 하나도 없을 때(main_room_screen.dart
// 호출부 조건 참고) 이 카드 1장을 보여준다. [확인/바로 가기]를 누르면
// WishRoomProvider.unlockAck(id, key)를 호출해 서버에 ack를 기록하고(멱등, decor
// 최초 ack면 🧧50 자동 지급) 매핑된 탭으로 이동한다. [나중에]를 눌러도 동일하게
// ack는 기록된다(app3 act(null) 1:1 — "열림" 자체는 이미 확정된 사실이고, "오늘 더는
// 보여주지 않는다"는 사용자 의사만 반영) — 다만 이동은 하지 않는다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../core/theme/wr_theme.dart';

class UnlockCardData {
  final String icon; // assets/wishroom/ 기준 상대경로
  final bool iconIsPhoto; // true면 room-empty.jpg처럼 원형 배경 이미지로 표시
  final String title, desc, cta;
  final int? targetTab; // WishRoomShell._tabs 인덱스(null = 이동 없음, 매핑 화면 미구현)
  const UnlockCardData(this.icon, this.title, this.desc, this.cta, {this.targetTab, this.iconIsPhoto = false});
}

// app3/flows.jsx UNLOCK_TXT 1:1 — go 매핑은 현재 WishRoomShell 탭 배치 기준으로 치환:
// 0=내 소원 · 1=수호자(캐릭터샵, 옷장 탭 포함) · 2=함께 빌기 · 3=상점(임시 DecorScreen,
// Todo #5에서 정식 ShopScreen 교체 전까지는 "꾸미기" 목적지로도 겸용) · 4=보관함.
// theme(방 분위기)은 아직 전용 화면/시트가 없어 targetTab=null(카드만 닫힘) — ⋯ 메뉴
// 구현(Todo #6) 때 함께 연결한다.
const Map<String, UnlockCardData> kUnlockCardData = {
  'guardian': UnlockCardData('chars/F00.png', '수호자가 찾아왔어요',
      '이제 소원방을 함께 지켜줄 친구가 생겼어요. 기도할 때 같이 두 손을 모아요.', '수호자 만나러 가기', targetTab: 1),
  'decor': UnlockCardData('items/pouch.png', '방을 꾸밀 수 있어요',
      '기도할 때마다 복주머니가 담겨요. 시작 선물로 복주머니 50개를 드려요.', '방 꾸미러 가기', targetTab: 3),
  'together': UnlockCardData('items/lotus.png', '함께 빌어줄 수 있어요',
      '지금도 누군가 소원을 빌고 있어요. 마음이 닿는 소원에 두 손을 모아 주세요.', '함께 빌러 가기', targetTab: 2),
  'wardrobe': UnlockCardData('outfits/O_free_01.png', '옷장이 열렸어요',
      '수호자에게 새 옷을 입혀 줄 수 있어요. 기본 옷 4벌은 무료이고, 계절 한복 · 성가대 가운 · 연등회 한복 같은 옷은 복주머니로 마련해요.',
      '옷 갈아입히기', targetTab: 1),
  'theme': UnlockCardData('room-empty.jpg', '원하면 방을 바꿀 수 있어요',
      '지금 방은 누구나 편한 자유 방이에요. 믿는 종교가 있다면 하나님 · 부처님 · 무속인 방으로 바꿀 수 있고, 그대로 두셔도 괜찮아요. 배경화면으로도 쓸 수 있어요.',
      '둘러보기', iconIsPhoto: true),
  'shop': UnlockCardData('items/chest.png', '소원 상점이 열렸어요',
      '2주 동안 정성을 들인 당신께 — 아래 🛍 상점 탭에서 수호자 20명 · 옷 20벌 · 꾸미기 210가지를 만날 수 있어요.',
      '상점 둘러보기', targetTab: 3),
};

class UnlockCard extends StatelessWidget {
  const UnlockCard({super.key, required this.roomId, required this.unlockKey, required this.dayN});
  final String roomId;
  final String unlockKey;
  final int dayN;

  Future<void> _act(BuildContext context, {required bool navigate}) async {
    final p = context.read<WishRoomProvider>();
    final data = kUnlockCardData[unlockKey];
    // app3 act(k)의 `window.WRF.ack(k)` 1:1 — 먼저 ack 기록(멱등, decor 최초 ack면
    // 서버가 🧧50 welcome 보너스를 함께 반영해 room/me를 돌려준다).
    await p.unlockAck(roomId, unlockKey);
    if (navigate && data?.targetTab != null) {
      p.requestTab(data!.targetTab!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = kUnlockCardData[unlockKey];
    if (data == null) return const SizedBox.shrink();
    return Stack(children: [
      Positioned.fill(child: Container(color: const Color(0x80080308))), // .dim
      Positioned(
        left: 26, right: 26, top: 200,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x61FFDC96)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF7461E38), Color(0xFA1A0812)]),
            boxShadow: [BoxShadow(color: const Color(0x38FFBE78), blurRadius: 60), const BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 24))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('DAY $dayN · NEW', style: WrF.mono(size: 10, color: const Color(0xFFFFE0A0)).copyWith(letterSpacing: 2)),
            const SizedBox(height: 10),
            SizedBox(
              width: 120, height: 120,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 152, height: 152,
                  decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0x80FFD282), Colors.transparent], stops: [0, .65])),
                ),
                data.iconIsPhoto
                    ? Container(width: 120, height: 120,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x99FFDC96), width: 3),
                          image: DecorationImage(image: AssetImage('assets/wishroom/${data.icon}'), fit: BoxFit.cover)))
                    : Image.asset('assets/wishroom/${data.icon}', width: 120, height: 120, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 120, height: 120)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(data.title, textAlign: TextAlign.center, style: WrF.display(21)),
            const SizedBox(height: 8),
            Text(data.desc, textAlign: TextAlign.center, style: WrF.body(13.5, color: WrC.muted, height: 1.65)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: WrDeco.btnGold,
                child: Material(color: Colors.transparent,
                  child: InkWell(borderRadius: BorderRadius.circular(16),
                    onTap: () => _act(context, navigate: true),
                    child: Center(child: Text(data.cta,
                      style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF4A2A10)))))),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _act(context, navigate: false),
              child: Text('나중에', style: WrF.body(12.5, color: WrC.muted)),
            ),
          ]),
        ),
      ),
    ]);
  }
}
