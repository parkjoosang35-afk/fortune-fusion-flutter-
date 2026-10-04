// SCR-03 소원방 메인 `/room` (탭1, 핵심 화면) — docs/SCREENS.md §SCR-03, CHANGELOG v2.3
// 방 장면(RoomScene) + TopBar + 레벨바 + 말풍선
// + 하단 슬림 도크(58px, 소원 한 줄 + 소원 빛깔/종이 반영) + 둥근 정성 버튼(66px, 링게이지)
// + 도크 탭 → 소원 전문 펼침 시트. §6.1(devote)/§6.2(rekindle) 연출은
// DevotionController/RekindleTimeline을 사용한다.
// app2/screens-a2.jsx › MainRoom() 1:1 이식.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/wr_canvas.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/fx/wr_level_up.dart';
import 'room_scene.dart';
import 'room_layout.dart';
import 'devotion_controller.dart';
import '../complete/complete_screen.dart';
import '../capsule/capsule_screen.dart';
import '../../../../core/util/safe_share.dart';
import '../guide/guide_prefs.dart';
import '../guide/guide_sheet.dart';
import '../wallpaper/wallpaper_screen.dart';
import '../wallet/wallet_sheet.dart';
import '../../core/wr_nav_pill.dart';
import '../../core/wr_toast.dart';

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
  // devote() 0.0/0.7/1.1 단계에서 주입하는 1회성 FX 오버레이(WrBurst/WrPetalRain/WrButterflies 등).
  final List<_FxEntry> _fx = [];
  // devote() 1.7(RITUAL.done) · 2.3(말씀카드) · rekindle() 2.1(n일만에 다시밝아졌어요) 캡션.
  String? _capText;
  (String, String)? _quoteText; // (문장, 출처) — 빈 출처는 ''
  DevotionGain? _lastGain; // 0.7 단계 아이템 기운 보너스 pill(top 236)
  // devote() 2.9s 보상시트 — [명세] 원본 jsx `{reward && <RewardSheet.../>}`는 quote와
  // 독립적인 state라 동시에 공존 가능(quote z-index:95가 reward dim/sheet z-index:88/89보다
  // 위에 겹쳐 보임). showModalBottomSheet(별도 Route)로는 이 레이어링을 재현할 수 없어
  // Stack 내부 오버레이로 구현한다.
  Map<String, dynamic>? _reward; // {title, sub, body, chips}
  // [버그수정 — 전수감사] fx2.jsx LevelUp()은 showDialog가 아니라 일반 z-85 전체화면
  // 뷰라 다른 오버레이(quote z95 등)와 동일한 Stack 레이어링 안에서 공존해야 한다.
  int? _levelUp;
  String? _levelUpWpNotice;
  // app2/screens-a2.jsx › MainRoom() capOpen/capLater — 타임캡슐(소원 봉인) 열기 오버레이 상태.
  bool _capOpen = false;
  bool _capLater = false;
  // A-4 말풍선 규칙 ② "다시 밝힌 직후" — rekindle() 완료 후 8초간 우선 노출.
  bool _justRekindled = false;
  // app2/guide2.jsx › shell2.jsx tour state — 메인 화면 위 6단계 코치마크 오버레이.
  bool _tour = false;
  bool _firstVisitReady = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<WishRoomProvider>();
    _devotion = DevotionController(p.repo);
    // [버그수정 — 전수 감사로 발견] DevotionController는 ChangeNotifier인데 아무도
    // addListener하지 않아 devote() 타임라인이 phase를 바꿔도(notifyListeners) 화면이
    // 전혀 다시 그려지지 않았다(흔들림·광원boost가 RoomScene에 반영되지 않는 버그).
    _devotion.addListener(() { if (mounted) setState(() {}); });
    if (p.room == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadMyRoom());
    }
    if (p.catalogLoaded == false) p.loadCatalog();
    // S-07(레벨업 안내)이 w.isSet/seenLevelNotice를 판단하려면 wallpaperStatus가
    // 미리 로드돼 있어야 한다 — 레벨업 시점에 처음 불러오면 그 사이 안내를 놓친다.
    p.loadWallpaperStatus();
    // app2/guide2.jsx › hintsOn()/seenSet()/wr_tour_done — localStorage 로딩을
    // shared_preferences 비동기 로딩으로 대체(GuidePrefs). FirstVisitChip은 이 값이
    // 준비된 뒤에야 올바른 표시 여부를 결정할 수 있다.
    GuidePrefs.I.load().then((_) { if (mounted) setState(() => _firstVisitReady = true); });
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

  void _addFx(Widget w, {int life = 2600}) {
    final key = UniqueKey();
    setState(() => _fx.add(_FxEntry(key, w)));
    Timer(Duration(milliseconds: life), () { if (mounted) setState(() => _fx.removeWhere((e) => e.key == key)); });
  }

  /// A-4 `devote()` 타임라인 — 0.0 shake+wash+촛불 링3+금빛버스트26+꽃잎버스트10 ·
  /// 0.3 boost1 · 0.7 버스트18+빛나선26+`+1 {verb}`+아이템 기운 보너스 ·
  /// 1.1 꽃잎22+나비4 · 1.7 boost2+wash2s+RITUAL.done · 2.3 말씀카드 · 2.9 끝.
  Future<void> _onDevote() async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null || _devotion.busy) return;
    setState(() { _armed = false; _capText = null; _quoteText = null; _lastGain = null; });
    final cat = WrCatalog.I;
    final ritual = cat.ritual(room.theme);
    final verb = ritual['verb'] as String? ?? '정성';
    await _devotion.devote(room.id,
      // t0.0 — 화면전체 금빛 wash 1.2s + 촛불 링3개(140px, 0/.15/.3s 스태거) +
      // 금빛 버스트26(spread190,1.4s) + 꽃잎 버스트10(glyph). app2/screens-a2.jsx devote() 230-234줄 1:1.
      onShakeBurst: () {
        debugPrint('WR_PHASE devote.shake');
        _addFx(Stack(children: const [
          WrWash(),
          WrCandleRings(x: 204, y: 330),
          WrBurst(x: 204, y: 330, n: 26, spread: 190, dur: 1400, color: Color(0xFFFFE7A0)),
          WrBurst(x: 204, y: 330, n: 10, spread: 120, dur: 1600, glyph: '🌸'),
        ]), life: 1800);
      },
      // t0.7 — 버스트18(spread130) + 빛나선26(Spiral) + `+1 {verb}`(plus-up) +
      // 정성 아이템별 fly-to(링+빛알갱이가 촛불로 날아감). 240-248줄 1:1.
      onItemBurst: (gain) {
        debugPrint('WR_PHASE devote.burst2');
        setState(() => _lastGain = gain);
        final fxItems = (gain?.fx ?? const <DevotionGainItem>[]).where((f) => f.type == 'devo').toList();
        final cat2 = WrCatalog.I;
        final p2 = context.read<WishRoomProvider>();
        final flyWidgets = <Widget>[];
        for (var i = 0; i < fxItems.length; i++) {
          final f = fxItems[i];
          final it = cat2.items.where((x) => x.id == f.id).firstOrNull;
          if (it == null) continue;
          final at = focusOf(it, room.equip, p2.items, room.layout);
          flyWidgets.add(_FlyToCandle(from: at, to: const Offset(204, 330), delayMs: 100 + i * 120));
        }
        _addFx(Stack(children: [
          WrBurst(x: 204, y: 330, n: 18, spread: 130, color: const Color(0xFFFFE08A)),
          const WrSpiral(x: 204, y: 330),
          _PlusUpText(text: '+1 $verb'),
          ...flyWidgets,
        ]), life: 1800);
        if (gain != null && gain.bonus > 0) {
          Timer(const Duration(milliseconds: 1800), () { if (mounted) setState(() => _lastGain = null); });
        }
      },
      onPetalButterfly: () {
        debugPrint('WR_PHASE devote.petal');
        _addFx(Stack(children: const [
          WrPetalRain(n: 22, dur: (2.0, 3.0), spread: .8),
          WrButterflies(x: 204, y: 380),
        ]), life: 3200);
      },
      // t1.7 — boost2 + 화면 wash 2s(강) + RITUAL.done 캡션(cap 블러해제 2.4s). 251줄 1:1.
      onWashDone: () {
        debugPrint('WR_PHASE devote.boost2');
        _addFx(const WrWash(strong: true, durMs: 2000), life: 2000);
        setState(() => _capText = ritual['done'] as String? ?? '');
      },
      onQuote: () {
        debugPrint('WR_PHASE devote.quote');
        final quotes = (ritual['quotes'] as List? ?? const []).cast<List>();
        if (quotes.isEmpty) return;
        final pick = quotes[math.Random().nextInt(quotes.length)];
        final text = pick[0] as String;
        final src = pick.length > 1 ? (pick[1] as String? ?? '') : '';
        setState(() => _quoteText = (text, src));
      },
      onDone: (res) {
        debugPrint('WR_PHASE devote.end');
        // [명세] 원본 jsx T(2900,...)는 setQuote(null)을 호출하지 않음 — 말씀 카드는
        // 사용자가 직접 탭해서 닫을 때까지 화면에 남아있어야 함(_quoteText는 지우지 않음).
        setState(() { _capText = null; _lastGain = null; });
        p.applyDevotionResult(res);
        if (res.leveledUp) {
          _showLevelUp(res.room.level);
        } else {
          final is10th = res.room.devotionsToday >= res.room.dailyLimit && res.bonus > 0;
          // [명세] showModalBottomSheet 대신 Stack 오버레이로 설정 — quote(z95)가 이
          // reward(z88/89) 위에 겹쳐 보이는 원본 레이어링을 재현하기 위함.
          setState(() => _reward = {
            'title': is10th ? '$verb 10회를 채웠어요' : '소원방이 더욱 빛나고 있어요',
            'sub': 'DEVOTION · ${res.room.devotionsToday.toString().padLeft(2, '0')} / ${res.room.dailyLimit}',
            'body': is10th ? '복주머니 +${res.bonus}' : null,
            'bonus': res.bonus,
            'cta': '확인', // A-4 devote() 보상시트 CTA — docs A_인트로…md 134줄(rekindle()의 '오늘도 정성 들이기'와 구분).
          });
        }
      },
      onError: (e) {
        if (e.code == 'COOLDOWN' && e.retryAfter != null) {
          setState(() => _cooldownRemain = e.retryAfter!);
          WrToast.show(context, '촛불이 $verb를 머금는 중이에요 · ${e.retryAfter}초');
        } else if (e.code == 'DAILY_LIMIT') {
          WrToast.show(context, '오늘의 정성을 모두 담았어요');
        } else {
          WrToast.show(context, e.message);
        }
      },
    );
  }

  /// A-4 `rekindle()` 타임라인 — 0.0 어둠(.06)+POST · 0.6 불씨pop+주황버스트12 ·
  /// 1.3 빛나선30+900px 링 · 2.1 boost2+꽃잎28+나비+버스트24+캡션 · 3.4 끝→보상시트.
  Future<void> _onRekindle() async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null || _rekindling) return;
    final absentDays = room.absentDays;
    debugPrint('WR_PHASE rekindle.dark');
    setState(() { _rekindling = true; _rekindleBrightness = .06; _rekindleBoost = 0; });
    // t0.6 — 주황 버스트12(x:204,y:318,spread:50,.9s) + 심지 불씨 16px pop(.6s 오버슛).
    // app2/screens-a2.jsx rekindle() 218줄 1:1(기존엔 좌표/spread/dur 불일치 + 불씨 pop 누락).
    Timer(RekindleTimeline.spark, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.spark');
      setState(() => _rekindleBrightness = .14);
      _addFx(Stack(children: const [
        WrBurst(x: 204, y: 318, n: 12, spread: 50, color: Color(0xFFFFB060), dur: 900),
        _WickEmber(x: 204, y: 318),
      ]), life: 1400);
    });
    // t1.3 — 빛나선30(Spiral) + 900px 빛번짐(WrLightRing, ring 2.2s). 219줄 1:1
    // (기존엔 전혀 다른 WrBurst(n:30,spread:220)로 대체돼 있었음 — 명세 위반).
    Timer(RekindleTimeline.grow, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.grow');
      setState(() { _rekindleBrightness = .7; _rekindleBoost = 1; });
      _addFx(Stack(children: const [
        WrSpiral(n: 30, x: 204, y: 330),
        WrLightRing(x: 204, y: 330),
      ]), life: 2600);
    });
    Timer(RekindleTimeline.bloom, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.bloom');
      setState(() { _rekindleBrightness = 1; _rekindleBoost = 2; _capText = '$absentDays일 만에 촛불이 다시 밝아졌어요'; });
      _addFx(Stack(children: const [
        WrPetalRain(n: 28, dur: (2.2, 3.4), spread: 1),
        WrButterflies(x: 204, y: 380),
        WrBurst(x: 204, y: 330, n: 24, spread: 180, color: Color(0xFFFFE08A)),
      ]), life: 3200);
    });
    final ok = await p.rekindle(room.id);
    Timer(RekindleTimeline.end, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.end');
      setState(() { _rekindling = false; _rekindleBoost = 0; _capText = null; });
      if (ok) {
        setState(() => _justRekindled = true);
        Timer(const Duration(seconds: 8), () { if (mounted) setState(() => _justRekindled = false); });
        setState(() => _reward = {
          'title': '촛불이 다시 환해졌어요',
          'sub': 'REKINDLED · 100%',
          'body': '$absentDays일 동안 소원방이 당신을 기다렸어요',
          'chips': const ['촛불 밝기 100%', '빛가루 +1'],
        });
      }
    });
  }

  // [버그수정 — 전수감사] app2/fx2.jsx › LevelUp() 93-126줄 1:1: showDialog가 아니라
  // 일반 Stack 오버레이(WrLevelUp, 아래 build()에서 Positioned.fill)로 교체 —
  // 원본은 halo-rays/PetalRain/Burst/fx별 배경효과/자동닫힘 타이머를 가진 전체화면
  // 시네마틱이며, 평범한 텍스트 Dialog가 아니었다(명세 위반).
  void _showLevelUp(int lv) {
    // S-07 — app2/fx2.jsx › LevelUp() 116-122줄 1:1: me.wallpaper가 있고(배경화면을
    // 설정한 적 있고) 그 roomId가 지금 이 방이며, seenLevelNotice가 이 레벨보다
    // 낮을 때만 1회 안내 문구를 보여준 뒤 서버에 기록한다(다음부턴 다시 안 보임).
    final p = context.read<WishRoomProvider>();
    final w = p.wallpaperStatus;
    final room = p.room;
    final showWpNotice = w.isSet && room != null && w.roomId == room.id && w.seenLevelNotice < lv;
    if (showWpNotice) p.wallpaperLevelNotice(lv);
    setState(() {
      _levelUp = lv;
      _levelUpWpNotice = showWpNotice ? (w.platform == 'ios' ? '소원방이 자랐어요. 배경화면을 새로 만들 수 있어요' : '소원방이 자랐어요. 배경화면에도 반영돼요') : null;
    });
  }

  void _openCareSheet(WishRoom room) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _CareSheet(room: room));
  }

  void _openShareSheet(WishRoom room) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _ShareSheet(room: room));
  }

  // app2/capsule2.jsx › UnsealBanner onOpen / screens-a2.jsx capOpen=true 1:1.
  // CapsuleOpenScreen은 자체 Scaffold를 갖는 전체화면이라 push로 띄우고, 닫히면(pop)
  // room.capsuleDue/outcome이 서버에서 갱신됐을 수 있으므로 reloadRoom(loadMyRoom) 한다.
  Future<void> _openCapsule(WishRoom room) async {
    setState(() => _capOpen = true);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CapsuleOpenScreen(room: room)));
    if (!mounted) return;
    setState(() => _capOpen = false);
    context.read<WishRoomProvider>().loadMyRoom();
  }

  // app2/guide2.jsx › app.openGuide(focus) 1:1 — focus를 펼친 채로 안내서를 연다.
  // room이 있을 때만(= 메인화면 안내서 버튼) "한 바퀴 둘러보기" 버튼을 함께 보여준다.
  void _openGuide([String? focus]) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => GuideBook(focus: focus, onStartTour: () => setState(() => _tour = true)));
  }

  // app2/fx2.jsx › NavPill onBack=app.back · onExitHome=app.exitHome 1:1.
  // 홈은 WishRoomShell의 탭 루트(= push된 화면 없음)이므로 뒤로가기를 누르면
  // 항상 "신통방통 홈으로 갈까요" 확인시트가 뜬다(원본 exitAsk와 동일).
  void _onBack() => wrBackOrAskExit(context);
  void _onExitHome() => wrExitHome(context);

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
        final boost = _devotion.busy ? _devotion.roomBoost : _rekindleBoost;
        final lim = room.dailyLimit > 0 ? room.dailyLimit : 10;
        final used = lim - room.devotionsRemaining;
        final busyCooldown = _cooldownRemain > 0 && used < lim;
        final done = used >= lim;
        final charge = busyCooldown ? 1 - _cooldownRemain / _cooldownTotal : 0.0;
        final double deg = busyCooldown ? charge * 360 : done ? 360.0 : (used / lim) * 360;
        final ritual = cat.ritual(room.theme);

        // app2/guide2.jsx › GuideBook "한 바퀴 둘러보기"를 꾸미기/보관함 등 다른 탭에서
        // 눌렀을 때: WishRoomShell이 먼저 이 탭(홈)으로 전환해두고, 여기서 실제 투어를 켠다.
        if (p.tourRequested) {
          p.consumeTourRequest();
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _tour = true); });
        }

        return Stack(children: [
          Positioned.fill(child: WrCanvasScaler(child: GestureDetector(
            onTap: _peek ? () => setState(() => _peek = false) : null,
            child: RoomScene(
              room: _withBrightness(room, effBrightness),
              items: p.items,
              pray: _devotion.busy || busyCooldown,
              boost: boost,
              shake: _devotion.shaking,
            ),
          ))),
          // devote()/rekindle() 1회성 FX 오버레이(버스트·꽃잎비·나비 등) — WrCanvasScaler로
          // 390×844 좌표계를 맞춰야 WrBurst(x:204,y:330) 등 절대좌표가 room과 일치한다.
          if (_fx.isNotEmpty) Positioned.fill(child: IgnorePointer(child: WrCanvasScaler(child: SizedBox(width: 390, height: 844,
            child: Stack(children: [for (final e in _fx) KeyedSubtree(key: e.key, child: e.widget)]))))),
          if (!_peek) SafeArea(child: WrCanvasScaler(child: Stack(children: [
            // TopBar — app2/fx2.jsx › TopBar({nav=true, right}) 1:1: 좌측 NavPill(뒤로가기+
            // 신통방통 홈), 우측 PouchPill. [버그수정 — 전수감사] 기존엔 NavPill이 전체
            // 화면 어디에도 없었고 PouchPill이 좌측에 있었다(원본은 우측).
            Positioned(top: 52, left: 14, child: WrNavPill(onBack: () => _onBack(), onExitHome: () => _onExitHome())),
            Positioned(top: 52, right: 14, child: _pouchPill(p.me?.pouch ?? 0)),
            const Positioned(top: 58, left: 0, right: 0, child: Center(child: Text('내 소원방', style: TextStyle(color: Colors.white, fontSize: 20)))),
            // 레벨바
            Positioned(top: 100, left: 14, child: _levelBar(room)),
            // 우상단 알약 버튼 3개: 안내서 · 방만 보기 · 공유
            if (!_devotion.busy && !_rekindling) Positioned(top: 100, right: 14, child: _pillBtn('안내서', () => _openGuide(), leading: _guideIcon())),
            // app2/guide2.jsx › FirstVisitChip — 처음 오셨나요 배너(top:140).
            if (_firstVisitReady && !_devotion.busy && !_rekindling)
              Positioned(top: 140, left: 0, right: 0, child: WrFirstVisitChip(onStartTour: () => setState(() => _tour = true))),
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
            // devote() 0.7s — 아이템 기운 보너스 pill(top 236) `✦ 아이템 기운 +n%` + 아이템별 칩 최대 4개.
            if (_lastGain != null && _lastGain!.bonus > 0) Positioned(left: 0, right: 0, top: 236, child: Center(child: _GainPill(gain: _lastGain!))),
            // devote() 1.7s RITUAL.done(`cap 2.4s`, 15px) / rekindle() 2.1s `{n}일 만에
            // 다시 밝아졌어요`(`cap 2.6s`, 19px) — top 520/500 캡션. cap: 블러해제 페이드.
            if (_capText != null) Positioned(key: ValueKey(_capText), left: 20, right: 20, top: _rekindling ? 500 : 520, child: Center(child: _CapText(
              text: _capText!, fontSize: _rekindling ? 19 : 15, durMs: _rekindling ? 2600 : 2400,
            ))),
            // devote() 2.9s / rekindle() 3.4s 보상시트 — [명세] quote보다 먼저(=아래) 배치해
            // quote(z95)가 이 위에 겹쳐 보이는 원본 레이어링(dim z88/sheet z89 < quote z95)을 재현.
            if (_reward != null) Positioned.fill(child: _RewardOverlay(
              data: _reward!, onClose: () => setState(() => _reward = null),
            )),
            // devote() 2.3s 말씀 카드(RITUAL.quotes 랜덤 1개, 테마별 디자인) — 탭하면 닫힘.
            if (_quoteText != null) Positioned.fill(child: _QuoteCard(
              text: _quoteText!.$1, src: _quoteText!.$2, theme: room.theme, icon: ritual['icon'] as String? ?? '✿',
              onClose: () => setState(() => _quoteText = null),
            )),
            // ── 하단 슬림 도크(58px) + 둥근 정성 버튼(66px) ──
            Positioned(left: 12, right: 12, top: 690, child: _bottomDock(
              room: room, cat: cat, isDim: isDim, busy: busyCooldown, done: done, deg: deg, ritual: ritual, used: used, lim: lim,
            )),
          ]))),
          if (_wishOpen) _wishFullCard(room, cat),
          // app2/screens-a2.jsx › MainRoom() 331줄 1:1 — 봉인 풀림 안내(UnsealBanner).
          // capsuleDue(서버 판정) && 아직 캡슐 오버레이를 열지 않았고 && '나중에' 선택도 안 했을 때.
          if (room.capsuleDue && !_capOpen && !_capLater)
            Positioned.fill(child: WrUnsealBanner(room: room, onOpen: () => _openCapsule(room), onLater: () => setState(() => _capLater = true)))
          // [버그수정 — 전수감사] '나중에'를 고른 뒤 top 176에 남는 금 버튼이 전혀 없어
          // 봉인일이 지난 방을 다시 열 방법이 사라지는 버그였다.
          // [버그수정 2] WrUnsealChip.build()는 Positioned를 최상위로 반환하므로 반드시 Stack의
          // 직계 자식이어야 한다 — WrCanvasScaler(ClipRect>OverflowBox>Transform.scale)로 바로 감싸면
          // "Incorrect use of ParentDataWidget" 런타임 에러로 전체 화면이 깨진다. 내부에 Stack을 한 겹 더 둔다.
          else if (room.capsuleDue && _capLater && !_capOpen)
            Positioned.fill(child: SafeArea(child: WrCanvasScaler(child: Stack(children: [
              WrUnsealChip(onOpen: () => _openCapsule(room)),
            ])))),
          // app2/guide2.jsx › shell2.jsx {tour && <Tour .../>} — 둘러보기 6단계 코치마크.
          if (_tour) Positioned.fill(child: WrCanvasScaler(child: WrTour(onDone: () {
            setState(() => _tour = false);
            GuidePrefs.I.setTourDone();
          }))),
          // fx2.jsx › LevelUp() z85 — 전체화면 레벨업 시네마틱. 최상위(가장 나중에 그려짐)에
          // 둬야 quote(위 WrCanvasScaler 내부 z95) 아래라도 그 외 모든 UI 위에 보인다.
          if (_levelUp != null) Positioned.fill(child: WrCanvasScaler(child: WrLevelUp(
            level: _levelUp!, wallpaperNotice: _levelUpWpNotice,
            onDone: () => setState(() { _levelUp = null; _levelUpWpNotice = null; }),
          ))),
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
    // [명세] jsx 344줄 1:1 — 집계 태그가 아니라 아이템별(src[]) 칩. 궁합(match)이면
    // 금→핑크 그라디언트 배경 + 진한 글자, 아니면 반투명 검정 배경.
    final effSrc = room.effects.src;
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () => setState(() => _wishOpen = false),
        child: Container(color: const Color(0x80080308)))), // .dim rgba(8,3,8,.5)
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
                  ? '🔐 ${fmtSealDot(room.sealUntil)}까지 봉인 · D-${room.sealDaysLeft}'
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
          if (effSrc.isNotEmpty) Container(
            margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: subColor.withValues(alpha: .4), width: 1 /* dashed 근사 */))),
            child: Wrap(spacing: 5, runSpacing: 5, children: effSrc.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                gradient: s.match ? const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFFFB0C8)]) : null,
                color: s.match ? null : const Color(0x14000000),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${s.name} · ${_effectShort(s.type, s.v)}',
                style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 10.5, color: s.match ? const Color(0xFF3A1A14) : inkColor)),
            )).toList()),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: SizedBox(height: 40, child: OutlinedButton(
              onPressed: () { setState(() => _wishOpen = false); _openShareSheet(room); },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
              child: Text('⤴ 공유', maxLines: 1, overflow: TextOverflow.ellipsis, style: WrF.body(13, color: WrC.fg)),
            ))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 40, child: OutlinedButton(
              onPressed: () { setState(() => _wishOpen = false); _openCareSheet(room); },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line), padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: Text('소원방 돌보기', maxLines: 1, overflow: TextOverflow.ellipsis, style: WrF.body(12, color: WrC.fg)),
            ))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 40, child: ElevatedButton(
              onPressed: () => setState(() => _wishOpen = false),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
              child: const Text('✿ 꾸미기', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 13)),
            ))),
          ]),
        ]),
      )),
    ]);
  }

  // [버그수정 — 전수 감사로 발견] 원본 app2/screens-a2.jsx › PouchPill({onClick:
  // app.openWallet})은 탭하면 지갑 시트가 열리지만, 기존 구현은 탭 핸들러가 전혀
  // 없는 정적 Container였다. _PouchPillTap으로 교체해 탭→openWalletSheet와
  // 금액 변동 시 bump(확대/축소) 애니메이션을 더한다.
  Widget _pouchPill(int pouch) => _PouchPillTap(pouch: pouch);

  Widget _levelBar(WishRoom room) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: const Color(0x8C1E0C18), borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('LV.${room.level}', style: const TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: 10, color: Color(0xFFF5CF6A), letterSpacing: 1.2)),
        const SizedBox(width: 6),
        Text(room.levelName, style: WrF.body(12, w: FontWeight.w700, color: WrC.fg)),
        const SizedBox(width: 8),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: SizedBox(width: 74, height: 4,
          child: _ShimmerLevelBar(progress: room.levelProgress))),
      ]));

  Widget _pillBtn(String label, VoidCallback onTap, {Widget? leading}) => GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 11, 5),
      decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
      child: leading == null
          ? Text(label, style: WrF.body(11.5, w: FontWeight.w700, color: WrC.fg))
          : Row(mainAxisSize: MainAxisSize.min, children: [leading, const SizedBox(width: 6), Text(label, style: WrF.body(11.5, w: FontWeight.w700, color: WrC.fg))]),
    ));

  // A-4: `? 안내서` — "?" 는 18px 핑크 원(배경 blossom, 글자 흰색) 안에 들어간다.
  // (원본 screens-a2.jsx: <span style="width:18,height:18,borderRadius:50%,background:blossom">?</span>안내서)
  Widget _guideIcon() => Container(width: 18, height: 18, alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: WrC.blossom),
      child: const Text('?', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white)));

  // A-4 말풍선 문구 규칙(우선순위 순) 1:1 — ①4일+부재(dim) ②다시밝힌 직후 ③머금는 중
  // (충전 단계 0/1/2) ④평상시(3종 순환).
  String _speechText(WishRoom room, Map<String, dynamic> ritual, bool busy, bool isDim) {
    if (isDim) return '${room.absentDays}일 만에 오셨네요\n촛불이 많이 약해졌어요';
    if (_justRekindled) return '다시 와주셔서\n고마워요';
    if (busy) {
      final stage = _cooldownRemain > _cooldownTotal * .67 ? 0 : _cooldownRemain > _cooldownTotal * .33 ? 1 : 2;
      return ['간절히…\n간절히 빌어요', '이 마음,\n꼭 닿기를', '곧 이루어질\n거예요'][stage];
    }
    const opts = ['오늘도 좋은 기운이\n모이고 있어요', '촛불이 따뜻하게\n타오르고 있어요', '조금씩, 분명히\n가까워지고 있어요'];
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
      labelText = '🔐 D-${room.sealDaysLeft} · ${fmtSealDot(room.sealUntil)}';
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
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(labelText, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 10, color: isDim ? const Color(0xFFB8442F) : subColor))),
              // [명세] jsx 313줄 1:1 — n(= effects.src.length) > 0 && !dim 일 때만 "기운 {n} · {...}" 칩.
              // 우선순위: devo > support > cool > (그 외) '켜짐'.
              if (room.effects.src.isNotEmpty && !isDim) Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: (wColor ?? Colors.black).withValues(alpha: wColor != null ? .2 : .08), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '기운 ${room.effects.src.length} · ${room.effects.devo > 0 ? '정성 +${room.effects.devo}%' : room.effects.support > 0 ? '응원 +${room.effects.support}%' : room.effects.cool > 0 ? '−${room.effects.cool}초' : '켜짐'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w800, fontSize: 9.5, color: inkColor)),
                ),
              ),
            ]),
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

  // [명세] app/data.js EFFECT_SHORT 1:1 — 아이템 칩에 쓰는 짧은 효과 표기.
  String _effectShort(String type, int v) {
    switch (type) {
      case 'devo': return '정성 +$v%';
      case 'support': return '응원 +$v%';
      case 'cool': return '−$v초';
      case 'daily': return '하루 +$v회';
      case 'pouch': return '복 +$v';
      case 'decay': return '불빛 $v%↑';
      default: return '';
    }
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

/// devote()/rekindle() 1회성 FX 오버레이 항목 — other_room_screen.dart `_FxEntry`와 동일 패턴.
class _FxEntry { final Key key; final Widget widget; _FxEntry(this.key, this.widget); }

/// devote() 0.7s `+1 {verb}` — x=204(중앙고정) y=250, 24px 흰색+핑크글로우.
/// plus-up keyframe 1:1: 0%(op0, scale.6, y+10) → 25%(op1, scale1.15, y-10) → 100%(op0, scale1, y-70).
/// app2/fx2.jsx › PlusText({x:204,y:250}) · wr2.css plus-up.
class _PlusUpText extends StatefulWidget {
  const _PlusUpText({required this.text});
  final String text;
  @override
  State<_PlusUpText> createState() => _PlusUpTextState();
}
class _PlusUpTextState extends State<_PlusUpText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Positioned(left: 0, right: 0, top: 250, child: IgnorePointer(child: Center(
    child: AnimatedBuilder(animation: _c, builder: (_, __) {
      final v = _c.value;
      double op, scale, dy;
      if (v < .25) {
        final t = v / .25;
        op = t; scale = .6 + (1.15 - .6) * t; dy = 10 + (-10 - 10) * t;
      } else {
        final t = (v - .25) / .75;
        op = 1 - t; scale = 1.15 + (1.0 - 1.15) * t; dy = -10 + (-70 - -10) * t;
      }
      return Opacity(opacity: op.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, dy), child: Transform.scale(scale: scale,
        child: Text(widget.text, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white,
          shadows: [Shadow(color: Color(0xFFFF8FB1), blurRadius: 14), Shadow(color: Color(0xB2F2628F), blurRadius: 26)])))));
    }),
  )));
}

