// SCR-09 보관함 `/vault` (탭5) — docs/SCREENS.md §SCR-09 · app2/screens-c2.jsx › Vault()/Archive()/
// ArchivePlayer()/RewardTab() 1:1 이식.
// [4-A — 대표 판정, CHECKLIST.md 참고] 탭 3개(소원 기록관·복주머니·응원 보상) →
// 2개(소원 기록관·응원 보상)로 축소. "복주머니"(적립/사용 내역)는 🧧 지갑 시트
// (wallet_sheet.dart)로 옮겼고, 우상단 "캐릭터" 칩은 제거했다(수호자 진입은 지갑
// 시트 "소원방에서 쓰는 곳" 카드로 들어감). 소원 기록관은 기존 진행중/완료 필터
// 칩 토글 대신 "지금 밝히는 소원" 카드를 항상 보여준다. 기록 카드(_ArchiveCard)와
// 재생 오버레이(_ReplayOverlay)는 room.outcome에 따라 成/放 도장을 구분 표시한다
// (4-B — CHECKLIST.md 대표님 판정).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';
import '../compose/compose_screen.dart';
import '../complete/complete_screen.dart';
import '../guide/guide_sheet.dart';
import '../../core/wr_nav_pill.dart';
import '../../core/wr_toast.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final p = context.read<WishRoomProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // [버그수정 — 사용자 리포트: "복주머니는 아예 안보이고"] 이 화면은
      // WishRoomShell의 IndexedStack 자식이라 Shell이 빌드되는 즉시(= 탭을
      // 누르기 전부터) build()가 실행되고, 그 안의 _PouchTab이 곧바로
      // `WrCatalog.I`(정적 카탈로그, EARN 목록 등)를 동기 참조한다. 정상
      // 플로우에서는 인트로 화면(_boot())이 WishRoomShell을 push하기 전에
      // WrCatalog.load()를 await하므로 안전하지만, 혹시라도 그 가드를
      // 거치지 않고 이 화면에 먼저 도달하는 경로가 생기면
      // `LateInitializationError`로 빌드 자체가 실패해 해당 탭이 완전히
      // 빈 화면(검은 화면)으로 보인다. 방어적으로 한 번 더 보장한다 —
      // 이미 로드됐으면 즉시 반환(멱등)이라 비용이 없다.
      if (!WrCatalog.isLoaded) await WrCatalog.load();
      if (!mounted) return;
      p.loadArchive();
      p.loadLedger();
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // [4-A] wallet_sheet.dart의 "전체 내역 보기"(구 복주머니 탭 이동) 호출은 이제
    // 지갑 시트 내 인라인 내역 리스트로 대체되어 더 이상 이 플래그를 세우지 않는다.
    // 메커니즘 자체(tourRequested와 동일한 "Provider 플래그 → 화면이 대신 전환"
    // 패턴)는 향후 보관함 내부 탭 전환이 다시 필요할 경우를 위해 남겨둔다.
    final subTab = context.select<WishRoomProvider, int?>((p) => p.requestedVaultSubTab);
    if (subTab != null && subTab != _tabs.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabs.animateTo(subTab);
        context.read<WishRoomProvider>().consumeVaultSubTabRequest();
      });
    }
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: SafeArea(bottom: false, child: Column(children: [
        // app2/fx2.jsx › TopBar() 제목은 left:104,right:104(화면폭 기준 중앙정렬) 고정값.
        // [버그수정 — 전수감사] 기존엔 NavPill 바로 옆에 좌측정렬되어 화면 중심에서
        // 벗어나 있었다. Stack+Positioned로 app2/fx2.jsx TopBar() 1:1 재구성.
        SizedBox(height: 44, child: Stack(children: [
          const Positioned(top: 0, bottom: 0, left: 104, right: 104, child: Center(child: Text('보관함',
            style: TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis))),
          Positioned(left: 16, top: 0, bottom: 0, child: Center(child:
            WrNavPill(onBack: () => wrBackOrAskExit(context), onExitHome: () => wrExitHome(context)))),
          Positioned(right: 16, top: 0, bottom: 0, child: Center(child: Row(children: [
            // [4-A — 대표 판정] 우상단 "캐릭터" 칩 제거. 수호자 진입은 🧧 지갑
            // 시트(wallet_sheet.dart) "소원방에서 쓰는 곳" 카드로 통합됐다.
            // app2/screens-c2.jsx › TopBar right › app.openGuide('archive') 1:1.
            // GuideBook의 "한 바퀴 둘러보기"는 app.room && 조건만 보므로 보관함에서도 항상
            // 노출되고, 누르면 app.go('home') 후 startTour() — requestTour()로 셸이 대신한다.
            GestureDetector(
              onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
                builder: (_) => GuideBook(focus: 'archive', onStartTour: context.read<WishRoomProvider>().requestTour)),
              child: Container(
                width: 32, height: 32, alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0x991E0C18), shape: BoxShape.circle, border: Border.all(color: WrC.line)),
                child: const Text('?', style: TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
              ),
            ),
          ]))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0), child: Container(
          height: 40, padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: WrC.tabsBg, borderRadius: BorderRadius.circular(WrR.tabs)),
          child: TabBar(
            controller: _tabs, dividerColor: Colors.transparent, indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(borderRadius: BorderRadius.circular(WrR.tab), gradient: const LinearGradient(colors: [WrC.blossom2, WrC.blossom])),
            labelColor: Colors.white, unselectedLabelColor: WrC.muted,
            labelStyle: WrF.body(13, w: FontWeight.w700), unselectedLabelStyle: WrF.body(13, w: FontWeight.w600),
            tabs: [
              Tab(child: Semantics(identifier: 'vault_tab_archive', button: true, child: const Text('소원 기록관'))),
              Tab(child: Semantics(identifier: 'vault_tab_rewards', button: true, child: const Text('응원 보상'))),
            ],
          ),
        )),
        Expanded(child: TabBarView(controller: _tabs, children: const [
          _ArchiveTab(), _RewardTab(),
        ])),
      ])),
    ));
  }
}

