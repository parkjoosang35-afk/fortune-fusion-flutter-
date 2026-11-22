// SCR-03 소원방 메인 `/room` (탭1, 핵심 화면) — docs/SCREENS.md §SCR-03, CHANGELOG v2.3
// 방 장면(RoomScene) + TopBar + 레벨바 + 말풍선
// + 하단 슬림 도크(58px, 소원 한 줄 + 소원 빛깔/종이 반영) + 둥근 정성 버튼(66px, 링게이지)
// + 도크 탭 → 소원 전문 펼침 시트. §6.1(devote)/§6.2(rekindle) 연출은
// DevotionController/RekindleTimeline을 사용한다.
// app2/screens-a2.jsx › MainRoom() 1:1 이식.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/wr_canvas.dart';
import '../../../fortune/shared/presentation/attached_readings_panel.dart';
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
import '../compose/compose_screen.dart';
import '../characters/character_shop_screen.dart';
import '../characters/guardian_detail_sheet.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../decor/decor_screen.dart';
import '../notifications/notifications_screen.dart';
import 'unlock_card.dart';
import 'tour21_screen.dart';
import 'care_menu_info.dart';
import 'care_menu_info_sheet.dart';
import '../entrust/entrust_sheet.dart';
import '../entrust/received_sheet.dart';
import 'wish_edit_sheet.dart';

// [v5 S2 — CHECKLIST.md "기도 버튼 2상태 (Ø96 분홍 → Ø76 보라 「✓ 기도 완료」)"]
// app3/home.jsx 7줄 BTN3 1:1 — 둥근 기도 버튼에만 쓰는 (라벨, 아이콘) 쌍.
// RITUAL[theme].verb(= 소원 카드 "N일째 · {동사} N번"에 쓰는 명사형 "정성/기도/
// 치성/정성")와는 다른 체계로, 버튼 위에는 "~하기/~모아" 동작 지시형 문구를 쓴다.
// RITUAL.icon과 글자가 다른 테마(god: ✝→✝ 동일, buddha: 🪷→🪷 동일, shaman:
// 🙌→🙌 동일, free: 🙏→🙏 동일)라 아이콘은 재사용하고 라벨만 이 맵에서 가져온다.
const Map<String, String> kPrayBtnLabel = {
  'free': '두 손 모아',
  'god': '기도하기',
  'buddha': '절 올리기',
  'shaman': '두 손 비비기',
};

// [v5 S2] app3/home.jsx 4줄 VERB3() 1:1 — "자유 방은 '기도'로 통일" 규칙.
// 소원 카드 "N일째 · {VB} N번"과 완료 버튼 "✓ {VB} 완료"에 공통으로 쓰는
// 동사로, RITUAL[theme].verb와 달리 free 테마만 "정성" 대신 "기도"로 바뀐다
// (god/buddha/shaman은 RITUAL.verb 그대로: 기도/치성/정성).
String wrVerb(String themeId, Map<String, dynamic> ritual) =>
    themeId == 'free' ? '기도' : (ritual['verb'] as String? ?? '기도');

class MainRoomScreen extends StatefulWidget {
  const MainRoomScreen({super.key});
  @override
  State<MainRoomScreen> createState() => _MainRoomScreenState();
}