/// devote() 1.7s `RITUAL.done` / rekindle() 2.1s `{n}일 만에 다시 밝아졌어요` 캡션 —
/// cap keyframe 1:1: 0%(op0,blur6px) → 30%~75%(op1,blur0) → 100%(op0). wr2.css › cap.
/// rekindle() t0.6 심지 불씨 — 16px 원, pop .6s cubic(.34,1.56,.64,1)(scale .4→1.08→1).
/// app2/screens-a2.jsx rekindle() 218줄 1:1.
class _WickEmber extends StatefulWidget {
  const _WickEmber({required this.x, required this.y});
  final double x, y;
  @override
  State<_WickEmber> createState() => _WickEmberState();
}
class _WickEmberState extends State<_WickEmber> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Positioned(left: widget.x - 8, top: widget.y - 8, child: IgnorePointer(child: AnimatedBuilder(
    animation: _c, builder: (_, __) {
      final v = _c.value;
      double op, scale;
      if (v < .6) { final t = v / .6; op = t; scale = .4 + (1.08 - .4) * t; }
      else { final t = (v - .6) / .4; op = 1; scale = 1.08 + (1 - 1.08) * t; }
      return Opacity(opacity: op.clamp(0.0, 1.0), child: Transform.scale(scale: scale, child: Container(
        width: 16, height: 16,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF4C0),
          boxShadow: [BoxShadow(color: Color(0xFFFFB060), blurRadius: 20, spreadRadius: 8), BoxShadow(color: Color(0x99FF963C), blurRadius: 60, spreadRadius: 20)]),
      )));
    },
  )));
}

