// SCR-03 소원방 메인 `/room` (탭1, 핵심 화면) — docs/SCREENS.md §SCR-03
// 방 장면(RoomScene) + TopBar + 레벨바 + 말풍선 + 오늘의 소원 카드 + 정성들이기/다시밝히기
// CTA + 감쇠 상태 UI + 소원방 돌보기 시트. §6.1(devote)/§6.2(rekindle) 연출은
// DevotionController/RekindleTimeline을 사용한다.
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
  bool _rekindling = false;
  double _rekindleBrightness = 1;
  double _rekindleBoost = 0;
  String? _speechOverride;
  int _speechIdx = 0;
  Timer? _speechTimer;

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
      final remain = room!.cooldownUntil!.difference(DateTime.now()).inSeconds;
      if (mounted) setState(() => _cooldownRemain = remain > 0 ? remain : 0);
    });
  }

  Future<void> _onDevote() async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null || _devotion.busy) return;
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

  void _openCareSheet() {
    final room = context.read<WishRoomProvider>().room;
    if (room == null) return;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _CareSheet(room: room));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.room;
        if (room == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A)));
        }
        final cat = WrCatalog.I;
        final isDim = room.decayBadge && room.brightness < 1 && !_rekindling;
        final effBrightness = _rekindling ? _rekindleBrightness : room.brightness;
        final boost = _devotion.lightBoost > 0 ? (_devotion.lightBoost * 10).clamp(0.0, 2.0) : _rekindleBoost;
        return Stack(children: [
          Positioned.fill(child: WrCanvasScaler(child: RoomScene(
            room: _withBrightness(room, effBrightness),
            items: p.items,
            pray: _devotion.behavior == Behavior.pray,
            boost: boost,
          ))),
          SafeArea(child: Column(children: [
            // TopBar
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x8C1E0C18), borderRadius: BorderRadius.circular(999)),
                child: Row(children: [
                  const Text('💰', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text('${p.me?.pouch ?? 0}', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                ])),
              const Expanded(child: Center(child: Text('내 소원방', style: TextStyle(color: Colors.white, fontSize: 20)))),
              IconButton(onPressed: _openCareSheet, icon: const Icon(Icons.settings, color: Colors.white, size: 20)),
            ])),
            // 레벨바
            Padding(padding: const EdgeInsets.only(top: 6), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: const Color(0x8C1E0C18), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('LV.${room.level}', style: const TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: 10, color: Color(0xFFF5CF6A))),
                const SizedBox(width: 6),
                Text(room.levelName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 8),
                ClipRRect(borderRadius: BorderRadius.circular(2), child: SizedBox(width: 74, height: 4,
                  child: LinearProgressIndicator(value: room.levelProgress, backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFF2628F))))),
              ]),
            )),
            const Spacer(),
          ])),
          // 말풍선
          Positioned(left: 22, top: 262, child: GestureDetector(
            onTap: () => setState(() => _speechIdx++),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xF0FFFAF4), borderRadius: BorderRadius.circular(14)),
              child: Text(_speechText(room, cat), style: const TextStyle(color: Color(0xFF5A2A36), fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          )),
          // 오늘의 소원 카드 + CTA
          Positioned(left: 16, right: 16, bottom: 0, child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 90),
            child: Column(children: [
              GestureDetector(onTap: _openCareSheet, child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xF7FFF4E2), Color(0xF2F7E2C8)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isDim ? '🕯 촛불 밝기 ${(room.brightness * 100).round()}% · ${room.decayLabel}' : '오늘의 소원 · ${room.daysLit}일째 밝히는 중',
                      style: TextStyle(fontSize: 11, color: isDim ? const Color(0xFFB8442F) : const Color(0x993C2D1E))),
                    const SizedBox(height: 6),
                    Text(room.text, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 15, color: Color(0xFF4A2A1C))),
                  ])),
                  const Text('願', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFFC94A3B))),
                ]),
              )),
              const SizedBox(height: 10),
              _ctaButton(room),
              const SizedBox(height: 8),
              if (!isDim) Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(room.dailyLimit, (i) {
                final used = i < room.devotionsToday;
                return Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: used ? const Color(0xFFFF8FB1) : const Color(0x33FFFFFF),
                    boxShadow: used ? const [BoxShadow(color: Color(0x99FF8FB1), blurRadius: 4)] : null));
              })),
            ]),
          )),
        ]);
      }),
    ));
  }

  String _speechText(WishRoom room, WrCatalog cat) {
    if (_speechOverride != null) return _speechOverride!;
    final ritual = cat.ritual(room.theme);
    final lines = (ritual['lines'] as List);
    if (_devotion.busy) {
      final i = _devotion.phase.index.clamp(0, lines.length - 1);
      final pair = lines[i.clamp(0, lines.length - 1)] as List;
      return pair[0] as String;
    }
    final opts = ['오늘도 이 소원, 잘 지켜보고 있어요', room.text, '이 소원, 분명 이루어질 거예요'];
    return opts[_speechIdx % opts.length];
  }

  Widget _ctaButton(WishRoom room) {
    final isDim = room.decayBadge && room.brightness < 1 && !_rekindling;
    if (isDim || _rekindling) {
      return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
        onPressed: _rekindling ? null : _onRekindle,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9A53A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text(_rekindling ? '촛불을 다시 밝히는 중' : '🕯 촛불 다시 밝히기',
          style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF2A1F14))),
      ));
    }
    if (room.devotionsRemaining <= 0) {
      return Container(width: double.infinity, height: 56, alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0x331A0D2E), borderRadius: BorderRadius.circular(16)),
        child: const Text('오늘의 정성을 모두 담았어요', style: TextStyle(color: Color(0x99F8F2E6), fontSize: 15)));
    }
    if (_cooldownRemain > 0) {
      return Container(width: double.infinity, height: 56, alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF2A1F3E), borderRadius: BorderRadius.circular(16)),
        child: Text('정성을 머금는 중 · $_cooldownRemain', style: const TextStyle(color: Colors.white70, fontSize: 15)));
    }
    final busy = _devotion.busy;
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
      onPressed: busy ? null : _onDevote,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2628F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: Text(busy ? '간절히 비는 중' : '🙏 정성 들이기',
        style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
    ));
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xF73E182C), Color(0xFA1E0A16)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontSize: 19, color: Colors.white)),
        const SizedBox(height: 8),
        Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2628F)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xF73E182C), Color(0xFA1E0A16)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text('Lv.${room.level} · ${room.levelName}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        Text('${room.curLevelPts} / ${room.nextLevelPts ?? room.curLevelPts}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5CF6A)),
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