class _MainRoomScreenState extends State<MainRoomScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late DevotionController _devotion;
  // [v5 S1] 3초 hold 정성 버튼 — app3/home.jsx down()/tick()/up() 1:1 이식.
  // 버튼을 누르고 있는 동안 AnimationController로 0→1(= RULES.holdMs, 서버 기준
  // WrCatalog.I.devotionRule['holdMs'] 3000ms) 진행시키고, 끝까지 채우면 자동으로
  // _onDevote(heldMs: holdMs)를 호출한다(= 원본의 "손을 떼지 않아도 3초가 되면
  // 자동 완료"). 3초 전에 손을 떼면(onTapUp/onTapCancel) 서버에 보내지 않고 취소만
  // 한다 — "조금만 더 머물러 주세요" 피드백.
  AnimationController? _holdCtrl;
  bool _holdEarly = false; // 3초 전에 손을 뗐을 때 잠깐 보여주는 안내(app3 setEarly(true) 1:1).
  Timer? _holdEarlyTimer;
  bool _rekindling = false;
  double _rekindleBrightness = 1;
  double _rekindleBoost = 0;
  int _speechIdx = 0;
  Timer? _speechTimer;
  bool _peek = false; // '◉ 방만 보기'
  // [v2.1 §14.4 "웹의 설정 버튼과 안내 문구" — "내 소원방" / "움직임 재생·정지"]
  // 웹에서만 노출되는 애니메이션 재생/정지 토글. true가 되면 RoomScene에
  // frozen을 전달해 L2~L7 동적 레이어(촛불·호흡·파티클 등)를 멈춘다. 앱
  // (Android/iOS)에는 이 버튼 자체가 보이지 않는다 — 웹 전용 감상 기능이며,
  // "웹이 정지라도 다른 기기의 앱 설정을 임의로 변경하지 않는다"(§13.1
  // 접근성·정지 모드 행)는 원칙대로 이 상태는 로컬(이 탭) 한정이고 서버에
  // 저장하지 않는다.
  bool _webPaused = false;
  bool _wishOpen = false; // 소원 전문 펼침
  // devote() 0.0/0.7/1.1 단계에서 주입하는 1회성 FX 오버레이(WrBurst/WrPetalRain/WrButterflies 등).
  final List<_FxEntry> _fx = [];
  // devote() 1.7(RITUAL.done) · 2.3(말씀카드) · rekindle() 2.1(n일만에 다시밝아졌어요) 캡션.
  String? _capText;
  (String, String)? _quoteText; // (문장, 출처) — 빈 출처는 ''
  // [v5 S2 — 대표 판정 "1일 · 기도 완료 카드 vs 보상 시트 → 고침: 카드 1장으로
  // 합칩니다. 오늘의 한마디 + 🧧+5 + [마음에 담기]. 보상 시트를 따로 띄우지
  // 마세요"] app3/home.jsx DoneCard() 1:1 — 원본은 말씀(q)·통계(dayN·prayedN)·
  // 보상(reward)·닫기버튼이 애초에 카드 1장이었다. Flutter는 onQuote(2.3s)에
  // 말씀만 먼저 띄우고 onDone(2.9s)에 별도 _reward 오버레이를 또 띄우는
  // 2장짜리 구조였던 걸 고친다 — onDone에서는 새 오버레이를 만들지 않고, 이미
  // 떠 있는 같은 말씀카드(_quoteText)에 아래 _devoteDone 데이터만 채워 넣는다
  // (카드는 1장 그대로, 0.6초 뒤 하단에 통계+보상+버튼이 나타나는 것처럼 보임).
  (int dayN, int prayedN, int bonus, bool streak)? _devoteDone;
  DevotionGain? _lastGain; // 0.7 단계 아이템 기운 보너스 pill(top 236)
  // rekindle() 3.4s 보상시트 전용(다시 밝히기는 기도 완료 카드와 다른 순간이라
  // 그대로 분리 유지 — 대표 판정 범위는 "1일 · 기도 완료 카드"에 한정됨).
  // [명세] 원본 jsx `{reward && <RewardSheet.../>}`는 quote와 독립적인 state라
  // 동시에 공존 가능(quote z-index:95가 reward dim/sheet z-index:88/89보다 위에
  // 겹쳐 보임). showModalBottomSheet(별도 Route)로는 이 레이어링을 재현할 수
  // 없어 Stack 내부 오버레이로 구현한다.
  Map<String, dynamic>? _reward; // {title, sub, body, chips} — rekindle() 전용
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
  // [J6 Tour21] app3/home.jsx DoneCard.onClose `firstTime = prayedN===1 &&
  // !toured && !realFirst` 1:1 — 생애 첫 기도였는지를 devote() onDone에서 미리
  // 계산해 두고, 보상시트(_reward)가 닫힐 때(= 원본 DoneCard.onClose 훅 포인트)
  // Tour21을 띄운다. GuidePrefs.I.tour21Done으로 "한 번이라도 봤으면 다시 안 뜸"을 보장.
  bool _firstTimeAfterPray = false;
  bool _tour21 = false;

  @override
  void initState() {
    super.initState();
    // [§6 WishAction 드레인] 앱이 포그라운드로 돌아올 때마다(onboarding →
    // 내 소원방이 아니라, 홈 조작판에서 치성을 남기고 다시 앱을 연 "복귀"
    // 시점) 조작판 위젯이 쌓아 둔 행동을 서버로 전송한다.
    WidgetsBinding.instance.addObserver(this);
    final p = context.read<WishRoomProvider>();
    _devotion = DevotionController(p.repo);
    // [버그수정 — 전수 감사로 발견] DevotionController는 ChangeNotifier인데 아무도
    // addListener하지 않아 devote() 타임라인이 phase를 바꿔도(notifyListeners) 화면이
    // 전혀 다시 그려지지 않았다(흔들림·광원boost가 RoomScene에 반영되지 않는 버그).
    _devotion.addListener(() {
      if (mounted) setState(() {});
    });
    if (p.room == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadMyRoom());
    }
    if (p.catalogLoaded == false) p.loadCatalog();
    // S-07(레벨업 안내)이 w.isSet/seenLevelNotice를 판단하려면 wallpaperStatus가
    // 미리 로드돼 있어야 한다 — 레벨업 시점에 처음 불러오면 그 사이 안내를 놓친다.
    p.loadWallpaperStatus();
    // app2/guide2.jsx › hintsOn()/seenSet()/wr_tour_done — localStorage 로딩을
    // shared_preferences 비동기 로딩으로 대체(GuidePrefs). [v5 S2] FirstVisitChip
    // 노출은 제거했지만 GuidePrefs 값(하단바 N배지·메뉴 안내 1회성 등)은 이 화면의
    // 다른 위젯도 참조하므로 로딩 자체는 유지한다.
    GuidePrefs.I.load().then((_) {
      if (mounted) setState(() {});
    });
    _speechTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _speechIdx++);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _devotion.dispose();
    _speechTimer?.cancel();
    _holdCtrl?.dispose();
    _holdEarlyTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // [§6 "다음 실행·허용된 백그라운드 작업에서 읽어 전송"] 홈 조작판에서
    // 치성을 남긴 뒤 앱으로 돌아온 시점(resumed)마다 네이티브 WishAction
    // 큐를 드레인한다 — "앱을 한 번도 열지 않으면 기록이 사라진다"는
    // 실패를 막기 위한 두 번째 진입점(첫 번째는 loadMyRoom() 성공 직후).
    if (state == AppLifecycleState.resumed) {
      context.read<WishRoomProvider>().drainPendingWishActions();
    }
  }

  /// [v5 S1] 정성 버튼 누름 시작 — app3/home.jsx `down(e)` 1:1. 오늘 이미
  /// 기도했거나(prayedToday) 연출 중이면 무시. holdMs(기본 3000ms, 서버
  /// WrCatalog.I.devotionRule['holdMs'])에 걸쳐 0→1로 진행시키고, 끝까지
  /// 채워지면(AnimationStatus.completed) 자동으로 _onDevote(heldMs: holdMs)를
  /// 호출한다.
  void _onHoldDown(WishRoom room) {
    if (room.devotionsToday >= 1 || _devotion.busy || _rekindling) return;
    _holdEarlyTimer?.cancel();
    setState(() => _holdEarly = false);
    final holdMs =
        (WrCatalog.I.devotionRule['holdMs'] as num?)?.toInt() ?? 3000;
    _holdCtrl?.dispose();
    final ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: holdMs),
    );
    _holdCtrl = ctrl;
    HapticFeedback.lightImpact();
    // 링게이지(_bottomDock deg)·방 boost·말풍선 문구가 매 프레임 진행률을
    // 반영해야 하므로 틱마다 setState (app3 tick()의 setProg(p) 1:1).
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    ctrl.forward();
    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _holdCtrl == ctrl) {
        _onDevote(heldMs: holdMs);
      }
    });
    setState(() {});
  }

  /// 정성 버튼에서 손을 떼거나(onTapUp) 벗어남(onTapCancel) — app3 `up()` 1:1.
  /// 3초를 채우기 전에 떼면 서버로 보내지 않고 취소만 하고 "조금만 더 머물러
  /// 주세요" 안내를 짧게 보여준다.
  void _onHoldUp() {
    final ctrl = _holdCtrl;
    if (ctrl == null || ctrl.status == AnimationStatus.completed) return;
    final wasProgressing = ctrl.value > 0;
    ctrl.stop();
    ctrl.reset();
    _holdCtrl = null;
    if (wasProgressing) {
      _holdEarlyTimer?.cancel();
      setState(() => _holdEarly = true);
      _holdEarlyTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _holdEarly = false);
      });
    } else {
      setState(() {});
    }
  }

  void _addFx(Widget w, {int life = 2600}) {
    final key = UniqueKey();
    setState(() => _fx.add(_FxEntry(key, w)));
    Timer(Duration(milliseconds: life), () {
      if (mounted) setState(() => _fx.removeWhere((e) => e.key == key));
    });
  }

  /// A-4 `devote()` 타임라인 — 0.0 shake+wash+촛불 링3+금빛버스트26+꽃잎버스트10 ·
  /// 0.3 boost1 · 0.7 버스트18+빛나선26+`+1 {verb}`+아이템 기운 보너스 ·
  /// 1.1 꽃잎22+나비4 · 1.7 boost2+wash2s+RITUAL.done · 2.3 말씀카드 · 2.9 끝.
  ///
  /// [v5 S1] heldMs — 정성 버튼을 실제로 누르고 있던 시간(ms, app3/home.jsx
  /// `performance.now() - t0.current` 1:1). _onHoldDown/_onHoldUp이 측정해 넘긴다.
  Future<void> _onDevote({int? heldMs}) async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null || _devotion.busy) return;
    setState(() {
      _capText = null;
      _quoteText = null;
      _lastGain = null;
    });
    if (kDebugMode) {
      debugPrint(
        '[WR_STATE] _onDevote start → _capText=$_capText _quoteText=$_quoteText _devoteDone=$_devoteDone',
      );
    }
    final cat = WrCatalog.I;
    final ritual = cat.ritual(room.theme);
    final verb = wrVerb(room.theme.name, ritual);
    await _devotion.devote(
      room.id,
      heldMs: heldMs,
      // t0.0 — 화면전체 금빛 wash 1.2s + 촛불 링3개(140px, 0/.15/.3s 스태거) +
      // 금빛 버스트26(spread190,1.4s) + 꽃잎 버스트10(glyph). app2/screens-a2.jsx devote() 230-234줄 1:1.
      onShakeBurst: () {
        debugPrint('WR_PHASE devote.shake');
        _addFx(
          Stack(
            children: const [
              WrWash(),
              WrCandleRings(x: 204, y: 330),
              WrBurst(
                x: 204,
                y: 330,
                n: 26,
                spread: 190,
                dur: 1400,
                color: Color(0xFFFFE7A0),
              ),
              WrBurst(
                x: 204,
                y: 330,
                n: 10,
                spread: 120,
                dur: 1600,
                glyph: '🌸',
              ),
            ],
          ),
          life: 1800,
        );
      },
      // t0.7 — 버스트18(spread130) + 빛나선26(Spiral) + `+1 {verb}`(plus-up) +
      // 정성 아이템별 fly-to(링+빛알갱이가 촛불로 날아감). 240-248줄 1:1.
      onItemBurst: (gain) {
        debugPrint('WR_PHASE devote.burst2');
        setState(() => _lastGain = gain);
        final fxItems = (gain?.fx ?? const <DevotionGainItem>[])
            .where((f) => f.type == 'devo')
            .toList();
        final cat2 = WrCatalog.I;
        final p2 = context.read<WishRoomProvider>();
        final flyWidgets = <Widget>[];
        for (var i = 0; i < fxItems.length; i++) {
          final f = fxItems[i];
          final it = cat2.items.where((x) => x.id == f.id).firstOrNull;
          if (it == null) continue;
          final at = focusOf(it, room.equip, p2.items, room.layout);
          flyWidgets.add(
            _FlyToCandle(
              from: at,
              to: const Offset(204, 330),
              delayMs: 100 + i * 120,
            ),
          );
        }
        _addFx(
          Stack(
            children: [
              WrBurst(
                x: 204,
                y: 330,
                n: 18,
                spread: 130,
                color: const Color(0xFFFFE08A),
              ),
              const WrSpiral(x: 204, y: 330),
              _PlusUpText(text: '+1 $verb'),
              ...flyWidgets,
            ],
          ),
          life: 1800,
        );
        if (gain != null && gain.bonus > 0) {
          Timer(const Duration(milliseconds: 1800), () {
            if (mounted) setState(() => _lastGain = null);
          });
        }
      },
      onPetalButterfly: () {
        debugPrint('WR_PHASE devote.petal');
        _addFx(
          Stack(
            children: const [
              WrPetalRain(n: 22, dur: (2.0, 3.0), spread: .8),
              WrButterflies(x: 204, y: 380),
            ],
          ),
          life: 3200,
        );
      },
      // t1.7 — boost2 + 화면 wash 2s(강) + RITUAL.done 캡션(cap 블러해제 2.4s). 251줄 1:1.
      onWashDone: () {
        debugPrint('WR_PHASE devote.boost2');
        _addFx(const WrWash(strong: true, durMs: 2000), life: 2000);
        setState(() => _capText = ritual['done'] as String? ?? '');
        if (kDebugMode) {
          debugPrint(
            '[WR_STATE] onWashDone(1.7s) → _capText=$_capText _quoteText=$_quoteText _devoteDone=$_devoteDone',
          );
        }
      },
      onQuote: () {
        debugPrint('WR_PHASE devote.quote');
        final quotes = (ritual['quotes'] as List? ?? const []).cast<List>();
        if (quotes.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[WR_STATE] onQuote(2.3s) → quotes EMPTY for theme=${room.theme}, skip setting _quoteText!',
            );
          }
          return;
        }
        final pick = quotes[math.Random().nextInt(quotes.length)];
        final text = pick[0] as String;
        final src = pick.length > 1 ? (pick[1] as String? ?? '') : '';
        setState(() => _quoteText = (text, src));
        if (kDebugMode) {
          debugPrint(
            '[WR_STATE] onQuote(2.3s) → _capText=$_capText _quoteText=$_quoteText _devoteDone=$_devoteDone',
          );
        }
      },
      onDone: (res) {
        debugPrint('WR_PHASE devote.end');
        // [명세] 원본 jsx T(2900,...)는 setQuote(null)을 호출하지 않음 — 말씀 카드는
        // 사용자가 직접 탭해서 닫을 때까지 화면에 남아있어야 함(_quoteText는 지우지 않음).
        setState(() {
          _capText = null;
          _lastGain = null;
        });
        if (kDebugMode) {
          debugPrint(
            '[WR_STATE] onDone(2.9s) after capText reset → _capText=$_capText _quoteText=$_quoteText _devoteDone=$_devoteDone leveledUp=${res.leveledUp}',
          );
        }
        p.applyDevotionResult(res);
        // [J6 Tour21] app3/home.jsx `cur.prayedN === 1 && !cur.toured && !cur.realFirst`
        // 1:1 — Flutter에는 toured/realFirst 대응 필드가 없으므로(서버 스키마 부재),
        // GuidePrefs.I.tour21Done(로컬 1회성 플래그, 원본 realFirst와 동등 역할)으로
        // 대체한다. prayedN==1이면서 아직 Tour21을 본 적 없을 때만 생애 첫 기도로 간주.
        _firstTimeAfterPray =
            res.room.prayedN == 1 && !GuidePrefs.I.tour21Done;
        if (res.leveledUp) {
          _showLevelUp(res.room.level);
        } else {
          // [v5 S2 — 대표 판정 "카드 1장으로 합칩니다" / "보상 숫자 확인"] app3/home.jsx
          // DoneCard() 1:1 — 별도 보상 오버레이(_reward)를 새로 띄우지 않고, onQuote에서
          // 이미 뜬 말씀카드(_quoteText)에 통계(🕯dayN·🙏prayedN)+🧧보상 칩을 추가로
          // 채워 넣는다. 🧧 숫자는 res.bonus(스트릭 보너스분만, 평소엔 0)가 아니라
          // res.pouchEarned(이번 기도로 실제 적립된 합계 — 평소 +5, 7일째 +25)를
          // 써야 한다. 4번째 요소(streak 칩 노출 여부)는 7일째인지(res.bonus>0)로 그대로 판정.
          setState(
            () => _devoteDone = (
              res.room.dayN,
              res.room.prayedN,
              res.pouchEarned,
              res.bonus > 0,
            ),
          );
          if (kDebugMode) {
            debugPrint(
              '[WR_STATE] onDone(2.9s) set _devoteDone → _capText=$_capText _quoteText=$_quoteText _devoteDone=$_devoteDone',
            );
          }
        }
      },
      onError: (e) {
        // [v5 S1] 서버 코드 변경(app3/flow.js pray() 1:1): COOLDOWN/DAILY_LIMIT →
        // ALREADY_TODAY(429, 오늘 이미 기도함) · HOLD_SHORT(400, 3초 미만 hold).
        if (e.code == 'ALREADY_TODAY') {
          WrToast.show(context, '오늘의 기도는 이미 올렸어요');
        } else if (e.code == 'HOLD_SHORT') {
          WrToast.show(context, '조금만 더 머물러 주세요');
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
    setState(() {
      _rekindling = true;
      _rekindleBrightness = .06;
      _rekindleBoost = 0;
    });
    // t0.6 — 주황 버스트12(x:204,y:318,spread:50,.9s) + 심지 불씨 16px pop(.6s 오버슛).
    // app2/screens-a2.jsx rekindle() 218줄 1:1(기존엔 좌표/spread/dur 불일치 + 불씨 pop 누락).
    Timer(RekindleTimeline.spark, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.spark');
      setState(() => _rekindleBrightness = .14);
      _addFx(
        Stack(
          children: const [
            WrBurst(
              x: 204,
              y: 318,
              n: 12,
              spread: 50,
              color: Color(0xFFFFB060),
              dur: 900,
            ),
            _WickEmber(x: 204, y: 318),
          ],
        ),
        life: 1400,
      );
    });
    // t1.3 — 빛나선30(Spiral) + 900px 빛번짐(WrLightRing, ring 2.2s). 219줄 1:1
    // (기존엔 전혀 다른 WrBurst(n:30,spread:220)로 대체돼 있었음 — 명세 위반).
    Timer(RekindleTimeline.grow, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.grow');
      setState(() {
        _rekindleBrightness = .7;
        _rekindleBoost = 1;
      });
      _addFx(
        Stack(
          children: const [
            WrSpiral(n: 30, x: 204, y: 330),
            WrLightRing(x: 204, y: 330),
          ],
        ),
        life: 2600,
      );
    });
    Timer(RekindleTimeline.bloom, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.bloom');
      setState(() {
        _rekindleBrightness = 1;
        _rekindleBoost = 2;
        _capText = '$absentDays일 만에 촛불이 다시 밝아졌어요';
      });
      _addFx(
        Stack(
          children: const [
            WrPetalRain(n: 28, dur: (2.2, 3.4), spread: 1),
            WrButterflies(x: 204, y: 380),
            WrBurst(
              x: 204,
              y: 330,
              n: 24,
              spread: 180,
              color: Color(0xFFFFE08A),
            ),
          ],
        ),
        life: 3200,
      );
    });
    final ok = await p.rekindle(room.id);
    Timer(RekindleTimeline.end, () {
      if (!mounted) return;
      debugPrint('WR_PHASE rekindle.end');
      setState(() {
        _rekindling = false;
        _rekindleBoost = 0;
        _capText = null;
      });
      if (ok) {
        setState(() => _justRekindled = true);
        Timer(const Duration(seconds: 8), () {
          if (mounted) setState(() => _justRekindled = false);
        });
        setState(
          () => _reward = {
            'title': '촛불이 다시 환해졌어요',
            'sub': 'REKINDLED · 100%',
            'body': '$absentDays일 동안 소원방이 당신을 기다렸어요',
            'chips': const ['촛불 밝기 100%', '빛가루 +1'],
          },
        );
      } else {
        // [전수검수 2026-10-12 — MAJOR] 재점화가 서버에서 거부됐을 때 피드백이
        // 전혀 없어 연출만 "밝아졌다가" 원상복귀됐다 — 실패 안내를 추가한다.
        if (mounted) {
          final err = context.read<WishRoomProvider>().lastError;
          WrToast.show(context, err?.message ?? '재점화에 실패했어요 · 잠시 후 다시 시도해주세요');
        }
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
    final showWpNotice =
        w.isSet &&
        room != null &&
        w.roomId == room.id &&
        w.seenLevelNotice < lv;
    if (showWpNotice) p.wallpaperLevelNotice(lv);
    setState(() {
      _levelUp = lv;
      _levelUpWpNotice = showWpNotice
          ? (w.platform == 'ios'
                ? '소원방이 자랐어요. 배경화면을 새로 만들 수 있어요'
                : '소원방이 자랐어요. 배경화면에도 반영돼요')
          : null;
    });
  }

  void _openCareSheet(WishRoom room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CareSheet(
        room: room,
        openGuide: _openGuide,
        openShare: () => _openShareSheet(room),
        // [v2.1 §14.4] 웹 전용 "움직임 줄이기" — 기존 pauseBtn과 동일한
        // _webPaused 플래그를 그대로 토글한다(서버 저장 없음, 이 화면
        // 로컬 상태). 사용자 지시: "휴대폰의 동작 줄이기 설정도 따르게
        // 한다" — MediaQuery.disableAnimations(OS 접근성 설정)가 true면
        // 이미 움직임이 줄어든 상태이므로 토글 기본값도 그에 맞춘다.
        webPaused: _webPaused,
        onToggleWebPaused: (v) => setState(() => _webPaused = v),
      ),
    );
  }

  void _openShareSheet(WishRoom room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareSheet(room: room),
    );
  }

  // app2/capsule2.jsx › UnsealBanner onOpen / screens-a2.jsx capOpen=true 1:1.
  // CapsuleOpenScreen은 자체 Scaffold를 갖는 전체화면이라 push로 띄우고, 닫히면(pop)
  // room.capsuleDue/outcome이 서버에서 갱신됐을 수 있으므로 reloadRoom(loadMyRoom) 한다.
  Future<void> _openCapsule(WishRoom room) async {
    setState(() => _capOpen = true);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CapsuleOpenScreen(room: room)));
    if (!mounted) return;
    setState(() => _capOpen = false);
    context.read<WishRoomProvider>().loadMyRoom();
  }

  // app2/guide2.jsx › app.openGuide(focus) 1:1 — focus를 펼친 채로 안내서를 연다.
  // room이 있을 때만(= 메인화면 안내서 버튼) "한 바퀴 둘러보기" 버튼을 함께 보여준다.
  void _openGuide([String? focus]) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GuideBook(
        focus: focus,
        onStartTour: () => setState(() => _tour = true),
      ),
    );
  }

  // app2/fx2.jsx › NavPill onBack=app.back · onExitHome=app.exitHome 1:1.
  // 홈은 WishRoomShell의 탭 루트(= push된 화면 없음)이므로 뒤로가기를 누르면
  // 항상 "신통방통 홈으로 갈까요" 확인시트가 뜬다(원본 exitAsk와 동일).
  void _onBack() => wrBackOrAskExit(context);
  void _onExitHome() => wrExitHome(context);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: Consumer<WishRoomProvider>(
          builder: (context, p, __) {
            final room = p.room;
            if (room == null) {
              // [버그수정 — 사용자 리포트: "비로그인 상태에서 다른 소원방 둘러보기 →
              // 내 소원방 탭 클릭 시 안내창 없이 로딩만 영원히 돎"] 기존 코드는
              // loadMyRoom()의 로딩 진행 중/완료 상태를 구분하지 않고 room==null이면
              // 무조건 CircularProgressIndicator만 보여줬다. 비로그인(게스트) 사용자는
              // 서버에 애초에 내 소원방이 없으므로(loadMyRoom()이 정상 응답해도
              // res.room이 null) 로딩이 끝난 뒤에도 room은 영원히 null로 남아
              // "로딩 스피너가 멈추지 않는 것처럼 보이는" 버그였다(실제로는 로딩이
              // 끝났지만 그 사실을 알려줄 분기가 없었을 뿐). loadMyRoom()이 아직
              // 끝나지 않았을 때만(p.isLoading && !p.loaded) 스피너를 보여주고,
              // 로딩이 끝났는데도 room이 없으면(게스트이거나 서버 오류) decor_screen.dart
              // _NoRoom과 동일한 패턴으로 안내 문구 + "첫 소원 담기" CTA를 보여준다.
              if (p.isLoading && !p.loaded) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF5CF6A)),
                );
              }
              return _NoRoomMain(onBack: _onBack, onExitHome: _onExitHome);
            }
            final cat = WrCatalog.I;
            final isDim =
                room.decayBadge && room.brightness < 1 && !_rekindling;
            final effBrightness = _rekindling
                ? _rekindleBrightness
                : room.brightness;
            // [v5 S1] app3/home.jsx `prog > .02 ? (prog > .6 ? 2 : 1) : done ? 2 : 0` 1:1 —
            // hold 진행률(0→1)에 따라 촛불 광원이 단계적으로 커진다.
            final holdProg = _holdCtrl?.value ?? 0.0;
            final boost = _devotion.busy
                ? _devotion.roomBoost
                : holdProg > .02
                ? (holdProg > .6 ? 2.0 : 1.0)
                : _rekindleBoost;
            // [v5 S1] dailyLimit은 이제 하루 1회 — done(오늘 기도 완료)은
            // devotionsToday>=1 하나로 판정한다(구 10회 카운터 폐기).
            final done = room.devotionsToday >= 1;
            final holding = _holdCtrl != null;
            final double deg = holding
                ? holdProg * 360
                : done
                ? 360.0
                : 0.0;
            final ritual = cat.ritual(room.theme);

            // app2/guide2.jsx › GuideBook "한 바퀴 둘러보기"를 꾸미기/보관함 등 다른 탭에서
            // 눌렀을 때: WishRoomShell이 먼저 이 탭(홈)으로 전환해두고, 여기서 실제 투어를 켠다.
            if (p.tourRequested) {
              p.consumeTourRequest();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _tour = true);
              });
            }

            return Stack(
              children: [
                Positioned.fill(
                  key: const ValueKey('roomScene'),
                  child: WrCanvasScaler(
                    // [필러박싱 버그 수정 — 사용자 리포트 "내 소원방 화면 좌우 비대칭"]
                    // 웰컴 화면과 동일 원인: 844 전체 기준으로 배율을 잡으면 실기기
                    // 뷰포트(제스처바 제외 실측)가 844보다 짧아 좌우에 불필요한
                    // 여백이 생긴다. 이 화면의 실제 콘텐츠 최하단은 정성 버튼
                    // (top:690, 최대 지름 96 → 786)까지이고, 다른 오버레이(투어21
                    // 완료 카드 등)의 하단 여유까지 고려해 14px 버퍼를 더한
                    // contentHeight:800으로 배율을 끌어올린다 —
                    // 8곳의 WrCanvasScaler(룸·FX·오버레이·투어·레벨업 등)가 전부 같은
                    // 좌표계를 공유하므로 반드시 동일한 값을 함께 적용해야 한다.
                    contentHeight: 800,
                    child: GestureDetector(
                      onTap: _peek ? () => setState(() => _peek = false) : null,
                      child: RoomScene(
                        room: _withBrightness(room, effBrightness),
                        items: p.items,
                        pray: _devotion.busy || holding,
                        boost: boost,
                        shake: _devotion.shaking,
                        // [v5 S2 — 대표 지시 "1일째 방에 수호자(하린)와 말풍선이 보임,
                        // 기획에서는 1일째엔 수호자가 없고 2일째 열릴 때 처음 나타나야
                        // 함"] app3/home.jsx `showG = v.open('guardian')` /
                        // `hideChar={!showG || ...}` 1:1 — guardian 탭이 아직 안 열렸으면
                        // (dayN<2 또는 기도 0번) 캐릭터 자체를 방에 그리지 않는다.
                        hideChar: !room.isFeatureUnlocked('guardian'),
                        // §14.4 "움직임 재생·정지" — 웹에서만 사용자가 로컬로 정지할 수
                        // 있다. 앱 빌드에서는 _webPaused가 항상 false로 고정되어 기존
                        // 동작(정성·흔들림 등 실시간 연출)에 영향이 없다.
                        frozen: kIsWeb && _webPaused,
                        // [Stage 3-B — 대표 판정 "3. 방에서 수호자를 누르면 옷장 대신
                        // 자세히 시트가 열리도록 바꿉니다"] 3-A까지는 자세히 화면이
                        // 없어 임시로 옷장을 열었으나, 이제 guardian_detail_sheet.dart의
                        // 정식 「수호자 자세히」 시트로 연결한다.
                        // '◉ 방만 보기'(_peek) 중이거나 수호자가 아직 숨겨진 상태
                        // (hideChar)에서는 탭할 대상이 없으므로 콜백을 주지 않는다.
                        onTapGuardian: (_peek || !room.isFeatureUnlocked('guardian'))
                            ? null
                            : () => showGuardianDetailSheet(context, room.char),
                      ),
                    ),
                  ),
                ),
                // devote()/rekindle() 1회성 FX 오버레이(버스트·꽃잎비·나비 등) — WrCanvasScaler로
                // 390×844 좌표계를 맞춰야 WrBurst(x:204,y:330) 등 절대좌표가 room과 일치한다.
                // [버그수정 — 3초 hold 취소 버그, 바깥쪽 Stack 방어적 Key 추가] 이 바깥쪽
                // Stack도 안쪽과 동일하게 조건부(if) 자식들로 구성돼 있어, hold 도중 _fx가
                // 바뀌거나 다른 오버레이가 토글되면 같은 Element 재사용 문제가 재발할 수
                // 있다 — 모든 직계 자식에 고유 Key를 줘서 원천 차단한다.
                if (_fx.isNotEmpty)
                  Positioned.fill(
                    key: const ValueKey('fxOverlay'),
                    child: IgnorePointer(
                      child: WrCanvasScaler(
                        contentHeight: 800,
                        child: SizedBox(
                          width: 390,
                          height: 844,
                          child: Stack(
                            children: [
                              for (final e in _fx)
                                KeyedSubtree(key: e.key, child: e.widget),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_peek)
                  SafeArea(
                    key: const ValueKey('mainOverlay'),
                    child: WrCanvasScaler(
                      contentHeight: 800,
                      child: Stack(
                        children: [
                          // TopBar — app2/fx2.jsx › TopBar({nav=true, right}) 1:1: 좌측 NavPill(뒤로가기+
                          // 신통방통 홈), 우측 PouchPill. [버그수정 — 전수감사] 기존엔 NavPill이 전체
                          // 화면 어디에도 없었고 PouchPill이 좌측에 있었다(원본은 우측).
                          Positioned(
                            key: const ValueKey('navPill'),
                            top: 52,
                            left: 14,
                            child: Row(
                              children: [
                                WrNavPill(
                                  onBack: () => _onBack(),
                                  onExitHome: () => _onExitHome(),
                                ),
                                const SizedBox(width: 6),
                                // [v5 S2 — 매핑표 05-D #11 "알림 탭 (05) → 하단바에서 제거 →
                                // 상단 ⋯ 또는 홈 상단 벨로 이동 (알림 화면 자체는 유지)" /
                                // CHECKLIST.md "하단바 6칸 … (알림 → 상단 🔔)"] ⋯ 메뉴는 이미
                                // 10줄+그밖에2줄로 포화 상태라, 매핑표가 제시한 두 선택지 중
                                // "홈 상단 벨"을 택해 좌측 NavPill 옆에 44px 원형 벨 버튼을
                                // 둔다(우측 [👁][🧧][⋯] 3버튼 Row는 B안 그대로 손대지 않음).
                                _bellBtn(p.unreadCount),
                              ],
                            ),
                          ),
                          const Positioned(
                            key: ValueKey('titleText'),
                            top: 58,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Text(
                                '내 소원방',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          // [v5 S2 — 사용자 확정] 레벨/통계 카드(레벨바) 제거.
                          // 진행 상황은 소원 카드("N일째·기도N번")와 보관함에서 보여준다.
                          // 레벨업 연출(WrLevelUp 시네마틱)은 그대로 유지한다.
                          // [v5 S2 — CHECKLIST.md "상단 오른쪽 [👁 방만 보기] [⋯] · 🧧 잔액은
                          // 3일째부터" / 사용자 확정 B안 "상단 우측 최종 모습 1~2일째: [👁 방만
                          // 보기][⋯] 2개, 3일째부터: [👁 방만 보기][🧧 잔액][⋯] 3개"] 기존
                          // guideBtn(안내서)·shareBtn(공유)·pauseBtn(움직임 정지) 3개 알약은
                          // 모두 제거하고 ⋯ 메뉴(_CareSheet, 곧 "소원방 돌보기" 10줄 메뉴)
                          // 「그 밖에」로 흡수한다(안내서→소원방 쓰는 법, 공유→함께 빌어달라고
                          // 하기 Row와 통합, 움직임 정지→움직임 줄이기 토글). 우상단은
                          // app3/home.jsx 60~66줄처럼 한 줄(Row)로 재배치한다 — 원본은 44px
                          // 원형 버튼+복주머니 알약+⋯ 44px 원형 버튼 순서.
                          if (!_devotion.busy && !_rekindling)
                            Positioned(
                              key: const ValueKey('topRightRow'),
                              top: 52,
                              right: 14,
                              child: Row(
                                children: [
                                  _circleBtn(
                                    Icons.remove_red_eye_outlined,
                                    () => setState(() => _peek = true),
                                  ),
                                  if (room.isFeatureUnlocked('decor')) ...[
                                    const SizedBox(width: 6),
                                    _pouchPill(p.me?.pouch ?? 0),
                                  ],
                                  const SizedBox(width: 6),
                                  _careBtn(room),
                                ],
                              ),
                            ),
                          // [v5 S2 — 대표 지시 "상단 「처음 오셨나요 · 소원방 한 바퀴
                          // 둘러보기」 칩이 모든 날짜에 남아 있음, v5에서는 이 칩을 없애고
                          // 아침 인사 카드와 21일 미리보기로 대신한다"] 매핑표 00-A
                          // "① 함께 빌기=응원 … ⑥ 아침 인사 = 기존 첫 방문 칩 대체"에
                          // 맞춰 FirstVisitChip 노출을 제거한다. 아침 인사 카드(A13)·
                          // 21일 미리보기(A3~A11) 신규 구현은 S3 이후 별도 작업이며,
                          // 투어 진입로(⋯ 메뉴 → 소원방 쓰는 법 → 한 바퀴 둘러보기)는
                          // 유지하므로 _tour 상태 자체는 그대로 둔다.
                          // 말풍선 — app3/home.jsx `showG && ... && bubble` 1:1. 캐릭터가
                          // 숨겨진 1일째(guardian 미열림)엔 말풍선도 같이 숨긴다([v5 S2 —
                          // 대표 지시] 수호자 숨기기와 세트).
                          if (room.isFeatureUnlocked('guardian'))
                            Positioned(
                              key: const ValueKey('speechBubble'),
                              left: 14,
                              top: 400,
                              child: GestureDetector(
                                onTap: () => setState(() => _speechIdx++),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 220,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xF0FFFAF4),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x59000000),
                                        blurRadius: 20,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _speechText(room, ritual, holdProg, isDim),
                                    style: const TextStyle(
                                      color: Color(0xFF5A2A36),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // 머금는 동안(3초 hold 진행 중)의 기도문
                          if (holding)
                            Positioned(
                              key: const ValueKey('prayLine'),
                              left: 16,
                              right: 16,
                              top: 640,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x8C1E0A18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0x40FFC8A0),
                                    ),
                                  ),
                                  child: Text(
                                    _prayLine(ritual, holdProg),
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFFFFF4E0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // devote() 0.7s — 아이템 기운 보너스 pill(top 236) `✦ 아이템 기운 +n%` + 아이템별 칩 최대 4개.
                          if (_lastGain != null && _lastGain!.bonus > 0)
                            Positioned(
                              key: const ValueKey('gainPill'),
                              left: 0,
                              right: 0,
                              top: 236,
                              child: Center(child: _GainPill(gain: _lastGain!)),
                            ),
                          // devote() 1.7s RITUAL.done(`cap 2.4s`, 15px) / rekindle() 2.1s `{n}일 만에
                          // 다시 밝아졌어요`(`cap 2.6s`, 19px) — top 520/500 캡션. cap: 블러해제 페이드.
                          if (_capText != null)
                            Positioned(
                              key: ValueKey('capText_$_capText'),
                              left: 20,
                              right: 20,
                              top: _rekindling ? 500 : 520,
                              child: Center(
                                child: _CapText(
                                  text: _capText!,
                                  fontSize: _rekindling ? 19 : 15,
                                  durMs: _rekindling ? 2600 : 2400,
                                ),
                              ),
                            ),
                          // ── 하단 슬림 도크(58px) + 둥근 정성 버튼(66px) ──
                          Positioned(
                            key: const ValueKey('bottomDock'),
                            left: 12,
                            right: 12,
                            top: 690,
                            child: _bottomDock(
                              room: room,
                              cat: cat,
                              isDim: isDim,
                              busy: holding,
                              done: done,
                              deg: deg,
                              ritual: ritual,
                            ),
                          ),

                          // rekindle() 3.4s 전용 보상시트 — [명세] quote보다 먼저(=아래) 배치해
                          // quote(z95)가 이 위에 겹쳐 보이는 원본 레이어링(dim z88/sheet z89 < quote z95)을 재현.
                          // [v5 S2 — 대표 판정] devote()(일반 기도 완료)는 더 이상 이 오버레이를
                          // 쓰지 않는다 — _reward는 rekindle()에서만 설정된다.
                          if (_reward != null)
                            Positioned.fill(
                              key: const ValueKey('rewardOverlay'),
                              child: _RewardOverlay(
                                data: _reward!,
                                onClose: () => setState(() => _reward = null),
                              ),
                            ),
                          // [v5 S2 — 대표 판정 "기도 완료 카드 하나로 합치기"] devote() 2.3s
                          // 말씀 카드(RITUAL.quotes 랜덤 1개, 테마별 디자인) + 2.9s 통계/보상
                          // (_devoteDone이 채워지면 카드 안에 함께 나타남) — 탭하면 카드 전체가
                          // 닫힌다. app3/home.jsx DoneCard() 1:1(말씀+🕯dayN+🙏prayedN+🧧bonus+
                          // "마음에 담기" 버튼이 카드 1장).
                          if (_quoteText != null)
                            Positioned.fill(
                              key: const ValueKey('quoteCard'),
                              child: _QuoteCard(
                                text: _quoteText!.$1,
                                src: _quoteText!.$2,
                                theme: room.theme,
                                icon: ritual['icon'] as String? ?? '✿',
                                verb: wrVerb(room.theme.name, ritual),
                                done: _devoteDone,
                onClose: () => setState(() {
                  if (kDebugMode) {
                    debugPrint(
                      '[WR_STATE] _QuoteCard.onClose (user tapped 마음에 담기/닫기) → before: _quoteText=$_quoteText _devoteDone=$_devoteDone',
                    );
                  }
                  _quoteText = null;
                  _devoteDone = null;
                  // [J6 Tour21] app3/home.jsx DoneCard.onClose 1:1 훅 포인트.
                  if (_firstTimeAfterPray) {
                    _firstTimeAfterPray = false;
                    _tour21 = true;
                  }
                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_wishOpen)
                  KeyedSubtree(
                    key: const ValueKey('wishFullCard'),
                    child: _wishFullCard(room, cat),
                  ),
                // app2/screens-a2.jsx › MainRoom() 331줄 1:1 — 봉인 풀림 안내(UnsealBanner).
                // capsuleDue(서버 판정) && 아직 캡슐 오버레이를 열지 않았고 && '나중에' 선택도 안 했을 때.
                if (room.capsuleDue && !_capOpen && !_capLater)
                  Positioned.fill(
                    key: const ValueKey('unsealBanner'),
                    child: WrUnsealBanner(
                      room: room,
                      onOpen: () => _openCapsule(room),
                      onLater: () => setState(() => _capLater = true),
                    ),
                  )
                // [버그수정 — 전수감사] '나중에'를 고른 뒤 top 176에 남는 금 버튼이 전혀 없어
                // 봉인일이 지난 방을 다시 열 방법이 사라지는 버그였다.
                // [버그수정 2] WrUnsealChip.build()는 Positioned를 최상위로 반환하므로 반드시 Stack의
                // 직계 자식이어야 한다 — WrCanvasScaler(ClipRect>OverflowBox>Transform.scale)로 바로 감싸면
                // "Incorrect use of ParentDataWidget" 런타임 에러로 전체 화면이 깨진다. 내부에 Stack을 한 겹 더 둔다.
                else if (room.capsuleDue && _capLater && !_capOpen)
                  Positioned.fill(
                    key: const ValueKey('unsealChip'),
                    child: SafeArea(
                      child: WrCanvasScaler(
                        contentHeight: 800,
                        child: Stack(
                          children: [
                            WrUnsealChip(onOpen: () => _openCapsule(room)),
                          ],
                        ),
                      ),
                    ),
                  ),
                // app2/guide2.jsx › shell2.jsx {tour && <Tour .../>} — 둘러보기 6단계 코치마크.
                if (_tour)
                  Positioned.fill(
                    key: const ValueKey('tour'),
                    child: WrCanvasScaler(
                      contentHeight: 800,
                      child: WrTour(
                        onDone: () {
                          setState(() => _tour = false);
                          GuidePrefs.I.setTourDone();
                        },
                      ),
                    ),
                  ),
                // [J6 Tour21] app3/shell.jsx `{tour && <Tour21 .../>}` 1:1 — 생애 첫
                // 기도 직후 보상시트를 닫으면 뜬다. WrTour(_tour, 6단계 둘러보기)와는
                // 별개 오버레이이며 동시에 뜨지 않는다(_tour21은 _reward.onClose에서만 켜짐).
                if (_tour21)
                  Positioned.fill(
                    key: const ValueKey('tour21'),
                    child: WrCanvasScaler(
                      contentHeight: 800,
                      child: Tour21Screen(
                        onEnd: (remind) {
                          setState(() => _tour21 = false);
                          // [S6 — 대표님 판정 반영] shell.jsx onEnd 콜백 `if (!v.goal)
                          // window.WRF.setGoal(21)` 1:1 — 미리보기를 끝낼 때 아직 기도
                          // 목표를 정하지 않았다면(새로 만든 방이라 항상 이 경우) 21일로
                          // 자동 설정한다. 실패해도(네트워크 등) 미리보기 종료 자체를
                          // 막을 이유는 없으므로 에러는 조용히 무시한다(토스트도 원본에
                          // 없음 — editWish(mode:'goal')은 성공 시에도 별도 안내가
                          // 없는 조용한 호출).
                          final r = context.read<WishRoomProvider>().room;
                          if (r != null && r.goal == null) {
                            unawaited(context.read<WishRoomProvider>().editWish(r.id, mode: 'goal', goalDays: 21).catchError((_) => false));
                          }
                          showTour21EndToast(context);
                        },
                      ),
                    ),
                  ),
                // fx2.jsx › LevelUp() z85 — 전체화면 레벨업 시네마틱. 최상위(가장 나중에 그려짐)에
                // 둬야 quote(위 WrCanvasScaler 내부 z95) 아래라도 그 외 모든 UI 위에 보인다.
                if (_levelUp != null)
                  Positioned.fill(
                    child: WrCanvasScaler(
                      contentHeight: 800,
                      child: WrLevelUp(
                        level: _levelUp!,
                        wallpaperNotice: _levelUpWpNotice,
                        onDone: () => setState(() {
                          _levelUp = null;
                          _levelUpWpNotice = null;
                        }),
                      ),
                    ),
                  ),
                // [v5 S2] 매핑표 00-C "열림 카드" — app3/shell.jsx 조건
                // `scr==='home' && v.pending && !sh && !cele && !tour && !v.inPreview` 1:1.
                // 서버가 계산한 room.pendingUnlock이 있고, 다른 시트·연출(소원 전문 펼침·
                // 방만 보기·투어·레벨업·정성/다시밝히기 진행 중·보상시트·말씀카드·봉인 오버레이)이
                // 하나도 떠 있지 않을 때만 1장을 보여준다. 가장 마지막(최상위)에 둬서 다른 모든
                // 오버레이 위에 보이게 한다 — 단, LevelUp보다는 아래가 자연스러워 그 다음에 배치.
                if (room.pendingUnlock != null &&
                    !_wishOpen &&
                    !_peek &&
                    !_tour &&
                    _levelUp == null &&
                    !_devotion.busy &&
                    !_rekindling &&
                    _reward == null &&
                    _quoteText == null &&
                    !_capOpen &&
                    !(room.capsuleDue && !_capLater))
                  Positioned.fill(
                    key: const ValueKey('unlockCard'),
                    child: WrCanvasScaler(
                      contentHeight: 800,
                      child: UnlockCard(
                        roomId: room.id,
                        unlockKey: room.pendingUnlock!,
                        dayN: room.dayN,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 소원 전문 펼침 — 도크를 탭하면 열리는 오버레이 카드(최대 150px 스크롤 + 기운 목록).
  Widget _wishFullCard(WishRoom room, WrCatalog cat) {
    final wishColor = cat.wishColors
        .where((c) => c['id'] == room.wishColor)
        .toList();
    final paper = cat.papers.where((p) => p['id'] == room.paper).toList();
    final W = wishColor.isNotEmpty ? wishColor.first : null;
    final pp = paper.isNotEmpty ? paper.first : cat.papers.first;
    final bgColors = (pp['bg'] as List).map((e) => _hex(e as String)).toList();
    final inkColor = _hex(pp['ink'] as String);
    final subColor = _hex2((pp['sub'] as String?) ?? '');
    // [명세] jsx 344줄 1:1 — 집계 태그가 아니라 아이템별(src[]) 칩. 궁합(match)이면
    // 금→핑크 그라디언트 배경 + 진한 글자, 아니면 반투명 검정 배경.
    final effSrc = room.effects.src;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _wishOpen = false),
            child: Container(color: const Color(0x80080308)),
          ),
        ), // .dim rgba(8,3,8,.5)
        Positioned(
          left: 14,
          right: 14,
          bottom: 96,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: bgColors,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: W != null
                            ? _hex(W['deep'] as String)
                            : WrC.accent,
                      ),
                      child: Text(
                        W != null ? (W['hanja'] as String) : '願',
                        style: const TextStyle(
                          fontFamily: 'NotoSerifKR',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFFFFF4E0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // [v5 S2] 소원 전문 펼침 카드 헤더도 _bottomDock과 동일하게 D-day
                          // 표시를 뺀다 — "오늘의 소원 · N일째 · 기도 N번"으로 통일.
                          Text(
                            '오늘의 소원 · ${room.dayN}일째 · ${wrVerb(room.theme.name, cat.ritual(room.theme))} ${room.prayedN}번',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: subColor,
                            ),
                          ),
                          if (W != null)
                            Text(
                              '${W['label']}의 소원',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: _hex(W['deep'] as String),
                              ),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _wishOpen = false),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x14000000),
                        ),
                        child: Text('✕', style: TextStyle(color: inkColor)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      room.text,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.7,
                        color: inkColor,
                      ),
                    ),
                  ),
                ),
                if (effSrc.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: subColor.withValues(alpha: .4),
                          width: 1 /* dashed 근사 */,
                        ),
                      ),
                    ),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: effSrc
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: s.match
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFFE08A),
                                          Color(0xFFFFB0C8),
                                        ],
                                      )
                                    : null,
                                color: s.match ? null : const Color(0x14000000),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${s.name} · ${_effectShort(s.type, s.v)}',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                  color: s.match
                                      ? const Color(0xFF3A1A14)
                                      : inkColor,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                // [v7 통합] 관상·손금 결과 화면에서 "이 풀이를 내 소원에
                // 봉인하기"로 동봉된 풀이가 있으면 여기에 칩으로 보여준다.
                // 비어 있으면 AttachedReadingsPanel이 SizedBox.shrink()를
                // 반환해 기존 레이아웃에 영향이 없다.
                AttachedReadingsPanel(wishRoomId: room.id),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _wishOpen = false);
                            _openShareSheet(room);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: WrC.line),
                          ),
                          child: Text(
                            '⤴ 공유',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WrF.body(13, color: inkColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _wishOpen = false);
                            _openCareSheet(room);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: WrC.line),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: Text(
                            '소원방 돌보기',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WrF.body(12, color: inkColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _wishOpen = false);
                            context.read<WishRoomProvider>().requestTab(3);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WrC.blossom,
                          ),
                          child: const Text(
                            '✿ 꾸미기',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // [버그수정 — 전수 감사로 발견] 원본 app2/screens-a2.jsx › PouchPill({onClick:
  // app.openWallet})은 탭하면 지갑 시트가 열리지만, 기존 구현은 탭 핸들러가 전혀
  // 없는 정적 Container였다. _PouchPillTap으로 교체해 탭→openWalletSheet와
  // 금액 변동 시 bump(확대/축소) 애니메이션을 더한다.
  Widget _pouchPill(int pouch) => _PouchPillTap(pouch: pouch);

  // [v5 S2 — 사용자 확정] 레벨바(_levelBar) 제거됨. 진행 상황은 소원 카드와
  // 보관함에서 보여준다(레벨업 시네마틱 WrLevelUp은 그대로 유지).

  // [v5 S2] app3/home.jsx 60~66줄 1:1 — 44px 원형 버튼(방만 보기 · ⋯ 메뉴).
  // 기존 알약(_pillBtn)과 달리 원형이며, glass 배경 + line 테두리로 기존
  // 톤을 유지한다.
  Widget _circleBtn(IconData icon, VoidCallback onTap, {Widget? badge}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: WrC.glass,
            shape: BoxShape.circle,
            border: Border.all(color: WrC.line),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              if (badge != null) Positioned(top: -2, right: -2, child: badge),
            ],
          ),
        ),
      );

  // [v5 S2 — 매핑표 05-D #11 "알림 탭 → 하단바에서 제거 → 상단 ⋯ 또는 홈 상단
  // 벨로 이동 (알림 화면 자체는 유지)"] 기존 WrNotificationsScreen(알림함)은
  // 그대로 두고, 진입 경로만 하단바 탭에서 NavPill 옆 44px 원형 벨 버튼으로
  // 옮긴다. 안 읽은 알림이 있으면(unreadCount>0) 숫자 배지를 보여준다
  // (notifications_screen.dart의 hasUnread 점 배지보다 한눈에 몇 개인지
  // 알 수 있도록 숫자로 표시 — 9개 초과는 "9+"로 줄인다).
  Widget _bellBtn(int unread) => _circleBtn(
    Icons.notifications_outlined,
    () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WrNotificationsScreen())),
    badge: unread > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: WrC.blossom,
            ),
            child: Text(
              unread > 9 ? '9+' : '$unread',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          )
        : null,
  );

  // [v5 S2] app3/home.jsx `v.pending && <span className="dot"/>` 1:1 — 아직
  // 확인(ack)하지 않은 열림이 있으면 ⋯ 버튼 우상단에 분홍 점 배지.
  Widget _careBtn(WishRoom room) => _circleBtn(
    Icons.more_horiz,
    () => _openCareSheet(room),
    badge: room.pendingUnlock != null
        ? Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: WrC.blossom,
            ),
          )
        : null,
  );

  // A-4 말풍선 문구 규칙(우선순위 순) 1:1 — ①4일+부재(dim) ②다시밝힌 직후 ③머금는 중
  // (충전 단계 0/1/2) ④평상시(3종 순환).
  // [v5 S1] app3/home.jsx down()/tick() 1:1 — hold 진행률(0→1, 증가 방향)에
  // 따라 간절함 멘트 3단계가 바뀐다(구 쿨다운 잔여초 감소 방향에서 전환).
  String _speechText(
    WishRoom room,
    Map<String, dynamic> ritual,
    double holdProg,
    bool isDim,
  ) {
    if (isDim) return '${room.absentDays}일 만에 오셨네요\n촛불이 많이 약해졌어요';
    if (_justRekindled) return '다시 와주셔서\n고마워요';
    // [v5 S1] app3/home.jsx hint — early(3초 전에 손을 뗐을 때) 안내 1:1.
    if (_holdEarly) return '조금만 더\n머물러 주세요';
    if (holdProg > 0) {
      final stage = holdProg < .34
          ? 0
          : holdProg < .67
          ? 1
          : 2;
      return ['간절히…\n간절히 빌어요', '이 마음,\n꼭 닿기를', '곧 이루어질\n거예요'][stage];
    }
    const opts = [
      '오늘도 좋은 기운이\n모이고 있어요',
      '촛불이 따뜻하게\n타오르고 있어요',
      '조금씩, 분명히\n가까워지고 있어요',
    ];
    return opts[_speechIdx % opts.length];
  }

  String _prayLine(Map<String, dynamic> ritual, double charge) {
    final lines = (ritual['lines'] as List);
    final stage = charge < .34
        ? 0
        : charge < .67
        ? 1
        : 2;
    final pair = lines[stage.clamp(0, lines.length - 1)] as List;
    final lineIx = DateTime.now().second ~/ 5 % 2;
    final text = (lineIx == 1 && pair.length > 1 && pair[1] != null)
        ? pair[1] as String
        : pair[0] as String;
    return text;
  }

  /// ── 하단 도크 — 소원 한 줄(소원 빛깔/종이 반영) + 둥근 정성 버튼(링게이지) ──
  Widget _bottomDock({
    required WishRoom room,
    required WrCatalog cat,
    required bool isDim,
    required bool busy,
    required bool done,
    required double deg,
    required Map<String, dynamic> ritual,
  }) {
    final wishColor = cat.wishColors
        .where((c) => c['id'] == room.wishColor)
        .toList();
    final paper = cat.papers.where((p) => p['id'] == room.paper).toList();
    final W = wishColor.isNotEmpty ? wishColor.first : null;
    final pp = paper.isNotEmpty ? paper.first : cat.papers.first;
    final bgColors = (pp['bg'] as List).map((e) => _hex(e as String)).toList();
    final inkColor = _hex(pp['ink'] as String);
    final subColor = _hex2((pp['sub'] as String?) ?? '');
    final wColor = W != null ? _hex(W['color'] as String) : null;
    final ringColor = WrC.blossom2;

    // [v5 S2] CHECKLIST.md "소원 카드 'N일째 · 기도 N번 · ✓ 오늘' (봉인일
    // D-day 표시 제거)" — app3/home.jsx 106~109줄 1:1:
    //   <span>{v.dayN}일째</span><span>{VB} {v.prayedN}번…</span>
    //   {v.prayedToday && <span>✓ 오늘</span>}
    // 기존에는 봉인일(sealUntil)이 있으면 'D-${sealDaysLeft} · ${날짜}'를 그대로
    // 보여줬는데(예: "D-100 · 2027.02.26"), v5에서 봉인일은 작성 화면 필수값이
    // 아닌 선택 사항(⋯ 소원방 돌보기 메뉴)으로 강등됐으므로 이 메인 카드
    // 라벨에서는 더 이상 D-day를 보여주지 않는다 — 봉인 중이어도 다른 방과
    // 동일하게 "N일째 · {의식 동사} N번[ · ✓ 오늘]"로 통일한다.
    // [v5 S2] app3/home.jsx VERB3() 1:1 — free 테마만 "정성" 대신 "기도"로
    // 통일(God/Buddha/Shaman은 RITUAL.verb 그대로).
    final verb = wrVerb(room.theme.name, ritual);
    String labelText;
    if (room.capsuleDue) {
      labelText = '🎁 소원 봉인이 풀렸어요';
    } else if (isDim) {
      labelText = '🕯 촛불 ${(room.brightness * 100).round()}%';
    } else if (done) {
      labelText = '${room.dayN}일째 · $verb ${room.prayedN}번 · ✓ 오늘';
    } else {
      labelText = '${room.dayN}일째 · $verb ${room.prayedN}번';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 소원 도크
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _wishOpen = true),
            child: Container(
              height: 58,
              padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bgColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (wColor ?? const Color(0x80FFDCB4)).withValues(
                      alpha: .4,
                    ),
                    blurRadius: 16,
                  ),
                  const BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: W != null ? _hex(W['deep'] as String) : WrC.accent,
                    ),
                    child: Text(
                      W != null ? (W['hanja'] as String) : '願',
                      style: const TextStyle(
                        fontFamily: 'NotoSerifKR',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFFFFF4E0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  // [버그수정 — 반응형 화면 규격 통일 작업 중 실제 테스트로 발견]
                  // 소원 도크는 높이 58px 고정 슬림 바(Container(height: 58))라,
                  // 라벨 줄(기운 칩 포함)+소원 한 줄 2줄 텍스트가 시스템 글자 확대
                  // 2.0배 조합에서 12px, 2.5배 조합에서 28px씩 세로로 넘쳐
                  // (RenderFlex overflowed) 아래 글자가 잘렸다. 바로 옆 원형 정성
                  // 버튼과 동일하게 FittedBox로 감싸 공간이 부족할 때만 내용을
                  // 비율대로 축소해(scaleDown) 58px 안에 항상 들어오게 한다
                  // (텍스트·칩·색상·좌측 정렬은 그대로 유지, 평소 크기에는 영향 없음).
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  labelText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: isDim
                                        ? const Color(0xFFB8442F)
                                        : subColor,
                                  ),
                                ),
                              ),
                              // [명세] jsx 313줄 1:1 — n(= effects.src.length) > 0 && !dim 일 때만 "기운 {n} · {...}" 칩.
                              // 우선순위: devo > support > cool > (그 외) '켜짐'.
                              if (room.effects.src.isNotEmpty && !isDim)
                                Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (wColor ?? Colors.black)
                                          .withValues(
                                            alpha: wColor != null ? .2 : .08,
                                          ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '기운 ${room.effects.src.length} · ${room.effects.devo > 0
                                          ? '정성 +${room.effects.devo}%'
                                          : room.effects.support > 0
                                          ? '응원 +${room.effects.support}%'
                                          : room.effects.cool > 0
                                          ? '−${room.effects.cool}초'
                                          : '켜짐'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 9.5,
                                        color: inkColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            room.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: inkColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 16,
                    color: inkColor.withValues(alpha: .5),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 둥근 정성 버튼 — [v5 S1] app3/home.jsx down()/up() 1:1: 탭 1회가
        // 아니라 "누르고 있는 동안"(onTapDown~onTapUp/onTapCancel) hold를 측정한다.
        GestureDetector(
          onTap: isDim ? _onRekindle : null,
          onTapDown: (!isDim && !busy && !done)
              ? (_) => _onHoldDown(room)
              : null,
          onTapUp: (_) => _onHoldUp(),
          onTapCancel: _onHoldUp,
          child: Container(
            // [v5 S2 — CHECKLIST.md "기도 버튼 2상태 (Ø96 분홍 → Ø76 보라
            // 「✓ 기도 완료」)" / app3/home.jsx 121줄 `width: v.prayedToday ? 76 : 96`
            // 1:1] 기존 66px 고정값은 원본과 다른 임의 값이었다 — 기도 전(평소·
            // 머금는 중)은 96, 완료 후에만 76으로 줄어든다. 색상·그라데이션·
            // 그림자는 이번 수정 범위 밖(별도 확인 후 진행)이라 기존 톤을 그대로
            // 유지한다.
            width: done ? 76 : 96,
            height: done ? 76 : 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  isDim ? const Color(0xFFFFE08A) : ringColor,
                  isDim ? const Color(0xFFFFE08A) : ringColor,
                  const Color(0x24FFFFFF),
                ],
                stops: [
                  0,
                  (isDim ? 1.0 : deg / 360).clamp(0.0, 1.0),
                  (isDim ? 1.0 : deg / 360).clamp(0.0, 1.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isDim
                      ? const Color(0xBFFFD278)
                      : const Color(0x80F2628F),
                  blurRadius: isDim ? 26 : 18,
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // [v5 S2 — 매핑표 05 "완료 Ø76 rgba(40,16,50,.85) + 금테
                // #f5cf6a" 1:1] 완료 상태는 더 이상 인디고~보라 그라데이션이
                // 아니라 rgba(40,16,50,.85) 단색 + 금테 보더다. busy("머금는
                // 중")는 기존 그라데이션을 그대로 유지(완료 전이라 명세
                // 대상 아님).
                color: done ? const Color(0xD9281020) : null,
                gradient: done
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDim
                            ? const [Color(0xFFFFE9A8), Color(0xFFF5C052)]
                            : (busy
                                  ? const [Color(0xFF4A2238), Color(0xFF2A1020)]
                                  : const [
                                      Color(0xFFFF9CBC),
                                      Color(0xFFF2628F),
                                    ]),
                      ),
                border: done
                    ? Border.all(
                        color: const Color(0xFFF5CF6A).withValues(alpha: .7),
                        width: 1.5,
                      )
                    : null,
                boxShadow: done
                    ? [
                        BoxShadow(
                          color: const Color(0xFFC8A0FF).withValues(alpha: .45),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              // [버그수정 — 반응형 화면 규격 통일 작업 중 실제 테스트로 발견]
              // 둥근 정성 버튼은 지름 66px(안쪽 패딩 4px 제외 시 58x58) 고정
              // 원형이라, 내부 아이콘+라벨 2줄 Column이 시스템 글자 확대
              // 1.3배 조합에서 6px 세로로 넘쳐(RenderFlex overflowed) 라벨이
              // 잘렸다. 이 버튼은 "소원방 메인화면의 핵심 버튼"으로 지시서가
              // 지목한 기기별 버튼 잘림의 전형적 사례다. FittedBox로 감싸
              // 공간이 부족할 때만 내용을 비율대로 축소해(scaleDown) 항상
              // 원 안에 들어오게 한다(아이콘·라벨·색상·레이아웃은 그대로 유지,
              // 평소 크기에는 전혀 영향 없음).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: isDim
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🕯',
                            style: TextStyle(fontSize: 20, height: 1),
                          ),
                          Text(
                            '다시 밝히기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                              color: const Color(0xFF4A2A10),
                            ),
                          ),
                        ],
                      )
                    : busy
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ritual['icon'] as String? ?? '🙏',
                            style: const TextStyle(fontSize: 18, height: 1),
                          ),
                          const Text(
                            '머금는 중',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      )
                    : done
                    // [v5 S2 — 매핑표 05 "완료 Ø76 rgba(40,16,50,.85) + 금테
                    // #f5cf6a 「✓ 기도 완료」한 줄" / app3/home.jsx 1:1]
                    // 기존 "✓" + "오늘 완료" 2줄 고정 문구는 임의값이었다 —
                    // 한 줄 "✓ {VB} 완료"로 통일(VB는 wrVerb, free만 "기도").
                    ? Text(
                        '✓ $verb 완료',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          color: Colors.white70,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ritual['icon'] as String? ?? '🙏',
                            style: const TextStyle(fontSize: 20, height: 1),
                          ),
                          Text(
                            // [v5 S2 — CHECKLIST.md "기도 버튼 2상태" /
                            // app3 BTN3 1:1] 기존 ritual['verb']는 명사형
                            // ("정성/기도/치성")이었다. 버튼 라벨은 동작형
                            // 문구(두 손 모아/기도하기/절 올리기/두 손
                            // 비비기)를 쓴다 — kPrayBtnLabel 참조.
                            kPrayBtnLabel[room.theme.name] ?? '두 손 모아',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // [명세] app/data.js EFFECT_SHORT 1:1 — 아이템 칩에 쓰는 짧은 효과 표기.
  String _effectShort(String type, int v) {
    switch (type) {
      case 'devo':
        return '정성 +$v%';
      case 'support':
        return '응원 +$v%';
      case 'cool':
        return '−$v초';
      case 'daily':
        return '하루 +$v회';
      case 'pouch':
        return '복 +$v';
      case 'decay':
        return '불빛 $v%↑';
      default:
        return '';
    }
  }

  Color _hex(String s) {
    final h = s.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Color _hex2(String rgba) {
    // rgba(r,g,b,a) 형식 파싱, 실패 시 fg 색
    final m = RegExp(
      r'rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)',
    ).firstMatch(rgba);
    if (m == null) return WrC.fg;
    final r = int.parse(m.group(1)!),
        g = int.parse(m.group(2)!),
        b = int.parse(m.group(3)!);
    final a = m.group(4) != null ? double.parse(m.group(4)!) : 1.0;
    return Color.fromRGBO(r, g, b, a);
  }

  WishRoom _withBrightness(WishRoom r, double b) {
    if (b == r.brightness) return r;
    // brightness만 오버라이드하는 얕은 복제 — RoomScene 렌더용(네트워크 전송 없음).
    return WishRoom.fromJson({
      'id': r.id,
      'ownerId': r.ownerId,
      'owner': r.owner,
      'region': r.region,
      'text': r.text,
      'char': r.char,
      'status': r.status.name,
      'visibility': r.visibility.name,
      'theme': r.theme.name,
      'outfit': r.outfit?.name,
      'outfitNow': r.outfitNow.name,
      'outfitId': r.outfitId,
      'wishColor': r.wishColor,
      'paper': r.paper,
      'devotionCount': r.devotionCount,
      'supportCount': r.supportCount,
      'pouchReceived': r.pouchReceived,
      'level': r.level,
      'commentCount': r.commentCount,
      'points': r.points,
      'levelName': r.levelName,
      'curLevelPts': r.curLevelPts,
      'nextLevelPts': r.nextLevelPts,
      'brightness': b,
      'decayLabel': r.decayLabel,
      'decayBadge': r.decayBadge,
      'isMine': r.isMine,
      'supportedToday': r.supportedToday,
      'absentDays': r.absentDays,
      'devotionsToday': r.devotionsToday,
      'devotionsRemaining': r.devotionsRemaining,
      'dailyLimit': r.dailyLimit,
      'cooldownSec': r.cooldownSec,
      'daysLit': r.daysLit,
      // [버그수정 — 전수감사] 얕은 재구성 시 v5 S2 신규 필드(dayN/prayedN/stage/
      // unlocked/pendingUnlock/lastUnlockAckDay)가 누락돼 밝기 오버라이드마다
      // 기본값으로 리셋되던 문제 — 원본 r의 값을 그대로 전달한다.
      'dayN': r.dayN,
      'prayedN': r.prayedN,
      'stage': r.stage,
      'unlocked': r.unlocked,
      'pendingUnlock': r.pendingUnlock, 'lastUnlockAckDay': r.lastUnlockAckDay,
      'equip': {
        'CANDLE': r.equip.candle,
        'FLOWER': r.equip.flower,
        'BACKGROUND': r.equip.background,
        'SPECIAL': r.equip.special,
        'DECORATION': r.equip.decoration,
        'SEAL': r.equip.seal,
        'THEME': r.equip.theme,
      },
      'layout': r.layout.map(
        (k, v) => MapEntry(k, {'x': v.x, 'y': v.y, 's': v.s}),
      ),
    });
  }
}

/// devote()/rekindle() 1회성 FX 오버레이 항목 — other_room_screen.dart `_FxEntry`와 동일 패턴.
class _FxEntry {
  final Key key;
  final Widget widget;
  _FxEntry(this.key, this.widget);
}

/// devote() 0.7s `+1 {verb}` — x=204(중앙고정) y=250, 24px 흰색+핑크글로우.
/// plus-up keyframe 1:1: 0%(op0, scale.6, y+10) → 25%(op1, scale1.15, y-10) → 100%(op0, scale1, y-70).
/// app2/fx2.jsx › PlusText({x:204,y:250}) · wr2.css plus-up.
class _PlusUpText extends StatefulWidget {
  const _PlusUpText({required this.text});
  final String text;
  @override
  State<_PlusUpText> createState() => _PlusUpTextState();
}

class _PlusUpTextState extends State<_PlusUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: 250,
    child: IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final v = _c.value;
            double op, scale, dy;
            if (v < .25) {
              final t = v / .25;
              op = t;
              scale = .6 + (1.15 - .6) * t;
              dy = 10 + (-10 - 10) * t;
            } else {
              final t = (v - .25) / .75;
              op = 1 - t;
              scale = 1.15 + (1.0 - 1.15) * t;
              dy = -10 + (-70 - -10) * t;
            }
            return Opacity(
              opacity: op.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      fontFamily: 'NotoSerifKR',
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0xFFFF8FB1), blurRadius: 14),
                        Shadow(color: Color(0xB2F2628F), blurRadius: 26),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
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