class _CapText extends StatefulWidget {
  const _CapText({required this.text, this.fontSize = 15, this.durMs = 2400});
  final String text;
  final double fontSize;
  final int durMs;
  @override
  State<_CapText> createState() => _CapTextState();
}
class _CapTextState extends State<_CapText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.durMs))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) {
    final v = _c.value;
    double op, blur;
    if (v < .3) { final t = v / .3; op = t; blur = 6 * (1 - t); }
    else if (v < .75) { op = 1; blur = 0; }
    else { final t = (v - .75) / .25; op = 1 - t; blur = 0; }
    final text = Text(widget.text, textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w700, fontSize: widget.fontSize, color: Colors.white,
        shadows: const [Shadow(color: Color(0xFFFFE08A), blurRadius: 16)]));
    return Opacity(opacity: op.clamp(0.0, 1.0), child: blur > .1
      ? ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: text)
      : text);
  });
}

/// devote() 0.7s 정성 아이템별 fly-to — 아이템 위치(from)에 링(60px,1s) + 빛알갱이(8px)가
/// 촛불(to=204,330)로 날아가며 축소·소멸. app2/screens-a2.jsx devote() 245-248줄 1:1.
class _FlyToCandle extends StatefulWidget {
  const _FlyToCandle({required this.from, required this.to, this.delayMs = 0});
  final Offset from, to;
  final int delayMs;
  @override
  State<_FlyToCandle> createState() => _FlyToCandleState();
}
class _FlyToCandleState extends State<_FlyToCandle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: 900 + widget.delayMs))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final delayFrac = widget.delayMs / (900 + widget.delayMs);
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final raw = ((_c.value - delayFrac) / (1 - delayFrac)).clamp(0.0, 1.0);
      if (_c.value < delayFrac) return const SizedBox.shrink();
      final ringT = Curves.easeOut.transform(raw.clamp(0.0, 1.0));
      final ringOp = (1 - ringT).clamp(0.0, 1.0);
      // fly-to: translate(0→(to-from)) scale(1→.3) opacity(1→0), cubic(.5,0,.6,1)
      final flyT = const Cubic(.5, 0, .6, 1).transform(raw);
      final dx = (widget.to.dx - widget.from.dx) * flyT, dy = (widget.to.dy - widget.from.dy) * flyT;
      final scale = 1 - .7 * flyT, op = 1 - flyT;
      return Positioned.fill(child: IgnorePointer(child: Stack(children: [
        Positioned(left: widget.from.dx - 30, top: widget.from.dy - 30, child: Opacity(opacity: ringOp, child: Container(
          width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: const Color(0xE6FFE1A0), width: 2),
            boxShadow: const [BoxShadow(color: Color(0xE6FFD282), blurRadius: 18)])))),
        Positioned(left: widget.from.dx - 4 + dx, top: widget.from.dy - 4 + dy, child: Opacity(opacity: op.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale.clamp(0.0, 1.0), child: Container(width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF4C0),
              boxShadow: [BoxShadow(color: Color(0xFFFFD070), blurRadius: 12)]))))),
      ])));
    });
  }
}