// ═══════════════════ 소원 기록관 — Archive() 1:1 ═══════════════════

class _ArchiveTab extends StatefulWidget {
  const _ArchiveTab();
  @override
  State<_ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<_ArchiveTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final rooms = p.archiveRooms;
      final cur = p.room; // 현재 소원방(진행 중)은 provider.room, 보관함 리스트는 완성/봉인분
      final done = rooms.where((r) => r.status == RoomStatus.SEALED || r.status == RoomStatus.ARCHIVED).toList();
      return RefreshIndicator(onRefresh: () => p.loadArchive(), child: CustomScrollView(slivers: [
        // [4-A — 대표 판정] 진행중/완료 필터 칩 토글 대신 "지금 밝히는 소원" 카드를
        // 항상 맨 위에 보여준다(app3/flows.jsx Vault3 1:1 — 단, 14일 칸·목표 남은
        // 횟수는 서버 데이터가 아직 없어 이번 커밋에서는 제외, CHECKLIST.md 참고).
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: cur != null ? _CurrentWishCard(room: cur) : GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComposeScreen())),
            child: const DottedBox(),
          ),
        )),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 10), child: Row(children: [
          Text('소원 기록관', style: WrF.display(16)),
          const SizedBox(width: 6),
          Text('${done.length}', style: WrF.body(12, color: WrC.muted)),
        ]))),
        if (done.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: WrC.line, width: 1.4, style: BorderStyle.solid)),
            alignment: Alignment.center,
            child: Text('이루어진 소원은 이곳에 영원히 머물러요', textAlign: TextAlign.center, style: WrF.body(12.5, color: WrC.muted, height: 1.7)),
          )))
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .74),
            delegate: SliverChildBuilderDelegate((_, i) {
              final room = done[i];
              return Semantics(identifier: 'archive_card_${room.id}', button: true,
                child: _ArchiveCard(room: room, items: p.items, onTap: () => _openReplay(context, room, p.items)));
            }, childCount: done.length),
          )),
      ]));
    });
  }

  void _openReplay(BuildContext context, WishRoom room, List<WrItem> items) {
    showDialog(context: context, barrierColor: const Color(0xE6000000), builder: (_) => _ReplayOverlay(room: room, items: items));
  }
}

