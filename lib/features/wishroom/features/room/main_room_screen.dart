// SCR-03 소원방 메인 `/room` (탭1, 핵심 화면) — docs/SCREENS.md §SCR-03, CHANGELOG v2.3
// 방 장면(RoomScene) + TopBar + 레벨바 + 말풍선
// + 하단 슬림 도크(58px, 소원 한 줄 + 소원 빛깔/종이 반영) + 둥근 정성 버튼(66px, 링게이지)
// + 도크 탭 → 소원 전문 펼침 시트. §6.1(devote)/§6.2(rekindle) 연출은
// DevotionController/RekindleTimeline을 사용한다.
// app2/screens-a2.jsx › MainRoom() 1:1 이식.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/wr_canvas.dart';
import 'room_scene.dart';
import 'devotion_controller.dart';
import '../complete/complete_screen.dart';

class MainRoomScreen extends StatefulWidget {
  const MainRoomScreen({super.key});
  @override
  State<MainRoomScreen> createState() => _MainRoomScreenState();
}

class _MainRoomScreenState extends State<MainRoomScreen> {
  late DevotionController _devotion;
  Timer? _cooldownTicker;
  int _cooldownRemain = 0;
  int _cooldownTotal = 30;
  bool _rekindling = false;
  double _rekindleBrightness = 1;
  double _rekindleBoost = 0;
  int _speechIdx = 0;
  Timer? _speechTimer;
  bool _peek = false; // '◉ 방만 보기'
  bool _wishOpen = false; // 소원 전문 펼침
  bool _armed = false; // 쿨타임 완료 후 탭 대기(버튼 맥동)
  int _prevCooldown = 0;