/// devote() 0.7s — "아이템 기운 보너스가 있으면 top 236 금→핑크 pill `✦ 아이템 기운 +n%`
/// + 아래 아이템별 작은 칩 최대 4개(`이름 +n%`, 궁합이면 금테 `· 궁합`)".
class _GainPill extends StatelessWidget {
  const _GainPill({required this.gain});
  final DevotionGain gain;
  @override
  Widget build(BuildContext context) {
    final pct = (gain.bonus * 100).round();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFFF8FB1)]),
          boxShadow: const [BoxShadow(color: Color(0x80FFC878), blurRadius: 16)]),
        child: Text('✦ 아이템 기운 +$pct%', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF4A2A10))),
      ),
      if (gain.fx.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(
        alignment: WrapAlignment.center, spacing: 5, runSpacing: 5,
        children: gain.fx.take(4).map((it) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: const Color(0x8C1E0C18), borderRadius: BorderRadius.circular(999),
            border: it.match ? Border.all(color: const Color(0xFFFFE08A)) : null),
          child: Text('${it.name} +${it.v}%${it.match ? ' · 궁합' : ''}', style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white)),
        )).toList(),
      )),
    ]);
  }
}

/// devote() 2.3s 말씀 카드 — RITUAL.quotes 중 랜덤 1개(문장 + 출처).
/// devote() 2.3s 말씀 카드 — docs A-5 1:1: 테마별 bg그라디언트/잉크색/머리말,
/// 상단 -26px 52px 아이콘서클(pop .8s .4s), 본문 ink-in 1.6s .5s, 출처 fade 1s 1.2s,
/// 테두리 반짝이 6개(twinkle), dim 포함 + 아무 곳 탭 → 닫기. app2/screens-a2.jsx QuoteCard() 1:1.
class _QuoteCard extends StatefulWidget {
  const _QuoteCard({required this.text, required this.src, required this.theme, required this.icon, required this.onClose});
  final String text, src, icon;
  final WrTheme theme;
  final VoidCallback onClose;
  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}