class _WickEmberState extends State<_WickEmber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.x - 8,
    top: widget.y - 8,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = _c.value;
          double op, scale;
          if (v < .6) {
            final t = v / .6;
            op = t;
            scale = .4 + (1.08 - .4) * t;
          } else {
            final t = (v - .6) / .4;
            op = 1;
            scale = 1.08 + (1 - 1.08) * t;
          }
          return Opacity(
            opacity: op.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFF4C0),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFFB060),
                      blurRadius: 20,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Color(0x99FF963C),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _CapText extends StatefulWidget {
  const _CapText({required this.text, this.fontSize = 15, this.durMs = 2400});
  final String text;
  final double fontSize;
  final int durMs;
  @override
  State<_CapText> createState() => _CapTextState();
}

class _CapTextState extends State<_CapText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durMs),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final v = _c.value;
      double op, blur;
      if (v < .3) {
        final t = v / .3;
        op = t;
        blur = 6 * (1 - t);
      } else if (v < .75) {
        op = 1;
        blur = 0;
      } else {
        final t = (v - .75) / .25;
        op = 1 - t;
        blur = 0;
      }
      final text = Text(
        widget.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'NotoSerifKR',
          fontWeight: FontWeight.w700,
          fontSize: widget.fontSize,
          color: Colors.white,
          shadows: const [Shadow(color: Color(0xFFFFE08A), blurRadius: 16)],
        ),
      );
      return Opacity(
        opacity: op.clamp(0.0, 1.0),
        child: blur > .1
            ? ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: text,
              )
            : text,
      );
    },
  );
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