  @override
  void initState() {
    super.initState();
    final p = context.read<WishRoomProvider>();
    _devotion = DevotionController(p.repo);
    if (p.room == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadMyRoom());
    }
    if (p.catalogLoaded == false) p.loadCatalog();
    _startCooldownTicker();
    _speechTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _speechIdx++);
    });
  }

  @override
  void dispose() {
    _devotion.dispose();
    _cooldownTicker?.cancel();
    _speechTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTicker() {
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final room = context.read<WishRoomProvider>().room;
      if (room?.cooldownUntil == null) {
        if (_cooldownRemain != 0 && mounted) setState(() => _cooldownRemain = 0);
        return;
      }
      _cooldownTotal = room!.cooldownSec > 0 ? room.cooldownSec : 30;
      final remain = room.cooldownUntil!.difference(DateTime.now()).inSeconds;
      final next = remain > 0 ? remain : 0;
      // 쿨타임이 막 끝난 순간(0 도달) → '가득 찼어요' 강한 피드백 1.6s
      if (_prevCooldown > 0 && next == 0 && room.devotionsRemaining > 0) {
        if (mounted) setState(() { _armed = true; });
        Timer(const Duration(milliseconds: 1600), () { if (mounted) setState(() => _armed = false); });
      }
      _prevCooldown = next;
      if (mounted) setState(() => _cooldownRemain = next);
    });
  }

  Future<void> _onDevote() async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null || _devotion.busy) return;
    setState(() => _armed = false);
    await _devotion.devote(room.id,
      onDust: () {}, onPetal: () {},
      onDone: (res) {
        p.applyDevotionResult(res);
        if (res.leveledUp) {
          _showLevelUp(res.room.level);
        }
      },
      onError: (e) {
        if (e.code == 'COOLDOWN' && e.retryAfter != null) {
          setState(() => _cooldownRemain = e.retryAfter!);
        } else if (e.code == 'DAILY_LIMIT') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오늘의 정성을 모두 담았어요')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    );
  }

  Future<void> _onRekindle() async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null || _rekindling) return;
    setState(() { _rekindling = true; _rekindleBrightness = .06; _rekindleBoost = 0; });
    Timer(RekindleTimeline.spark, () { if (mounted) setState(() => _rekindleBrightness = .14); });
    Timer(RekindleTimeline.grow, () { if (mounted) setState(() { _rekindleBrightness = .7; _rekindleBoost = 1; }); });
    Timer(RekindleTimeline.bloom, () { if (mounted) setState(() { _rekindleBrightness = 1; _rekindleBoost = 2; }); });
    final ok = await p.rekindle(room.id);
    Timer(RekindleTimeline.end, () {
      if (!mounted) return;
      setState(() { _rekindling = false; _rekindleBoost = 0; });
      if (ok) {
        showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => _RewardSheet(
          title: '촛불이 다시 환해졌어요',
          sub: '소원방이 당신을 기다렸어요',
        ));
      }
    });
  }

  void _showLevelUp(int lv) {
    final unlock = RoomLayoutUnlocks.of(lv);
    showDialog(context: context, barrierColor: const Color(0xCC000000), builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: const Color(0xFF1A0D2E), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33F5CF6A))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('LEVEL UP', style: TextStyle(color: Color(0xFFF5CF6A), fontSize: 14, letterSpacing: 4)),
          const SizedBox(height: 8),
          ShaderMask(shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFF6D8), Color(0xFFF5CF6A), Color(0xFFFF8FB1)]).createShader(b),
            child: Text('Lv.$lv', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 64, color: Colors.white))),
          if (unlock != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(unlock['say'] as String,
            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF8F2E6), fontSize: 14))),
          const SizedBox(height: 20),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인')),
        ]),
      ),
    ));
  }

  void _openCareSheet(WishRoom room) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _CareSheet(room: room));
  }

  void _openShareSheet(WishRoom room) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _ShareSheet(room: room));
  }

  void _openGuide() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => const _GuideSheet());
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.room;
        if (room == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A)));
        }
        final cat = WrCatalog.I;
        final isDim = room.decayBadge && room.brightness < 1 && !_rekindling;
        final effBrightness = _rekindling ? _rekindleBrightness : room.brightness;
        final boost = _devotion.lightBoost > 0 ? (_devotion.lightBoost * 10).clamp(0.0, 2.0) : _rekindleBoost;
        final lim = room.dailyLimit > 0 ? room.dailyLimit : 10;
        final used = lim - room.devotionsRemaining;
        final busyCooldown = _cooldownRemain > 0 && used < lim;
        final done = used >= lim;
        final charge = busyCooldown ? 1 - _cooldownRemain / _cooldownTotal : 0.0;
        final double deg = busyCooldown ? charge * 360 : done ? 360.0 : (used / lim) * 360;
        final ritual = cat.ritual(room.theme);

        return Stack(children: [
          Positioned.fill(child: WrCanvasScaler(child: GestureDetector(
            onTap: _peek ? () => setState(() => _peek = false) : null,
            child: RoomScene(
              room: _withBrightness(room, effBrightness),
              items: p.items,
              pray: _devotion.behavior == Behavior.pray || (busyCooldown),
              boost: boost,
            ),
          ))),
          if (!_peek) SafeArea(child: WrCanvasScaler(child: Stack(children: [
            // TopBar
            Positioned(top: 52, left: 14, child: _pouchPill(p.me?.pouch ?? 0)),
            const Positioned(top: 58, left: 0, right: 0, child: Center(child: Text('내 소원방', style: TextStyle(color: Colors.white, fontSize: 20)))),
            // 레벨바
            Positioned(top: 100, left: 14, child: _levelBar(room)),
            // 우상단 알약 버튼 3개: 안내서 · 방만 보기 · 공유
            if (!_devotion.busy && !_rekindling) Positioned(top: 100, right: 14, child: _pillBtn('? 안내서', _openGuide)),
            if (!_devotion.busy && !_rekindling) Positioned(top: 136, right: 14, child: _pillBtn('◉ 방만 보기', () => setState(() => _peek = true))),
            if (!_devotion.busy && !_rekindling) Positioned(top: 172, right: 14, child: _pillBtn('⤴ 공유', () => _openShareSheet(room))),
            // 말풍선
            Positioned(left: 14, top: 400, child: GestureDetector(
              onTap: () => setState(() => _speechIdx++),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xF0FFFAF4), borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 20, offset: Offset(0, 6))]),
                child: Text(_speechText(room, ritual, busyCooldown, isDim),
                  style: const TextStyle(color: Color(0xFF5A2A36), fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.4)),
              ),
            )),
            // 머금는 동안의 기도문
            if (busyCooldown) Positioned(left: 16, right: 16, top: 640, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(color: const Color(0x8C1E0A18), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x40FFC8A0))),
              child: Text(_prayLine(ritual, charge), style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFFFFF4E0))),
            ))),
            // ── 하단 슬림 도크(58px) + 둥근 정성 버튼(66px) ──
            Positioned(left: 12, right: 12, top: 690, child: _bottomDock(
              room: room, cat: cat, isDim: isDim, busy: busyCooldown, done: done, deg: deg, ritual: ritual, used: used, lim: lim,
            )),
          ]))),
          if (_wishOpen) _wishFullCard(room, cat),
        ]);
      }),
    ));
  }

  /// 소원 전문 펼침 — 도크를 탭하면 열리는 오버레이 카드(최대 150px 스크롤 + 기운 목록).
  Widget _wishFullCard(WishRoom room, WrCatalog cat) {
    final wishColor = cat.wishColors.where((c) => c['id'] == room.wishColor).toList();
    final paper = cat.papers.where((p) => p['id'] == room.paper).toList();
    final W = wishColor.isNotEmpty ? wishColor.first : null;
    final pp = paper.isNotEmpty ? paper.first : cat.papers.first;
    final bgColors = (pp['bg'] as List).map((e) => _hex(e as String)).toList();
    final inkColor = _hex(pp['ink'] as String);
    final subColor = _hex2((pp['sub'] as String?) ?? '');
    final eff = room.effects;
    final fxTags = <String>[
      if (eff.devo > 0) '정성 +${eff.devo}%',
      if (eff.support > 0) '응원 +${eff.support}%',
      if (eff.cool > 0) '쿨타임 -${eff.cool}초',
      if (eff.daily > 0) '일일 +${eff.daily}회',
      if (eff.pouch > 0) '정성보너스 +${eff.pouch}',
    ];
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () => setState(() => _wishOpen = false),
        child: Container(color: const Color(0x80000000)))),
      Positioned(left: 14, right: 14, bottom: 96, child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bgColors),
          boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 34, height: 34, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: W != null ? _hex(W['deep'] as String) : WrC.accent),
              child: Text(W != null ? (W['hanja'] as String) : '願', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFFFF4E0)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.sealUntil != null && room.capsule == Capsule.LOCKED
                  ? '🔐 ${room.sealUntil}까지 봉인 · D-${room.sealDaysLeft}'
                  : '오늘의 소원 · ${room.daysLit}일째 밝히는 중',
                style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 11, color: subColor)),
              if (W != null) Text('${W['label']}의 소원', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 12, color: _hex(W['deep'] as String))),
            ])),
            GestureDetector(onTap: () => setState(() => _wishOpen = false), child: Container(
              width: 30, height: 30, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x14000000)),
              child: Text('✕', style: TextStyle(color: inkColor)))),
          ]),
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxHeight: 150), child: SingleChildScrollView(
            child: Text(room.text, style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, height: 1.7, color: inkColor)),
          )),
          if (fxTags.isNotEmpty) Container(
            margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: subColor.withValues(alpha: .4)))),
            child: Wrap(spacing: 5, runSpacing: 5, children: fxTags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: const Color(0x14000000), borderRadius: BorderRadius.circular(999)),
              child: Text(t, style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 10.5, color: inkColor)),
            )).toList()),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: SizedBox(height: 40, child: OutlinedButton(
              onPressed: () { setState(() => _wishOpen = false); _openShareSheet(room); },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
              child: Text('⤴ 공유', style: WrF.body(13, color: WrC.fg)),
            ))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 40, child: OutlinedButton(
              onPressed: () { setState(() => _wishOpen = false); _openCareSheet(room); },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
              child: Text('소원방 돌보기', style: WrF.body(13, color: WrC.fg)),
            ))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 40, child: ElevatedButton(
              onPressed: () => setState(() => _wishOpen = false),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
              child: const Text('✿ 꾸미기', style: TextStyle(color: Colors.white, fontSize: 13)),
            ))),
          ]),
        ]),
      )),
    ]);
  }

  Widget _pouchPill(int pouch) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0x8C1E0C18), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('💰', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text('$pouch', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
      ]));

  Widget _levelBar(WishRoom room) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: const Color(0x8C1E0C18), borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('LV.${room.level}', style: const TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: 10, color: Color(0xFFF5CF6A), letterSpacing: 1.2)),
        const SizedBox(width: 6),
        Text(room.levelName, style: WrF.body(12, w: FontWeight.w700, color: WrC.fg)),
        const SizedBox(width: 8),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: SizedBox(width: 74, height: 4,
          child: LinearProgressIndicator(value: room.levelProgress, backgroundColor: const Color(0x24FFFFFF),
            valueColor: const AlwaysStoppedAnimation(WrC.blossom)))),
      ]));

  Widget _pillBtn(String label, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 11, 5),
      decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
      child: Text(label, style: WrF.body(11.5, w: FontWeight.w700, color: WrC.fg)),
    ));

  String _speechText(WishRoom room, Map<String, dynamic> ritual, bool busy, bool isDim) {
    if (isDim) return '${room.absentDays}일 만에 오셨네요\n촛불이 많이 약해졌어요';
    if (busy) {
      final stage = _cooldownRemain > _cooldownTotal * .67 ? 0 : _cooldownRemain > _cooldownTotal * .33 ? 1 : 2;
      return ['간절히…\n간절히 빌어요', '이 마음,\n꼭 닿기를', '곧 이루어질\n거예요'][stage];
    }
    final opts = ['오늘도 이 소원, 잘 지켜보고 있어요', room.text, '이 소원, 분명 이루어질 거예요'];
    return opts[_speechIdx % opts.length];
  }

  String _prayLine(Map<String, dynamic> ritual, double charge) {
    final lines = (ritual['lines'] as List);
    final stage = charge < .34 ? 0 : charge < .67 ? 1 : 2;
    final pair = lines[stage.clamp(0, lines.length - 1)] as List;
    final lineIx = DateTime.now().second ~/ 5 % 2;
    final text = (lineIx == 1 && pair.length > 1 && pair[1] != null) ? pair[1] as String : pair[0] as String;
    return text;
  }

  /// ── 하단 도크 — 소원 한 줄(소원 빛깔/종이 반영) + 둥근 정성 버튼(링게이지) ──
  Widget _bottomDock({required WishRoom room, required WrCatalog cat, required bool isDim, required bool busy,
      required bool done, required double deg, required Map<String, dynamic> ritual, required int used, required int lim}) {
    final wishColor = cat.wishColors.where((c) => c['id'] == room.wishColor).toList();
    final paper = cat.papers.where((p) => p['id'] == room.paper).toList();
    final W = wishColor.isNotEmpty ? wishColor.first : null;
    final pp = paper.isNotEmpty ? paper.first : cat.papers.first;
    final bgColors = (pp['bg'] as List).map((e) => _hex(e as String)).toList();
    final inkColor = _hex(pp['ink'] as String);
    final subColor = _hex2((pp['sub'] as String?) ?? '');
    final wColor = W != null ? _hex(W['color'] as String) : null;
    final ringColor = _armed ? const Color(0xFFFFE08A) : WrC.blossom2;

    String labelText;
    if (room.capsuleDue) {
      labelText = '🎁 소원 봉인이 풀렸어요';
    } else if (room.sealUntil != null && room.capsule == Capsule.LOCKED) {
      labelText = '🔐 D-${room.sealDaysLeft} · ${room.sealUntil}';
    } else if (isDim) {
      labelText = '🕯 촛불 ${(room.brightness * 100).round()}%';
    } else {
      labelText = '${room.daysLit}일째 밝히는 중';
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // 소원 도크
      Expanded(child: GestureDetector(onTap: () => setState(() => _wishOpen = true), child: Container(
        height: 58,
        padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bgColors),
          boxShadow: [
            BoxShadow(color: (wColor ?? const Color(0x80FFDCB4)).withValues(alpha: .4), blurRadius: 16),
            const BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: W != null ? _hex(W['deep'] as String) : WrC.accent),
            child: Text(W != null ? (W['hanja'] as String) : '願', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFFFFF4E0)))),
          const SizedBox(width: 9),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(labelText, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 10, color: isDim ? const Color(0xFFB8442F) : subColor)),
            const SizedBox(height: 2),
            Text(room.text, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 13.5, color: inkColor)),
          ])),
          Icon(Icons.keyboard_arrow_up, size: 16, color: inkColor.withValues(alpha: .5)),
        ]),
      ))),
      const SizedBox(width: 10),
      // 둥근 정성 버튼
      GestureDetector(
        onTap: isDim ? _onRekindle : (busy ? null : _onDevote),
        child: Container(
          width: 66, height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [isDim ? const Color(0xFFFFE08A) : ringColor, isDim ? const Color(0xFFFFE08A) : ringColor, const Color(0x24FFFFFF)],
              stops: [0, (isDim ? 1.0 : deg / 360).clamp(0.0, 1.0), (isDim ? 1.0 : deg / 360).clamp(0.0, 1.0)]),
            boxShadow: [BoxShadow(color: (_armed || isDim) ? const Color(0xBFFFD278) : const Color(0x80F2628F), blurRadius: (_armed || isDim) ? 26 : 18)],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: isDim || _armed ? const [Color(0xFFFFE9A8), Color(0xFFF5C052)] : (busy || done ? const [Color(0xFF4A2238), Color(0xFF2A1020)] : const [Color(0xFFFF9CBC), Color(0xFFF2628F)])),
            ),
            alignment: Alignment.center,
            child: isDim
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🕯', style: TextStyle(fontSize: 20, height: 1)),
                  Text('다시 밝히기', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w800, fontSize: 9.5, color: const Color(0xFF4A2A10))),
                ])
              : busy
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$_cooldownRemain', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 19, color: Colors.white, height: 1)),
                    const Text('머금는 중', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 9, color: Colors.white70)),
                  ])
                : done
                  ? Column(mainAxisSize: MainAxisSize.min, children: const [
                      Text('✓', style: TextStyle(fontSize: 17, color: Colors.white70, height: 1)),
                      Text('오늘 완료', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 9, color: Colors.white70)),
                    ])
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(ritual['icon'] as String? ?? '🙏', style: const TextStyle(fontSize: 20, height: 1)),
                      Text('${ritual['verb']} $used/$lim', style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w800, fontSize: 10, color: Colors.white)),
                    ]),
          ),
        ),
      ),
    ]);
  }

  Color _hex(String s) { final h = s.replaceFirst('#', ''); return Color(int.parse('FF$h', radix: 16)); }
  Color _hex2(String rgba) {
    // rgba(r,g,b,a) 형식 파싱, 실패 시 fg 색
    final m = RegExp(r'rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)').firstMatch(rgba);
    if (m == null) return WrC.fg;
    final r = int.parse(m.group(1)!), g = int.parse(m.group(2)!), b = int.parse(m.group(3)!);
    final a = m.group(4) != null ? double.parse(m.group(4)!) : 1.0;
    return Color.fromRGBO(r, g, b, a);
  }

  WishRoom _withBrightness(WishRoom r, double b) {
    if (b == r.brightness) return r;
    // brightness만 오버라이드하는 얕은 복제 — RoomScene 렌더용(네트워크 전송 없음).
    return WishRoom.fromJson({
      'id': r.id, 'ownerId': r.ownerId, 'owner': r.owner, 'region': r.region, 'text': r.text, 'char': r.char,
      'status': r.status.name, 'visibility': r.visibility.name, 'theme': r.theme.name,
      'outfit': r.outfit?.name, 'outfitNow': r.outfitNow.name, 'wishColor': r.wishColor, 'paper': r.paper,
      'devotionCount': r.devotionCount, 'supportCount': r.supportCount, 'pouchReceived': r.pouchReceived,
      'level': r.level, 'commentCount': r.commentCount, 'points': r.points, 'levelName': r.levelName,
      'curLevelPts': r.curLevelPts, 'nextLevelPts': r.nextLevelPts, 'brightness': b, 'decayLabel': r.decayLabel,
      'decayBadge': r.decayBadge, 'isMine': r.isMine, 'supportedToday': r.supportedToday,
      'absentDays': r.absentDays, 'devotionsToday': r.devotionsToday, 'devotionsRemaining': r.devotionsRemaining,
      'dailyLimit': r.dailyLimit, 'cooldownSec': r.cooldownSec, 'daysLit': r.daysLit,
      'equip': {
        'CANDLE': r.equip.candle, 'FLOWER': r.equip.flower, 'BACKGROUND': r.equip.background, 'SPECIAL': r.equip.special,
        'DECORATION': r.equip.decoration, 'SEAL': r.equip.seal, 'THEME': r.equip.theme,
      },
      'layout': r.layout.map((k, v) => MapEntry(k, {'x': v.x, 'y': v.y, 's': v.s})),
    });
  }
}