/// "지금 밝히는 소원" 카드 — app3/flows.jsx Vault3 1:1(願 인장 + 소원 문구 +
/// 🕯dayN·🙏prayedN·✦단계 통계줄 + 완료 버튼). [4-A 스코프 제외 — CHECKLIST.md 기록]
/// 원본의 "최근 14일" 점등 칸과 "N일 기도 목표 · N번 남음" 문구는 뒷받침하는 서버
/// 데이터(일자별 기도 로그 · 목표 설정)가 아직 없어 이번 커밋에서는 넣지 않는다.
class _CurrentWishCard extends StatelessWidget {
  const _CurrentWishCard({required this.room});
  final WishRoom room;
  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final stageName = room.stage >= 0 && room.stage < cat.levels.length
        ? cat.levels[room.stage]['name'] as String
        : '정성 전';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: WrDeco.hanji,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WrSealGlyph(glyph: '願'),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('지금 밝히는 소원', style: TextStyle(fontFamily: 'Pretendard', fontSize: 12, color: WrC.hanjiInk.withValues(alpha: .6))),
            const SizedBox(height: 2),
            Text(room.text, style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 17, color: WrC.hanjiInk, height: 1.45)),
          ])),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 4, children: [
          Text('🕯 ${room.dayN}일째', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF8A4A3A))),
          Text('🙏 ${room.prayedN}번', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF8A4A3A))),
          Text('✦ $stageName', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF8A4A3A))),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: Semantics(identifier: 'vault_fulfill', button: true, child: ElevatedButton(
          onPressed: () => _confirmFulfill(context),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.glow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('✿ 소원이 이루어졌어요', style: TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)),
        ))),
      ]),
    );
  }

  // main_room_screen.dart `_CareSheet` 완료 버튼 1:1(2단계 확인: 아직이에요 /
  // 네, 이루어졌어요) — 보관함 카드에서도 같은 확인 절차를 거쳐 실수 완료를 막는다.
  void _confirmFulfill(BuildContext context) {
    showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: WrC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('정말 이루어졌나요', style: WrF.body(15, w: FontWeight.w700, color: Colors.white)),
      content: Text('완료 후 7일 동안은 되돌릴 수 있어요.', style: WrF.body(12.5, color: WrC.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: Text('아직이에요', style: WrF.body(13, color: WrC.fg))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
          onPressed: () {
            Navigator.of(dialogCtx).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompleteScreen(roomId: room.id)));
          },
          child: const Text('네, 이루어졌어요', style: TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    ));
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.room, required this.items, required this.onTap});
  final WishRoom room; final List<WrItem> items; final VoidCallback onTap;
  String _d(DateTime? t) => t == null ? '' : '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    // [4-B 신규] 放(RELEASED) 완료 기록은 도장을 成과 다른 색/글자로 표시.
    final isRelease = room.outcome == Outcome.RELEASED;
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(color: WrC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x66F5CF6A))),
      padding: const EdgeInsets.all(10),
      // [반응형 화면 규격 통일 — 잘림 현상 수정 · 실버그 발견] childAspectRatio:.74
      // 그리드 셀 안, 썸네일(Expanded) 아래 "완성"+소원 텍스트+날짜 3줄 블록이
      // 항상 고정 자연 높이를 요구해 320x568@2.5에서 46px `RenderFlex
      // overflowed`가 났다(실측). 이 블록을 Flexible+FittedBox(scaleDown)로
      // 감싸 공간이 부족할 때만 비율대로 작아지게 했다 — 평소엔 기존 모습
      // 그대로. 디자인·문구·색상 변경 없음.
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // G-4 RoomThumb 공용 썸네일 — [버그수정 — 전수감사] 기존 더미 아이콘 교체.
        // [버그수정 — 전수감사] app2/screens-c2.jsx › Archive(): `<RoomThumb room={{...r,
        // ...s, brightness:1}}...>` — 완성된 소원은 미접속 감쇠(brightness)를 무시하고
        // 항상 최대 밝기로 보여준다. brightnessOverride 누락.
        Expanded(child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10),
            child: LayoutBuilder(builder: (context, c) =>
              RoomThumb(room: room, items: items, w: c.maxWidth, h: c.maxHeight, focus: .22, zoom: 1.5, brightnessOverride: 1)))),
          Positioned(right: 4, top: 4, child: Transform.rotate(angle: -6 * 3.14159 / 180, child: Container(
            width: 28, height: 28, alignment: Alignment.center,
            decoration: BoxDecoration(color: isRelease ? const Color(0xFF7A6A9A) : WrC.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: isRelease ? const Color(0xFF7A6A9A).withValues(alpha: .5) : const Color(0x80C94A3B), blurRadius: 8)]),
            child: Text(isRelease ? '放' : '成', style: const TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFFF9E8)))))),
        ])),
        const SizedBox(height: 6),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('완성', style: WrF.body(12.5, w: FontWeight.w700, color: WrC.glow)),
          const SizedBox(height: 2),
          Text(room.text, style: WrF.body(11.5, color: WrC.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${_d(room.completedAt)} · ${room.daysLit}일', style: WrF.body(10.5, color: WrC.muted)),
        ]))),
      ]),
    ));
  }
}