class _QuoteCardState extends State<_QuoteCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    const bg = {
      WrTheme.god: [Color(0xFFFFFAF0), Color(0xFFF3E6C8)],
      WrTheme.buddha: [Color(0xFFFFF4DC), Color(0xFFF0D9A8)],
      WrTheme.shaman: [Color(0xFFFFF1EA), Color(0xFFF3D2C4)],
      WrTheme.free: [Color(0xFFFFF6FA), Color(0xFFF6DBE6)],
    };
    const ink = {WrTheme.god: Color(0xFF4A3510), WrTheme.buddha: Color(0xFF5A3510), WrTheme.shaman: Color(0xFF6A1A1A), WrTheme.free: Color(0xFF5A2A3A)};
    const head = {WrTheme.god: '✝ 오늘의 말씀', WrTheme.buddha: '☸ 오늘의 법문', WrTheme.shaman: '❖ 오늘의 덕담', WrTheme.free: '✿ 오늘의 한마디'};
    const accent = {WrTheme.god: Color(0xFFFFE6A8), WrTheme.buddha: Color(0xFFFFC870), WrTheme.shaman: Color(0xFFFF7A6A), WrTheme.free: Color(0xFFFF8FB1)};
    final c = accent[widget.theme] ?? const Color(0xFFFFD98A);
    final inkC = ink[widget.theme] ?? const Color(0xFF5A2A3A);
    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        // dim — fade .6s
        TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 600),
          builder: (_, t, __) => Opacity(opacity: .7 * t, child: const DecoratedBox(decoration: BoxDecoration(color: Colors.black),
            child: SizedBox.expand()))),
        AnimatedBuilder(animation: _c, builder: (_, __) {
          // quote-in: 0%(op0,y+30,scale.9,blur6) → 100%(op1,y0,scale1,blur0), cubic(.22,1,.36,1)
          final t = WrCurves.out.transform(_c.value);
          final op = t.clamp(0.0, 1.0);
          final dy = 30 * (1 - t);
          final scale = .9 + .1 * t;
          final blur = 6 * (1 - t);
          Widget card = Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bg[widget.theme] ?? bg[WrTheme.free]!),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: .67), blurRadius: 0, spreadRadius: 1.5),
                BoxShadow(color: c.withValues(alpha: .53), blurRadius: 40),
                const BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 20)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(head[widget.theme] ?? '', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5, color: inkC.withValues(alpha: .7))),
              const SizedBox(height: 10),
              Text('"${widget.text}"', textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 17, height: 1.65, color: inkC)),
              if (widget.src.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10),
                child: Text('— ${widget.src}', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: inkC.withValues(alpha: .7)))),
              const SizedBox(height: 16),
              Text('눌러서 닫기', style: TextStyle(fontFamily: 'Pretendard', fontSize: 11, color: inkC.withValues(alpha: .5))),
            ]),
          );
          if (blur > .1) card = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: card);
          return Positioned(left: 26, right: 26, top: 250, child: Opacity(opacity: op, child: Transform.translate(offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: Stack(clipBehavior: Clip.none, children: [
              card,
              // twinkle 반짝이 6개 — 카드 상단 테두리를 따라 분산
              for (var i = 0; i < 6; i++) Positioned(left: null, right: null, top: -4,
                child: FractionallySizedBox(widthFactor: 1, child: Align(alignment: Alignment((i - 2.5) / 2.5, 0),
                  child: _Twinkle(color: c, delayMs: i * 200, periodMs: (1400 + i * 300))))),
              // 상단 아이콘 서클 — pop .8s .4s
              Positioned(left: 0, right: 0, top: -26, child: Center(child: _IconPop(
                delayMs: 400, child: Container(width: 52, height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bg[widget.theme] ?? bg[WrTheme.free]!),
                    boxShadow: [BoxShadow(color: c.withValues(alpha: .67), blurRadius: 0, spreadRadius: 1.5), BoxShadow(color: c, blurRadius: 24)]),
                  alignment: Alignment.center,
                  child: Text(widget.icon, style: const TextStyle(fontSize: 26))),
              ))),
            ])),
          )));
        }),
      ]),
    );
  }
}