/// §5 레벨업 해금 UNLOCKS 텍스트 — room_layout.dart의 RoomLayout.unlocks를 그대로 노출.
class RoomLayoutUnlocks {
  static Map<String, Object>? of(int lv) {
    const unlocks = <int, Map<String, Object>>{
      2: {'say': '창가에 첫 꽃잎이 날리기 시작했어요'},
      3: {'say': '작은 향로에서 향이 피어올라요'},
      4: {'say': '양쪽 기둥에 등불이 켜졌어요'},
      5: {'say': '촛불 받침이 은은하게 빛나요'},
      6: {'say': '창가에 연꽃등이 떠올랐어요'},
      7: {'say': '천장에 별이 내려앉았어요'},
      8: {'say': '기둥에 복주머니가 걸렸어요'},
      9: {'say': '방 전체가 환하게 밝아졌어요'},
      10: {'say': '당신의 소원방이 완성되었어요'},
    };
    return unlocks[lv];
  }
}

class _RewardSheet extends StatelessWidget {
  const _RewardSheet({required this.title, required this.sub});
  final String title, sub;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      decoration: WrDeco.sheet,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: WrF.display(19, color: Colors.white)),
        const SizedBox(height: 8),
        Text(sub, style: WrF.body(13, color: Colors.white70)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
          child: const Text('오늘도 정성 들이기', style: TextStyle(color: Colors.white)),
        )),
      ]),
    );
  }
}