class DottedBox extends StatelessWidget {
  const DottedBox({super.key});
  @override
  // [반응형 화면 규격 통일 — 잘림 현상 수정 · 실버그 발견] childAspectRatio:.74
  // 그리드 셀 안에서 이 Column(mainAxisSize:min)도 셀이 좁아지면 자연 높이가
  // 가용 높이를 넘어 320x568@2.5에서 3.3px `RenderFlex overflowed`가 났다
  // (실측). FittedBox(scaleDown)로 전체를 감싸 공간이 부족할 때만 비율대로
  // 작아지게 했다 — 평소엔 기존 모습 그대로. 디자인·문구·색상 변경 없음.
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: WrC.line, width: 1.4)),
        alignment: Alignment.center,
        child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x33F2628F), border: Border.all(color: WrC.blossom2)),
            child: const Text('+', style: TextStyle(fontSize: 20, color: WrC.blossom2))),
          const SizedBox(height: 8),
          Text('새로운 소원방\n만들기', textAlign: TextAlign.center, style: WrF.body(12.5, color: WrC.fg, w: FontWeight.w700)),
        ])),
      );
}

/// "당시 모습 재생" — 원본 ArchivePlayer() 1:1. 전체화면 흑배경 + Room(gold:.25) + 꽃잎비 + 한지카드(成 인장 + 생성→완료 기간 + 스탯).
class _ReplayOverlay extends StatelessWidget {
  const _ReplayOverlay({required this.room, required this.items});
  final WishRoom room; final List<WrItem> items;
  String _d(DateTime? t) => t == null ? '' : '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    // [4-B 신규] 放(RELEASED) 완료 기록은 도장을 成과 다른 색/글자로 표시.
    final isRelease = room.outcome == Outcome.RELEASED;
    return Dialog(backgroundColor: Colors.black, insetPadding: EdgeInsets.zero, child: Stack(children: [
      // [버그수정 — 전수감사] app2/screens-c2.jsx › ArchivePlayer(): `<Room room={{...r,
      // ...s, brightness:1}} gold={.25} entering/>` — frozen 지정이 없다(= 평소처럼
      // drift/pulse/파티클이 계속 흐르는 채로 재생, 추가로 카메라인 2.2s 입장 연출)
      // + brightness:1 강제(미접속 감쇠 무시, 항상 최대 밝기). frozen:true로 모든
      // 애니메이션을 멈춰버리고 entering·brightnessOverride도 빠져 있던 버그 —
      // "그날의 모습 그대로"를 재생하는 연출 의도(살아있는 방)와 반대로 정지된
      // 흐릿한 스냅샷처럼 보였다.
      Positioned.fill(child: WrCanvasScaler(child: RoomScene(room: room, items: items, gold: .25, entering: true, brightnessOverride: 1))),
      const WrPetalRain(n: 16, dur: (6, 9), spread: 6),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: Row(children: [
        GestureDetector(onTap: () => Navigator.of(context).pop(), child: Container(
          width: 32, height: 32, alignment: Alignment.center,
          decoration: BoxDecoration(color: WrC.glass, shape: BoxShape.circle, border: Border.all(color: WrC.line)),
          child: const Icon(Icons.close, size: 15, color: Colors.white))),
        const Spacer(),
      ]))),
      const Positioned(left: 0, right: 0, top: 58, child: Center(child: Column(children: [
        Text('이루어진 소원방', style: TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        SizedBox(height: 1),
        Text('그날의 모습 그대로', style: TextStyle(fontFamily: 'Pretendard', fontSize: 11, color: Color(0xA8FFECDC))),
      ]))),
      Positioned(left: 16, right: 16, bottom: 44, child: Container(
        padding: const EdgeInsets.all(16), decoration: WrDeco.hanji,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 28, height: 28, alignment: Alignment.center,
              decoration: BoxDecoration(color: isRelease ? const Color(0xFF7A6A9A) : WrC.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: isRelease ? const Color(0xFF7A6A9A).withValues(alpha: .5) : const Color(0x80C94A3B), blurRadius: 8)]),
              child: Text(isRelease ? '放' : '成', style: const TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFFF9E8)))),
            const SizedBox(width: 10),
            // [반응형 화면 규격 통일 — 잘림 현상 수정] 좁은 화면(320px대)+글자
            // 확대(1.3배) 조합에서 이 날짜 문구가 Row 폭을 넘어 가로로
            // 14px 오버플로되던 버그 수정. Expanded로 감싸 넘치면 줄바꿈되게
            // 한다(디자인·문구·색상 변경 없음, 레이아웃 제약만 추가).
            Expanded(child: Text('${_d(room.createdAt)} → ${_d(room.completedAt)} · ${room.daysLit}일', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xA65A321E)))),
          ]),
          const SizedBox(height: 10),
          Text(room.text, style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: WrC.hanjiInk, height: 1.5)),
          const SizedBox(height: 10),
          // [반응형 화면 규격 통일 — 잘림 현상 수정] 레벨/정성/응원/福 4개
          // 고정폭 항목이 Flexible·스크롤 보호 없는 Row에 그대로 들어있어,
          // 320x568@2.5 배율에서 오른쪽으로 37px 오버플로되는 것을 실측
          // 확인했다. 디자인·문구·간격은 그대로 두고 Row를 Wrap으로
          // 교체해, 넘칠 때만 다음 줄로 자연스럽게 내려가게 한다(내용이
          // 좁은 화면에서도 전부 보이고, 평소(1.0~1.5배)에는 기존과
          // 동일하게 한 줄로 표시됨).
          Wrap(spacing: 14, runSpacing: 4, children: [
            Text('Lv.${room.level}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
            Text('🙏 ${room.devotionCount}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
            Text('❤ ${room.supportCount}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
            Text('福 ${room.pouchReceived}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
          ]),
        ]),
      )),
    ]));
  }
}