class _FlyToCandleState extends State<_FlyToCandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 900 + widget.delayMs),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delayFrac = widget.delayMs / (900 + widget.delayMs);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final raw = ((_c.value - delayFrac) / (1 - delayFrac)).clamp(0.0, 1.0);
        if (_c.value < delayFrac) return const SizedBox.shrink();
        final ringT = Curves.easeOut.transform(raw.clamp(0.0, 1.0));
        final ringOp = (1 - ringT).clamp(0.0, 1.0);
        // fly-to: translate(0→(to-from)) scale(1→.3) opacity(1→0), cubic(.5,0,.6,1)
        final flyT = const Cubic(.5, 0, .6, 1).transform(raw);
        final dx = (widget.to.dx - widget.from.dx) * flyT,
            dy = (widget.to.dy - widget.from.dy) * flyT;
        final scale = 1 - .7 * flyT, op = 1 - flyT;
        return Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  left: widget.from.dx - 30,
                  top: widget.from.dy - 30,
                  child: Opacity(
                    opacity: ringOp,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xE6FFE1A0),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0xE6FFD282), blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: widget.from.dx - 4 + dx,
                  top: widget.from.dy - 4 + dy,
                  child: Opacity(
                    opacity: op.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: scale.clamp(0.0, 1.0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFF4C0),
                          boxShadow: [
                            BoxShadow(color: Color(0xFFFFD070), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE08A), Color(0xFFFF8FB1)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x80FFC878), blurRadius: 16),
            ],
          ),
          child: Text(
            '✦ 아이템 기운 +$pct%',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: Color(0xFF4A2A10),
            ),
          ),
        ),
        if (gain.fx.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              runSpacing: 5,
              children: gain.fx
                  .take(4)
                  .map(
                    (it) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x8C1E0C18),
                        borderRadius: BorderRadius.circular(999),
                        border: it.match
                            ? Border.all(color: const Color(0xFFFFE08A))
                            : null,
                      ),
                      child: Text(
                        '${it.name} +${it.v}%${it.match ? ' · 궁합' : ''}',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// devote() 2.3s 말씀 카드 — RITUAL.quotes 중 랜덤 1개(문장 + 출처).
/// devote() 2.3s 말씀 카드 — docs A-5 1:1: 테마별 bg그라디언트/잉크색/머리말,
/// 상단 -26px 52px 아이콘서클(pop .8s .4s), 본문 ink-in 1.6s .5s, 출처 fade 1s 1.2s,
/// 테두리 반짝이 6개(twinkle), dim 포함 + 아무 곳 탭 → 닫기. app2/screens-a2.jsx QuoteCard() 1:1.
class _QuoteCard extends StatefulWidget {
  const _QuoteCard({
    required this.text,
    required this.src,
    required this.theme,
    required this.icon,
    required this.onClose,
    this.verb,
    this.done,
  });
  final String text, src, icon;
  final WrTheme theme;
  final VoidCallback onClose;
  // [v5 S2 — 대표 판정 "기도 완료 카드 하나로 합치기"] verb(기도/치성/정성 등
  // 테마별 동사)와 done((dayN, prayedN, bonus, streak))이 채워지면, 말씀 아래에
  // app3/home.jsx DoneCard() 1:1인 통계(🕯dayN·🙏prayedN·🧧bonus)와 "마음에
  // 담기" 버튼이 함께 나타난다. null이면(=onQuote 직후, onDone 전) 기존처럼
  // "눌러서 닫기" 안내만 보여준다.
  final String? verb;
  final (int dayN, int prayedN, int bonus, bool streak)? done;
  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<_QuoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = {
      WrTheme.god: [Color(0xFFFFFAF0), Color(0xFFF3E6C8)],
      WrTheme.buddha: [Color(0xFFFFF4DC), Color(0xFFF0D9A8)],
      WrTheme.shaman: [Color(0xFFFFF1EA), Color(0xFFF3D2C4)],
      WrTheme.free: [Color(0xFFFFF6FA), Color(0xFFF6DBE6)],
    };
    const ink = {
      WrTheme.god: Color(0xFF4A3510),
      WrTheme.buddha: Color(0xFF5A3510),
      WrTheme.shaman: Color(0xFF6A1A1A),
      WrTheme.free: Color(0xFF5A2A3A),
    };
    const head = {
      WrTheme.god: '✝ 오늘의 말씀',
      WrTheme.buddha: '☸ 오늘의 법문',
      WrTheme.shaman: '❖ 오늘의 덕담',
      WrTheme.free: '✿ 오늘의 한마디',
    };
    const accent = {
      WrTheme.god: Color(0xFFFFE6A8),
      WrTheme.buddha: Color(0xFFFFC870),
      WrTheme.shaman: Color(0xFFFF7A6A),
      WrTheme.free: Color(0xFFFF8FB1),
    };
    final c = accent[widget.theme] ?? const Color(0xFFFFD98A);
    final inkC = ink[widget.theme] ?? const Color(0xFF5A2A3A);
    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // dim — fade .6s
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (_, t, __) => Opacity(
              opacity: .7 * t,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Colors.black),
                child: SizedBox.expand(),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
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
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: bg[widget.theme] ?? bg[WrTheme.free]!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: .67),
                      blurRadius: 0,
                      spreadRadius: 1.5,
                    ),
                    BoxShadow(color: c.withValues(alpha: .53), blurRadius: 40),
                    const BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 50,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      head[widget.theme] ?? '',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: inkC.withValues(alpha: .7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '"${widget.text}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        height: 1.65,
                        color: inkC,
                      ),
                    ),
                    if (widget.src.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '— ${widget.src}',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: inkC.withValues(alpha: .7),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // [v5 S2 — 대표 판정 "카드 1장으로 합치기"] app3/home.jsx DoneCard()
                    // 1:1 — done이 채워지면(onDone 2.9s 시점) 🕯dayN·🙏prayedN·(bonus>0
                    // 이면 🧧+bonus) 통계 Row + "마음에 담기" 버튼을 보여준다. 아직
                    // null이면(onQuote 2.3s~2.9s 사이) 기존처럼 안내 문구만 보인다.
                    if (widget.done != null) ...[
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text(
                            '🕯 ${widget.done!.$1}일째',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: inkC.withValues(alpha: .8),
                            ),
                          ),
                          Text(
                            '🙏 ${widget.done!.$2}번',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: inkC.withValues(alpha: .8),
                            ),
                          ),
                          if (widget.done!.$3 > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/wishroom/items/pouch.png',
                                  width: 16,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('🧧', style: TextStyle(fontSize: 13)),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '+${widget.done!.$3}',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: inkC.withValues(alpha: .8),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (widget.done!.$4)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x38F5BE5A),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '✦ 7일 연속 ${widget.verb ?? '기도'} · 복주머니 보너스',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: inkC,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: widget.onClose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WrC.blossom,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '마음에 담기',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Text(
                        '눌러서 닫기',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11,
                          color: inkC.withValues(alpha: .5),
                        ),
                      ),
                  ],
                ),
              );
              if (blur > .1) {
                card = ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: card,
                );
              }
              return Positioned(
                left: 26,
                right: 26,
                top: 250,
                child: Opacity(
                  opacity: op,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          card,
                          // twinkle 반짝이 6개 — 카드 상단 테두리를 따라 분산
                          for (var i = 0; i < 6; i++)
                            Positioned(
                              left: null,
                              right: null,
                              top: -4,
                              child: FractionallySizedBox(
                                widthFactor: 1,
                                child: Align(
                                  alignment: Alignment((i - 2.5) / 2.5, 0),
                                  child: _Twinkle(
                                    color: c,
                                    delayMs: i * 200,
                                    periodMs: (1400 + i * 300),
                                  ),
                                ),
                              ),
                            ),
                          // 상단 아이콘 서클 — pop .8s .4s
                          Positioned(
                            left: 0,
                            right: 0,
                            top: -26,
                            child: Center(
                              child: _IconPop(
                                delayMs: 400,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors:
                                          bg[widget.theme] ?? bg[WrTheme.free]!,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.withValues(alpha: .67),
                                        blurRadius: 0,
                                        spreadRadius: 1.5,
                                      ),
                                      BoxShadow(color: c, blurRadius: 24),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    widget.icon,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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

class _IconPopState extends State<_IconPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final v = _c.value;
      double op, scale;
      if (v < .6) {
        final t = v / .6;
        op = t;
        scale = .4 + (1.08 - .4) * t;
      } else {
        final t = (v - .6) / .4;
        op = 1;
        scale = 1.08 + (1 - 1.08) * t;
      }
      return Opacity(
        opacity: op.clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: widget.child),
      );
    },
  );
}