/// 말씀카드 상단 아이콘 서클 pop-in — pop keyframe(scale.4→1.08→1), delayMs 뒤 시작.
class _IconPop extends StatefulWidget {
  const _IconPop({required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;
  @override
  State<_IconPop> createState() => _IconPopState();
}
class _IconPopState extends State<_IconPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  @override
  void initState() { super.initState(); Timer(Duration(milliseconds: widget.delayMs), () { if (mounted) _c.forward(); }); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) {
    final v = _c.value;
    double op, scale;
    if (v < .6) { final t = v / .6; op = t; scale = .4 + (1.08 - .4) * t; }
    else { final t = (v - .6) / .4; op = 1; scale = 1.08 + (1 - 1.08) * t; }
    return Opacity(opacity: op.clamp(0.0, 1.0), child: Transform.scale(scale: scale, child: widget.child));
  });
}

/// 말씀카드 테두리 반짝이 — twinkle(scale.6↔1.2, op.2↔1) 무한 반복.
class _Twinkle extends StatefulWidget {
  const _Twinkle({required this.color, this.delayMs = 0, this.periodMs = 1400});
  final Color color;
  final int delayMs, periodMs;
  @override
  State<_Twinkle> createState() => _TwinkleState();
}
class _TwinkleState extends State<_Twinkle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.periodMs));
  @override
  void initState() { super.initState(); Timer(Duration(milliseconds: widget.delayMs), () { if (mounted) _c.repeat(reverse: true); }); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) {
    final t = Curves.easeInOut.transform(_c.value);
    final op = .2 + .8 * t, scale = .6 + .6 * t;
    return Opacity(opacity: op, child: Transform.scale(scale: scale, child: Container(width: 5, height: 5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFF6D0), boxShadow: [BoxShadow(color: widget.color, blurRadius: 10)]))));
  });
}

/// A-4 보상 시트 — devote() 2.9s 또는 rekindle() 3.4s 끝에 표시.
/// devote: sub `DEVOTION · 0n / 10` · 10회째면 제목이 `{verb} 10회를 채웠어요` · 칸
/// `꽃잎 +1 · 빛가루 +1 · 연꽃잎 +1`(10회째는 마지막 칸이 `복주머니 +n`).
/// rekindle: sub `REKINDLED · 100%` · 본문 `{n}일 동안 소원방이 당신을 기다렸어요` ·
/// 칸 `촛불 밝기 100% · 빛가루 +1`.
class _RewardSheet extends StatelessWidget {
  const _RewardSheet({required this.title, required this.sub, this.body, this.bonus = 0, this.chips, this.cta = '오늘도 정성 들이기', this.onClose});
  final String title, sub;
  final String? body;
  final int bonus;
  final List<String>? chips;
  final String cta;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) {
    final cc = chips ?? (bonus > 0 ? ['꽃잎 +1', '빛가루 +1', '복주머니 +$bonus'] : ['꽃잎 +1', '빛가루 +1', '연꽃잎 +1']);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      decoration: WrDeco.sheet,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(sub, style: WrF.mono(size: 10, color: WrC.muted)),
        const SizedBox(height: 6),
        Text(title, style: WrF.display(19, color: Colors.white), textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, style: WrF.body(13, color: Colors.white70), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < cc.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(999)),
              child: Text(cc[i], style: WrF.body(11.5, w: FontWeight.w700, color: Colors.white))),
          ],
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
          child: Text(cta, style: const TextStyle(color: Colors.white)),
        )),
      ]),
    );
  }
}

/// devote()/rekindle() 보상시트를 Stack 내부 오버레이로 띄우는 wrapper —
/// [명세] 원본 jsx `.dim`(z88)+`.sheet`(bottom:22,z89) 1:1. showModalBottomSheet
/// (별도 Route) 대신 사용해야 `_quoteText`(z95)가 이 위에 겹쳐 보이는 레이어링이 가능하다.
class _RewardOverlay extends StatelessWidget {
  const _RewardOverlay({required this.data, required this.onClose});
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final chips = data['chips'] as List<String>?;
    return Stack(children: [
      GestureDetector(onTap: onClose, behavior: HitTestBehavior.opaque,
        child: Container(color: const Color(0x80080308))), // .dim rgba(8,3,8,.5)
      Positioned(left: 10, right: 10, bottom: 22, child: _RewardSheet(
        title: data['title'] as String,
        sub: data['sub'] as String,
        body: data['body'] as String?,
        bonus: data['bonus'] as int? ?? 0,
        chips: chips,
        cta: data['cta'] as String? ?? '오늘도 정성 들이기',
        onClose: onClose,
      )),
    ]);
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
  bool _confirm = false;
  late Visibility _vis = widget.room.visibility;

  // [명세위반 전면수정 — 전수감사] A-6 RoomMenu 7개 항목 중 4(공개범위 즉시
  // PATCH)·5(공유버튼)·6(인트로생략 토글)·7(완료 2단계 확인)이 통째로 누락되고,
  // Sheet 헤더(sub MY WISH ROOM/title 소원방 돌보기 + ✕닫기)도 없었다.
  // app2/screens-a2.jsx › RoomMenu({app,room,close}) 1:1 재구현.
  Future<void> _setVis(Visibility v) async {
    if (v == _vis) return;
    final p = context.read<WishRoomProvider>();
    final ok = await p.updateVisibility(widget.room.id, v);
    if (!mounted || !ok) return;
    setState(() => _vis = v);
  }