// ═══════════════════ 응원 보상 — RewardTab() 1:1 ═══════════════════

class _RewardTab extends StatefulWidget {
  const _RewardTab();
  @override
  State<_RewardTab> createState() => _RewardTabState();
}

class _RewardTabState extends State<_RewardTab> {
  bool _busy = false;
  Map<String, dynamic>? _open; // 받기 연출 상태 { at, reward, item, bonus }
  int _openKey = 0;

  Future<void> _claim(WishRoomProvider p, String id, Map<String, dynamic> r) async {
    final at = r['at'] as int;
    setState(() => _busy = true);
    final res = await p.claimSupportReward(id, at);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res != null) {
      setState(() { _openKey++; _open = {'at': at, 'reward': r['reward'], 'item': res['item'], 'bonus': res['bonus']}; });
    } else if (p.lastError != null) {
      WrToast.show(context, p.lastError!.message);
    }
  }

  String _rewardGlyph(String icon) => switch (icon) {
        'petal' => '🌸', 'spark' => '✨', 'gift' => '🎁', 'chest' => '🧧', 'star' => '⭐', _ => '✦',
      };

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final room = p.room;
      if (room == null) return Center(child: Text('소원방을 만들면 응원 보상이 열려요', style: WrF.body(14, color: WrC.muted)));
      final rewards = cat.supportRewards;
      final serverStates = {for (final r in room.rewards ?? const <SupportRewardState>[]) r.at: r};
      final n = room.supportCount;
      Map<String, dynamic>? next;
      for (final r in rewards) { final at = r['at'] as int; final st = serverStates[at]; final reached = st?.reached ?? n >= at; if (!reached) { next = r; break; } }
      final prevAt = next == null ? 0 : (rewards.indexOf(next) > 0 ? rewards[rewards.indexOf(next) - 1]['at'] as int : 0);
      final pct = next == null ? 1.0 : ((n - prevAt) / ((next['at'] as int) - prevAt)).clamp(0, 1).toDouble();
      final ready = rewards.where((r) { final at = r['at'] as int; final st = serverStates[at]; final reached = st?.reached ?? n >= at; final claimed = st?.claimed ?? false; return reached && !claimed; }).length;

      return Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              gradient: const RadialGradient(center: Alignment(0, -1), radius: 1.6, colors: [Color(0x4CF2628F), Color(0x14220E1C)])),
            child: Column(children: [
              Text('응원을 많이 받을수록\n특별한 보상이 열려요', textAlign: TextAlign.center, style: WrF.display(17)),
              const SizedBox(height: 6),
              RichText(textAlign: TextAlign.center, text: TextSpan(style: WrF.body(13, color: WrC.muted), children: [
                const TextSpan(text: '지금까지 받은 응원 '),
                TextSpan(text: '❤ $n', style: const TextStyle(color: Color(0xFFFF8FB1), fontSize: 15, fontWeight: FontWeight.w700)),
              ])),
              if (next != null) Padding(padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // [반응형 화면 규격 통일] 우측 "N회 남음" 텍스트가 Flexible 없이
                // 고정폭으로 들어있어, textScale 2.0에서 폭이 커지면 왼쪽 Expanded가
                // 0까지 줄어도 Row 전체가 가로로 넘쳤다(실측 320x568@2.0, 62px 초과 —
                // 응원 보상 탭 최상단에서 발생해 그 아래 _ClaimOverlay 접근 자체를 막음).
                // 우측 텍스트도 Flexible로 감싸 필요시 줄어들게 한다.
                Row(children: [
                  Expanded(child: Text.rich(TextSpan(style: WrF.body(11.5, color: WrC.muted), children: [
                    const TextSpan(text: '다음 보상 · '),
                    TextSpan(text: '${next['reward']}', style: const TextStyle(color: WrC.fg)),
                  ]))),
                  Flexible(child: Text('${(next['at'] as int) - n}회 남음', textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: WrF.body(11.5, color: WrC.muted))),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
                  value: pct, minHeight: 8, backgroundColor: const Color(0x1AFFFFFF),
                  valueColor: const AlwaysStoppedAnimation(WrC.blossom))),
              ])) else Padding(padding: const EdgeInsets.only(top: 10), child: Text('✦ 모든 응원 보상을 열었어요', style: WrF.body(12.5, color: const Color(0xFFFFE08A)))),
              if (ready > 0) Padding(padding: const EdgeInsets.only(top: 10), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0x2EF5CF6A), border: Border.all(color: const Color(0x80F5CF6A))),
                child: Text('🎁 받을 수 있는 보상 $ready개', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFFFE08A))))),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 0), child: Text.rich(TextSpan(style: WrF.body(11.5, color: WrC.muted, height: 1.6), children: [
            const TextSpan(text: '받은 보상은 보관함에 담기고, '),
            const TextSpan(text: '꾸미기', style: TextStyle(color: WrC.fg)),
            const TextSpan(text: '에서 바로 방에 둘 수 있어요. 응원 보상 아이템은 상점에서 살 수 없어요.'),
          ]))),
          const SizedBox(height: 12),
          ...rewards.asMap().entries.map((entry) {
            final r = entry.value; final at = r['at'] as int;
            final st = serverStates[at];
            final reached = st?.reached ?? n >= at;
            final claimed = st?.claimed ?? false;
            final statusReady = reached && !claimed;
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: statusReady ? const Color(0x29F5CF6A) : WrC.card,
                border: Border.all(color: statusReady ? const Color(0xB3F5CF6A) : (claimed ? const Color(0x4DF5CF6A) : WrC.cardBorder), width: statusReady ? 1.4 : 1),
              ),
              child: Row(children: [
                Container(width: 54, height: 54, alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x4DFFA0BE), Colors.transparent])),
                  child: Stack(alignment: Alignment.center, children: [
                    Opacity(opacity: reached ? 1 : .35, child: Text(_rewardGlyph(r['icon'] as String), style: const TextStyle(fontSize: 26))),
                    if (!reached) const Positioned(right: -2, bottom: -2, child: Text('🔒', style: TextStyle(fontSize: 12))),
                  ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(claimed ? _ownedLabel(r) : '$at회 · ${r['reward']}', style: WrF.body(13.5, w: FontWeight.w700, color: WrC.fg)),
                  const SizedBox(height: 2),
                  Text('응원 $at회 · ${r['desc']}', style: WrF.body(11, color: WrC.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                // [반응형 화면 규격 통일] 기존엔 이 액션 영역(버튼/칩)이 Flexible 없이
                // Row에 바로 들어있어, textScale이 커지면("✓ 받음 · 꾸미기 ›" 칩이
                // 특히 긴 문자열이라 textScale 2.0에서 62px 초과) 왼쪽 Expanded 텍스트
                // 컬럼이 0까지 줄어들어도 Row 전체가 가로로 넘쳐흘렀다(실측 320x568@2.0
                // "RenderFlex overflowed by 62 pixels"). Flexible로 감싸 필요시 칩/버튼
                // 자체도 줄어들 수 있게 하여(平소 1-2줄 내용일 땐 그대로 보이고, 공간이
                // 부족할 때만 줄바꿈되거나 폭이 줄어듦) 항상 Row 폭 안에 들어오게 한다.
                if (statusReady)
                  Flexible(child: GestureDetector(onTap: _busy ? null : () => _claim(p, room.id, r), child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(colors: [Color(0xFFFFE7A0), WrC.glow, Color(0xFFD9A53A)])),
                    child: const Text('🎁 받기', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF4A2A10))))))
                // app2/screens-c2.jsx › RewardTab() st==='claimed' 칩 onClick={() => app.go('decor')} 1:1.
                // [버그수정 — 전수감사] 기존엔 탭 핸들러 없는 정적 Container + "✓ 받음"만
                // 표시했다(원본은 "✓ 받음 · 꾸미기 ›" + 꾸미기 탭(탭3)으로 이동).
                else if (claimed)
                  Flexible(child: GestureDetector(onTap: () => context.read<WishRoomProvider>().requestTab(3), child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: WrC.glow, borderRadius: BorderRadius.circular(999)),
                    child: const Text('✓ 받음 · 꾸미기 ›', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF4A2A10), fontSize: 11, fontWeight: FontWeight.w700)))))
                else
                  Flexible(child: Text('${at - n}회 남음', textAlign: TextAlign.right, style: WrF.body(11, color: WrC.muted))),
              ]),
            ));
          }),
        ]),
        if (_open != null) _ClaimOverlay(key: ValueKey(_openKey), data: _open!, room: room, onClose: () => setState(() => _open = null)),
      ]);
    });
  }

  String _ownedLabel(Map<String, dynamic> r) => r['reward'] as String;
}