/// 말씀카드 테두리 반짝이 — twinkle(scale.6↔1.2, op.2↔1) 무한 반복.
class _Twinkle extends StatefulWidget {
  const _Twinkle({required this.color, this.delayMs = 0, this.periodMs = 1400});
  final Color color;
  final int delayMs, periodMs;
  @override
  State<_Twinkle> createState() => _TwinkleState();
}

class _TwinkleState extends State<_Twinkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.periodMs),
  );
  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final t = Curves.easeInOut.transform(_c.value);
      final op = .2 + .8 * t, scale = .6 + .6 * t;
      return Opacity(
        opacity: op,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF6D0),
              boxShadow: [BoxShadow(color: widget.color, blurRadius: 10)],
            ),
          ),
        ),
      );
    },
  );
}

/// A-4 보상 시트 — devote() 2.9s 또는 rekindle() 3.4s 끝에 표시.
/// devote: sub `DEVOTION · 0n / 10` · 10회째면 제목이 `{verb} 10회를 채웠어요` · 칸
/// `꽃잎 +1 · 빛가루 +1 · 연꽃잎 +1`(10회째는 마지막 칸이 `복주머니 +n`).
/// rekindle: sub `REKINDLED · 100%` · 본문 `{n}일 동안 소원방이 당신을 기다렸어요` ·
/// 칸 `촛불 밝기 100% · 빛가루 +1`.
class _RewardSheet extends StatelessWidget {
  const _RewardSheet({
    required this.title,
    required this.sub,
    this.body,
    this.bonus = 0,
    this.chips,
    this.cta = '오늘도 정성 들이기',
    this.onClose,
  });
  final String title, sub;
  final String? body;
  final int bonus;
  final List<String>? chips;
  final String cta;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) {
    final cc =
        chips ??
        (bonus > 0
            ? ['꽃잎 +1', '빛가루 +1', '복주머니 +$bonus']
            : ['꽃잎 +1', '빛가루 +1', '연꽃잎 +1']);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      decoration: WrDeco.sheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sub, style: WrF.mono(size: 10, color: WrC.muted)),
          const SizedBox(height: 6),
          Text(
            title,
            style: WrF.display(19, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              style: WrF.body(13, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cc.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    cc[i],
                    style: WrF.body(
                      11.5,
                      w: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
              child: Text(cta, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
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
    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: Container(color: const Color(0x80080308)),
        ), // .dim rgba(8,3,8,.5)
        Positioned(
          left: 10,
          right: 10,
          bottom: 22,
          child: _RewardSheet(
            title: data['title'] as String,
            sub: data['sub'] as String,
            body: data['body'] as String?,
            bonus: data['bonus'] as int? ?? 0,
            chips: chips,
            cta: data['cta'] as String? ?? '오늘도 정성 들이기',
            onClose: onClose,
          ),
        ),
      ],
    );
  }
}