  void _openShare() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _ShareSheet(room: widget.room));
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final p = context.watch<WishRoomProvider>();
    final skipIntro = p.me?.skipIntro ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sheet 헤더 — app2/fx2.jsx › Sheet({sub,title}) 1:1 (✕ 닫기 포함).
        Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MY WISH ROOM', style: WrF.mono(size: 10, color: WrC.blossom2)),
            const SizedBox(height: 6),
            Text('소원방 돌보기', style: WrF.display(20, color: Colors.white)),
          ]),
          Positioned(right: 0, top: 0, child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(width: 32, height: 32, alignment: Alignment.center,
              decoration: BoxDecoration(color: WrC.glass, shape: BoxShape.circle, border: Border.all(color: WrC.line)),
              child: const Icon(Icons.close, size: 13, color: Colors.white)),
          )),
        ]),
        const SizedBox(height: 16),
        // 1. 한지 카드 — Lv.n 레벨명 · 성장 {pt}[/{다음기준}] + 소원 14.5 + 인장 願.
        Container(
          padding: const EdgeInsets.all(14), decoration: WrDeco.hanji,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lv.${room.level} ${room.levelName} · 성장 ${room.points.floor()}${room.nextLevelPts != null ? ' / ${room.nextLevelPts}' : ''}',
                  style: WrF.body(11, w: FontWeight.w700, color: const Color(0x995A321E))),
              const SizedBox(height: 4),
              Text(room.text, style: WrF.body(14.5, w: FontWeight.w700, height: 1.5, color: const Color(0xFF3A1A14))),
            ])),
            const SizedBox(width: 10),
            Container(width: 34, height: 34, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF8A3A2A)),
              child: const Text('願', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFFF4E0)))),
          ]),
        ),
        const SizedBox(height: 10),
        // 2. 3칸 카드 — 🙏 정성 n · ❤ 응원 n · 福 복주머니 n.
        Row(children: [
          _stat('🙏', '정성', room.devotionCount),
          const SizedBox(width: 8),
          _stat('❤', '응원', room.supportCount),
          const SizedBox(width: 8),
          _stat('福', '복주머니', room.pouchReceived),
        ]),
        // 3. 배경화면 진입 카드.
        WPEntryCard(room: room),
        const SizedBox(height: 4),
        // 4. 공개 범위 탭 — 선택 즉시 PATCH.
        Text('공개 범위', style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Row(children: [
          _visTab('모두에게', Visibility.PUBLIC),
          const SizedBox(width: 6),
          _visTab('링크로만', Visibility.LINK),
          const SizedBox(width: 6),
          _visTab('나만 보기', Visibility.PRIVATE),
        ]),
        // 5. (비공개 아님) 소원방 공유하기 버튼.
        if (_vis != Visibility.PRIVATE) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 46, child: OutlinedButton(
            onPressed: _openShare,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line), backgroundColor: WrC.glass),
            child: Text('⤴ 소원방 공유하기 · 링크 보내기', style: WrF.body(13.5, w: FontWeight.w700, color: Colors.white)),
          )),
        ],
        const SizedBox(height: 12),
        // 6. 입장 인트로 항상 생략 — 토글 카드.
        GestureDetector(
          onTap: () => context.read<WishRoomProvider>().setSkipIntro(!skipIntro),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: WrDeco.card,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('입장 인트로 항상 생략', style: WrF.body(13.5, color: Colors.white)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400), width: 44, height: 26,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), color: skipIntro ? WrC.blossom : Colors.white24),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 400), curve: const Cubic(.34, 1.56, .64, 1),
                  alignment: skipIntro ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // 7. 완료 버튼 — 2단계 확인(아직이에요 / 네, 이루어졌어요).
        if (!_confirm)
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () => setState(() => _confirm = true),
            style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
            child: const Text('✿ 소원이 이루어졌어요', style: TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)),
          ))
        else
          Container(
            padding: const EdgeInsets.all(14), decoration: WrDeco.card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('정말 이루어졌나요.', style: WrF.body(14, height: 1.6, color: Colors.white)),
              Text('완료 후 7일 동안은 되돌릴 수 있어요.', style: WrF.body(12.5, color: WrC.muted)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: SizedBox(height: 40, child: OutlinedButton(
                  onPressed: () => setState(() => _confirm = false),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
                  child: Text('아직이에요', style: WrF.body(13, color: WrC.fg)),
                ))),
                const SizedBox(width: 8),
                Expanded(child: SizedBox(height: 40, child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompleteScreen(roomId: room.id)));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
                  child: const Text('네, 이루어졌어요', style: TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700, fontSize: 13)),
                ))),
              ]),
            ]),
          ),
      ])),
    );
  }

  Widget _visTab(String label, Visibility v) {
    final sel = _vis == v;
    return Expanded(child: GestureDetector(onTap: () => _setVis(v), child: Container(
      height: WrSize.tabH, alignment: Alignment.center,
      decoration: sel ? WrDeco.tabOn : BoxDecoration(borderRadius: BorderRadius.circular(WrR.tab), color: WrC.chipBg),
      child: Text(label, style: WrF.body(WrSize.tabFont, w: FontWeight.w700, color: sel ? Colors.white : WrC.muted)),
    )));
  }

  Widget _stat(String glyph, String label, int v) => Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10), decoration: WrDeco.card, alignment: Alignment.center,
        child: Column(children: [
          Text(glyph, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text('$v', style: WrF.display(17, color: Colors.white)),
          Text(label, style: WrF.body(11, color: WrC.muted)),
        ]),
      ));
}

Color _shareHex(String s) { final h = s.replaceFirst('#', ''); return Color(int.parse('FF$h', radix: 16)); }