/// 소원방 돌보기 시트 — SCR-03 하단 설명.
class _CareSheet extends StatefulWidget {
  const _CareSheet({required this.room});
  final WishRoom room;
  @override
  State<_CareSheet> createState() => _CareSheetState();
}

class _CareSheetState extends State<_CareSheet> {
  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text('Lv.${room.level} · ${room.levelName}', style: WrF.body(16, color: Colors.white)),
        Text('${room.curLevelPts} / ${room.nextLevelPts ?? room.curLevelPts}', style: WrF.body(12, color: Colors.white54)),
        const SizedBox(height: 16),
        Row(children: [
          _stat('정성', room.devotionCount),
          _stat('응원', room.supportCount),
          _stat('복주머니', room.pouchReceived),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompleteScreen(roomId: room.id)));
          },
          style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
          child: const Text('✿ 소원이 이루어졌어요', style: TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)),
        )),
      ]),
    );
  }

  Widget _stat(String label, int v) => Expanded(child: Column(children: [
        Text('$v', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]));
}

/// 공유 시트 — CHANGELOG '소원방 공유' §: 공개범위 미리보기 + 링크 복사(최소 구현).
class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.room});
  final WishRoom room;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text('소원방 공유하기', style: WrF.display(18, color: Colors.white)),
        const SizedBox(height: 8),
        Text('링크를 받은 사람은 내 소원방을 방문해 응원할 수 있어요', style: WrF.body(12, color: Colors.white70)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: SizedBox(height: 48, child: OutlinedButton(
            onPressed: () { Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크가 복사되었어요'))); },
            style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
            child: Text('🔗 링크 복사', style: WrF.body(14, color: Colors.white)),
          ))),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 48, child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
            child: const Text('카카오톡 공유', style: TextStyle(color: Colors.white)),
          ))),
        ]),
      ]),
    );
  }
}

/// 안내서 시트 — CHANGELOG '봉인 안내 문구' GUIDE 섹션(최소 구현).
class _GuideSheet extends StatelessWidget {
  const _GuideSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text('소원방 안내서', style: WrF.display(18, color: Colors.white)),
        const SizedBox(height: 12),
        _guideRow('🙏 정성 들이기', '매일 ${WrCatalog.I.devotionRule['dailyLimit'] ?? 10}회까지 정성을 담을 수 있어요'),
        _guideRow('🕯 촛불이 약해졌어요', '4일 이상 찾지 않으면 촛불이 가물거려요'),
        _guideRow('🔐 소원 봉인', '봉인일을 정하면 그날까지 소원을 간직해요'),
        _guideRow('✿ 꾸미기', '복주머니로 방을 꾸밀 수 있어요'),
      ]),
    );
  }

  Widget _guideRow(String title, String desc) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 3),
        Text(desc, style: WrF.body(12, color: Colors.white70)),
      ]));
}