/// 소원방 돌보기 시트 — v5 S2 「⋯ 소원방 돌보기」 메뉴. app3/shop.jsx Menu3 1:1 —
/// menuinfo.js 10개 항목을 원본 순서·문구 그대로 Row로 그리고, 그 아래에
/// Flutter 전용 「그 밖에」 2줄(소원방 쓰는 법 · 움직임 줄이기)을 더한다
/// (사용자 확정 B안: "⋯ 버튼을 누르면 기존 _CareSheet가 열린다 — 이
/// CareSheet가 곧 v5의 「소원방 돌보기」 메뉴. CareSheet 본문 자체를 10줄
/// 리스트로 바꾼다. 나머지 3개(안내서·공유·움직임정지)는 맨 아래 「그 밖에」
/// 묶음으로 — 공유는 10줄 중 「함께 빌어달라고 하기」 안의 링크 공유와
/// 합친다").
/// [회귀 방지] 기존 ⑦ 완료 버튼(✿ 소원이 이루어졌어요, 2단계 확인)은
/// menuinfo.js 10줄 어디에도 대응 항목이 없고(app3 원본에서는 Vault3(보관함)
/// 소속 — flows.jsx Fulfill3) Flutter 쪽에는 보관함에 이 기능의 대체
/// 구현이 없어, 지금 삭제하면 "소원 완료 처리" 기능 자체가 앱에서 완전히
/// 사라진다. 10줄 + 그 밖에 2줄 아래에 그대로 유지한다.
class _CareSheet extends StatefulWidget {
  const _CareSheet({
    required this.room,
    required this.openGuide,
    required this.openShare,
    required this.webPaused,
    required this.onToggleWebPaused,
  });
  final WishRoom room;
  final void Function([String? focus]) openGuide;
  final VoidCallback openShare;
  final bool webPaused;
  final ValueChanged<bool> onToggleWebPaused;
  @override
  State<_CareSheet> createState() => _CareSheetState();
}