/// app2/capsule2.jsx › ShareSheet 1:1 — 미리보기 카드 + 공개범위 전환 + 링크 복사/카카오톡/문자/더보기/새 링크.
class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.room});
  final WishRoom room;
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late Visibility _vis = widget.room.visibility;
  ({String token, String url})? _link;
  bool _copied = false;
  bool _loadingLink = false;

  @override
  void initState() {
    super.initState();
    if (_vis != Visibility.PRIVATE) _loadLink(false);
  }

  Future<void> _loadLink(bool reissue) async {
    setState(() => _loadingLink = true);
    final p = context.read<WishRoomProvider>();
    final link = await p.shareLink(widget.room.id, reissue: reissue);
    if (!mounted) return;
    setState(() { _link = link; _loadingLink = false; });
    if (reissue && link != null) {
      WrToast.show(context, '새 링크를 만들었어요 · 이전 링크는 더 열리지 않아요');
    }
  }

  Future<void> _changeVis(Visibility v) async {
    if (v == _vis) return;
    final p = context.read<WishRoomProvider>();
    final ok = await p.updateVisibility(widget.room.id, v);
    if (!mounted || !ok) return;
    setState(() => _vis = v);
    if (v != Visibility.PRIVATE && _link == null) _loadLink(false);
  }

  String get _shareMessage {
    final p = context.read<WishRoomProvider>();
    final nick = p.me?.nick ?? '나';
    return '[신통방통 소원방] $nick님의 소원방에 초대해요\n"${widget.room.text}"\n촛불 하나 함께 밝혀주세요';
  }

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) return;
    setState(() => _copied = true);
    Timer(const Duration(milliseconds: 2200), () { if (mounted) setState(() => _copied = false); });
  }

  Future<void> _nativeShare() async {
    if (_link == null) return;
    await safeShareText(context, '$_shareMessage\n${_link!.url}');
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final room = widget.room;
    final w = cat.wishColors.firstWhere((e) => e['id'] == room.wishColor, orElse: () => cat.wishColors.first);
    final pp = cat.papers.firstWhere((e) => e['id'] == room.paper, orElse: () => cat.papers.first);
    final color = _shareHex(w['color'] as String), deep = _shareHex(w['deep'] as String), hanja = w['hanja'] as String;
    final bg = (pp['bg'] as List).cast<String>().map(_shareHex).toList();
    final nick = context.watch<WishRoomProvider>().me?.nick ?? '나';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text('SHARE · 소원방 공유', style: WrF.mono(size: 10, color: WrC.muted)),
        const SizedBox(height: 4),
        Text('소원방 초대하기', style: WrF.display(18, color: Colors.white)),
        const SizedBox(height: 16),
        // 미리보기 카드 — 받는 사람에게 보이는 모습.
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: WrC.line),
            boxShadow: [BoxShadow(color: color.withValues(alpha: .2), blurRadius: 20)]),
          child: Column(children: [
            // G-4 RoomThumb — [버그수정 — 전수감사] items:const[] 고정으로 장식이 전혀 반영되지 않던 버그.
            // [버그수정 — 전수감사] app2/capsule2.jsx › ShareSheet(): `<RoomThumb ... w={342}
            // h={110} focus={.42} zoom={1.05}/>` — 다른 가로형 카드의 focus/zoom(.22/1.5)이
            // 복붙되어 있어 크롭 위치/확대율이 원본과 달랐다.
            SizedBox(height: 110, child: Stack(children: [
              Positioned.fill(child: LayoutBuilder(builder: (context, c) =>
                RoomThumb(room: room, items: context.read<WishRoomProvider>().items, w: c.maxWidth, h: 110, focus: .42, zoom: 1.05))),
              Positioned(left: 10, top: 10, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x80000000), borderRadius: BorderRadius.circular(999)),
                child: Text('SINTONG · WISH ROOM', style: WrF.mono(size: 9, color: const Color(0xFFFFE08A)).copyWith(letterSpacing: 2)),
              )),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bg)),
              child: Row(children: [
                Container(width: 30, height: 30, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: deep),
                  child: Text(hanja, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFFF4E0)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$nick님의 소원방 · Lv.${room.level}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 10.5, color: Color(0xFF8A6A50))),
                  Text('"${room.text}"', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF4A2A1C))),
                ])),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('누구에게 보여줄까요', style: WrF.body(13.5, w: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Row(children: [
          _visTab('모두에게', Visibility.PUBLIC),
          const SizedBox(width: 6),
          _visTab('링크로만', Visibility.LINK),
          const SizedBox(width: 6),
          _visTab('나만 보기', Visibility.PRIVATE),
        ]),
        const SizedBox(height: 8),
        Text(_visDesc(_vis), style: WrF.body(11.5, color: WrC.muted, height: 1.6)),
        if (_vis == Visibility.PRIVATE) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16), alignment: Alignment.center,
            decoration: WrDeco.card,
            child: Column(children: [
              const Text('🔒', style: TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text('지금은 나만 볼 수 있는 소원방이에요', style: WrF.body(13, color: WrC.fg)),
              const SizedBox(height: 12),
              SizedBox(height: WrSize.btnSmH, child: DecoratedBox(decoration: WrDeco.btnPink, child: Material(color: Colors.transparent,
                child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => _changeVis(Visibility.LINK),
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: Text('링크로만 공개하기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)))))))),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0x47000000),
              border: Border.all(color: _copied ? const Color(0xB37FD6A0) : WrC.line)),
            child: Row(children: [
              Expanded(child: Text(_loadingLink ? '링크를 만드는 중…' : (_link?.url.replaceFirst('https://', '') ?? '링크를 만드는 중…'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: WrF.mono(size: 12, color: WrC.fg))),
              const SizedBox(width: 8),
              SizedBox(height: 36, child: DecoratedBox(decoration: _copied ? WrDeco.btnDark : WrDeco.btnPink, child: Material(color: Colors.transparent,
                child: InkWell(borderRadius: BorderRadius.circular(16), onTap: _link == null ? null : _copy,
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Center(child: Text(_copied ? '✓ 복사됨' : '링크 복사',
                    style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)))))))),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _shareOpt('💬', const Color(0xFFFEE500), '카카오톡', () async { await _copy(); if (!mounted) return; WrToast.show(context, '카카오톡 공유는 앱에서 열려요 · 링크를 복사해 두었어요'); }),
            _shareOpt('✉', const Color(0xFF3FAE55), '문자', () async { await _copy(); if (!mounted) return; WrToast.show(context, '문자 앱으로 보내요 · 링크를 복사해 두었어요'); }),
            _shareOpt('⤴', const Color(0xFF4A7AD8), '더보기', _nativeShare),
            _shareOpt('⟳', Colors.white12, '새 링크', () => _loadLink(true)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: WrC.line)),
            child: Text('· 링크를 받은 분은 방을 보고 응원·응원 메시지·복주머니를 보낼 수 있어요.\n· 소원방을 꾸미거나 정성을 들이는 건 나만 할 수 있어요.\n· 링크가 퍼졌다면 새 링크를 누르세요. 이전 링크는 더 이상 열리지 않아요.',
              style: WrF.body(11.5, color: WrC.muted, height: 1.6)),
          ),
        ],
        if (_copied) Container(
          margin: const EdgeInsets.only(top: 10), alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0xEB14281C), border: Border.all(color: const Color(0x9A7FD6A0))),
          child: Text('링크를 복사했어요 · 원하는 곳에 붙여넣어 주세요', style: WrF.body(12, w: FontWeight.w700, color: const Color(0xFFC8F5D4))),
        ),
      ])),
    );
  }

  Widget _visTab(String label, Visibility v) {
    final sel = _vis == v;
    return Expanded(child: GestureDetector(onTap: () => _changeVis(v), child: Container(
      height: WrSize.tabH, alignment: Alignment.center,
      decoration: sel ? WrDeco.tabOn : BoxDecoration(borderRadius: BorderRadius.circular(WrR.tab), color: WrC.chipBg),
      child: Text(label, style: WrF.body(WrSize.tabFont, w: FontWeight.w700, color: sel ? Colors.white : WrC.muted)),
    )));
  }

  String _visDesc(Visibility v) {
    switch (v) {
      case Visibility.PUBLIC:
        return '모두의 소원방에도 보이고, 링크로도 들어올 수 있어요.';
      case Visibility.LINK:
        return '링크를 받은 분만 들어와 응원할 수 있어요. 모두의 소원방에는 보이지 않아요.';
      case Visibility.PRIVATE:
        return '나만 보기에서는 공유할 수 없어요. 공유하려면 공개 범위를 바꿔주세요.';
    }
  }

  Widget _shareOpt(String icon, Color bg, String label, VoidCallback onTap) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 52, height: 52, alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: bg,
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 14)]),
        child: Text(icon, style: const TextStyle(fontSize: 22))),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 11.5, color: Colors.white)),
    ]),
  ));
}

/// 복주머니 pill — app2/screens-a2.jsx › PouchPill({onClick: app.openWallet}) 1:1.
/// 탭하면 wallet_sheet.dart를 열고, 금액이 바뀔 때마다(정성·광고보상 등) 0.3초
/// bump(확대 후 복귀) 애니메이션을 재생한다.
/// [버그수정 — 전수감사] app2/screens-a2.jsx 293줄 레벨바: `background: linear-gradient(90deg,
/// var(--blossom), #ffd98a, var(--blossom)); background-size: 200% 100%; animation: shimmer
/// 2.6s linear infinite` (wr2.css `@keyframes shimmer { to { background-position: -200% 0 } }`)
/// — 단순 LinearProgressIndicator로는 이 반짝이는 그라디언트 이동 효과가 전혀 재현되지 않는다.
/// 채워진 부분(progress)만 2.6s 주기로 그라디언트가 흐르도록 CustomPaint로 1:1 재현.
class _ShimmerLevelBar extends StatefulWidget {
  const _ShimmerLevelBar({required this.progress});
  final double progress;
  @override
  State<_ShimmerLevelBar> createState() => _ShimmerLevelBarState();
}

class _ShimmerLevelBarState extends State<_ShimmerLevelBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(2))),
      FractionallySizedBox(widthFactor: widget.progress.clamp(0.0, 1.0), child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(painter: _ShimmerPainter(t: _c.value), size: Size.infinite),
      )),
    ]);
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.t});
  final double t; // 0..1, shimmer 2.6s linear infinite
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // background-size:200% 100% + background-position 0→-200% ≡ 그라디언트 폭을 2배로 두고
    // 왼쪽으로 2배 폭만큼 흘려보내는 것과 동일.
    final w = size.width * 2;
    final dx = -w * t;
    final rect = Rect.fromLTWH(dx, 0, w, size.height);
    final paint = Paint()..shader = const LinearGradient(
      colors: [WrC.blossom, Color(0xFFFFD98A), WrC.blossom],
      stops: [0, .5, 1],
    ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)), paint);
  }
  @override
  bool shouldRepaint(covariant _ShimmerPainter old) => old.t != t;
}

class _PouchPillTap extends StatefulWidget {
  const _PouchPillTap({required this.pouch});
  final int pouch;
  @override
  State<_PouchPillTap> createState() => _PouchPillTapState();
}

class _PouchPillTapState extends State<_PouchPillTap> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
  late int _prev = widget.pouch;

  @override
  void didUpdateWidget(covariant _PouchPillTap old) {
    super.didUpdateWidget(old);
    if (widget.pouch != _prev) {
      _prev = widget.pouch;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openWalletSheet(context),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          // 0→.5에서 1 → 1.18로 커졌다가 .5→1에서 다시 1로 — 원본 "bump" 느낌.
          final scale = 1 + 0.18 * (t < .5 ? (t / .5) : (1 - (t - .5) / .5));
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0x8C1E0C18), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/wishroom/items/pouch.png', width: 18, height: 18,
                errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 16))),
            const SizedBox(width: 6),
            Text('${widget.pouch}', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

/// 안내서 시트 — CHANGELOG '봉인 안내 문구' GUIDE 섹션(최소 구현).