/// 받기 연출 — 상자가 열리고 아이템이 떠오름. 원본 RewardTab() 214-232줄.
class _ClaimOverlay extends StatefulWidget {
  const _ClaimOverlay({super.key, required this.data, required this.room, required this.onClose});
  final Map<String, dynamic> data; final WishRoom room; final VoidCallback onClose;
  @override
  State<_ClaimOverlay> createState() => _ClaimOverlayState();
}

class _ClaimOverlayState extends State<_ClaimOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final at = widget.data['at'] as int;
    final item = widget.data['item'] as Map<String, dynamic>?;
    final bonus = widget.data['bonus'] as int?;
    final itemName = item?['name'] as String?;
    final itemImg = item?['img'] as String?;
    // [반응형 화면 규격 통일] 기존엔 top:150 고정 + 아래쪽(bottom) 제한이 전혀 없는
    // Positioned라, 받은 아이템 이름이 길거나(예: 한정판 장식 이름 2줄) textScale이
    // 커지면 카드 내용 전체 높이가 늘어나 화면 바닥 밖으로 밀려났다(실측:
    // 360x640@1.3 "닫기" 버튼 23px 잘림, 320x568@1.5 168px 잘림, 320x568@2.0
    // 완전 붕괴/오버플로). 이 오버레이는 _RewardTab의 Stack(=TabBarView 영역,
    // 즉 상단바+탭바 높이만큼 화면 전체보다 작음) 기준 Positioned.fill이라
    // MediaQuery의 화면 전체 높이가 아니라 LayoutBuilder로 실제 부모 Stack의
    // 가용 높이를 받아야 한다. top 앵커(150)와 좌우 여백(24)은 그대로 두고,
    // 카드 전체를 "남은 가용 높이"로 maxHeight 제한한 뒤 SingleChildScrollView로
    // 감싸 — 평소(짧은 내용)엔 그대로 내용 크기만큼만 차지하고(시각적 변화 없음),
    // 넘칠 때만 카드 내부가 스크롤되어 버튼이 항상 눌리도록 한다.
    return Positioned.fill(child: LayoutBuilder(builder: (context, constraints) {
      final maxCardHeight = (constraints.maxHeight - 150 - 24).clamp(0.0, double.infinity);
      return Stack(children: [
      GestureDetector(onTap: widget.onClose, child: Container(color: const Color(0xB3000000))),
      Positioned(left: 24, right: 24, top: 150, child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxCardHeight),
        child: SingleChildScrollView(child: Container(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF7461E38), Color(0xFA1A0812)]),
          border: Border.all(color: const Color(0x73FFDC96)),
          boxShadow: const [BoxShadow(color: Color(0x4DFFC878), blurRadius: 60), BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 24))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('SUPPORT × $at', style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 10, letterSpacing: 3, color: const Color(0xFFFFE08A))),
          SizedBox(height: 150, child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
            AnimatedBuilder(animation: _c, builder: (_, __) {
              final t = Curves.easeOut.transform(_c.value);
              return Positioned(top: 60, child: Opacity(opacity: (t * 3).clamp(0.0, 1.0), child: Transform.scale(scale: .7 + .3 * t,
                child: Image.asset('assets/wishroom/items/chest.png', width: 90, errorBuilder: (_, __, ___) => const Text('🧰', style: TextStyle(fontSize: 60))))));
            }),
            AnimatedBuilder(animation: _c, builder: (_, __) {
              final raw = ((_c.value - .55) / .45).clamp(0.0, 1.0);
              final t = Curves.easeOutCubic.transform(raw);
              return Positioned(top: 20 - 20 * t, child: Opacity(opacity: raw, child:
                itemImg != null
                  ? Image.asset('assets/wishroom/items/$itemImg.png', width: 96, errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 70)))
                  : Image.asset('assets/wishroom/items/pouch.png', width: 90, errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 60)))));
            }),
            if (_c.value > .5) WrBurst(x: 0, y: 70, n: 26, spread: 150, color: const Color(0xFFFFE0A0)),
          ])),
          Text(itemName ?? '복주머니 +${bonus ?? 0}', style: WrF.display(21)),
          const SizedBox(height: 8),
          Text(itemName != null
                ? '응원해주신 마음이 모여 선물이 되었어요.\n보관함에 담아두었어요.'
                : '모든 장식을 이미 가지고 있어 복주머니로 드려요.',
              textAlign: TextAlign.center, style: WrF.body(13, color: WrC.muted, height: 1.6)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: GestureDetector(onTap: widget.onClose, child: Container(
              height: 46, alignment: Alignment.center, decoration: WrDeco.btnDark,
              child: const Text('닫기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
            if (item != null) ...[
              const SizedBox(width: 8),
              // app2/screens-c2.jsx › RewardTab() 받기 연출 "방에 두기" onClick
              // { setOpen(null); app.go('decor') } 1:1. [버그수정 — 전수감사]
              // 기존엔 장착만 하고 꾸미기 탭으로 이동하지 않았다.
              Expanded(flex: 2, child: GestureDetector(onTap: () async {
                final p = context.read<WishRoomProvider>();
                final id = item['id'] as String?;
                if (id != null) await p.equip(widget.room.id, id);
                widget.onClose();
                p.requestTab(3);
              }, child: Container(
                height: 46, alignment: Alignment.center, decoration: WrDeco.btnPink,
                child: const Text('방에 두기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
            ],
          ]),
        ]),
      )))),
      ]);
    }));
  }
}