class _CareSheetState extends State<_CareSheet> {
  bool _confirm = false;
  // [4-B 신규 — CHECKLIST.md 대표님 판정] 소원 마무리 선택(成/放) + 한 줄 메모.
  // 기준 원본: app3/extras.js Fulfill3 (mode: 'done'|'let', note maxLength).
  Outcome _finishMode = Outcome.FULFILLED;
  final _noteCtrl = TextEditingController();
  bool _releaseAsk = false; // 放 선택 시 2차 확인("정말 내려놓을까요") 노출 여부
  // [버그수정] showModalBottomSheet의 builder는 한 번만 호출되고 이 시트는
  // Overlay 경로의 별도 Route라서, 부모(_MainRoomScreenState)의 setState만으로는
  // 이미 열려 있는 이 시트가 리빌드되지 않는다(클릭 자체는 부모 상태에 반영되지만
  // 토글 모양이 화면에서 바뀌지 않는 현상의 원인). 로컬에도 상태를 복사해 두고
  // 토글 시 이 위젯 자신도 setState하여 즉시 시각 반영, 동시에 부모 콜백도 호출해
  // 시트를 닫은 뒤 메인 화면(frozen 애니메이션)에도 반영되도록 한다.
  late bool _webPaused = widget.webPaused;
  // [v5 S2 — 사용자 확정 "그 밖에 블록에 인트로 토글 추가"] skipIntro도 같은 이유로
  // 로컬 상태를 별도로 들고, 서버 PATCH 완료 후에만 반영한다(낙관적 갱신 없음 —
  // 실패 시 토글이 원래대로 되돌아가야 하므로 Provider의 me.skipIntro를 신뢰하되
  // 통신 중에는 이 로컬 값으로 즉시 토글 모양을 보여준다).
  bool? _skipIntroOverride;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final p = context.watch<WishRoomProvider>();
    final cat = WrCatalog.I;
    final reduceMotionOs = MediaQuery.of(context).disableAnimations;
    final skipIntro = _skipIntroOverride ?? (p.me?.skipIntro ?? false);

    // app3/shop.jsx Row 2행 부제(s) 1:1 치환 — 서버 데이터가 없는 항목(v.entrustNow
    // 등 전용 API 없음)은 note 수준의 일반 안내 문구로 대체한다.
    final guardian = p.characters.where((c) => c.id == room.char).firstOrNull;
    final themeInfo = cat.themes
        .where((t) => t['id'] == room.theme.name)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet 헤더 — app2/fx2.jsx › Sheet({sub,title}) 1:1 (✕ 닫기 포함).
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY WISH ROOM',
                      style: WrF.mono(size: 10, color: WrC.blossom2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '소원방 돌보기',
                      style: WrF.display(20, color: Colors.white),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: WrC.glass,
                        shape: BoxShape.circle,
                        border: Border.all(color: WrC.line),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // app3/shop.jsx `{v.pending && <button>...}` 1:1 — 아직 확인 안 한
            // 열림이 있으면 배너로 안내(누르면 시트만 닫고 방으로 돌아가 UnlockCard를 보게 한다).
            if (room.pendingUnlock != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0x1AF5CF6A),
                      border: Border.all(color: const Color(0x80F5CF6A)),
                    ),
                    child: Text(
                      '✦ 새로 열린 것이 있어요 · 방으로 돌아가 확인해 보세요',
                      style: WrF.body(13, w: FontWeight.w700, color: WrC.fg),
                    ),
                  ),
                ),
              ),
            // 10줄 — kCareMenuInfos(menuinfo.js INFO) 순서 그대로.
            for (final info in kCareMenuInfos)
              _careRow(
                context,
                info,
                room: room,
                guardian: guardian,
                themeInfo: themeInfo,
              ),
            const SizedBox(height: 10),
            Divider(color: WrC.line, height: 1),
            const SizedBox(height: 10),
            Text(
              '그 밖에',
              style: WrF.body(12, w: FontWeight.w700, color: WrC.muted),
            ),
            // 「그 밖에」 1 — 소원방 쓰는 법(= 기존 guideBtn 안내서, A11 탭 안내).
            _plainRow(
              ic: '📖',
              t: '소원방 쓰는 법',
              s: '탭 6개 · ⋯ 메뉴 · 각 열리는 날을 한 장으로',
              onTap: () => widget.openGuide(),
            ),
            // 「그 밖에」 2 — 들어갈 때 인트로 보기(skipIntro 반전 토글).
            // [v5 S2 — 사용자 확정] 서버 PATCH(setSkipIntro)에 연결, 값=true면
            // "인트로를 본다"(= skipIntro=false)로 매핑한다.
            _toggleRow(
              ic: '🎬',
              t: '들어갈 때 인트로 보기',
              s: skipIntro ? '바로 방으로 들어가요' : '들어갈 때마다 짧은 인트로를 봐요',
              value: !skipIntro,
              enabled: true,
              onChanged: (showIntro) async {
                final next = !showIntro; // skipIntro
                setState(() => _skipIntroOverride = next); // 즉시 시각 반영
                final ok = await context.read<WishRoomProvider>().setSkipIntro(
                  next,
                );
                if (!mounted) return;
                if (!ok) {
                  // 실패 시 토글을 되돌린다.
                  setState(() => _skipIntroOverride = !next);
                }
              },
            ),
            // 「그 밖에」 3 — 움직임 줄이기(기존 pauseBtn 웹 전용 토글을 흡수).
            // 사용자 지시: "휴대폰의 동작 줄이기 설정도 따르게 한다" — OS
            // disableAnimations가 이미 켜져 있으면 이 토글은 항상 켜진 것으로
            // 보여주고(끌 수 없음), 꺼져 있으면 이 화면 로컬 _webPaused를 토글한다.
            _toggleRow(
              ic: '❚❚',
              t: '움직임 줄이기',
              s: reduceMotionOs ? '휴대폰 설정으로 항상 켜져 있어요' : '방 안의 움직임을 멈춰요',
              value: reduceMotionOs || _webPaused,
              enabled: !reduceMotionOs,
              onChanged: (v) {
                setState(() => _webPaused = v); // 시트 자신도 즉시 리빌드
                widget.onToggleWebPaused(v); // 부모(방 화면) 상태도 동기화
              },
            ),
            const SizedBox(height: 16),
            // 완료 버튼 — 2단계 확인(아직이에요 / 다음 단계: 成/放 선택). [회귀 방지 유지]
            if (!_confirm)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => setState(() => _confirm = true),
                  style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
                  child: const Text(
                    '✿ 소원이 이루어졌어요',
                    style: TextStyle(
                      color: Color(0xFF4A2A10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              _buildFinishPanel(context, room, p),
          ],
        ),
      ),
    );
  }

  /// [4-B 신규 — CHECKLIST.md 대표님 판정] 소원 마무리(成/放) 2분기 선택 +
  /// 한 줄 메모(최대 40자). 기준 원본: app3/extras.js Fulfill3 1:1 —
  /// 成(FULFILLED)/放(RELEASED) 카드 2개 + textarea + 하단 안내문. 放 선택 시
  /// 원본과 동일하게 "정말 내려놓을까요" 2차 확인을 한 번 더 거친다.
  Widget _buildFinishPanel(
    BuildContext context,
    WishRoom room,
    WishRoomProvider p,
  ) {
    final isRelease = _finishMode == Outcome.RELEASED;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: WrDeco.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이 소원을 마무리할까요',
            style: WrF.body(14, w: FontWeight.w700, height: 1.6, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _finishModeCard(
                  identifier: 'finish_mode_fulfilled',
                  selected: !isRelease,
                  seal: '成',
                  sealColor: const Color(0xFFC9602A),
                  title: '이루어졌어요',
                  sub: '꽃비와 함께 보관함으로',
                  onTap: () => setState(() {
                    _finishMode = Outcome.FULFILLED;
                    _releaseAsk = false;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _finishModeCard(
                  identifier: 'finish_mode_released',
                  selected: isRelease,
                  seal: '放',
                  sealColor: const Color(0xFF7A6A9A),
                  title: '마음을 내려놓을게요',
                  sub: '지우지 않고 고이 담아요',
                  onTap: () => setState(() {
                    _finishMode = Outcome.RELEASED;
                    _releaseAsk = false;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isRelease
                ? '${room.dayN}일 동안 ${room.prayedN}번 빈 마음은 그대로 남아요. 새 소원은 1일째부터, 수호자 · 옷 · 산 물건은 그대로예요.'
                : '한 줄 남기면 기록관에서 다시 볼 수 있어요 (선택)',
            style: WrF.body(12.5, color: WrC.muted, height: 1.6),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: WrDeco.hanji,
            child: Semantics(
              identifier: 'finish_note_field',
              textField: true,
              child: TextField(
                controller: _noteCtrl,
                maxLength: 40,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: WrC.hanjiInk,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: isRelease ? '예) 지금은 다른 마음을 담고 싶어요' : '예) 엄마가 건강하게 퇴원하셨어요',
                  hintStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    color: WrC.hanjiInk.withValues(alpha: .4),
                  ),
                ),
              ),
            ),
          ),
          if (isRelease && _releaseAsk)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '내려놓은 소원은 다시 이어서 빌 수 없어요. 정말 내려놓을까요',
                style: WrF.body(12.5, color: WrC.muted, height: 1.5),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: Semantics(
                    identifier: 'finish_not_yet',
                    button: true,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _confirm = false;
                        _releaseAsk = false;
                      }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: WrC.line),
                      ),
                      child: Text('아직이에요', style: WrF.body(13, color: WrC.fg)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: Semantics(
                    identifier: 'finish_confirm',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {
                        // 放 — app3 Fulfill3 go() 1:1: 첫 클릭은 확인만, 두 번째
                        // 클릭에서 실제로 진행한다.
                        if (isRelease && !_releaseAsk) {
                          setState(() => _releaseAsk = true);
                          return;
                        }
                        final note = _noteCtrl.text.trim();
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CompleteScreen(
                              roomId: room.id,
                              outcome: _finishMode,
                              note: note.isEmpty ? null : note,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRelease ? WrC.darkBtn : WrC.glow,
                      ),
                      child: Text(
                        isRelease
                            ? (_releaseAsk ? '放 네, 내려놓을게요' : '마음을 내려놓을게요')
                            : '네, 이루어졌어요',
                        style: TextStyle(
                          color: isRelease ? Colors.white : const Color(0xFF4A2A10),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finishModeCard({
    required String identifier,
    required bool selected,
    required String seal,
    required Color sealColor,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Semantics(
      identifier: identifier,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? const Color(0x24F2628F) : WrC.card,
            border: Border.all(
              color: selected ? WrC.blossom2 : WrC.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: sealColor, shape: BoxShape.circle),
                child: Text(
                  seal,
                  style: const TextStyle(
                    fontFamily: 'NotoSerifKR',
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFFFFF9E8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: WrF.body(13.5, w: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(sub, style: WrF.body(11, color: WrC.muted), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // app3/shop.jsx Row 1:1 — 아이콘 40x40 + 제목/부제 + ? 안내버튼 + › 화살표.
  // 잠기면 아이콘 자리에 🔒, 부제 자리에 "N일 뒤에 열려요", 전체 opacity .5.
  Widget _careRow(
    BuildContext context,
    CareMenuInfo info, {
    required WishRoom room,
    required dynamic guardian,
    required Map<String, dynamic>? themeInfo,
  }) {
    final unlockDay = info.lockKey == null
        ? 0
        : ((WrCatalog.I.raw['UNLOCK'] as Map)[info.lockKey] as int? ?? 0);
    // [v5 S2 — 사용자 확정 "API가 없는 3줄 → 기능 미구현이면 항상 잠김"]
    // unimplemented면 서버 unlocked[]/날짜와 무관하게 항상 잠긴 것으로 본다.
    final isOpen =
        !info.unimplemented &&
        (info.lockKey == null || room.isFeatureUnlocked(info.lockKey!));
    final dayN = room.dayN;
    final lockLabel = isOpen
        ? null
        : (info.unimplemented
              ? '곧 열려요'
              : '${math.max(1, unlockDay - dayN)}일 뒤에 열려요');
    final sub =
        lockLabel ??
        _subFor(info.key, room: room, guardian: guardian, themeInfo: themeInfo);

    void openInfo(VoidCallback onGo) {
      showCareMenuInfoSheet(
        context,
        info: info,
        lock: !isOpen,
        need: unlockDay,
        dayN: dayN,
        comingSoon: info.unimplemented,
        onGo: onGo,
      );
    }

    void tap() {
      final onGo = _onGoFor(info.key);
      if (!isOpen) {
        openInfo(onGo);
        return;
      }
      if (!GuidePrefs.I.menuInfoSeen(info.key)) {
        openInfo(() {
          GuidePrefs.I.markMenuInfoSeen(info.key);
          onGo();
        });
        return;
      }
      onGo();
    }

    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isOpen ? 1 : .5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: WrC.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: WrC.card,
                  border: Border.all(color: WrC.cardBorder),
                ),
                child: Text(
                  isOpen ? _iconFor(info.key) : '🔒',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: WrF.body(
                        15,
                        w: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      sub,
                      style: WrF.body(12, color: WrC.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => openInfo(_onGoFor(info.key)),
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: WrC.line),
                  ),
                  child: Text(
                    '?',
                    style: WrF.body(12, w: FontWeight.w700, color: WrC.muted),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: WrC.muted),
            ],
          ),
        ),
      ),
    );
  }

  // app3/shop.jsx Row ic 속성 1:1(한글 key → 원본 이모지).
  String _iconFor(String key) =>
      const {
        '수호자': '👤',
        '수호자에게 맡기기': '🙏',
        '찾아온 수호자': '☾',
        '옷 갈아입기': '👗',
        '방 꾸미기': '✿',
        '방 분위기': '⛩',
        '배경화면으로 쓰기': '▣',
        '소원 상점': '🛍',
        '함께 빌어달라고 하기': '☾',
        '소원 · 목표 고쳐 쓰기': '✎',
      }[key] ??
      '•';

  // app3/shop.jsx Row s 속성 1:1 치환 — 서버 데이터가 없는 것은 안내 문구로 대체.
  String _subFor(
    String key, {
    required WishRoom room,
    required dynamic guardian,
    required Map<String, dynamic>? themeInfo,
  }) {
    switch (key) {
      case '수호자':
        return guardian != null
            ? '${guardian.name} · 함께 지켜요'
            : '함께 지켜줄 친구를 만나요';
      case '수호자에게 맡기기':
        return '내가 못 오는 날 대신 빌어요';
      case '찾아온 수호자':
        return '받은 마음 · 답례';
      case '옷 갈아입기':
        return '지금 ${room.outfitNow == room.theme ? '테마 의상' : '기본 의상'}';
      case '방 꾸미기':
        return '복주머니로 방을 채워요';
      case '방 분위기':
        return themeInfo != null
            ? '지금 ${themeInfo['glyph']} ${themeInfo['label']}'
            : '지금 자유 방';
      case '배경화면으로 쓰기':
        return '내 소원방을 휴대폰 배경으로';
      case '소원 상점':
        return '수호자 · 옷 · 촛불 · 배경 · 특별 효과';
      case '함께 빌어달라고 하기':
        return room.visibility != Visibility.PRIVATE
            ? '공개 중 · ${room.supportCount}명이 함께'
            : '지금은 나만 봐요';
      case '소원 · 목표 고쳐 쓰기':
        return room.goal != null ? '지금 목표 ${room.goal}일' : '목표 없음';
      default:
        return '';
    }
  }

  // app3/shop.jsx Row on={} 1:1 매핑. API/화면이 없는 3개
  // (수호자에게 맡기기 · 찾아온 수호자 · 소원·목표 고쳐쓰기)는 CareMenuInfo.unimplemented
  // 플래그로 _careRow의 isOpen을 항상 false로 묶어 두기 때문에(사용자 확정
  // "기능 미구현이면 항상 잠김"), 이 default 분기는 열린 상태에서만 호출될 수
  // 있는 onGo를 요구하는 showCareMenuInfoSheet의 '바로 가기' 버튼 경로에서는
  // 실질적으로 호출되지 않는다(항상 잠김 → [기다릴게요] 버튼만 노출). 그래도
  // 안전망으로 남겨 두되, "준비 중" 토스트는 더 이상 띄우지 않는다(잠김
  // 안내창이 이미 "곧 열려요" 문구로 사용자에게 정직하게 보여줬으므로).
  VoidCallback _onGoFor(String key) {
    switch (key) {
      case '수호자':
        return () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CharacterShopScreen()),
          );
        };
      // [Stage 3-A — 대표 결정] ⋯ 「옷 갈아입기」 진입점 — 기존 CharacterShopScreen
      // 대신 새로 분리된 WardrobeScreen으로 연결한다.
      case '옷 갈아입기':
        return () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WardrobeScreen()),
          );
        };
      case '방 꾸미기':
      case '방 분위기':
        return () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DecorScreen()));
        };
      case '배경화면으로 쓰기':
        return () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WallpaperScreen()));
        };
      case '소원 상점':
        return () {
          Navigator.of(context).pop();
          context.read<WishRoomProvider>().requestTab(3);
        };
      case '함께 빌어달라고 하기':
        return () {
          Navigator.of(context).pop();
          widget.openShare();
        };
      case '수호자에게 맡기기':
        return () {
          Navigator.of(context).pop();
          openEntrustSheet(context);
        };
      case '찾아온 수호자':
        return () {
          Navigator.of(context).pop();
          openReceivedSheet(context);
        };
      case '소원 · 목표 고쳐 쓰기':
        return () {
          Navigator.of(context).pop();
          openWishEditSheet(context);
        };
      default:
        return () {};
    }
  }

  Widget _plainRow({
    required String ic,
    required String t,
    required String s,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: WrC.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: WrC.card,
                border: Border.all(color: WrC.cardBorder),
              ),
              child: Text(ic, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t,
                    style: WrF.body(
                      15,
                      w: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    s,
                    style: WrF.body(12, color: WrC.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: WrC.muted),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required String ic,
    required String t,
    required String s,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : .7,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: WrC.card,
                  border: Border.all(color: WrC.cardBorder),
                ),
                child: Text(ic, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t,
                      style: WrF.body(
                        15,
                        w: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      s,
                      style: WrF.body(12, color: WrC.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 44,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: value ? WrC.blossom : Colors.white24,
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 400),
                  curve: const Cubic(.34, 1.56, .64, 1),
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _shareHex(String s) {
  final h = s.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

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
    setState(() {
      _link = link;
      _loadingLink = false;
    });
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
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _nativeShare() async {
    if (_link == null) return;
    await safeShareText(context, '$_shareMessage\n${_link!.url}');
  }

  // [버그수정 — 사용자 리포트: "공유하기 안돼고"] 기존 카카오톡/문자 버튼은
  // 실제로 어떤 앱도 열려는 시도조차 없이 클립보드 복사 + "앱에서
  // 열려요"라는 오해를 부르는 토스트만 띄웠다(눌러도 아무 일도 안 일어나
  // 보여 "안 된다"고 느껴짐). guinji_map_share_screen.dart의
  // shareGuinjiMapInvite() 패턴을 따라, 문자는 `sms:` 스킴으로 실제 문자
  // 앱을 직접 열도록 시도하고(네이티브에서만 — 웹은 스킴 처리 불가해
  // ERR_UNKNOWN_URL_SCHEME로 깨지는 알려진 버그가 있어 곧바로 클립보드
  // 폴백), 카카오톡은 네이티브 공유 시트(navigator.share/Share.share)를
  // 먼저 시도해 대상 목록에 카카오톡이 뜨도록 한다. 모든 경로의 최종
  // 실패 시에만 클립보드 복사로 폴백한다.
  Future<void> _shareSms() async {
    if (_link == null) return;
    final text = '$_shareMessage\n${_link!.url}';
    if (!kIsWeb) {
      try {
        final ok = await launchUrl(
          Uri(scheme: 'sms', path: '', queryParameters: {'body': text}),
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      } catch (_) {
        /* fall through to clipboard */
      }
    }
    await _copy();
    if (!mounted) return;
    WrToast.show(context, '문자 앱을 열 수 없어 링크를 복사했어요 · 문자 앱에 붙여넣어 주세요');
  }

  Future<void> _shareKakao() async {
    if (_link == null) return;
    final text = '$_shareMessage\n${_link!.url}';
    await safeShareText(
      context,
      text,
      copiedMessage: '카카오톡 공유를 열 수 없어 링크를 복사했어요 · 카카오톡에 붙여넣어 주세요',
      failedMessage: '카카오톡 공유를 열 수 없어 링크를 복사했어요 · 카카오톡에 붙여넣어 주세요',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final room = widget.room;
    final w = cat.wishColors.firstWhere(
      (e) => e['id'] == room.wishColor,
      orElse: () => cat.wishColors.first,
    );
    final pp = cat.papers.firstWhere(
      (e) => e['id'] == room.paper,
      orElse: () => cat.papers.first,
    );
    final color = _shareHex(w['color'] as String),
        deep = _shareHex(w['deep'] as String),
        hanja = w['hanja'] as String;
    final bg = (pp['bg'] as List).cast<String>().map(_shareHex).toList();
    final nick = context.watch<WishRoomProvider>().me?.nick ?? '나';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('SHARE · 소원방 공유', style: WrF.mono(size: 10, color: WrC.muted)),
            const SizedBox(height: 4),
            Text('소원방 초대하기', style: WrF.display(18, color: Colors.white)),
            const SizedBox(height: 16),
            // 미리보기 카드 — 받는 사람에게 보이는 모습.
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: WrC.line),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: .2), blurRadius: 20),
                ],
              ),
              child: Column(
                children: [
                  // G-4 RoomThumb — [버그수정 — 전수감사] items:const[] 고정으로 장식이 전혀 반영되지 않던 버그.
                  // [버그수정 — 전수감사] app2/capsule2.jsx › ShareSheet(): `<RoomThumb ... w={342}
                  // h={110} focus={.42} zoom={1.05}/>` — 다른 가로형 카드의 focus/zoom(.22/1.5)이
                  // 복붙되어 있어 크롭 위치/확대율이 원본과 달랐다.
                  SizedBox(
                    height: 110,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, c) => RoomThumb(
                              room: room,
                              items: context.read<WishRoomProvider>().items,
                              w: c.maxWidth,
                              h: 110,
                              focus: .42,
                              zoom: 1.05,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x80000000),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'SINTONG · WISH ROOM',
                              style: WrF.mono(
                                size: 9,
                                color: const Color(0xFFFFE08A),
                              ).copyWith(letterSpacing: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: bg,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: deep,
                          ),
                          child: Text(
                            hanja,
                            style: const TextStyle(
                              fontFamily: 'NotoSerifKR',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFFFFF4E0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$nick님의 소원방 · Lv.${room.level}',
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                  color: Color(0xFF8A6A50),
                                ),
                              ),
                              Text(
                                '"${room.text}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Color(0xFF4A2A1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '누구에게 보여줄까요',
              style: WrF.body(13.5, w: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _visTab('모두에게', Visibility.PUBLIC),
                const SizedBox(width: 6),
                _visTab('링크로만', Visibility.LINK),
                const SizedBox(width: 6),
                _visTab('나만 보기', Visibility.PRIVATE),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _visDesc(_vis),
              style: WrF.body(11.5, color: WrC.muted, height: 1.6),
            ),
            if (_vis == Visibility.PRIVATE) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                decoration: WrDeco.card,
                child: Column(
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 26)),
                    const SizedBox(height: 6),
                    Text(
                      '지금은 나만 볼 수 있는 소원방이에요',
                      style: WrF.body(13, color: WrC.fg),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: WrSize.btnSmH,
                      child: DecoratedBox(
                        decoration: WrDeco.btnPink,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _changeVis(Visibility.LINK),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Center(
                                child: Text(
                                  '링크로만 공개하기',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0x47000000),
                  border: Border.all(
                    color: _copied ? const Color(0xB37FD6A0) : WrC.line,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _loadingLink
                            ? '링크를 만드는 중…'
                            : (_link?.url.replaceFirst('https://', '') ??
                                  '링크를 만드는 중…'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WrF.mono(size: 12, color: WrC.fg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: DecoratedBox(
                        decoration: _copied ? WrDeco.btnDark : WrDeco.btnPink,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _link == null ? null : _copy,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Center(
                                child: Text(
                                  _copied ? '✓ 복사됨' : '링크 복사',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _shareOpt('💬', const Color(0xFFFEE500), '카카오톡', _shareKakao),
                  _shareOpt('✉', const Color(0xFF3FAE55), '문자', _shareSms),
                  _shareOpt('⤴', const Color(0xFF4A7AD8), '더보기', _nativeShare),
                  _shareOpt('⟳', Colors.white12, '새 링크', () => _loadLink(true)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: WrC.line),
                ),
                child: Text(
                  '· 링크를 받은 분은 방을 보고 응원·응원 메시지·복주머니를 보낼 수 있어요.\n· 소원방을 꾸미거나 정성을 들이는 건 나만 할 수 있어요.\n· 링크가 퍼졌다면 새 링크를 누르세요. 이전 링크는 더 이상 열리지 않아요.',
                  style: WrF.body(11.5, color: WrC.muted, height: 1.6),
                ),
              ),
            ],
            if (_copied)
              Container(
                margin: const EdgeInsets.only(top: 10),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xEB14281C),
                  border: Border.all(color: const Color(0x9A7FD6A0)),
                ),
                child: Text(
                  '링크를 복사했어요 · 원하는 곳에 붙여넣어 주세요',
                  style: WrF.body(
                    12,
                    w: FontWeight.w700,
                    color: const Color(0xFFC8F5D4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _visTab(String label, Visibility v) {
    final sel = _vis == v;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeVis(v),
        child: Container(
          height: WrSize.tabH,
          alignment: Alignment.center,
          decoration: sel
              ? WrDeco.tabOn
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(WrR.tab),
                  color: WrC.chipBg,
                ),
          child: Text(
            label,
            style: WrF.body(
              WrSize.tabFont,
              w: FontWeight.w700,
              color: sel ? Colors.white : WrC.muted,
            ),
          ),
        ),
      ),
    );
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

  Widget _shareOpt(String icon, Color bg, String label, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: bg,
                  boxShadow: const [
                    BoxShadow(color: Color(0x59000000), blurRadius: 14),
                  ],
                ),
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
}

/// 복주머니 pill — app2/screens-a2.jsx › PouchPill({onClick: app.openWallet}) 1:1.
/// 탭하면 wallet_sheet.dart를 열고, 금액이 바뀔 때마다(정성·광고보상 등) 0.3초
/// bump(확대 후 복귀) 애니메이션을 재생한다.
// [v5 S2 — 사용자 확정] 레벨바(_levelBar)와 함께 이 바(_ShimmerLevelBar/_ShimmerPainter)를
// 쓰던 레벨/통계 카드를 제거했다. 레벨업 시네마틱(WrLevelUp)은 그대로 유지한다.
class _PouchPillTap extends StatefulWidget {
  const _PouchPillTap({required this.pouch});
  final int pouch;
  @override
  State<_PouchPillTap> createState() => _PouchPillTapState();
}

class _PouchPillTapState extends State<_PouchPillTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
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
  void dispose() {
    _c.dispose();
    super.dispose();
  }

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
          decoration: BoxDecoration(
            color: const Color(0x8C1E0C18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wishroom/items/pouch.png',
                width: 18,
                height: 18,
                errorBuilder: (_, __, ___) =>
                    const Text('💰', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.pouch}',
                style: const TextStyle(
                  fontFamily: 'NotoSerifKR',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 안내서 시트 — CHANGELOG '봉인 안내 문구' GUIDE 섹션(최소 구현).

/// [버그수정 — "내 소원방" 무한 로딩] decor_screen.dart의 `_NoRoom` 패턴을
/// 메인 소원방 화면에도 적용한다. 비로그인(게스트) 사용자가 "다른 소원방
/// 둘러보기"를 거쳐 이 탭으로 돌아왔을 때, 안내 없이 로딩만 영원히 도는
/// 대신 "아직 소원이 담기지 않았어요" 안내와 "첫 소원 담기" CTA를 보여준다.
class _NoRoomMain extends StatelessWidget {
  const _NoRoomMain({required this.onBack, required this.onExitHome});
  final VoidCallback onBack, onExitHome;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image.asset(
              'assets/wishroom/room-lv1.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: WrC.bg2),
            ),
          ),
        ),
        Positioned.fill(child: Container(color: const Color(0x66000000))),
        Positioned(
          left: 14,
          top: 52,
          child: WrNavPill(onBack: onBack, onExitHome: onExitHome),
        ),
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    size: 100,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '아직 소원이 담기지 않았어요',
                    textAlign: TextAlign.center,
                    style: WrF.body(14, color: WrC.muted, height: 1.7),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '첫 소원을 담으면 나만의 소원방이 만들어져요',
                    textAlign: TextAlign.center,
                    style: WrF.body(12.5, color: WrC.muted, height: 1.6),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 200,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ComposeScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WrC.blossom,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '✿ 첫 소원 담기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
